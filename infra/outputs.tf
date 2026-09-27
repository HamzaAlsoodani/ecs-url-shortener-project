output "app_url" {
  value = "http://${module.alb.alb_dns_name}"
}

output "github_deploy_role_arn" {
  value = module.github_oidc.deploy_role_arn
}
