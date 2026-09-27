module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  aws_region   = var.aws_region
}

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
}

module "sqs" {
  source       = "./modules/sqs"
  project_name = var.project_name
}

module "database" {
  source = "./modules/database"

  project_name            = var.project_name
  private_subnet_ids      = module.vpc.private_subnet_ids
  rds_security_group_id   = module.vpc.security_group_ids["rds"]
  redis_security_group_id = module.vpc.security_group_ids["redis"]
}
