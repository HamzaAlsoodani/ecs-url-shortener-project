output "app_url" {
  value = "http://${module.alb.alb_dns_name}"
}
