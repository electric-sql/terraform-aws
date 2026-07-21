resource "aws_security_group" "rds_sg" {
  name_prefix = var.security_group_name_prefix

  vpc_id = var.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 5432
    to_port     = 5432
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.security_group_name
  }
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = var.subnet_group_name
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = var.subnet_group_name
  }
}

resource "aws_db_parameter_group" "with_logical_replication" {
  name   = var.parameter_group_name
  family = "postgres15"

  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  tags = {
    Name = var.parameter_group_name
  }
}

resource "aws_db_instance" "main" {
  identifier        = var.instance_identifier
  allocated_storage = 20
  storage_type      = "gp2"
  engine            = "postgres"
  engine_version    = "15.5"
  instance_class    = "db.t4g.micro"
  db_name           = var.db_name
  username          = var.db_username
  password          = var.db_password

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  parameter_group_name   = aws_db_parameter_group.with_logical_replication.name
  apply_immediately      = true

  skip_final_snapshot = true

  tags = {
    Name = var.instance_identifier
  }
}
