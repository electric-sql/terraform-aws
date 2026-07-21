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

variable "vpc_public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets. These subnets will be used by the application load balancer"
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

variable "tls_certificate_arn" {
  description = "ARN of the certificate to use with the HTTPS listener of the application load balancer"
}
