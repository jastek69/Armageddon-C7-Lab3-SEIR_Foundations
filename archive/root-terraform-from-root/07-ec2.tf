/*

resource "aws_instance" "web_server" {
  ami                         = "ami-06d455b8b50b0de4d"
  associate_public_ip_address = true
  instance_type               = "t3.micro"
  # key_name                    = "your-existing-key-name-here"  # Uncomment and specify if you want SSH access
  vpc_security_group_ids = [aws_security_group.taaops_alb01_sg443.id, aws_security_group.taaops_ec2_app_sg.id]
  subnet_id              = aws_subnet.taaops_subnet_public_a.id

  user_data = file("user_data.sh")

  tags = {
    Name = "web-server"
  }
}

*/
