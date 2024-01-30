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
