variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "repository_arns" {
  type = map(string)
}

variable "cluster_name" {
  type = string
}

variable "service_names" {
  type = map(string)
}

variable "task_role_arns" {
  type = list(string)
}
