output "arn" {
  description = "ARN of the new task definition"
  value       = aws_ecs_task_definition.electric_sync.arn
}
