output "username" {
  description = "RDS instance root username"
  value       = aws_db_instance.main.username
}

output "endpoint" {
  description = "RDS instance endpoint in the address:port format"
  value       = aws_db_instance.main.endpoint
}

output "db_name" {
  description = "Name of the RDS instance's main database"
  value       = aws_db_instance.main.db_name
}

output "connection_uri" {
  description = "Full connection URI of the created database"
  value       = "postgresql://${aws_db_instance.main.username}:${var.db_password}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
  sensitive   = true
}
