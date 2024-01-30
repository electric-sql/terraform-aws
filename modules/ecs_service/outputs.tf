output "lb_target_group_main" {
  description = "HTTP target group"
  value       = aws_lb_target_group.main
}

output "lb_target_group_proxy" {
  description = "TCP target group for the Migrations proxy"
  value       = aws_lb_target_group.proxy
}
