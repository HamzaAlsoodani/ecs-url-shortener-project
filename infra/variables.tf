variable "project_name" {
  type    = string
  default = "url-shortener"
}

variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "image_tag" {
  type = string
}

variable "github_repo" {
  type    = string
  default = "HamzaAlsoodani@149546966/ecs-url-shortener-project@1391000351"
}
