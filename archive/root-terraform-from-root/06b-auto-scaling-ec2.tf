# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/aws_launch_template
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/aws_autoscaling_group


resource "aws_autoscaling_group" "ec2_tokyo_asg" {
  name             = "ec2-tokyo-asg"
  max_size         = 4
  min_size         = 1
  desired_capacity = 2
  vpc_zone_identifier = [
    aws_subnet.tokyo_subnet_private_a.id,
    aws_subnet.tokyo_subnet_private_b.id,
    aws_subnet.tokyo_subnet_private_c.id
  ]

  target_group_arns = [aws_lb_target_group.taaops_lb_tg80.arn]

  launch_template {
    id      = aws_launch_template.ec2_launch_template.id
    version = "$Latest"
  }
  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "ec2-tokyo-asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}





resource "aws_autoscaling_group" "ec2_sao_asg" {
  name             = "ec2-sao-asg"
  max_size         = 4
  min_size         = 1
  desired_capacity = 2
  vpc_zone_identifier = [
    aws_subnet.sao_subnet_private_a.id,
    aws_subnet.sao_subnet_private_b.id,
    aws_subnet.sao_subnet_private_c.id
  ]

  target_group_arns = [aws_lb_target_group.sao_lb_tg80.arn]

  launch_template {
    id      = aws_launch_template.ec2_launch_template.id
    version = "$Latest"
  }
  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "ec2-sao-asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}




/*

# ASG 443 - Secure Database
resource "aws_autoscaling_group" "tokyo_asg443-db" {  
  name_prefix           = "tokyo443-auto-scaling-group-"
  min_size              = 1
  max_size              = 4
  desired_capacity      = 3
  vpc_zone_identifier   = [
    aws_subnet.tokyo_subnet_private_a.id,
    aws_subnet.tokyo_subnet_private_b.id,
    aws_subnet.tokyo_subnet_private_c.id
  ]
  health_check_type          = "ELB"
  health_check_grace_period  = 300
  force_delete               = true
  target_group_arns          = [aws_lb_target_group.taaops_lb_tg80.arn]

  launch_template {
    id      = aws_launch_template.ec2_launch_template.id
    version = "$Latest"
  }

  enabled_metrics = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupTotalInstances"]

  # Instance protection for launching
  initial_lifecycle_hook {
    name                  = "instance-protection-launch"
    lifecycle_transition  = "autoscaling:EC2_INSTANCE_LAUNCHING"
    default_result        = "CONTINUE"
    heartbeat_timeout     = 60
    notification_metadata = "{\"key\":\"value\"}"
  }

  # Instance protection for terminating
  initial_lifecycle_hook {
    name                  = "scale-in-protection"
    lifecycle_transition  = "autoscaling:EC2_INSTANCE_TERMINATING"
    default_result        = "CONTINUE"
    heartbeat_timeout     = 300
  }

  tag {
    key                 = "Name"
    value               = "tokyo-instance-443-db"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "Production"
    propagate_at_launch = true
  }
}


# Auto Scaling Policy
resource "aws_autoscaling_policy" "tokyo443_scaling_policy-db" {
  name                   = "tokyo-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.tokyo_asg443-db.name

  policy_type = "TargetTrackingScaling"
  estimated_instance_warmup = 120

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 75.0
  }
}

# Enabling instance scale-in protection
resource "aws_autoscaling_attachment" "tokyo443_asg_attachment-db" {
  autoscaling_group_name = aws_autoscaling_group.tokyo_asg443.name
  lb_target_group_arn   = aws_lb_target_group.taaops_lb_tg80.arn
}
*/
