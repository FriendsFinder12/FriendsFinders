# ──────────────────────────────────────────────────────────────────────────────
# Cost budget — warns by email when the AWS bill of the whole account grows
#
# A budget covers the whole account, not one stack, so only one stack creates it
# (create_account_budget = true, set for prod). The email is alarm_email, the same address
# that receives the Lambda error alarms, and AWS Budgets sends the messages itself, so there
# is nothing to confirm. Without an address there is nobody to warn and no budget is made.
# ──────────────────────────────────────────────────────────────────────────────

variable "create_account_budget" {
  description = "Create the monthly cost budget of the AWS account. Set it in one stack only, since the budget covers every stack in the account"
  type        = bool
  default     = false
}

variable "monthly_budget_usd" {
  description = "Monthly cost limit of the account in US dollars"
  type        = number
  default     = 10
}

resource "aws_budgets_budget" "account" {
  count = var.create_account_budget && var.alarm_email != "" ? 1 : 0

  name         = "${var.project_name}-monthly-cost"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Half of the limit is spent: an early sign that something is running more than expected.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alarm_email]
  }

  # The limit is passed.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alarm_email]
  }

  # AWS expects to pass the limit before the month ends, judging by the spending so far.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alarm_email]
  }

  tags = local.tags
}
