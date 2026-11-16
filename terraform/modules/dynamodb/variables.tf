variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "protect" {
  description = "Production safeguards: deletion protection and point-in-time recovery"
  type        = bool
  default     = false
}
