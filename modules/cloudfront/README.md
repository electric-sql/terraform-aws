`cloudfront`
============

Creates a CloudFront distribution with an S3 bucket as its sole origin. Can be configured with a custom domain and TLS certificate.

## Example

```hcl
module "s3" {
  source = "./modules/s3"

  app_bucket_name = "electric-aws-example-app-bucket"
}

resource "aws_acm_certificate" "tls_cert" {
  domain_name       = "my.example.com"
  key_algorithm     = "EC_prime256v1"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

module "cloudfront" {
  source = "./modules/cloudfront"

  app_bucket      = module.s3.app_bucket
  tls_certificate = aws_acm_certificate.tls_cert
}
```
