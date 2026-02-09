data "aws_ec2_managed_prefix_list" "galactus_cf_origin_facing01" {
  provider = aws.tokyo
  name     = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group_rule" "galactus_alb_ingress_cf_ports" {
  provider          = aws.tokyo
  type              = "ingress"
  security_group_id = data.terraform_remote_state.tokyo.outputs.tokyo_alb_sg_id
  from_port         = 80
  to_port           = 443
  protocol          = "tcp"
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.galactus_cf_origin_facing01.id]

  description = "Allow CloudFront origin-facing IPs to ALB"
}

resource "aws_lb_listener_rule" "galactus_require_origin_header01" {
  provider    = aws.tokyo
  listener_arn = data.terraform_remote_state.tokyo.outputs.tokyo_alb_https_listener_arn
  priority    = 10

  action {
    type             = "forward"
    target_group_arn = data.terraform_remote_state.tokyo.outputs.tokyo_alb_tg_arn
  }

  condition {
    http_header {
      http_header_name = "X-Galactus-Code"
      values           = [random_password.galactus_origin_header_value01.result]
    }
  }
}

resource "aws_lb_listener_rule" "galactus_default_block01" {
  provider    = aws.tokyo
  listener_arn = data.terraform_remote_state.tokyo.outputs.tokyo_alb_https_listener_arn
  priority    = 99

  action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }

  condition {
    path_pattern { values = ["*"] }
  }
}
