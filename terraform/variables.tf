variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
  default     = "nearby-friends"
}

variable "environment" {
  description = "Which environment this deployment is: dev or prod. Sets the Environment tag and, later, the production-only protections"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be \"dev\" or \"prod\"."
  }
}

variable "ssm_prefix" {
  description = "Path prefix of the runtime settings in SSM Parameter Store, without a trailing slash. Each environment in the same account needs its own"
  type        = string
  default     = "/nearby-friends"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "nearby-friends"
    Environment = "dev"
    ManagedBy   = "terraform"
    Team        = "team-3"
    Name        = "juan.contreras@iteso.mx"
  }
}
