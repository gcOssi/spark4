resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# CPU > 70% for frontend service
resource "aws_cloudwatch_metric_alarm" "fe_cpu_high" {
  alarm_name          = "${var.name_prefix}-fe-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Frontend ECS service CPU > 70%"
  treat_missing_data  = "notBreaching"
  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.frontend.name
  }
  alarm_actions = [aws_sns_topic.alerts.arn]
}

# CPU > 70% for backend service
resource "aws_cloudwatch_metric_alarm" "be_cpu_high" {
  alarm_name          = "${var.name_prefix}-be-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Backend ECS service CPU > 70%"
  treat_missing_data  = "notBreaching"
  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.backend.name
  }
  alarm_actions = [aws_sns_topic.alerts.arn]
}
