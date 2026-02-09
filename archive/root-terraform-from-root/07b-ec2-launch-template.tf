# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template

resource "aws_launch_template" "ec2_launch_template" {
  name_prefix = "ec2-launch-template-"
  description = "ec2-launch-template"
  # image_id      = "ami-0ebf411a80b6b22cb"  # Amazon Linux 2 AMI ID for Oregon (us-west-2)
  image_id      = var.ec2_ami_id
  instance_type = var.ec2_instance_type
  key_name      = var.key_pair_name

  network_interfaces {
    security_groups = [aws_security_group.tokyo_ec2_app_sg.id]
  }


  iam_instance_profile {
    name = aws_iam_instance_profile.taaops_ec2_instance_profile.name
  }

  user_data = filebase64("./scripts/user_data.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      ManagedBy = "Terraform"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}




# name
# description
# ami
# instance type
# key
# SG
# user data
