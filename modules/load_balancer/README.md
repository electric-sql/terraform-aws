`load_balancer`
===============

Creates a security group, an application load balancer and a set of listeners needed to route traffic to the sync service's HTTP port. Uses TLS with the certificate given as an argument.

## Example

```hcl
module "vpc" {
  source = "./modules/vpc"
  ...
}

module "ecs_service" {
  source = "./modules/ecs_service"
  ...
}

module "load_balancer" {
  source = "./modules/load_balancer"
  
  vpc_id          = module.vpc.id
  subnet_ids      = module.vpc.public_subnet_ids

  lb_target_group_main  = module.ecs_service.lb_target_group_main
}
```
