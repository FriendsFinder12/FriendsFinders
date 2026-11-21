# Settings for the prod environment. Use with:
#   TF_WORKSPACE=friendsfinders-prod terraform init
#   terraform plan -var-file=envs/prod.tfvars
environment  = "prod"
project_name = "nearby-friends-prod"
ssm_prefix   = "/nearby-friends-prod"

websocket_stage_name = "prod"
log_retention_days   = 30

# The email for the Lambda error alarms is not kept here, because this repository is public.
# Deploys read it from the secret ALARM_EMAIL of the production GitHub Environment; locally, run
#   export TF_VAR_alarm_email=you@example.com
# AWS sends a confirmation message to that address.

# Only jobs of the GitHub Environment "production" can assume this stack's deploy role. The
# OIDC provider already exists (created by the dev stack), so this stack only looks it up.
github_environment          = "production"
create_github_oidc_provider = false

# GitHub puts ids in the subject of this repository's tokens (immutable subject claims).
github_subject_prefix = "repo:FriendsFinder12@357106725/FriendsFinders@1245137645"

# The monthly cost budget covers the whole AWS account, so only this stack creates it. It warns
# the alarm email at 50% and 100% of monthly_budget_usd (10) and when 100% is forecast.
create_account_budget = true
