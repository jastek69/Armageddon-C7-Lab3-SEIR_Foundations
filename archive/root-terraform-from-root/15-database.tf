# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_instance

# Creating RDS Aurora Cluster in taaops region in private subnets 1A, 1B, 1C


resource "aws_db_subnet_group" "taaops_vpc01_private_subnet_group" {
  name = "taaops-vpc01-private-subnet-group"
  subnet_ids = [
    aws_subnet.tokyo_subnet_private_a.id,
    aws_subnet.tokyo_subnet_private_b.id,
    aws_subnet.tokyo_subnet_private_c.id
  ]
}


resource "aws_rds_cluster_instance" "taaops_rds_cluster_instances" {
  count                = 2
  identifier           = "${var.project_name}-aurora-${count.index}"
  cluster_identifier   = aws_rds_cluster.taaops_rds_cluster.id
  db_subnet_group_name = aws_db_subnet_group.taaops_vpc01_private_subnet_group.name
  instance_class       = "db.r5.large"
  engine               = aws_rds_cluster.taaops_rds_cluster.engine
  engine_version       = aws_rds_cluster.taaops_rds_cluster.engine_version
  # remove manage_master_user_password / master_user_secret_kms_key_id here
}



resource "aws_rds_cluster" "taaops_rds_cluster" {
  cluster_identifier   = "${var.project_name}-aurora-cluster"
  availability_zones   = var.tokyo_azs
  db_subnet_group_name = aws_db_subnet_group.taaops_vpc01_private_subnet_group.name
  engine               = "aurora-mysql"
  database_name        = "taaopsdb"
  master_username      = var.db_username
  master_password      = var.db_password
  # NOTE: Do not set manage_master_user_password or master_user_secret_kms_key_id
  # when using a custom Secrets Manager + Lambda rotation.
  storage_encrypted               = true
  kms_key_id                      = local.taaops_kms_key_id
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]
  skip_final_snapshot             = true
  vpc_security_group_ids          = [aws_security_group.taaops_rds_sg.id]
}




/*
resource "aws_db_instance" "taaops_db_instance" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "taaopsdb"
  username             = "admin"
  password             = "admintest"
  parameter_group_name = "default.mysql5.7"
  db_subnet_group_name = aws_db_subnet_group.taaops_private_subnet_group.name
}
*/

