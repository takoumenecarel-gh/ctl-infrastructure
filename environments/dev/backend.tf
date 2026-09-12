terraform {
  backend "s3" {
    bucket       = "ctl-terraform-state-stepin.ink"
    key          = "ctl/dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}