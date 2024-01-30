variable "vpc_id" {
  description = "ID of the VPC created in the root module"
}

variable "public_subnet_id" {
  description = "The public subnet where the load balancer wil be running"
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

variable "lb_target_group_proxy" {
  description = "TCP target group for the Migrations proxy"
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

variable "proxy_listener_name" {
  description = "Name of the TCP/TLS listener for the Migrations proxy"
  default     = "electric-proxy-listener"
}
