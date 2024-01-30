### Target Groups ###

resource "aws_lb_target_group" "main" {
  name        = var.main_target_group_name
  port        = 80
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = 5

  health_check {
    protocol            = "HTTP"
    port                = 5133
    path                = "/api/status"
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

resource "aws_lb_target_group" "proxy" {
  name        = var.proxy_target_group_name
  port        = 65432
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = 5

  health_check {
    protocol            = "TCP"
    timeout             = "3"
    interval            = "30"
    healthy_threshold   = "2"
    unhealthy_threshold = "2"
  }

  tags = {
    Name = var.proxy_target_group_name
  }
}

### ECS Service ###

resource "aws_security_group" "ecs_sg" {
  name_prefix = var.security_group_name_prefix
  vpc_id      = var.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 5133
    to_port     = 5133
    self        = "false"
    cidr_blocks = [var.public_subnet_cidr]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 65432
    to_port     = 65432
    self        = "false"
    cidr_blocks = [var.public_subnet_cidr]
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

resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  tags = {
    Name = var.cluster_name
  }
}

resource "aws_ecs_service" "electric_sync" {
  name                              = var.service_name
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = var.task_definition.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  network_configuration {
    security_groups = [aws_security_group.ecs_sg.id]
    subnets         = [var.public_subnet_id]

    # This is required for Fargate tasks launched by this service to be able to
    # pull a Docker image from ECR or Docker Hub.
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.id
    container_name   = var.task_container_name
    container_port   = 5133
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.proxy.id
    container_name   = var.task_container_name
    container_port   = 65432
  }

  # This is needed to keep terraform from falling into an infinite loop when the task fails to
  # start and is automatically recreated by AWS.
  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Name = var.service_name
  }
}
