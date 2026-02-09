# Tokyo Database Configuration - Secure Medical Data Authority
# Database and related security components stay in Tokyo for APPI compliance

################################################################################
# DATABASE SUBNET GROUP
################################################################################

resource "aws_db_subnet_group" "tokyo_db_subnet_group" {
  name = "tokyo-db-private-subnet-group"
  subnet_ids = [
    aws_subnet.tokyo_subnet_private_a.id,
    aws_subnet.tokyo_subnet_private_b.id,
    aws_subnet.tokyo_subnet_private_c.id
  ]

  tags = {
    Name    = "tokyo-db-subnet-group"
    Purpose = "DatabaseSecure"
  }
}

################################################################################
# RDS AURORA CLUSTER
################################################################################

# Aurora MySQL Cluster (Primary)
resource "aws_rds_cluster" "taaops_rds_cluster" {
  cluster_identifier   = var.rds_cluster_identifier
  availability_zones   = var.tokyo_azs
  db_subnet_group_name = aws_db_subnet_group.tokyo_db_subnet_group.name
  engine               = "aurora-mysql"
  database_name        = "taaopsdb"
  master_username      = var.db_username

  # Use Secrets Manager for password management - references existing secret in 16-secrets.tf
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.taaops_kms_key01.arn

  storage_encrypted               = true
  kms_key_id                      = aws_kms_key.taaops_kms_key01.arn
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]
  skip_final_snapshot             = true
  vpc_security_group_ids          = [aws_security_group.tokyo_rds_sg.id]
  backup_retention_period         = 7
  preferred_backup_window         = "03:00-04:00"
  preferred_maintenance_window    = "sun:04:00-sun:05:00"
  apply_immediately               = false

  tags = {
    Name        = "tokyo-aurora-cluster"
    Purpose     = "MedicalDataAuthority"
    Compliance  = "APPI"
    Environment = "production"
    Region      = "Tokyo"
  }
}

# Aurora Instances
resource "aws_rds_cluster_instance" "taaops_rds_cluster_instances" {
  count              = 2
  identifier         = "${var.project_name}-aurora-${count.index}"
  cluster_identifier = aws_rds_cluster.taaops_rds_cluster.id
  instance_class     = "db.r5.large"
  engine             = aws_rds_cluster.taaops_rds_cluster.engine
  engine_version     = aws_rds_cluster.taaops_rds_cluster.engine_version

  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_enhanced_monitoring.arn

  tags = {
    Name = "tokyo-aurora-instance-${count.index}"
    Type = count.index == 0 ? "writer" : "reader"
  }
}

################################################################################
# DATABASE SECURITY GROUP
################################################################################

resource "aws_security_group" "tokyo_rds_sg" {
  name        = "tokyo-rds-sg"
  description = "Security group for Tokyo Database instances"
  vpc_id      = aws_vpc.shinjuku_vpc01.id

  # Allow local Tokyo access
  ingress {
    description     = "MySQL from Tokyo EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.tokyo_ec2_app_sg.id]
  }

  # Allow Sao Paulo access via TGW
  ingress {
    description = "MySQL from Sao Paulo via TGW"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.saopaulo_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tokyo-rds-sg"
  }
}

################################################################################
# GLOBAL DATABASE IAM ROLES & POLICIES
################################################################################

# RDS Enhanced Monitoring Role
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "rds-enhanced-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Global Database Access Policy (can be referenced by regional roles)
data "aws_iam_policy_document" "global_database_access" {
  statement {
    sid    = "DatabaseSecretAccess"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      aws_secretsmanager_secret.db_secret.arn
    ]
  }

  statement {
    sid    = "DatabaseParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParameterHistory"
    ]
    resources = [
      "arn:aws:ssm:ap-northeast-1:${data.aws_caller_identity.taaops_self01.account_id}:parameter/taaops/database/*",
      "arn:aws:ssm:sa-east-1:${data.aws_caller_identity.taaops_self01.account_id}:parameter/taaops/database/*"
    ]
  }

  statement {
    sid    = "DatabaseKMSAccess"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = [
      aws_kms_key.taaops_kms_key01.arn
    ]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values = [
        "secretsmanager.ap-northeast-1.amazonaws.com",
        "secretsmanager.sa-east-1.amazonaws.com",
        "rds.ap-northeast-1.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_policy" "global_database_access" {
  name        = "global-database-access"
  description = "Global database access policy for all regions"
  policy      = data.aws_iam_policy_document.global_database_access.json
}

################################################################################
# DATABASE INTEGRATION - CREATE SECRETS AND PARAMETERS
################################################################################

# Create the main database secret
resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "${var.project_name}/rds/mysql"
  description             = "Tokyo RDS Aurora MySQL database credentials"
  recovery_window_in_days = 7

  tags = {
    Name        = "${var.project_name}-rds-secret"
    Environment = "production"
    Region      = "Tokyo"
    ManagedBy   = "Terraform"
  }
}

# Create initial secret version with database credentials
resource "aws_secretsmanager_secret_version" "tokyo_db_secret_initial" {
  depends_on = [aws_rds_cluster.taaops_rds_cluster]
  secret_id  = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    engine   = "aurora-mysql"
    host     = aws_rds_cluster.taaops_rds_cluster.endpoint
    port     = 3306
    dbname   = "taaopsdb"
    # Tokyo-specific endpoints
    cluster_endpoint = aws_rds_cluster.taaops_rds_cluster.endpoint
    reader_endpoint  = aws_rds_cluster.taaops_rds_cluster.reader_endpoint
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# SSM Parameters for database configuration
resource "aws_ssm_parameter" "tokyo_db_endpoint" {
  name        = "/taaops/db/endpoint"
  description = "Tokyo RDS Aurora cluster endpoint"
  type        = "String"
  value       = aws_rds_cluster.taaops_rds_cluster.endpoint
  tags = {
    Name      = "taaops-db-endpoint"
    Region    = "Tokyo"
    ManagedBy = "Terraform"
  }
}

resource "aws_ssm_parameter" "tokyo_db_port" {
  name        = "/taaops/db/port"
  description = "Tokyo RDS Aurora cluster port"
  type        = "String"
  value       = tostring(aws_rds_cluster.taaops_rds_cluster.port)
  tags = {
    Name      = "taaops-db-port"
    Region    = "Tokyo"
    ManagedBy = "Terraform"
  }
}

resource "aws_ssm_parameter" "tokyo_db_name" {
  name        = "/taaops/db/name"
  description = "Tokyo RDS Aurora database name"
  type        = "String"
  value       = aws_rds_cluster.taaops_rds_cluster.database_name
  tags = {
    Name      = "taaops-db-name"
    Region    = "Tokyo"
    ManagedBy = "Terraform"
  }
}

# Update existing SSM parameters with Tokyo database values
resource "aws_ssm_parameter" "tokyo_db_endpoint_update" {
  name  = "/lab/db/endpoint"
  type  = "String"
  value = aws_rds_cluster.taaops_rds_cluster.endpoint
  # Remove this deprecated attribute
  # overwrite = true

  tags = {
    Name   = "db-endpoint-tokyo"
    Type   = "database"
    Region = "Tokyo"
  }
}

# Additional Tokyo-specific parameters for cross-region access
resource "aws_ssm_parameter" "tokyo_db_reader_endpoint" {
  name  = "/lab/db/reader_endpoint"
  type  = "String"
  value = aws_rds_cluster.taaops_rds_cluster.reader_endpoint

  tags = {
    Name   = "db-reader-endpoint"
    Type   = "database"
    Region = "Tokyo"
  }
}

################################################################################
# CROSS-REGION PARAMETER REPLICATION TO SÃO PAULO
################################################################################

# Replicate Tokyo database endpoints to São Paulo region for regional access
resource "aws_ssm_parameter" "saopaulo_db_endpoint_replica" {
  provider = aws.saopaulo
  name     = "/lab/db/endpoint"
  type     = "String"
  value    = aws_rds_cluster.taaops_rds_cluster.endpoint

  tags = {
    Name         = "db-endpoint-replica"
    Type         = "database"
    SourceRegion = "Tokyo"
    Region       = "SaoPaulo"
  }
}

resource "aws_ssm_parameter" "saopaulo_db_reader_endpoint_replica" {
  provider = aws.saopaulo
  name     = "/lab/db/reader_endpoint"
  type     = "String"
  value    = aws_rds_cluster.taaops_rds_cluster.reader_endpoint

  tags = {
    Name         = "db-reader-endpoint-replica"
    Type         = "database"
    SourceRegion = "Tokyo"
    Region       = "SaoPaulo"
  }
}