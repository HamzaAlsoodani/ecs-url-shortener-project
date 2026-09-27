output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_names" {
  value = {
    api       = aws_ecs_service.api.name
    worker    = aws_ecs_service.worker.name
    dashboard = aws_ecs_service.dashboard.name
  }
}
