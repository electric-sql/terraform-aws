variable "web_app_bucket" {
  description = "S3 bucket to use as the origin"
}

variable "tls_certificate" {
  description = "aws_certificate_request object"
}

variable "distribution_domain_alias" {
  description = "Domain name to use as an alias for the distribution"
}

variable "origin_access_control_name" {
  description = "Name of the default origin access control"
  default     = "Electric Origin Access Control"
}

variable "distribution_name" {
  description = "Name of the distribution"
  default     = "Electric S3-backed web app"
}
