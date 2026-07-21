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

variable "electric_secret" {
  description = "Value for ELECTRIC_SECRET, used to authenticate api requests to Electric"
  sensitive   = true
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  default     = "electric-cluster"
}

variable "launch_type" {
  description = "How to run the Electric task: FARGATE (simplest) or EC2 (persistent NVMe/EBS storage)"
  type        = string
  default     = "FARGATE"

  validation {
    condition     = contains(["FARGATE", "EC2"], var.launch_type)
    error_message = "launch_type must be FARGATE or EC2."
  }
}

variable "ec2_instance_type" {
  description = "EC2 instance type when launch_type is EC2. i4i/m6id types have local NVMe instance store; pair m6a/m6i/m7a/m7i with ec2_data_storage.kind = \"ebs-gp3\""
  type        = string
  default     = "m6id.large"
}

variable "ec2_data_storage" {
  description = "Storage backing for the Electric data dir when launch_type is EC2"
  type = object({
    kind            = string
    size_gb         = optional(number, 100)
    iops            = optional(number, 3000)
    throughput_mbps = optional(number, 125)
  })
  default = {
    kind = "nvme"
  }
}

variable "ec2_task_cpu" {
  description = "Task CPU units when launch_type is EC2. Size to the host, e.g. 2048 for the 2-vCPU m6id.large"
  type        = number
  default     = 2048
}

variable "ec2_task_memory" {
  description = "Task memory (MiB) when launch_type is EC2. Host total minus ~2048 MiB reserved for OS/Docker/ECS agent, e.g. 6144 for the 8 GiB m6id.large"
  type        = number
  default     = 6144
}
