terraform {
  backend "s3" {
    bucket         = "taaops-terraform-state-tokyo"
    key            = "global/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    use_lockfile   = true
  }
}
