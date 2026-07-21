variable "docker_image_tag" {
  description = "Tag to use when pulling the electricsql/electric image from Docker Hub"
}

variable "container_environment" {
  description = "Configuration for the sync service"
}

variable "awslogs_region" {
  description = "The AWS region to send CloudWatch logs to"
}

variable "awslogs_stream_prefix" {
  description = "Stream prefix to use in task's logs"
  default     = "electric-sync"
}

variable "cloudwatch_group_name" {
  description = "Name of the CloudWatch log group to create"
  default     = "/ecs/electric-sync"
}

variable "task_execution_role_name" {
  description = "Name of the task execution role"
  default     = "electric-task-execution-role"
}

variable "task_definition_family" {
  description = "Name of the task definition family"
  default     = "electric-sync"
}

variable "container_name" {
  description = "Name of the sole container that runs as part of the task"
  default     = "electric-sync"
}

variable "launch_type" {
  description = "ECS launch type the task definition targets: FARGATE or EC2"
  type        = string
  default     = "FARGATE"

  validation {
    condition     = contains(["FARGATE", "EC2"], var.launch_type)
    error_message = "launch_type must be FARGATE or EC2."
  }
}

variable "task_cpu" {
  description = "Task CPU units (1024 = 1 vCPU). For EC2, size to the host: full vCPUs minus nothing (CPU is compressible)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Task memory in MiB. For EC2, size to the host total minus ~2048 MiB for the OS, Docker and ECS agent"
  type        = number
  default     = 512
}

variable "instance_label" {
  description = "Label used in the host data directory path (/mnt/nvme/electric/<label>). Must match the ecs_ec2_capacity module's instance_label"
  type        = string
  default     = "main"
}
