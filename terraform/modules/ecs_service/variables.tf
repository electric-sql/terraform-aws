variable "vpc_id" {
  description = "ID of the VPC created in the root module"
}

variable "public_subnet_cidrs" {
  description = "Address space of the public subnet, in CIDR notation"
}

variable "public_subnet_ids" {
  description = "IDs of public subnets which the ECS service will run in"
}

variable "task_definition" {
  description = "The task definition to run as part of the ECS service"
}

variable "security_group_name_prefix" {
  description = "Name prefix to use for the 'Security group name' attribute"
  default     = "electric-ecs-"
}

variable "security_group_name" {
  description = "Name of the security group created for the ECS cluster"
  default     = "Electric ECS security group"
}

variable "service_name" {
  description = "Name of the Electric ECS service"
  default     = "electric-sync"
}

variable "task_container_name" {
  description = "Name of the container defined in the 'ecs_task_definition' module"
}

variable "main_target_group_name" {
  description = "Name of the target group for the HTTP endpoint"
  default     = "electric-main"
}

variable "proxy_target_group_name" {
  description = "Name of the target group for the Migrations proxy TCP endpoint"
  default     = "electric-proxy"
}

variable "cluster_arn" {
  description = "ARN of the ECS cluster (created in the root module) to run the service in"
  type        = string
}

variable "launch_type" {
  description = "ECS launch type: FARGATE or EC2"
  type        = string
  default     = "FARGATE"

  validation {
    condition     = contains(["FARGATE", "EC2"], var.launch_type)
    error_message = "launch_type must be FARGATE or EC2."
  }
}

variable "capacity_provider_name" {
  description = "Capacity provider to place tasks on when launch_type is EC2 (from the ecs_ec2_capacity module)"
  type        = string
  default     = null
}
