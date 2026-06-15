resource "aws_lb" "main" {
  name               = "brew-and-bean-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = { Name = "brew-and-bean-alb" }
}

resource "aws_lb_target_group" "main" {
  name        = "brew-and-bean-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path     = "/health"
    protocol = "HTTP"
    port     = "3000"
  }

  tags = { Name = "brew-and-bean-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "The public URL of the coffee shop"
}
