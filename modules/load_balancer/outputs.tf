output "dns_name" {
  description = "DNS name of the Load Balancer that can be used in a CNAME record"
  value       = aws_lb.main.dns_name
}
