resource "aws_ecs_cluster" "this" {
  name = var.project_name
}

resource "aws_cloudwatch_log_group" "this" {
  for_each = toset(["api", "worker", "dashboard"])

  name              = "/ecs/${var.project_name}/${each.value}"
  retention_in_days = 7
}

locals {
  aws_env = [
    { name = "AWS_REGION", value = var.aws_region },
    { name = "AWS_DEFAULT_REGION", value = var.aws_region },
  ]

  database_secret = [
    { name = "DATABASE_URL", valueFrom = var.database_url_secret_arn },
  ]
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.api_task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([{
    name         = "api"
    image        = "${var.repository_urls["api"]}:${var.image_tag}"
    essential    = true
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]

    environment = concat(local.aws_env, [
      { name = "PORT", value = "8080" },
      { name = "SQS_QUEUE_URL", value = var.queue_url },
      { name = "REDIS_URL", value = var.redis_url },
      { name = "BASE_URL", value = "http://${var.alb_dns_name}" },
    ])
    secrets = local.database_secret

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this["api"].name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "api"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "dashboard" {
  family                   = "${var.project_name}-dashboard"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.execution_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([{
    name         = "dashboard"
    image        = "${var.repository_urls["dashboard"]}:${var.image_tag}"
    essential    = true
    portMappings = [{ containerPort = 8081, protocol = "tcp" }]

    environment = [{ name = "PORT", value = "8081" }]
    secrets     = local.database_secret

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this["dashboard"].name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "dashboard"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.project_name}-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.worker_task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([{
    name      = "worker"
    image     = "${var.repository_urls["worker"]}:${var.image_tag}"
    essential = true

    environment = concat(local.aws_env, [
      { name = "SQS_QUEUE_URL", value = var.queue_url },
    ])
    secrets = local.database_secret

    healthCheck = {
      command     = ["CMD", "curl", "-f", "http://localhost:8090/healthz"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 30
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this["worker"].name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "worker"
      }
    }
  }])
}

resource "aws_ecs_service" "api" {
  name            = "api"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.api_desired_count
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.security_group_ids["api"]]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.api_target_group_arn
    container_name   = "api"
    container_port   = 8080
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}

resource "aws_ecs_service" "dashboard" {
  name            = "dashboard"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.dashboard.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.security_group_ids["dashboard"]]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.dashboard_target_group_arn
    container_name   = "dashboard"
    container_port   = 8081
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}

resource "aws_ecs_service" "worker" {
  name            = "worker"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.security_group_ids["worker"]]
    assign_public_ip = false
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}
