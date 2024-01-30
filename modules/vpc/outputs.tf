output "id" {
  description = "ID of the created VPC resource"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs of the created private subnets"
  value       = aws_subnet.private.*.id
}

output "public_subnet_id" {
  description = "ID of the created public subnets"
  value       = aws_subnet.public.id
}
