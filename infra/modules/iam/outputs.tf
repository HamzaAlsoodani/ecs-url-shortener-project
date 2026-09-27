output "execution_role_arn" {
  value = aws_iam_role.execution.arn
}

output "api_task_role_arn" {
  value = aws_iam_role.api.arn
}

output "worker_task_role_arn" {
  value = aws_iam_role.worker.arn
}

output "all_role_arns" {
  value = [
    aws_iam_role.execution.arn,
    aws_iam_role.api.arn,
    aws_iam_role.worker.arn,
  ]
}
