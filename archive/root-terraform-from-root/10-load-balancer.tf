# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener



##########################################################################################################################
# LOAD BALANCER

data "aws_route53_zone" "main-taaops" {
  name         = var.domain_name
  private_zone = false
}
resource "aws_lb" "taaops_lb01" {
  # provider           = aws.saopaulo
  name               = "taaops-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.tokyo_alb_sg.id]
  subnets = [
    aws_subnet.tokyo_subnet_public_a.id,
    aws_subnet.tokyo_subnet_public_b.id
  ]
  enable_deletion_protection = false
  #Lots of death and suffering here, make sure it's false

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "alb/taaops"
    enabled = true
  }

  tags = {
    Name    = "taaops_LoadBalancer"
    Service = "LoadBalancer"
    Owner   = "User"
    Project = "Web Service"
  }

}

/* not needed
resource "aws_lb_listener" "taaops-http" {
  # provider          = aws.saopaulo
  load_balancer_arn = aws_lb.taaops_lb01.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.taaops_lb_tg80.arn
  }
}
*/


resource "aws_acm_certificate" "alb_origin" {
  count             = var.alb_origin_cert_arn == "" ? 1 : 0
  domain_name       = local.alb_origin_fqdn
  validation_method = var.certificate_validation_method
}

resource "aws_route53_record" "alb_origin_cert_validation" {
  for_each = var.alb_origin_cert_arn == "" ? {
    for dvo in aws_acm_certificate.alb_origin[0].domain_validation_options :
    dvo.domain_name => dvo
  } : {}

  zone_id = data.aws_route53_zone.main-taaops.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 300
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "alb_origin" {
  count                   = var.alb_origin_cert_arn == "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.alb_origin[0].arn
  validation_record_fqdns = [for r in aws_route53_record.alb_origin_cert_validation : r.fqdn]
}


# Header based Cloaking Rules: header match -> forward; fallback -> 403 - You shall not pass
resource "aws_lb_listener" "taaops-https" {
  # provider          = aws.saopaulo
  load_balancer_arn = aws_lb.taaops_lb01.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08" # or whichever policy suits your requirements
  certificate_arn   = local.alb_origin_cert_arn



  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.taaops_lb_tg80.arn
  }
}

output "taaops-lb_dns_name" {
  value       = aws_lb.taaops_lb01.dns_name
  description = "The DNS name of the Taaops Load Balancer."
}

# Sao Paulo ALB and listener
resource "aws_lb" "sao_alb" {
  provider           = aws.saopaulo
  name               = "sao-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sao_alb_sg.id]
  subnets = [
    aws_subnet.sao_subnet_public_a.id,
    aws_subnet.sao_subnet_public_b.id
  ]

  enable_deletion_protection = false

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "alb/sao"
    enabled = true
  }

  tags = {
    Name    = "sao_LoadBalancer"
    Service = "LoadBalancer"
    Owner   = "User"
    Project = "Web Service"
  }
}

resource "aws_lb_listener" "sao_http" {
  provider          = aws.saopaulo
  load_balancer_arn = aws_lb.sao_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sao_lb_tg80.arn
  }
}


##########################################################################################################################
