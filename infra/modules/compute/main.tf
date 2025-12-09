data "aws_ami" "amazon_linux_2023" {
  count       = var.custom_ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }
}

locals {
  ami_id = var.custom_ami_id != "" ? var.custom_ami_id : data.aws_ami.amazon_linux_2023[0].id
}

resource "aws_security_group" "server_sg" {
  name        = "${var.instance_name}-sg"
  description = "Security group for ${var.instance_name} instance"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Application port"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.instance_name}-sg"
    Terraform = "true"
  }
}

module "iam_assumable_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role             = true
  create_instance_profile = true

  role_name         = "ec2_ssm_role"
  role_requires_mfa = false

  trusted_role_services = [
    "ec2.amazonaws.com"
  ]

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]

  tags = {
    Terraform = "true"
  }
}

resource "aws_iam_role_policy" "ecr_access" {
  name = "ecr-access-policy"
  role = module.iam_assumable_role.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.0"

  name = var.instance_name

  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.server_sg.id]

  associate_public_ip_address = true

  iam_instance_profile = module.iam_assumable_role.iam_instance_profile_name

  root_block_device = [
    {
      volume_type = "gp3"
      volume_size = 20
      encrypted   = false
    }
  ]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    
    echo "=== Preparing EC2 instance ==="
    
    # Expand filesystem if volume was resized
    echo "Checking and expanding filesystem if needed..."
    if command -v growpart > /dev/null 2>&1; then
      growpart /dev/nvme0n1 1 || true
      if command -v xfs_growfs > /dev/null 2>&1; then
        xfs_growfs / || true
      elif command -v resize2fs > /dev/null 2>&1; then
        resize2fs /dev/nvme0n1p1 || true
      fi
    fi
    
    # Update system
    dnf update -y || yum update -y
    
    # Verify SSM Agent is running (should be preinstalled in custom AMI)
    echo "Verifying SSM Agent..."
    if ! systemctl is-active --quiet amazon-ssm-agent; then
      echo "SSM Agent not running, installing..."
      dnf install -y amazon-ssm-agent || yum install -y amazon-ssm-agent || true
      systemctl enable amazon-ssm-agent
      systemctl start amazon-ssm-agent
    else
      echo "SSM Agent is running"
    fi
    
    # Verify Docker is installed and running (should be preinstalled in custom AMI)
    echo "Verifying Docker..."
    if ! command -v docker > /dev/null 2>&1; then
      echo "Docker not found, installing..."
      dnf install -y docker || yum install -y docker
      systemctl enable docker
      systemctl start docker
      sleep 5
    fi
    
    # Ensure Docker service is running
    if ! systemctl is-active --quiet docker; then
      echo "Starting Docker service..."
      systemctl enable docker
      systemctl start docker
      sleep 5
    fi
    
    # Verify Docker is working
    if systemctl is-active --quiet docker; then
      echo "Docker is running"
      docker --version || echo "Docker version check failed"
    else
      echo "Warning: Docker service may not be running"
    fi
    
    # Ensure ec2-user is in docker group
    if getent group docker > /dev/null 2>&1; then
      usermod -a -G docker ec2-user || true
    fi
    
    echo "=== Logging into ECR ==="
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    ECR_REGISTRY=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
    
    # Login to ECR
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY || \
    aws ecr get-login-password --region $AWS_REGION | podman login --username AWS --password-stdin $ECR_REGISTRY
    
    echo "=== Pulling and running container ==="
    REPOSITORY_URI=$ECR_REGISTRY/image-services
    
    # Pull the server image
    echo "Pulling image: $REPOSITORY_URI:server"
    docker pull $REPOSITORY_URI:server || podman pull $REPOSITORY_URI:server
    
    # Stop and remove existing container if it exists
    docker stop service-app || podman stop service-app || true
    docker rm service-app || podman rm service-app || true
    
    # Run the container
    echo "Starting container..."
    docker run -d \
      -p 80:8080 \
      -p 8080:8080 \
      --name service-app \
      --restart unless-stopped \
      $REPOSITORY_URI:server || \
    podman run -d \
      -p 80:8080 \
      -p 8080:8080 \
      --name service-app \
      --restart unless-stopped \
      $REPOSITORY_URI:server
    
    echo "=== Container deployment completed ==="
    docker ps || podman ps
  EOF
  )

  tags = {
    Terraform   = "true"
    Environment = "dev"
    Name        = var.instance_name
  }
}
