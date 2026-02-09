terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.24.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "tokyo"
  region = var.tokyo_region
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}
