# ============================================================
# CATEGORY 2 - COMPUTE
# EC2 web instance in the private subnet, Application Load
# Balancer in the public subnets, target group and listener.
# The Nginx/Flask stack inside the instance is set up by
# scripts/bootstrap-web.sh (Terraform cannot configure inside
# a container).
# ============================================================

resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.lab.key_name
  iam_instance_profile   = aws_iam_instance_profile.web.name

  tags = {
    Name = "${var.project}-web-01"
    Role = "web"
  }
}

resource "aws_lb" "app" {
  name               = "my-app-alb"
  load_balancer_type = "application"
  internal           = false
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.alb.id]
  tags               = { Name = "${var.project}-alb" }
}

resource "aws_lb_target_group" "web" {
  name        = "nginx-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.lab.id
  target_type = "instance"

  # /health is served by Nginx itself, so ALB health does not depend on S3.
  health_check {
    path                = "/health"
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = { Name = "${var.project}-nginx-tg" }
}

resource "aws_lb_target_group_attachment" "web" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web.id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
