# One CloudWatch dashboard with the numbers that show whether the app is healthy and how busy it
# is: Lambda traffic, errors and duration, memory used, API Gateway requests and CloudFront.
#
# Lambda reports no CPU metric (CPU is allocated in proportion to the memory setting), so the
# dashboard shows duration and memory, which are what a Lambda is sized and billed by.

data "aws_region" "current" {}

locals {
  function_names = [
    var.websocket_handler_function_name,
    var.rest_handler_function_name,
    var.fanout_handler_function_name,
  ]

  region = data.aws_region.current.name

  # One line per function for a Lambda metric.
  lambda_invocations = [for name in local.function_names : ["AWS/Lambda", "Invocations", "FunctionName", name]]
  lambda_errors      = [for name in local.function_names : ["AWS/Lambda", "Errors", "FunctionName", name]]
  lambda_throttles   = [for name in local.function_names : ["AWS/Lambda", "Throttles", "FunctionName", name]]
  lambda_duration    = [for name in local.function_names : ["AWS/Lambda", "Duration", "FunctionName", name]]

  # Logs Insights reads the REPORT line Lambda writes at the end of every invocation.
  memory_query = join(" | ", concat(
    [for name in local.function_names : "SOURCE '/aws/lambda/${name}'"],
    [
      "filter @type = \"REPORT\"",
      "stats max(@maxMemoryUsed / 1024 / 1024) as maxUsedMB, avg(@maxMemoryUsed / 1024 / 1024) as avgUsedMB, max(@memorySize / 1024 / 1024) as configuredMB, count(*) as invocations by @log",
    ]
  ))
}

resource "aws_cloudwatch_dashboard" "overview" {
  dashboard_name = "${var.name_prefix}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "text", x = 0, y = 0, width = 24, height = 2
        properties = {
          markdown = "# ${var.name_prefix}\nLambda traffic, errors, duration and memory; API Gateway; CloudFront. Traces are in CloudWatch > X-Ray traces. Lambda has no CPU metric: CPU scales with the memory setting, so duration and memory stand in for it."
        }
      },
      {
        type = "metric", x = 0, y = 2, width = 8, height = 6
        properties = {
          title = "Lambda invocations", region = local.region, view = "timeSeries", stacked = false
          stat  = "Sum", period = 60, metrics = local.lambda_invocations
        }
      },
      {
        type = "metric", x = 8, y = 2, width = 8, height = 6
        properties = {
          title = "Lambda errors", region = local.region, view = "timeSeries", stacked = false
          stat  = "Sum", period = 60, metrics = local.lambda_errors
        }
      },
      {
        type = "metric", x = 16, y = 2, width = 8, height = 6
        properties = {
          title = "Lambda throttles", region = local.region, view = "timeSeries", stacked = false
          stat  = "Sum", period = 60, metrics = local.lambda_throttles
        }
      },
      {
        type = "metric", x = 0, y = 8, width = 12, height = 6
        properties = {
          title = "Lambda duration, average (ms)", region = local.region, view = "timeSeries", stacked = false
          stat  = "Average", period = 60, metrics = local.lambda_duration
        }
      },
      {
        type = "metric", x = 12, y = 8, width = 12, height = 6
        properties = {
          title = "Lambda duration, p95 (ms)", region = local.region, view = "timeSeries", stacked = false
          stat  = "p95", period = 60, metrics = local.lambda_duration
        }
      },
      {
        type = "log", x = 0, y = 14, width = 24, height = 6
        properties = {
          title = "Lambda memory used (MB) against the configured size", region = local.region
          view  = "table", query = local.memory_query
        }
      },
      {
        type = "metric", x = 0, y = 20, width = 8, height = 6
        properties = {
          title = "REST API requests, client errors and server errors", region = local.region, view = "timeSeries", stacked = false
          stat  = "Sum", period = 60
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", var.http_api_id],
            ["AWS/ApiGateway", "4xx", "ApiId", var.http_api_id],
            ["AWS/ApiGateway", "5xx", "ApiId", var.http_api_id],
          ]
        }
      },
      {
        type = "metric", x = 8, y = 20, width = 8, height = 6
        properties = {
          title  = "REST API latency (ms)", region = local.region, view = "timeSeries", stacked = false
          period = 60
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiId", var.http_api_id, { stat = "Average" }],
            ["AWS/ApiGateway", "Latency", "ApiId", var.http_api_id, { stat = "p95" }],
          ]
        }
      },
      {
        type = "metric", x = 16, y = 20, width = 8, height = 6
        properties = {
          title = "WebSocket connections and messages", region = local.region, view = "timeSeries", stacked = false
          stat  = "Sum", period = 60
          metrics = [
            ["AWS/ApiGateway", "ConnectCount", "ApiId", var.websocket_api_id, "Stage", var.websocket_stage_name],
            ["AWS/ApiGateway", "MessageCount", "ApiId", var.websocket_api_id, "Stage", var.websocket_stage_name],
            ["AWS/ApiGateway", "ExecutionError", "ApiId", var.websocket_api_id, "Stage", var.websocket_stage_name],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 26, width = 24, height = 6
        properties = {
          title  = "CloudFront requests and error rates (web app)", region = "us-east-1", view = "timeSeries", stacked = false
          period = 300
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", var.cloudfront_distribution_id, "Region", "Global", { stat = "Sum" }],
            ["AWS/CloudFront", "4xxErrorRate", "DistributionId", var.cloudfront_distribution_id, "Region", "Global", { stat = "Average", yAxis = "right" }],
            ["AWS/CloudFront", "5xxErrorRate", "DistributionId", var.cloudfront_distribution_id, "Region", "Global", { stat = "Average", yAxis = "right" }],
          ]
        }
      },
    ]
  })
}
