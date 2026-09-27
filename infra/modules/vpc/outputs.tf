output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "security_group_ids" {
  value = {
    alb       = aws_security_group.alb.id
    api       = aws_security_group.api.id
    dashboard = aws_security_group.dashboard.id
    worker    = aws_security_group.worker.id
    rds       = aws_security_group.rds.id
    redis     = aws_security_group.redis.id
  }
}
