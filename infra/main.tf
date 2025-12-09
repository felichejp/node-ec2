provider "aws" {
  region = "us-east-1"
}

module "networking" {
  source = "./modules/networking"

  vpc_name         = var.vpc_name
  vpc_cidr         = var.vpc_cidr
  azs              = var.azs
  private_subnets  = var.private_subnets
  public_subnets   = var.public_subnets
  database_subnets = var.database_subnets
}

# module "database" {
#   source = "./modules/database"

#   vpc_id         = module.networking.vpc_id
#   vpc_cidr_block = module.networking.vpc_cidr_block
#   subnets        = module.networking.database_subnets

#   snapshot_identifier = var.snapshot_identifier
#   db_username         = var.db_username
#   db_password         = var.db_password
# }

# module "compute" {
#   source = "./modules/compute"

#   instance_name      = var.instance_name
#   instance_type      = var.instance_type
#   subnet_id          = module.networking.private_subnets[0]
#   security_group_ids = [module.database.security_group_id]
# }

module "cicd" {
  source = "./modules/cicd"

  bucket_name = var.bucket_name
  folders     = var.folders
}
