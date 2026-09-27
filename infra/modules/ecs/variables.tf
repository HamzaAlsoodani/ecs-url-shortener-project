variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = map(string)
}

variable "repository_urls" {
  type = map(string)
}

variable "queue_url" {
  type = string
}

variable "database_url_secret_arn" {
  type = string
}

variable "redis_url" {
  type = string
}

variable "alb_dns_name" {
  type = string
}

variable "api_target_group_arn" {
  type = string
}

variable "dashboard_target_group_arn" {
  type = string
}

variable "execution_role_arn" {
  type = string
}

variable "api_task_role_arn" {
  type = string
}

variable "worker_task_role_arn" {
  type = string
}

variable "api_desired_count" {
  type    = number
  default = 2
}
