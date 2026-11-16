# Settings for the prod environment. Use with:
#   terraform init -backend-config=backend.hcl -backend-config=envs/prod.backend.hcl
#   terraform plan -var-file=envs/prod.tfvars
environment  = "prod"
project_name = "nearby-friends-prod"
ssm_prefix   = "/nearby-friends-prod"
