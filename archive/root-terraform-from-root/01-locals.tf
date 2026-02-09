############################################
# Locals (naming convention: taaops-*)
############################################
locals {
  name_prefix     = "taaops"
  rds_secret_name = "rds-database-credentials"
  # TODO: Switch to module.armageddon_vpc.vpc_id after VPC modules are introduced.
  vpc_ids = {
    armageddon = aws_vpc.shinjuku_vpc01.id
  }

}


locals {
  # Explanation: This is the roar address — where the galaxy finds your app.
  taaops_fqdn = "${var.app_subdomain}.${var.domain_name}"
}


/*
 # -------------------------------------------------------------------
  # VPC IDs keyed by project (from VPC modules)
  # -------------------------------------------------------------------
  vpc_ids = {
    chewbacca = module.chewbacca_vpc.vpc_id
    armageddon = module.armageddon_vpc.vpc_id   
  }

*/



locals {
  # Explanation: Name prefix is the roar that echoes through every tag.
  taaops_prefix = var.project_name

  # TODO: lock this down after apply using the real secret ARN from outputs/state
  taaops_secret_arn_guess = "arn:aws:secretsmanager:${data.aws_region.taaops_region01.name}:${data.aws_caller_identity.taaops_self01.account_id}:secret:${local.taaops_prefix}/rds/mysql*"

  # KMS key override (if provided), otherwise use the Terraform-managed CMK.
  taaops_kms_key_id = (
    var.kms_key_id != null && var.kms_key_id != ""
  ) ? var.kms_key_id : aws_kms_key.rds_s3_data.arn



}


locals {
  # Explanation: Dedicated ALB origin hostname used by CloudFront (TLS must match this name).
  alb_origin_fqdn = "${var.alb_origin_subdomain}.${var.domain_name}"

  # Use a provided ALB cert ARN or the Terraform-created cert.
  alb_origin_cert_arn = var.alb_origin_cert_arn != "" ? var.alb_origin_cert_arn : (
    length(aws_acm_certificate.alb_origin) > 0 ? aws_acm_certificate.alb_origin[0].arn : ""
  )
}
