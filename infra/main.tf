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

module "compute" {
  source = "./modules/compute"

  instance_name = "server"
  instance_type = "t4g.small"
  subnet_id     = module.networking.public_subnets[0]
  vpc_id        = module.networking.vpc_id
}

module "s3" {
  source = "./modules/s3"

  bucket_name = var.bucket_name
  folders     = var.folders
}

module "ecr" {
  source = "./modules/ecr"
}

module "cicd" {
  source = "./modules/cicd"

  bucket_id     = module.s3.bucket_id
  bucket_arn    = module.s3.bucket_arn
  base_repo_url = module.ecr.base_repo_url
}
