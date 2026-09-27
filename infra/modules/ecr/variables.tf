variable "project_name" {
  type = string
}

variable "services" {
  type    = list(string)
  default = ["api", "worker", "dashboard"]
}
