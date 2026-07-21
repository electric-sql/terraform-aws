output "capacity_provider_name" {
  description = "Name of the ECS capacity provider — use in the service's capacity_provider_strategy"
  value       = aws_ecs_capacity_provider.this.name
}

output "instance_security_group_id" {
  description = "Security group attached to the container instances"
  value       = aws_security_group.instance.id
}

output "autoscaling_group_name" {
  description = "Name of the autoscaling group running the container instances"
  value       = aws_autoscaling_group.this.name
}
