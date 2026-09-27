data "aws_caller_identity" "current" {}

locals {
  log_groups_arn = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.project_name}/*:*"

  ecs_tasks_trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "execution" {
  name               = "${var.project_name}-ecs-execution"
  assume_role_policy = local.ecs_tasks_trust_policy
}

resource "aws_iam_role_policy" "execution" {
  name = "pull-images-write-logs-read-secret"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ]
        Resource = values(var.repository_arns)
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = local.log_groups_arn
      },
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.database_url_secret_arn
      },
    ]
  })
}

resource "aws_iam_role" "api" {
  name               = "${var.project_name}-api-task"
  assume_role_policy = local.ecs_tasks_trust_policy
}

resource "aws_iam_role_policy" "api" {
  name = "send-click-events"
  role = aws_iam_role.api.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sqs:SendMessage"
      Resource = var.queue_arn
    }]
  })
}

resource "aws_iam_role" "worker" {
  name               = "${var.project_name}-worker-task"
  assume_role_policy = local.ecs_tasks_trust_policy
}

resource "aws_iam_role_policy" "worker" {
  name = "consume-click-events"
  role = aws_iam_role.worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage"]
      Resource = var.queue_arn
    }]
  })
}
