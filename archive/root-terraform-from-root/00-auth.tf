terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.24.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  alias  = "us-east-1"
  region = var.aws_region_tls
}

provider "tls" {
  # Configuration options (if any)
}

# Tokyo provider (default region)
provider "aws" {
  region = "ap-northeast-1"
  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Region    = "Tokyo"
    }
  }
}

# São Paulo provider
provider "aws" {
  alias  = "saopaulo"
  region = "sa-east-1"
  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Region    = "SaoPaulo"
    }
  }
}