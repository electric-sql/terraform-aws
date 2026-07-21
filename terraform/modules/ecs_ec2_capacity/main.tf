data "aws_ssm_parameter" "ecs_optimized_ami" {
  # Latest x86_64 ECS-optimized Amazon Linux 2023 AMI.
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

### Instance security group ###

# Task ENIs (awsvpc mode) have their own security group; the instance
# itself only needs outbound access (ECS agent, image pulls, SSM).
resource "aws_security_group" "instance" {
  name_prefix = "${var.name_prefix}-instance-"
  description = "Container instance SG for ${var.name_prefix}"
  vpc_id      = var.vpc_id

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.name_prefix}-instance"
  }
}

### IAM ###

resource "aws_iam_role" "instance" {
  name_prefix = "${var.name_prefix}-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "instance" {
  for_each = toset([
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])

  role       = aws_iam_role.instance.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "instance" {
  name_prefix = "${var.name_prefix}-"
  role        = aws_iam_role.instance.name
}

### Launch template ###

resource "aws_launch_template" "this" {
  name_prefix   = "${var.name_prefix}-"
  image_id      = data.aws_ssm_parameter.ecs_optimized_ami.value
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.instance.arn
  }

  user_data = base64encode(templatefile("${path.module}/../../../shared/user-data.sh.tpl", {
    cluster_name   = var.cluster_name
    instance_label = var.instance_label
  }))

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  network_interfaces {
    associate_public_ip_address = var.associate_public_ip
    security_groups             = [aws_security_group.instance.id]
  }

  # Root volume. The data volume is separate: either the host's NVMe
  # instance store (wired up automatically by AWS on i4i/m6id) or the
  # gp3 volume below.
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  # gp3 data volume, only when data_storage.kind == "ebs-gp3".
  # /dev/sdf is the conventional first additional EBS device; the
  # kernel exposes it as /dev/nvme1n1 on Nitro hosts, which the
  # user-data picks up via its non-root NVMe scan.
  dynamic "block_device_mappings" {
    for_each = var.data_storage.kind == "ebs-gp3" ? [var.data_storage] : []

    content {
      device_name = "/dev/sdf"

      ebs {
        volume_size           = block_device_mappings.value.size_gb
        volume_type           = "gp3"
        iops                  = block_device_mappings.value.iops
        throughput            = block_device_mappings.value.throughput_mbps
        delete_on_termination = true
        encrypted             = true
      }
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = var.name_prefix
    }
  }
}

### Autoscaling group ###

resource "aws_autoscaling_group" "this" {
  name_prefix         = "${var.name_prefix}-"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  # Required for ECS managed termination protection: the capacity
  # provider takes over scale-in decisions and protects instances
  # that are running tasks.
  protect_from_scale_in = true

  health_check_type         = "EC2"
  health_check_grace_period = 300

  # Required tag for ECS-managed ASGs.
  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = var.name_prefix
    propagate_at_launch = true
  }
}

# Gives ECS time to drain the container instance before the EC2
# instance is terminated.
resource "aws_autoscaling_lifecycle_hook" "drain" {
  name                   = "${var.name_prefix}-terminate-hook"
  autoscaling_group_name = aws_autoscaling_group.this.name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
  heartbeat_timeout      = 600
  default_result         = "CONTINUE"
}

### Capacity provider ###

resource "aws_ecs_capacity_provider" "this" {
  name = var.name_prefix

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.this.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 100
      instance_warmup_period    = 120
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 1
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = var.cluster_name
  capacity_providers = [aws_ecs_capacity_provider.this.name]
}
