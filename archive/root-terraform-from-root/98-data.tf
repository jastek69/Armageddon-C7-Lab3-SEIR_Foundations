# DATA RESOURCES
/*#########################################################
Using a separate data "aws_caller_identity" block (e.g., galactus_self01) vs reusing taaops_self01 is mostly about clarity and isolation, not functionality. Both return the same account ID.

Advantages of a dedicated data source:

Readability: Each logical subsystem has its own references, so it’s clear what’s related to the “Galactus” pipeline.
Isolation for refactors: If you later move the Bedrock pipeline into its own module, you already have its own data sources.
Reduced coupling: Fewer cross‑references between unrelated files. This can help avoid confusion in larger projects.
#########################################################*/


data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}




# IAM Policy for EC2 to read DB Secret from Secrets Manager
data "aws_iam_policy_document" "ec2_read_db_secret" {
  statement {
    sid     = "ReadSpecificSecret"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.db_secret.arn
    ]
  }
}



data "aws_availability_zones" "available" {}

data "aws_region" "current" {}


/*
data "aws_kms_key" "rds_kms_key" {
  key_id = "arn:aws:kms:us-west-2:015195098145:key/12345678-1234-1234-1234-123456789012"
}
*/


# Explanation: ARN for taaops.
data "aws_caller_identity" "taaops_self01" {}
data "aws_caller_identity" "galactus_self01" {}


# Explanation: Region for taaops.
data "aws_region" "taaops_region01" {}



