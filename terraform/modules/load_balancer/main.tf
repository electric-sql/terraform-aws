### Network Load Balancer ###

resource "aws_security_group" "lb_sg" {
  name_prefix = var.security_group_name_prefix
  vpc_id      = var.vpc_id

  ingress {
    protocol         = "tcp"
    from_port        = 80
    to_port          = 80
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    protocol         = "tcp"
    from_port        = 443
    to_port          = 443
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
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

resource "aws_lb" "main" {
  name               = var.load_balancer_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = var.subnet_ids

  tags = {
    Name = var.load_balancer_name
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = var.lb_target_group_main.id
    type             = "forward"
  }

  tags = {
    Name = var.http_listener_name
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.id
  port              = 443
  protocol          = "HTTPS"

  certificate_arn = var.tls_certificate_arn

  default_action {
    target_group_arn = var.lb_target_group_main.id
    type             = "forward"
  }

  tags = {
    Name = var.https_listener_name
  }
}
