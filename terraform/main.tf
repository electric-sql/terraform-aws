provider "aws" {
  profile = var.profile
  region  = var.region
}

### VPC

module "vpc" {
  source = "./modules/vpc"

  cidr_block           = var.vpc_cidr_block
  public_subnet_cidrs  = var.vpc_public_subnet_cidrs
  private_subnet_cidrs = var.vpc_private_subnet_cidrs
}

### Database

module "rds" {
  source = "./modules/rds"

  vpc_id             = module.vpc.id
  private_subnet_ids = module.vpc.private_subnet_ids

  db_username = var.rds_username
  db_password = var.rds_password
  db_name     = var.rds_db_name
}

### Backend

module "ecs_task_definition" {
  source = "./modules/ecs_task_definition"

  docker_image_tag = var.docker_image_tag
  awslogs_region   = var.region

  container_name = var.ecs_task_container_name

  container_environment = [
    {
      name  = "LOG_LEVEL"
      value = "info"
    },
    {
      name  = "DATABASE_URL"
      value = module.rds.connection_uri
    },
    {
      name  = "ELECTRIC_INSTANCE_ID"
      value = "terraform-aws-test-instance"
    },
    {
      name  = "PROMETHEUS_PORT"
      value = "4000"
    }
  ]
}

module "ecs_service" {
  source = "./modules/ecs_service"

  vpc_id              = module.vpc.id
  public_subnet_cidrs = var.vpc_public_subnet_cidrs
  public_subnet_ids   = module.vpc.public_subnet_ids
  task_definition     = module.ecs_task_definition
  task_container_name = var.ecs_task_container_name
}

module "load_balancer" {
  source = "./modules/load_balancer"

  vpc_id              = module.vpc.id
  subnet_ids          = module.vpc.public_subnet_ids
  tls_certificate_arn = var.tls_certificate_arn

  lb_target_group_main = module.ecs_service.lb_target_group_main
}
