variable "project_name" {
  description = "Prefix used to name every resource"
  type        = string
  default     = "url-shortener"
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-2"
}

variable "image_tag" {
  description = "Image tag (git commit SHA) used for the initial task definitions"
  type        = string
}

variable "github_repo" {
  description = "GitHub OIDC subject for the repo allowed to deploy, in owner@id/repo@id format"
  type        = string
  default     = "HamzaAlsoodani@149546966/ecs-url-shortener-project@1391000351"
}
