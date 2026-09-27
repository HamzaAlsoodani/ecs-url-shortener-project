output "database_url_secret_arn" {
  value = aws_secretsmanager_secret.database_url.arn
}

output "db_endpoint" {
  value = aws_db_instance.postgres.address
}

output "redis_url" {
  value = "rediss://${aws_elasticache_replication_group.redis.primary_endpoint_address}:6379"
}
