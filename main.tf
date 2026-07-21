# vpc 
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "terraform-vpc"
  }
}


# IGW 


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-igw"
  }
}

# subnets 

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr[0]
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-Subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr[1]
  availability_zone       = var.availability_zones[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-Subnet-2"
  }
}


# RT


resource "aws_route_table" "public_rt" {

  vpc_id = aws_vpc.main.id

  route {

    cidr_block = "0.0.0.0/0"

    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}


# Route Table Association


resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}


# SG for ALB


resource "aws_security_group" "alb_sg" {

  name = "alb-security-group"

  description = "Allow HTTP Traffic"

  vpc_id = aws_vpc.main.id

  ingress {

    from_port = 80

    to_port = 80

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]

  }

  egress {

    from_port = 0

    to_port = 0

    protocol = "-1"

    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {

    Name = "alb-sg"

  }

}

# Security Group for EC2


resource "aws_security_group" "ec2_sg" {

  name = "ec2-security-group"

  description = "Allow ALB traffic"

  vpc_id = aws_vpc.main.id

  ingress {

    from_port = 5000

    to_port = 5000

    protocol = "tcp"

    security_groups = [
      aws_security_group.alb_sg.id
    ]

  }

  ingress {

    from_port = 22

    to_port = 22

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]

  }



  egress {

    from_port = 0

    to_port = 0

    protocol = "-1"

    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {

    Name = "ec2-sg"

  }

}


# Using data resouces to take Latest Ubuntu AMI


data "aws_ami" "ubuntu" {

  most_recent = true

  owners = ["099720109477"]

  filter {

    name = "name"

    values = [
      "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
    ]

  }

  filter {

    name = "virtualization-type"

    values = ["hvm"]

  }

}


# Launch Template


resource "aws_launch_template" "web" {

  name_prefix = "nodejs-template-"

  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  key_name = "Ec2-file"

  vpc_security_group_ids = [
    aws_security_group.ec2_sg.id
  ]

  block_device_mappings {

    device_name = "/dev/sda1"

    ebs {
      volume_size           = 10
      volume_type           = "gp3"
      delete_on_termination = true
    }

  }

  user_data = base64encode(file("userdata.sh"))

  tag_specifications {

    resource_type = "instance"

    tags = {
      Name = "NodeJS-ASG"
    }

  }

}


# TG


resource "aws_lb_target_group" "tg" {

  name     = "nodejs-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {

    path                = "/"
    protocol            = "HTTP"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3

  }

  tags = {
    Name = "nodejs-target-group"
  }

}


# Application Load Balancer


resource "aws_lb" "alb" {

  name               = "nodejs-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb_sg.id
  ]

  subnets = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]

  tags = {
    Name = "nodejs-alb"
  }

}


# Listener


resource "aws_lb_listener" "http" {

  load_balancer_arn = aws_lb.alb.arn

  port = 80

  protocol = "HTTP"

  default_action {

    type = "forward"

    target_group_arn = aws_lb_target_group.tg.arn

  }

}


# Auto Scaling Group


resource "aws_autoscaling_group" "asg" {

  name = "nodejs-asg"

  desired_capacity = 2
  min_size         = 2
  max_size         = 4

  vpc_zone_identifier = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]

  target_group_arns = [
    aws_lb_target_group.tg.arn
  ]

  launch_template {

    id      = aws_launch_template.web.id
    version = "$Latest"

  }

  health_check_type = "ELB"

  health_check_grace_period = 60

  tag {

    key                 = "Name"
    value               = "NodeJS-ASG"
    propagate_at_launch = true

  }

}