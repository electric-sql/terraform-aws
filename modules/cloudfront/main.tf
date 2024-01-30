locals {
  origin_id = "web-app-bucket"
}

resource "aws_cloudfront_origin_access_control" "default" {
  origin_access_control_origin_type = "s3"

  name             = var.origin_access_control_name
  signing_behavior = "always"
  signing_protocol = "sigv4"
}

resource "aws_cloudfront_distribution" "web_app" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  comment             = "CloudFront distribution for the S3-backed web app"

  aliases = [var.distribution_domain_alias]

  origin {
    domain_name              = var.web_app_bucket.bucket_regional_domain_name
    origin_id                = local.origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
  }

  default_cache_behavior {
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.origin_id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = var.tls_certificate.arn
    ssl_support_method  = "sni-only"
  }

  tags = {
    Name = var.distribution_name
  }
}

data "aws_iam_policy_document" "web_app_bucket" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${var.web_app_bucket.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudfront_distribution.web_app.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "web_app_bucket_policy" {
  bucket = var.web_app_bucket.id
  policy = data.aws_iam_policy_document.web_app_bucket.json
}
