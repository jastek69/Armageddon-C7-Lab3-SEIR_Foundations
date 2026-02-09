# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret
# Manage RDS credentials using AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_secret" {
  name       = "${var.project_name}/rds/mysql"
  kms_key_id = local.taaops_kms_key_id
}

resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    engine   = "aurora-mysql"
    host     = aws_rds_cluster.taaops_rds_cluster.endpoint
    port     = 3306
    dbname   = var.db_name
  })
}

// NOTE: If you need to read the secret value, add a data source after
// the secret version exists to avoid AWSCURRENT lookup errors during create.
