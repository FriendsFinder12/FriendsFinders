# Settings for the dev environment. Use with:
#   TF_WORKSPACE=friendsfinders-dev terraform init
#   terraform plan -var-file=envs/dev.tfvars
environment  = "dev"
project_name = "nearby-friends-dev"
ssm_prefix   = "/nearby-friends-dev"

# The WebSocket URL ends in this stage name, so keep the two environments apart.
websocket_stage_name = "dev"
