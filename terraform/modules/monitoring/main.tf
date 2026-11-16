resource "aws_cloudwatch_log_group" "websocket_handler" {
  name              = "/aws/lambda/${var.websocket_handler_function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "rest_handler" {
  name              = "/aws/lambda/${var.rest_handler_function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "fanout_handler" {
  name              = "/aws/lambda/${var.fanout_handler_function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# Optional email notification for the alarms (the address must confirm the subscription).
resource "aws_sns_topic" "alarms" {
  count = var.alarm_email == "" ? 0 : 1

  name = "${var.name_prefix}-alarms"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "alarm_email" {
  count = var.alarm_email == "" ? 0 : 1

  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

locals {
  alarm_actions = var.alarm_email == "" ? [] : [aws_sns_topic.alarms[0].arn]
}

# Error alarms per Lambda
resource "aws_cloudwatch_metric_alarm" "websocket_handler_errors" {
  alarm_name          = "${var.websocket_handler_function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "WebSocket handler error rate exceeded threshold"
  alarm_actions       = local.alarm_actions

  dimensions = {
    FunctionName = var.websocket_handler_function_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rest_handler_errors" {
  alarm_name          = "${var.rest_handler_function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "REST handler error rate exceeded threshold"
  alarm_actions       = local.alarm_actions

  dimensions = {
    FunctionName = var.rest_handler_function_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "fanout_handler_errors" {
  alarm_name          = "${var.fanout_handler_function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Fanout handler error rate exceeded threshold"
  alarm_actions       = local.alarm_actions

  dimensions = {
    FunctionName = var.fanout_handler_function_name
  }

  tags = var.tags
}
