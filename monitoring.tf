# ============================================================
# CATEGORY 5 - MONITORING
# SNS topic -> HTTP forwarder -> Mailpit, CloudWatch alarms,
# custom port/disk metrics (pushed by scripts/lab-metrics.sh),
# and a log group with a metric filter for nginx 5xx errors.
# ============================================================

resource "aws_sns_topic" "alerts" {
  name = "WebAppAlerts"
  tags = { Name = "${var.project}-alerts" }
}

# Email subscriptions are not used: Floci's SNS docs list SQS, Lambda
# and HTTP delivery. HTTP goes to the forwarder, which emails Mailpit.
resource "aws_sns_topic_subscription" "forwarder" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "http"
  endpoint  = var.alert_forwarder_url
}

locals {
  alarm_actions = [aws_sns_topic.alerts.arn]
}

# ---------- Compute ----------

resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  alarm_name          = "${var.project}-ec2-cpu-high"
  alarm_description   = "Web instance CPU above 80% for 5 minutes"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { InstanceId = aws_instance.web.id }
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "ec2_status_check" {
  alarm_name          = "${var.project}-ec2-status-check-failed"
  alarm_description   = "Instance or system status check failing"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { InstanceId = aws_instance.web.id }
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "disk_high" {
  alarm_name          = "${var.project}-disk-used-high"
  alarm_description   = "Root filesystem above 85% (custom metric from lab-metrics.sh)"
  namespace           = "Lab/System"
  metric_name         = "DiskUsedPercent"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { InstanceId = aws_instance.web.id }
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# ---------- Load balancer ----------

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.project}-alb-unhealthy-hosts"
  alarm_description   = "At least one target failing ALB health checks"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    TargetGroup  = aws_lb_target_group.web.arn_suffix
    LoadBalancer = aws_lb.app.arn_suffix
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "alb_target_5xx" {
  alarm_name          = "${var.project}-alb-target-5xx"
  alarm_description   = "More than 5 HTTP 5xx responses from targets in 5 minutes"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { LoadBalancer = aws_lb.app.arn_suffix }
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "alb_latency" {
  alarm_name          = "${var.project}-alb-slow-response"
  alarm_description   = "Average target response time above 1 second"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { LoadBalancer = aws_lb.app.arn_suffix }
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# ---------- NAT (conceptual: Floci does not emulate NAT traffic) ----------

resource "aws_cloudwatch_metric_alarm" "nat_port_allocation" {
  alarm_name          = "${var.project}-nat-port-allocation-errors"
  alarm_description   = "NAT out of source ports. Expect INSUFFICIENT_DATA in Floci; learning object."
  namespace           = "AWS/NATGateway"
  metric_name         = "ErrorPortAllocation"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { NatGatewayId = aws_nat_gateway.nat.id }
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# ---------- Ports (custom metric PortUp, one alarm per port) ----------

resource "aws_cloudwatch_metric_alarm" "port_down" {
  for_each = var.probe_ports

  alarm_name          = "${var.project}-port-${each.key}-down"
  alarm_description   = "Port ${each.value} (${each.key}) not reachable on the host"
  namespace           = "Lab/Ports"
  metric_name         = "PortUp"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching" # no probe data at all also means "down"
  dimensions          = { Port = tostring(each.value) }
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# ---------- Storage and queues ----------

resource "aws_cloudwatch_metric_alarm" "dynamodb_throttled" {
  alarm_name          = "${var.project}-users-throttled"
  alarm_description   = "DynamoDB requests being throttled on the users table"
  namespace           = "AWS/DynamoDB"
  metric_name         = "ThrottledRequests"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { TableName = aws_dynamodb_table.app_users.name }
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.project}-alerts-dlq-not-empty"
  alarm_description   = "Undelivered alert messages are sitting in the DLQ"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { QueueName = aws_sqs_queue.alerts_dlq.name }
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# ---------- Logs ----------

resource "aws_cloudwatch_log_group" "nginx_access" {
  name              = "/lab/nginx/access"
  retention_in_days = 14
}

# Counts nginx responses with a 5xx status. Stays quiet until you ship
# access.log into this group (a stretch scenario in the guide).
resource "aws_cloudwatch_log_metric_filter" "nginx_5xx" {
  name           = "nginx-5xx"
  log_group_name = aws_cloudwatch_log_group.nginx_access.name
  pattern        = "[ip, ident, user, time, request, status=5*, size]"

  metric_transformation {
    name          = "Nginx5xx"
    namespace     = "Lab/Nginx"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "nginx_5xx" {
  alarm_name          = "${var.project}-nginx-5xx-burst"
  alarm_description   = "Five or more nginx 5xx responses in 5 minutes"
  namespace           = "Lab/Nginx"
  metric_name         = "Nginx5xx"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}
