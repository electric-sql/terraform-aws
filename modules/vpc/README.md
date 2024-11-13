`vpc`
=====

Creates a VPC and some private and public subnets in different availability zones. The number of subnets is determined by the `private_subnet_cidrs` and `public_subnet_cidrs` variables. Note that at least two private subnets are required by RDS and at least two public ones are needed to create an application load balancer.

## Example

```hcl
module "vpc" {
  source = "./modules/vpc"

  cidr_block           = "10.0.0.0/24"
  private_subnet_cidrs = ["10.0.0.0/28", "10.0.0.16/28"]
  public_subnet_cidrs  = ["10.0.0.32/28", "10.0.0.48/28"]
}
```
