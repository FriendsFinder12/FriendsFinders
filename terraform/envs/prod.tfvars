# Settings for the prod environment. Use with:
#   TF_WORKSPACE=friendsfinders-prod terraform init
#   terraform plan -var-file=envs/prod.tfvars
environment  = "prod"
project_name = "nearby-friends-prod"
ssm_prefix   = "/nearby-friends-prod"

websocket_stage_name = "prod"
log_retention_days   = 30

# Email for the Lambda error alarms; AWS sends a confirmation message to it. Uncomment and set
# your own address, or pass it with -var alarm_email=...
alarm_email = "gilbertoeybarrai@gmail.com"

# Only jobs of the GitHub Environment "production" can assume this stack's deploy role. The
# OIDC provider already exists (created by the dev stack), so this stack only looks it up.
github_environment          = "production"
create_github_oidc_provider = false
