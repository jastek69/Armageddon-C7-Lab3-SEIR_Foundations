# This file contains the SSM Parameter Store resources for the RDS cluster parameters.
# Sets the database endpoint, port, and name as parameters in the SSM Parameter Store for easy retrieval by other resources or applications.
# https://registry.terraform.io/providers/-/aws/5.8.0/docs/resources/ssm_parameter
# use import blocks: https://discuss.hashicorp.com/t/replacement-for-overwrite-true-in-aws-ssm-parameter-database-url/67820

resource "aws_ssm_parameter" "db_endpoint" {
  name  = "/lab/db/endpoint"
  type  = "String"
  value = aws_rds_cluster.taaops_rds_cluster.endpoint
}

resource "aws_ssm_parameter" "db_port" {
  name  = "/lab/db/port"
  type  = "String"
  value = "3306"
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/lab/db/name"
  type  = "String"
  value = var.db_name
}

