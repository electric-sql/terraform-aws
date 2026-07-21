resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = var.cloudwatch_group_name
  retention_in_days = 1
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = var.task_execution_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role = aws_iam_role.ecs_task_execution_role.name

  # Predefined policy in AWS
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "electric_sync" {
  family                   = var.task_definition_family
  network_mode             = "awsvpc"
  requires_compatibilities = [var.launch_type]
  cpu                      = var.task_cpu
  memory                   = var.task_memory

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  # On EC2 the shape-log storage is a bind mount from the host's
  # bootstrap-formatted data disk (see modules/ecs_ec2_capacity).
  # Data survives task restarts; Electric rebuilds it from Postgres
  # if the host is replaced.
  dynamic "volume" {
    for_each = var.launch_type == "EC2" ? [1] : []

    content {
      name      = "electric-data"
      host_path = "/mnt/nvme/electric/${var.instance_label}"
    }
  }

  container_definitions = jsonencode([
    {
      essential = true

      name  = var.container_name
      image = "docker.io/electricsql/electric:${var.docker_image_tag}"

      portMappings = [
        {
          name          = "http"
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      mountPoints = var.launch_type == "EC2" ? [
        {
          sourceVolume  = "electric-data"
          containerPath = "/var/lib/electric"
        }
      ] : []

      environment = concat(
        var.container_environment,
        var.launch_type == "EC2" ? [
          {
            name  = "ELECTRIC_STORAGE_DIR"
            value = "/var/lib/electric"
          }
        ] : []
      )

      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-create-group"  = "true"
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_log_group.name
          "awslogs-region"        = var.awslogs_region
          "awslogs-stream-prefix" = var.awslogs_stream_prefix
        }
      }
    }
  ])
}
