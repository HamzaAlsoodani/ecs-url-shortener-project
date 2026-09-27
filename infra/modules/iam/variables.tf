variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "repository_arns" {
  type = map(string)
}

variable "queue_arn" {
  type = string
}

variable "database_url_secret_arn" {
  type = string
}
