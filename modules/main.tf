resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
}

resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
}

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_security_group" "webSg" {
  name        = "webSg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

resource "aws_s3_bucket" "example" {
  bucket = "thilankadhterraform2023"
}

resource "aws_instance" "webserver" {
  count                  = 2
  ami                    = "ami-0261755bbcb8c4a84"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.webSg.id]
  subnet_id              = count.index == 0 ? aws_subnet.sub1.id : aws_subnet.sub2.id
  user_data              = count.index == 0 ? base64encode(file("userdata.sh")) : base64encode(file("userdata1.sh"))
}

resource "aws_lb" "myalb" {
  count              = 1
  name               = "myalb-${count.index}"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.webSg.id]
  subnets         = [aws_subnet.sub1.id, aws_subnet.sub2.id]

  tags = {
    Name = "web-${count.index}"
  }
}

resource "aws_lb_target_group" "tg" {
  count    = 1
  name     = "myTG-${count.index}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "attach" {
  count            = 2
  target_group_arn = aws_lb_target_group.tg[0].arn
  target_id        = aws_instance.webserver[count.index].id
  port             = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.myalb[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg[0].arn
    type             = "forward"
  }
}

