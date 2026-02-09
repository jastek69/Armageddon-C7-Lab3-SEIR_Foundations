
# DATABASE TARGET GROUP
resource "aws_lb_target_group" "taaops_lb_tg80" {

  name        = "taaops-lb-tg80"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.shinjuku_vpc01.id
  target_type = "instance"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name    = "taaops-db-TargetGroup443"
    Service = "Database"
    Owner   = "User"
    Project = "TMMC"
  }
}

# Sao Paulo Target Group
resource "aws_lb_target_group" "sao_lb_tg80" {
  provider    = aws.saopaulo
  name        = "sao-lb-tg80"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.liberdade_vpc01.id
  target_type = "instance"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name    = "sao-db-TargetGroup80"
    Service = "Database"
    Owner   = "User"
    Project = "TMMC"
  }
}
