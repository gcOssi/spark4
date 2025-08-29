# Target groups (HTTP internal)
resource "aws_lb_target_group" "fe" {
  name        = "${var.name_prefix}-fe-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "ip"
  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
}

resource "aws_lb_target_group" "be" {
  name        = "${var.name_prefix}-be-tg"
  port        = 4000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "ip"
  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    matcher             = "200-499"
  }
}

# ALB listening HTTP (private behind CloudFront's HTTPS)
resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# FE rule on / (priority 10)
resource "aws_lb_listener_rule" "fe" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fe.arn
  }
  condition {
    path_pattern { values = ["/", "/*"] }
  }
}

# BE rule on /api* (priority 5)
resource "aws_lb_listener_rule" "be" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 5
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.be.arn
  }
  condition {
    path_pattern { values = ["/api*", "/api/*"] }
  }
}

# Services
resource "aws_ecs_service" "frontend" {
  name            = "${var.name_prefix}-frontend-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.fe.arn
    container_name   = "auth-proxy"
    container_port   = 80
  }
  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_service" "backend" {
  name            = "${var.name_prefix}-backend-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.be.arn
    container_name   = "backend"
    container_port   = 4000
  }
  depends_on = [aws_lb_listener.http]
}
