variable "profile" {
  description = "AWS CLI profile to use when authenticating with AWS API"
}
variable "region" {
  description = "AWS region to stand up the infra in"
}

variable "vpc_cidr_block" {
  description = "Address space for the VPC, in CIDR notation"
}

variable "vpc_private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets. These subnets will be assigned to the RDS subnet group"
}

variable "vpc_public_subnet_cidr" {
  description = "CIDR block for the single public subnet to run the ECS task in"
}

variable "rds_username" {
  description = "Name for the main database role"
}

variable "rds_password" {
  description = "Password for the main database role"
}

variable "rds_db_name" {
  description = "Name for the new database"
}

variable "docker_image_tag" {
  description = "Image tag of the electricsql/electric image to use for the ECS task"
  default     = "latest"
}

variable "ecs_task_container_name" {
  description = "Name of the container in ecs_task_definition"
}

variable "pg_proxy_password" {
  description = "Password for Electric's Migrations proxy"
}

variable "tls_cert_domain" {
  description = "Primary domain name in the certificate"
  # Intended to be used as the domain name of your web app.
  #
  # Add a CNAME record containing the CloudFront distribution domain, for example,
  #
  #   CNAME  example.com  dcg4fctrf2vrb.cloudfront.net
}

variable "tls_cert_aliases" {
  description = "List of Subject Alternative Names in the certificate. May contain wildcard domains."
  # An alias is intended to be used as the domain name of the sync service.
  #
  # Add a CNAME record containing the Load Balancer domain, for example,
  #
  #   CNAME  sync.example.com  electric-lb-02a4e5802150763f.elb.us-east-1.amazonaws.com
}

variable "tls_cert_key_algorithm" {
  description = "Key generation algorithm to use for the certificate's key"
  default     = "EC_prime256v1"
}

variable "load_balancer_ssl_policy" {
  description = "SSL Policy to use for the Network Load Balancer"
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for hosting the web app's assets"
}

variable "cloudfront_domain" {
  description = "Domain name to use for the CloudFront distribution's 'Alternate domain names'. Usually the same value as tls_cert_domain."
}
