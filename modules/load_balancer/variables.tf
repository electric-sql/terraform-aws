variable "vpc_id" {
  description = "ID of the VPC created in the root module"
}

variable "subnet_ids" {
  description = "List of subnets IDs for the load balancer. These subnets must be from at leat two AZs."
}

variable "ssl_policy" {
  description = "SSL policy"
}

variable "tls_certificate" {
  description = "An aws_certificate_request object"
}

variable "lb_target_group_main" {
  description = "HTTP target group"
}

variable "security_group_name_prefix" {
  description = "Name prefix to use for the 'Security group name' attribute"
  default     = "electric-lb-"
}

variable "security_group_name" {
  description = "Name of the security group created for the Load Balancer"
  default     = "Electric Load Balancer security group"
}

variable "load_balancer_name" {
  description = "Name of the Load Balancer"
  default     = "electric-lb"
}

variable "http_listener_name" {
  description = "Name of the HTTP listener"
  default     = "electric-http-listener"
}

variable "https_listener_name" {
  description = "Name of the HTTPS listener"
  default     = "electric-https-listener"
}
