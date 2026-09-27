output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "api_target_group_arn" {
  value = aws_lb_target_group.api.arn
}

output "dashboard_target_group_arn" {
  value = aws_lb_target_group.dashboard.arn
}

output "listener_arn" {
  value = aws_lb_listener.http.arn
}
