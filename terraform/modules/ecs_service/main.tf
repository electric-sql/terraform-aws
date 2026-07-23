### Target Groups ###

resource "aws_lb_target_group" "main" {
  name        = var.main_target_group_name
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = 5

  health_check {
    protocol            = "HTTP"
    path                = "/v1/health"
    matcher             = "200"
    timeout             = "3"
    interval            = "30"
    healthy_threshold   = "2"
    unhealthy_threshold = "2"
  }

  tags = {
    Name = var.main_target_group_name
  }
}

### ECS Service ###

resource "aws_security_group" "ecs_sg" {
  name_prefix = var.security_group_name_prefix
  vpc_id      = var.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 3000
    to_port     = 3000
    self        = "false"
    cidr_blocks = var.public_subnet_cidrs
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = var.security_group_name
  }
}

resource "aws_ecs_service" "electric_sync" {
  name                              = var.service_name
  cluster                           = var.cluster_arn
  task_definition                   = var.task_definition.arn
  desired_count                     = 1
  health_check_grace_period_seconds = 60

  # launch_type and capacity_provider_strategy are mutually exclusive:
  # Fargate services set launch_type; EC2 services place tasks via the
  # capacity provider (which manages the ASG).
  launch_type = var.launch_type == "FARGATE" ? "FARGATE" : null

  dynamic "capacity_provider_strategy" {
    for_each = var.launch_type == "EC2" ? [1] : []

    content {
      capacity_provider = var.capacity_provider_name
      weight            = 1
      base              = 1
    }
  }

  # Single-host deployment: stop the old task before starting the new
  # one (the replacement task needs the same host's storage and the
  # replication slot).
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  network_configuration {
    security_groups = [aws_security_group.ecs_sg.id]
    subnets         = var.public_subnet_ids

    # Fargate tasks pull their image via the task ENI, so it needs a
    # public IP. EC2 task ENIs cannot have one (pulls go via the host
    # ENI instead).
    assign_public_ip = var.launch_type == "FARGATE"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.id
    container_name   = var.task_container_name
    container_port   = 3000
  }

  # This is needed to keep terraform from falling into an infinite loop
  # when the task fails to start and is automatically recreated by AWS.
  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Name = var.service_name
  }
}
