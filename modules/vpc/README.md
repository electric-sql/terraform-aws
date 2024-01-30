`vpc`
=====

Creates a VPC, two private subnets in two availability zones and one public subnet.

## Example

```hcl
module "vpc" {
  source = "./modules/vpc"

  cidr_block           = "10.0.0.0/24"
  private_subnet_cidrs = ["10.0.0.0/28", "10.0.0.16/28"]
  public_subnet_cidr   = "10.0.0.32/28"
}
```
