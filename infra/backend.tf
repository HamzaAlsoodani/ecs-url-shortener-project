terraform {
  backend "s3" {
    bucket       = "url-shortener-tfstate-076056288980"
    key          = "url-shortener/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
