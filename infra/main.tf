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

module "alb" {
  source = "./modules/alb"

  project_name          = var.project_name
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.vpc.security_group_ids["alb"]
}

module "iam" {
  source = "./modules/iam"

  project_name            = var.project_name
  aws_region              = var.aws_region
  repository_arns         = module.ecr.repository_arns
  queue_arn               = module.sqs.queue_arn
  database_url_secret_arn = module.database.database_url_secret_arn
}

module "ecs" {
  source = "./modules/ecs"

  project_name = var.project_name
  aws_region   = var.aws_region
  image_tag    = var.image_tag

  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = module.vpc.security_group_ids

  repository_urls = module.ecr.repository_urls
  queue_url       = module.sqs.queue_url

  database_url_secret_arn = module.database.database_url_secret_arn
  redis_url               = module.database.redis_url

  alb_dns_name               = module.alb.alb_dns_name
  api_target_group_arn       = module.alb.api_target_group_arn
  dashboard_target_group_arn = module.alb.dashboard_target_group_arn

  execution_role_arn   = module.iam.execution_role_arn
  api_task_role_arn    = module.iam.api_task_role_arn
  worker_task_role_arn = module.iam.worker_task_role_arn

  depends_on = [module.alb]
}
