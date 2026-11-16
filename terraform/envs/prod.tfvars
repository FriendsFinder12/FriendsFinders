# Settings for the prod environment. Use with:
#   terraform init -backend-config=backend.hcl -backend-config=envs/prod.backend.hcl
#   terraform plan -var-file=envs/prod.tfvars
environment  = "prod"
project_name = "nearby-friends-prod"
ssm_prefix   = "/nearby-friends-prod"

websocket_stage_name = "prod"
log_retention_days   = 30

# Email for the Lambda error alarms; AWS sends a confirmation message to it. Uncomment and set
# your own address, or pass it with -var alarm_email=...
alarm_email = "gilbertoeybarrai@gmail.com"
