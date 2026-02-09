# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/aws_launch_template
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/aws_autoscaling_group

# Launch Template for EC2 instances in Auto Scaling Group
/*
resource "aws_autoscaling_group" "taaops_ecs_asg" {
  name             = "taaops-ecs-asg"
  max_size         = 2
  min_size         = 1
  desired_capacity = 1
  vpc_zone_identifier = [
    aws_subnet.taaops_subnet_public_a.id,
    aws_subnet.taaops_subnet_public_b.id,
    aws_subnet.taaops_subnet_public_c.id
  ]


  launch_template {
    id      = aws_launch_template.ec2_launch_template.id
    version = "$Latest"
  }
  health_check_type         = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "taaops-ecs-asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

*/