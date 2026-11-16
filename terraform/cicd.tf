# ──────────────────────────────────────────────────────────────────────────────
# CI/CD — GitHub Actions OIDC provider + deploy role
#
# Lets the GitHub Actions workflow assume an IAM role using a short-lived OIDC
# token — no long-lived AWS keys stored in GitHub. These resources are created
# by the FIRST local `terraform apply` of each stack; every deploy from GitHub Actions
# thereafter uses them.
# ──────────────────────────────────────────────────────────────────────────────

variable "github_repo" {
  description = "GitHub repo (owner/name) allowed to assume the deploy role"
  type        = string
  default     = "FriendsFinder12/FriendsFinders"
}

variable "github_environment" {
  description = "GitHub Environment whose jobs may assume the deploy role (develop or production). Empty keeps the original rule: any job on the main branch"
  type        = string
  default     = ""
}

variable "create_github_oidc_provider" {
  description = "Create GitHub's OIDC identity provider. An AWS account can have only one, so every stack in the account except one sets this to false and uses the existing provider"
  type        = bool
  default     = true
}

# GitHub's OIDC identity provider. There can be only ONE per AWS account: the first stack
# applied creates it, and the others (create_github_oidc_provider = false) look it up. If one
# already exists that Terraform does not manage, import it instead of creating it:
#   terraform import 'aws_iam_openid_connect_provider.github[0]' <existing-arn>
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fca",
  ]
  tags = local.tags
}

# The stack that created the provider was applied first; apply it before the others.
data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1

  url = "https://token.actions.githubusercontent.com"
}

# Earlier versions created the provider without a count.
moved {
  from = aws_iam_openid_connect_provider.github
  to   = aws_iam_openid_connect_provider.github[0]
}

locals {
  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn

  # Each stack's role can only be assumed by the jobs of its own GitHub Environment, so a deploy
  # to dev can never assume the prod role.
  github_subject = var.github_environment == "" ? "repo:${var.github_repo}:ref:refs/heads/main" : "repo:${var.github_repo}:environment:${var.github_environment}"
}

# Trust policy: only the GitHub Actions jobs of this repo that match github_subject may
# assume the role.
data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.github_subject]
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name               = "${var.project_name}-github-actions-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
  tags               = local.tags
}

# Broad access so Terraform can manage the whole stack.
# For production, scope this down to the services actually used (Lambda, API
# Gateway, DynamoDB, S3, Cognito, CloudFront, IAM, SSM, CloudWatch). The state is in HCP
# Terraform, so this role needs nothing for it.
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "github_actions_deploy_role_arn" {
  description = "Set this as the GitHub Actions repo variable AWS_DEPLOY_ROLE_ARN"
  value       = aws_iam_role.github_actions_deploy.arn
}
