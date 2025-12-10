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
    
    # 1. Wait for metadata service to be available
    echo "Waiting for metadata service..."
    for i in {1..30}; do
      if curl -s --max-time 2 http://169.254.169.254/latest/meta-data/instance-id > /dev/null 2>&1; then
        echo "✅ Metadata service is available"
        break
      fi
      sleep 2
    done
    
    # 2. Get region from metadata (with retry)
    AWS_REGION=""
    for i in {1..10}; do
      AWS_REGION=$(curl -s --max-time 5 http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo "")
      if [ -n "$${AWS_REGION}" ]; then
        echo "Region: $${AWS_REGION}"
        break
      fi
      sleep 2
    done
    
    if [ -z "$${AWS_REGION}" ]; then
      echo "⚠️  Could not get region from metadata, defaulting to us-east-1"
      AWS_REGION="us-east-1"
    fi
    export AWS_REGION
    
    # 3. Expand filesystem
    echo "Expanding filesystem..."
    if command -v growpart > /dev/null 2>&1; then
      growpart /dev/nvme0n1 1 || true
      if command -v xfs_growfs > /dev/null 2>&1; then
        xfs_growfs / || true
      elif command -v resize2fs > /dev/null 2>&1; then
        resize2fs /dev/nvme0n1p1 || true
      fi
    fi
    
    # 4. Update system
    echo "Updating system..."
    dnf update -y || yum update -y || true
    
    # 5. Install SSM Agent (critical - must succeed)
    echo "Installing SSM Agent..."
    if ! dnf install -y amazon-ssm-agent 2>/dev/null; then
      if ! yum install -y amazon-ssm-agent 2>/dev/null; then
        echo "ERROR: Failed to install SSM Agent"
        exit 1
      fi
    fi
    
    # 6. Install Podman (from EPEL or use Docker as fallback)
    echo "Installing container runtime..."
    if dnf install -y epel-release 2>/dev/null; then
      dnf install -y podman 2>/dev/null || echo "⚠️  Podman not available, will use Docker"
    fi
    
    # If podman not available, try Docker
    if ! command -v podman > /dev/null 2>&1; then
      echo "Installing Docker as fallback..."
      dnf install -y docker 2>/dev/null || yum install -y docker 2>/dev/null || echo "⚠️  Docker also not available"
      if command -v docker > /dev/null 2>&1; then
        systemctl enable docker
        systemctl start docker
      fi
    fi
    
    # 7. Configure SSM Agent
    echo "Configuring SSM Agent..."
    systemctl enable amazon-ssm-agent
    systemctl restart amazon-ssm-agent
    
    # Wait for SSM Agent to start
    echo "Waiting for SSM Agent to start..."
    for i in {1..12}; do
      if systemctl is-active --quiet amazon-ssm-agent; then
        echo "✅ SSM Agent is running"
        break
      fi
      sleep 5
      if [ $i -eq 12 ]; then
        echo "⚠️  SSM Agent may not be running, but continuing..."
      fi
    done
    
    # 8. Enable Podman socket if available
    if command -v podman > /dev/null 2>&1; then
      echo "Configuring Podman..."
      systemctl enable podman.socket || true
      systemctl start podman.socket || true
    fi
    
    # 9. Create update-container script
    echo "Creating update-container script..."
    cat > /opt/update-container.sh <<'SCRIPT_EOF'
    ${file("${path.module}/update-container.sh")}
    SCRIPT_EOF
    
    chmod +x /opt/update-container.sh
    
    # 10. Verify SSM Agent status
    echo "=== SSM Agent Status ==="
    systemctl status amazon-ssm-agent --no-pager -l || true
    
    # 11. Initial Run (skip if SSM not ready - will be deployed later via CodeBuild)
    echo "=== Bootstrap completed ==="
    echo "SSM Agent installation complete. It may take a few minutes to register with Systems Manager."
    echo "Check status with: systemctl status amazon-ssm-agent"
  EOF
  )

  tags = {
    Terraform   = "true"
    Environment = "dev"
    Name        = var.instance_name
  }
}
