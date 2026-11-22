variable "websocket_handler_function_name" {
  description = "Function name of the WebSocket handler Lambda"
  type        = string
}

variable "rest_handler_function_name" {
  description = "Function name of the REST handler Lambda"
  type        = string
}

variable "fanout_handler_function_name" {
  description = "Function name of the fanout handler Lambda"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "name_prefix" {
  description = "Prefix for the names of resources created here (the project name)"
  type        = string
}

variable "log_retention_days" {
  description = "How long CloudWatch keeps the Lambda logs"
  type        = number
  default     = 14
}

variable "alarm_email" {
  description = "Email address notified when an alarm fires; empty means no notification"
  type        = string
  default     = ""
}

variable "http_api_id" {
  description = "ID of the HTTP (REST) API, for the dashboard"
  type        = string
}

variable "websocket_api_id" {
  description = "ID of the WebSocket API, for the dashboard"
  type        = string
}

variable "websocket_stage_name" {
  description = "Stage of the WebSocket API, for the dashboard"
  type        = string
}

variable "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution that serves the web app, for the dashboard"
  type        = string
}
