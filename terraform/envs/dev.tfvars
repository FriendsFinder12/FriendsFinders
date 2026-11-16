# Settings for the dev environment. Use with:
#   TF_WORKSPACE=friendsfinders-dev terraform init
#   terraform plan -var-file=envs/dev.tfvars
environment  = "dev"
project_name = "nearby-friends-dev"
ssm_prefix   = "/nearby-friends-dev"

# The WebSocket URL ends in this stage name, so keep the two environments apart.
websocket_stage_name = "dev"

# Only jobs of the GitHub Environment "develop" can assume this stack's deploy role. This stack
# creates the account's GitHub OIDC provider, so apply it before prod.
github_environment = "develop"
