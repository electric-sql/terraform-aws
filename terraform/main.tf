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

resource "aws_ecs_cluster" "main" {
  name = var.ecs_cluster_name

  tags = {
    Name = var.ecs_cluster_name
  }
}

module "ecs_ec2_capacity" {
  count  = var.launch_type == "EC2" ? 1 : 0
  source = "./modules/ecs_ec2_capacity"

  cluster_name  = aws_ecs_cluster.main.name
  vpc_id        = module.vpc.id
  subnet_ids    = module.vpc.public_subnet_ids
  instance_type = var.ec2_instance_type
  data_storage  = var.ec2_data_storage
}

module "ecs_task_definition" {
  source = "./modules/ecs_task_definition"

  docker_image_tag = var.docker_image_tag
  awslogs_region   = var.region

  container_name = var.ecs_task_container_name

  launch_type = var.launch_type
  task_cpu    = var.launch_type == "EC2" ? var.ec2_task_cpu : 256
  task_memory = var.launch_type == "EC2" ? var.ec2_task_memory : 512

  container_environment = [
    {
      name  = "ELECTRIC_LOG_LEVEL"
      value = "info"
    },
    {
      name  = "DATABASE_URL"
      value = module.rds.connection_uri
    },
    {
      name  = "ELECTRIC_SECRET"
      value = var.electric_secret
    },
    {
      name  = "ELECTRIC_INSTANCE_ID"
      value = "electric-aws-example"
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

  cluster_arn            = aws_ecs_cluster.main.arn
  launch_type            = var.launch_type
  capacity_provider_name = var.launch_type == "EC2" ? module.ecs_ec2_capacity[0].capacity_provider_name : null
}

module "load_balancer" {
  source = "./modules/load_balancer"

  vpc_id              = module.vpc.id
  subnet_ids          = module.vpc.public_subnet_ids
  tls_certificate_arn = var.tls_certificate_arn

  lb_target_group_main = module.ecs_service.lb_target_group_main
}
