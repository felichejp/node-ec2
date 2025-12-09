module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "postgres-sg"
  description = "Security group for PostgreSQL"
  vpc_id      = var.vpc_id

  # Allow ingress from VPC CIDR
  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access from within VPC"
      cidr_blocks = var.vpc_cidr_block
    },
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access from internet"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
}

module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "demodb"

  snapshot_identifier = var.snapshot_identifier

  engine               = "postgres"
  engine_version       = "16.8"
  family               = "postgres16"
  major_engine_version = "16.8"
  instance_class       = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name  = "demodb"
  username = var.db_username
  password = var.db_password
  port     = 5432

  manage_master_user_password = false

  publicly_accessible = true

  create_db_subnet_group = true
  subnet_ids             = var.subnets

  vpc_security_group_ids = [module.security_group.security_group_id]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  # Disable backups to create DB faster
  backup_retention_period = 0

  skip_final_snapshot = true

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
