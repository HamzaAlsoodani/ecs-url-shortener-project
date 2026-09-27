terraform {
  backend "s3" {
    key          = "url-shortener/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
