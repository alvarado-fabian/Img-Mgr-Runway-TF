# Backend setup
terraform {
  backend "s3" {
    key = "img-mgr.tfstate"
  }
}

# Variable definitions
variable "region" {}

# Provider and access setup
provider "aws" {
  version = "~> 2.0"
  region = "${var.region}"
}

# Data and resources

data "terraform_remote_state" "dev" {
  backend = "s3"
  config = {
    bucket = "fabian-solutions-common-tf-s-terraformstatebucket-3k4jmhdc0ks8"
    region = "us-west-1"
    key = "env://dev/sampleapp.tfstate"
  }
}

## S3 Bucket Creation

resource "aws_s3_bucket" "img-mgr-s3" {
  bucket = "img-mgr-bucket-121561815618916915"
  acl    = "private"

  tags = {
    Name        = "s3-bucket"
  }
}

## IAM Roles / Instance Profile

resource "aws_iam_role" "img-mgr-iam-role" {
  name = "Img-Mgr-Server-IAM-Role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "img-mgr-instance-profile" {
  name = "img-mgr-instance-profile"
  role = "${aws_iam_role.img-mgr-iam-role.name}"
}

resource "aws_iam_role_policy" "img-mgr-iam-policy" {
  name = "Img-Mgr-Server-IAM-Policy"
  role = "${aws_iam_role.img-mgr-iam-role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.img-mgr-s3.arn}",
        "${aws_s3_bucket.img-mgr-s3.arn}/*"
        ]
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "iam-attach" {
  name       = "test-attachment"
  roles      = [aws_iam_role.img-mgr-iam-role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}



## LB SG

resource "aws_security_group" "sg-lb-allow-80" {
    vpc_id = data.terraform_remote_state.dev.outputs.vpc_id

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "Allow-80-To-LB"
    }
}

## Server SG

resource "aws_security_group" "sg-lb-webserver" {
    vpc_id = data.terraform_remote_state.dev.outputs.vpc_id

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        security_groups = [ aws_security_group.sg-lb-allow-80.id ]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "LB-To-WebServer"
    }
}

## LB Creation

resource "aws_elb" "Img-Mgr-ELB" {
  name               = "img-mgr-terraform-elb"
  subnets            = data.terraform_remote_state.dev.outputs.public_subnets
  security_groups    = [ aws_security_group.sg-lb-allow-80.id ]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "img-mgr-terraform-elb"
  }
}

## Lanch Templete

resource "aws_launch_template" "img-mgr-launch-temp" {
  name = "img-mgr-template"
  update_default_version = true
  image_id = "ami-011996ff98de391d1"
  instance_initiated_shutdown_behavior = "terminate"
  iam_instance_profile {
    name = aws_iam_instance_profile.img-mgr-instance-profile.name
  }
  instance_type = "t2.small"
  key_name = "Cali-us-west-1-key"
  vpc_security_group_ids = [ aws_security_group.sg-lb-webserver.id ]

  user_data = filebase64("userdata.sh")
}

## Auto Scaling group

resource "aws_autoscaling_group" "img-mgr-asg" {
  vpc_zone_identifier = data.terraform_remote_state.dev.outputs.private_subnets
  desired_capacity   = 2
  max_size           = 2
  min_size           = 2
  load_balancers = ["${aws_elb.Img-Mgr-ELB.name}"]

  launch_template {
    id      = aws_launch_template.img-mgr-launch-temp.id
    version = "$Latest"
  }
}
