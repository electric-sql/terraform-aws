`ecs_task_definition`
=====================

Creates an ECS task definition for Electric sync service using the latest image from Docker Hub by default and the given container environment for configuration.

## Example

```hcl
module "ecs_task_definition" {
  source = "./modules/ecs_task_definition"
  
  awslogs_region = "us-east-1"

  container_environment = [
    {
      name  = "AUTH_MODE"
      value = "insecure"
    },
    {
      name  = "DATABASE_URL"
      value = "postgresql://..."
    },
    {
      name  = "ELECTRIC_WRITE_TO_PG_MODE"
      value = "direct_writes"
    },
    {
      name  = "PG_PROXY_PASSWORD"
      value = var.pg_proxy_password
    }
  ]
}
```
