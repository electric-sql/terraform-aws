output "distribution_domain" {
  description = "DNS name of the created CloudFront distribution"
  value       = aws_cloudfront_distribution.web_app.domain_name
}
