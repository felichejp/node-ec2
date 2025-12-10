data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }
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

  ami                    = data.aws_ami.amazon_linux_2023.id
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
    
    echo "=== Bootstrapping EC2 instance ==="
    
    # 1. Expand filesystem
    if command -v growpart > /dev/null 2>&1; then
      growpart /dev/nvme0n1 1 || true
      if command -v xfs_growfs > /dev/null 2>&1; then
        xfs_growfs / || true
      elif command -v resize2fs > /dev/null 2>&1; then
        resize2fs /dev/nvme0n1p1 || true
      fi
    fi
    
    # 2. Update & Install dependencies
    dnf update -y || yum update -y
    dnf install -y podman amazon-ssm-agent || yum install -y podman amazon-ssm-agent
    
    # Enable Podman socket (optional, good for Docker API compatibility)
    systemctl enable podman.socket
    systemctl start podman.socket
    
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    
    # 3. Create update-container script
    cat > /opt/update-container.sh <<'SCRIPT_EOF'
    ${file("${path.module}/update-container.sh")}
    SCRIPT_EOF
    
    chmod +x /opt/update-container.sh
    
    # 4. Initial Run
    echo "=== Running initial deployment ==="
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    ECR_REGISTRY="$${AWS_ACCOUNT_ID}.dkr.ecr.$${AWS_REGION}.amazonaws.com"
    REPO_URI="$${ECR_REGISTRY}/image-services"
    
    /opt/update-container.sh "$REPO_URI" "server"
    
    echo "=== Bootstrap completed ==="
  EOF
  )

  tags = {
    Terraform   = "true"
    Environment = "dev"
    Name        = var.instance_name
  }
}
