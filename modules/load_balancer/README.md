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

resource "aws_acm_certificate" "tls_cert" {
  domain_name               = "my.custom.domain.com"
  key_algorithm             = "EC_prime256v1"
  validation_method         = "DNS"
}

module "load_balancer" {
  source = "./modules/load_balancer"
  
  vpc_id          = module.vpc.id
  subnet_ids      = module.vpc.public_subnet_ids
  tls_certificate = aws_acm_certificate.tls_cert

  lb_target_group_main  = module.ecs_service.lb_target_group_main
}
```
