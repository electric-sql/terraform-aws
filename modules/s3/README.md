`s3`
====

Creates a bucket with no public access. Suitable for use as a CloudFront distribution's origin.

## Example

```hcl
module "s3" {
  source = "./modules/s3"

  app_bucket_name = "electric-aws-example-app-bucket"
}
```
