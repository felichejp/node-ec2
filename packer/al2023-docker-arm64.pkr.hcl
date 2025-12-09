packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "ami_name_prefix" {
  type    = string
  default = "al2023-docker-arm64"
}

source "amazon-ebs" "al2023_docker" {
  ami_name      = "${var.ami_name_prefix}-{{timestamp}}"
  instance_type = "t4g.small"
  region        = var.aws_region
  source_ami_filter {
    filters = {
      name                = "al2023-ami-*-arm64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  ssh_username = "ec2-user"
  
  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name        = "${var.ami_name_prefix}-{{timestamp}}"
    CreatedBy   = "Packer"
    BaseAMI     = "al2023-arm64"
    Docker      = "preinstalled"
  }
}

build {
  name = "al2023-docker-arm64"
  sources = [
    "source.amazon-ebs.al2023_docker"
  ]

  provisioner "shell" {
    inline = [
      "sudo dnf update -y",
      "sudo dnf install -y docker",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo usermod -a -G docker ec2-user",
      "sudo dnf install -y amazon-ssm-agent",
      "sudo systemctl enable amazon-ssm-agent",
      "sudo systemctl start amazon-ssm-agent",
      "sudo docker --version",
      "echo 'Docker and SSM Agent installed successfully'"
    ]
  }

  post-processor "manifest" {
    output     = "packer-manifest.json"
    strip_path = true
  }
}

