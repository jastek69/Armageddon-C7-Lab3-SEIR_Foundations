# Regional Monitoring Module
# Creates CloudWatch Log Groups, SNS Topics, and monitoring infrastructure for a region

# Variables
variable "region_name" {
  description = "Region name for resource naming (e.g., tokyo, saopaulo)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "taaops"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "sns_email_endpoints" {
  description = "Email addresses for SNS notifications"
  type        = list(string)
  default     = []
}


variable "enable_alarms" {
  description = "Whether to create CloudWatch alarms"
  type        = bool
  default     = true
}


# CLOUDWATCH AGENT VARIABLES
variable "cw_agent_config_param_name" {
  description = "SSM parameter name for CloudWatch Agent config."
  type        = string
  default     = "/cw/agent/config"
}

variable "cw_agent_log_file_path" {
  description = "Log file path to ship via CloudWatch Agent."
  type        = string
  default     = "/var/log/rdsapp.log"
}

variable "cw_agent_log_group_name" {
  description = "CloudWatch Logs group for EC2 app logs."
  type        = string
  default     = "/aws/ec2/rdsapp"
}

variable "cw_agent_target_tag_key" {
  description = "Tag key used to target instances for CW Agent SSM association."
  type        = string
  default     = "ManagedBy"
}

variable "cw_agent_target_tag_value" {
  description = "Tag value used to target instances for CW Agent SSM association."
  type        = string
  default     = "Terraform"
}

variable "alarm_ssm_param_name" {
  description = "SSM parameter name with DB connection config."
  type        = string
  default     = ""
}

variable "alarm_secret_id" {
  description = "Secrets Manager secret ID or ARN for DB credentials."
  type        = string
  default     = ""
}

variable "alarm_asg_name" {
  description = "Auto Scaling Group name to refresh when alarms fire (optional)."
  type        = string
  default     = ""
}








# Locals
locals {
  resource_prefix = "${var.project_name}-${var.region_name}"
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

################################################################################
# CLOUDWATCH LOG GROUPS
################################################################################

# Application Log Group



resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/${local.resource_prefix}/application"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${local.resource_prefix}-app-logs"
    Region      = var.region_name
    Environment = "production"
  }
}

# System Log Group
resource "aws_cloudwatch_log_group" "system" {
  name              = "/aws/${local.resource_prefix}/system"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${local.resource_prefix}-system-logs"
    Region      = var.region_name
    Environment = "production"
  }
}

# Load Balancer Log Group (if ALB logs go to CloudWatch)
resource "aws_cloudwatch_log_group" "alb" {
  name              = "/aws/${local.resource_prefix}/alb"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${local.resource_prefix}-alb-logs"
    Region      = var.region_name
    Environment = "production"
  }
}

################################################################################
# SNS TOPICS FOR ALERTS
################################################################################

# Regional Alert Topic
resource "aws_sns_topic" "cloudwatch_alarms" {
  name = "${var.project_name}-cloudwatch-alarms"
}

resource "aws_sns_topic" "regional_alerts" {
  name         = "${local.resource_prefix}-alerts"
  display_name = "${var.region_name} Regional Alerts"

  tags = {
    Name   = "${local.resource_prefix}-alerts"
    Region = var.region_name
  }
}

# SNS Topic Policy
data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    sid    = "AllowCloudWatchAlarmsToPublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    actions = [
      "sns:Publish"
    ]

    resources = [
      aws_sns_topic.regional_alerts.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "regional_alerts" {
  arn    = aws_sns_topic.regional_alerts.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

# Email Subscriptions
resource "aws_sns_topic_subscription" "cloudwatch_alarms_email" {
  count     = length(var.sns_email_endpoints) != 0 ? 1 : 0
  topic_arn = aws_sns_topic.cloudwatch_alarms.arn
  protocol  = "email"
  endpoint  = var.sns_email_endpoints[0]
}

resource "aws_sns_topic_subscription" "email_alerts" {
  count = length(var.sns_email_endpoints)

  topic_arn = aws_sns_topic.regional_alerts.arn
  protocol  = "email"
  endpoint  = var.sns_email_endpoints[count.index]
}


################################################################################
# CLOUDWATCH ALARMS - REQUIRED
################################################################################

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



################################################################################
# CLOUDWATCH ALARMS (Optional)
################################################################################

# High CPU Alarm Template (can be used by calling modules)
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${local.resource_prefix}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization in ${var.region_name}"
  alarm_actions       = [aws_sns_topic.regional_alerts.arn]

  tags = {
    Name   = "${local.resource_prefix}-high-cpu-alarm"
    Region = var.region_name
  }
}

# Disk Space Alarm Template
resource "aws_cloudwatch_metric_alarm" "high_disk_usage" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${local.resource_prefix}-high-disk-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DiskSpaceUtilization"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This metric monitors disk usage in ${var.region_name}"
  alarm_actions       = [aws_sns_topic.regional_alerts.arn]

  dimensions = {
    Device     = "/dev/xvda1"
    Fstype     = "ext4"
    MountPath  = "/"
  }

  tags = {
    Name   = "${local.resource_prefix}-high-disk-alarm"
    Region = var.region_name
  }
}



################################################################################
# CLOUDWATCH SSM
################################################################################

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



/* 
################################################################################
# CLOUDWATCH DASHBOARD
################################################################################

resource "aws_cloudwatch_dashboard" "regional_dashboard" {
  dashboard_name = "${local.resource_prefix}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization"],
            ["CWAgent", "DiskSpaceUtilization"]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "${var.region_name} System Metrics"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          query   = "SOURCE '${aws_cloudwatch_log_group.application.name}' | fields @timestamp, @message | sort @timestamp desc | limit 100"
          region  = data.aws_region.current.name
          title   = "${var.region_name} Application Logs"
        }
      }
    ]
  })
}
*/