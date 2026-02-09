############################################
# modules/vpc/main.tf
############################################

/*
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/google"
      version = "~> 6.36.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      ManagedBy = "Terraform"
    }
  }
}



module "vpc1" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${local.name}-1"
  cidr = local.vpc1_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc1_cidr, 8, k)]

  enable_ipv6                                    = true
  private_subnet_assign_ipv6_address_on_creation = true
  private_subnet_ipv6_prefixes                   = [0, 1, 2]

  tags = local.tags
}

module "vpc2" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${local.name}-2"
  cidr = local.vpc2_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc2_cidr, 8, k)]

  enable_ipv6 = false

  tags = local.tags
}

*/
