resource "aws_sns_topic" "cloudwatch_alarms" {
  name = "${var.project_name}-cloudwatch-alarms"
}

resource "aws_sns_topic_subscription" "cloudwatch_alarms_email" {
  count     = var.sns_email_endpoint != "" ? 1 : 0
  topic_arn = aws_sns_topic.cloudwatch_alarms.arn
  protocol  = "email"
  endpoint  = var.sns_email_endpoint
}

resource "aws_cloudwatch_metric_alarm" "rdsapp_db_errors" {
  alarm_name          = "rdsapp-db-errors-alarm"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  metric_name         = "RdsAppDbErrors"
  namespace           = "Lab/RDSApp"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
}

resource "aws_cloudwatch_metric_alarm" "db_connections_low" {
  alarm_name          = "AWS/RDS DatabaseConnections DBInstanceIdentifier=taaops-rds"
  alarm_description   = "This alarm indicates the database has zero active connections. If this is unexpected, immediately verify application health, network connectivity, and database availability. Review idle/sleeping sessions, implement or tune connection pooling, and ensure the DB instance class and max_connections setting are sized appropriately for the workload."
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  treat_missing_data  = "breaching"

  dimensions = {
    DBInstanceIdentifier = "taaops-rds"
  }
}

resource "aws_cloudwatch_metric_alarm" "asm_rotation_errors" {
  alarm_name          = "asm-rotation-errors-alarm"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  metric_name         = "AsmRotationErrors"
  namespace           = "Lab/ASM"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
}

# CloudWatch Agent config and SSM associations (for EC2 instances).
resource "aws_ssm_parameter" "cw_agent_config" {
  name = var.cw_agent_config_param_name
  type = "String"
  value = jsonencode({
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path       = var.cw_agent_log_file_path
              log_group_name  = var.cw_agent_log_group_name
              log_stream_name = "{instance_id}"
              timezone        = "UTC"
            }
          ]
        }
      }
    }
  })
}

resource "aws_ssm_association" "cw_agent_install" {
  name = "AWS-ConfigureAWSPackage"

  parameters = {
    action = "Install"
    name   = "AmazonCloudWatchAgent"
  }

  targets {
    key    = "tag:${var.cw_agent_target_tag_key}"
    values = [var.cw_agent_target_tag_value]
  }
}

resource "aws_ssm_association" "cw_agent_configure" {
  name = "AmazonCloudWatch-ManageAgent"

  parameters = {
    action                        = "configure"
    mode                          = "ec2"
    optionalConfigurationSource   = "ssm"
    optionalConfigurationLocation = aws_ssm_parameter.cw_agent_config.name
    optionalRestart               = "yes"
  }

  targets {
    key    = "tag:${var.cw_agent_target_tag_key}"
    values = [var.cw_agent_target_tag_value]
  }
}
