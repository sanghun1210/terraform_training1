terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_vpc" "vpc-ap-northeast-2-web-app-stack" {
  cidr_block  = "10.0.0.0/16"  
  tags = {
    Name = "vpc-ap-northeast-2-web-app-stack"
  }
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "subnet-ap-northeast-2a-public-1" {
  vpc_id = "${aws_vpc.vpc-ap-northeast-2-web-app-stack.id}"
  cidr_block = "10.0.10.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "subnet-ap-northeast-2a-public-1"
  }
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet-ap-northeast-2c-public-2" {
  vpc_id = "${aws_vpc.vpc-ap-northeast-2-web-app-stack.id}"
  cidr_block = "10.0.20.0/24"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "subnet-ap-northeast-2c-public-2"
  }
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet-ap-northeast-2a-private-1" {
  vpc_id = "${aws_vpc.vpc-ap-northeast-2-web-app-stack.id}"
  cidr_block = "10.0.100.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "subnet-ap-northeast-2a-private-1"
  }
}

resource "aws_subnet" "subnet-ap-northeast-2c-private-2" {
  vpc_id = "${aws_vpc.vpc-ap-northeast-2-web-app-stack.id}"
  cidr_block = "10.0.200.0/24"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "subnet-ap-northeast-2c-private-2"
  }
}

resource "aws_internet_gateway" "igw-demo-1" {
  vpc_id = "${aws_vpc.vpc-ap-northeast-2-web-app-stack.id}"
  tags = {
    Name = "igw-demo-1"
  }
}

resource "aws_default_route_table" "public_rt" {
    default_route_table_id = aws_vpc.vpc-ap-northeast-2-web-app-stack.default_route_table_id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw-demo-1.id
    }

    tags = {
        Name = "public route table"
    }
}

resource "aws_route_table_association" "public_rta_a" {
    subnet_id      = aws_subnet.subnet-ap-northeast-2a-public-1.id
    route_table_id = aws_default_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rta_b" {
    subnet_id      = aws_subnet.subnet-ap-northeast-2c-public-2.id
    route_table_id = aws_default_route_table.public_rt.id
}

resource "aws_eip" "eip-1" {
  vpc   = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_nat_gateway" "nat-gateway-1" {
  allocation_id = "${aws_eip.eip-1.id}"
  subnet_id = "${aws_subnet.subnet-ap-northeast-2a-public-1.id}"

  tags = {
    Name = "nat-gateway-1"
  }
}

resource "aws_route_table" "route_table_private" {
  vpc_id = aws_vpc.vpc-ap-northeast-2-web-app-stack.id

  tags = {
    Name = "route_table_private_1"
  }
}

resource "aws_route" "private_nat_1" {
  route_table_id              = aws_route_table.route_table_private.id
  destination_cidr_block      = "0.0.0.0/0"
  nat_gateway_id              = aws_nat_gateway.nat-gateway-1.id
}

resource "aws_route_table_association" "private_rta_a" {
    subnet_id      = aws_subnet.subnet-ap-northeast-2a-private-1.id
    route_table_id = aws_route_table.route_table_private.id
}

resource "aws_route_table_association" "privata_rta_b" {
    subnet_id      = aws_subnet.subnet-ap-northeast-2c-private-2.id
    route_table_id = aws_route_table.route_table_private.id
}

####################################################################

resource "aws_security_group" "webserversg" {
  name        = "webserversg"
  description = "allow 22, 80"
  vpc_id      = aws_vpc.vpc-ap-northeast-2-web-app-stack.id
}

resource "aws_security_group_rule" "websg-ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.webserversg.id
  description       = "ssh"
}

resource "aws_security_group_rule" "websg_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.webserversg.id
  description       = "http"
}

resource "aws_security_group_rule" "websg_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.webserversg.id
  description       = "outbound"
}

resource "aws_instance" "webapp_server-1" {
  ami           = "ami-0eddbd81024d3fbdd"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet-ap-northeast-2a-private-1.id
  vpc_security_group_ids = ["${aws_security_group.webserversg.id}"]
  user_data              = <<-EOF
    #!/bin/sh
    yum update -y
    yum install httpd-2.4.51 -y
    systemctl start httpd
    systemctl enable httpd
    httpd -v
    cp /usr/share/httpd/noindex/index.html /var/www/html/index.html
    EOF

  tags = {
    Name = "webapp_server-1"
  }
}

resource "aws_instance" "webapp_server-2" {
  ami           = "ami-0eddbd81024d3fbdd"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet-ap-northeast-2c-private-2.id
  vpc_security_group_ids = ["${aws_security_group.webserversg.id}"]
  user_data              = <<-EOF
    #!/bin/sh
    yum update -y
    yum install httpd-2.4.51 -y
    systemctl start httpd
    systemctl enable httpd
    httpd -v
    cp /usr/share/httpd/noindex/index.html /var/www/html/index.html
    EOF
  tags = {
    Name = "webapp_server-2"
  }
}

#####################################################
# ALB 구성하기

resource "aws_security_group" "web-alb-sg" {
  name        = "web-alb-sg"
  description = "allow 22, 80"
  vpc_id      = aws_vpc.vpc-ap-northeast-2-web-app-stack.id
}

resource "aws_security_group_rule" "web-alb-sg-ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web-alb-sg.id
  description       = "ssh"
}

resource "aws_security_group_rule" "web-alb-sg-http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web-alb-sg.id
  description       = "http"
}

resource "aws_security_group_rule" "web-alb-sg-outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web-alb-sg.id
  description       = "outbound"
}

resource "aws_alb" "alb-frontend" {
  name            = "alb-example"
  internal        = false
  security_groups = ["${aws_security_group.web-alb-sg.id}"]
  subnets         = [
    "${aws_subnet.subnet-ap-northeast-2a-public-1.id}",
    "${aws_subnet.subnet-ap-northeast-2c-public-2.id}"
  ]

  lifecycle { create_before_destroy = true }
}

resource "aws_alb_target_group" "alb-taget-group" {
  name     = "alb-taget-group"
  vpc_id   = aws_vpc.vpc-ap-northeast-2-web-app-stack.id
  port     = 80
  protocol = "HTTP"
  target_type = "instance"

#   health_check {
#     interval            = 30
#     path                = "/"
#     healthy_threshold   = 3
#     unhealthy_threshold = 3
#   }
}

resource "aws_alb_target_group_attachment" "alb-taget-group-attachment-1" {
  target_group_arn = aws_alb_target_group.alb-taget-group.arn
  target_id        = "${aws_instance.webapp_server-1.id}"
}

resource "aws_alb_target_group_attachment" "alb-taget-group-attachment-2" {
  target_group_arn = aws_alb_target_group.alb-taget-group.arn
  target_id        = "${aws_instance.webapp_server-2.id}"
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = "${aws_alb.alb-frontend.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.alb-taget-group.arn}"
    type             = "forward"
  }
}

#################################################################
