output "capacity_provider_name" {
  description = "Name of the ECS capacity provider — use in the service's capacity_provider_strategy. Derived from the cluster association so consumers wait for it"
  value       = one(aws_ecs_cluster_capacity_providers.this.capacity_providers)
}

output "instance_security_group_id" {
  description = "Security group attached to the container instances"
  value       = aws_security_group.instance.id
}

output "autoscaling_group_name" {
  description = "Name of the autoscaling group running the container instances"
  value       = aws_autoscaling_group.this.name
}
