provider "aws" {
  profile = var.profile
  region  = var.region
}

### VPC

module "vpc" {
  source = "./modules/vpc"

  cidr_block           = var.vpc_cidr_block
  public_subnet_cidr   = var.vpc_public_subnet_cidr
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
      name  = "AUTH_MODE"
      value = "insecure"
    },
    {
      name  = "DATABASE_URL"
      value = module.rds.connection_uri
    },
    {
      name  = "ELECTRIC_WRITE_TO_PG_MODE"
      value = "direct_writes"
    },
    {
      name  = "PG_PROXY_PASSWORD"
      value = var.pg_proxy_password
    }
  ]
}

module "ecs_service" {
  source = "./modules/ecs_service"

  vpc_id              = module.vpc.id
  public_subnet_cidr  = var.vpc_public_subnet_cidr
  public_subnet_id    = module.vpc.public_subnet_id
  task_definition     = module.ecs_task_definition
  task_container_name = var.ecs_task_container_name
}

# You'll have to manually copy the CNAME value from the
# request in AWS console and update your custom domain name's records
# with it to pass the DNS validation.
resource "aws_acm_certificate" "tls_cert" {
  domain_name               = var.tls_cert_domain
  subject_alternative_names = var.tls_cert_aliases
  key_algorithm             = var.tls_cert_key_algorithm
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}


module "load_balancer" {
  source = "./modules/load_balancer"

  vpc_id           = module.vpc.id
  public_subnet_id = module.vpc.public_subnet_id
  tls_certificate  = aws_acm_certificate.tls_cert
  ssl_policy       = var.load_balancer_ssl_policy

  lb_target_group_main  = module.ecs_service.lb_target_group_main
  lb_target_group_proxy = module.ecs_service.lb_target_group_proxy
}

### Frontend

module "s3" {
  source = "./modules/s3"

  app_bucket_name = var.s3_bucket_name
}

module "cloudfront" {
  source = "./modules/cloudfront"

  web_app_bucket            = module.s3.bucket
  tls_certificate           = aws_acm_certificate.tls_cert
  distribution_domain_alias = var.cloudfront_domain
}
