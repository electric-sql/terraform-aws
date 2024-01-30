resource "aws_s3_bucket" "web_app" {
  bucket = var.app_bucket_name

  tags = {
    Name = var.app_bucket_name
  }
}

resource "aws_s3_account_public_access_block" "web_app" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
