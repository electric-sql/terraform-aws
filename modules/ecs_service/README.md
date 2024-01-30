`ecs_service`
=============

Creates an ECS service using the given task definition, running in the given VPC. Also creates target groups with health checks for the two public ports of the Electric sync service.

## Example

```hcl
module "vpc" {
  source = "./modules/vpc"
  ...
}

module "ecs_task_definition" {
  source = "./modules/ecs_task_definition"
  ...
}

module "ecs_service" {
  source = "./modules/ecs_service"
  
  vpc_id             = module.vpc.id
  public_subnet_cidr = var.public_subnet_cidr
  public_subnet_id   = module.vpc.public_subnet_id
  task_definition    = module.ecs_task_definition
}
```
