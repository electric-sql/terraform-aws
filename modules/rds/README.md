`rds`
=====

Creates a security group, a subnet group using the input list of subnets, a parameter group to enable logical replication, and a PostgreSQL instance.

## Example

```hcl
module "vpc" {
  source = "./modules/vpc"
  ...
}

module "rds" {
  source = "./modules/rds"

  vpc_id             = module.vpc.id
  private_subnet_ids = module.vpc.private_subnet_ids

  db_name     = "app_db"
  db_username = "postgres"
  db_password = var.db_password
}
```
