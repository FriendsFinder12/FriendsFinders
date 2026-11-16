# Tech Stack

## Runtime & Language

- TypeScript (strict mode, ESNext target, CommonJS modules for Lambda compatibility), one `tsconfig.json` at the repo root that also covers the tests
- Node.js 20 on AWS Lambda (`nodejs20.x`)
- Lambda code is bundled with esbuild (`scripts/build.js`), one bundle per handler, with the AWS SDK left external because the Lambda runtime provides it
- The web app is a single `frontend/index.html` (plain HTML, CSS and JavaScript, no build step)

## AWS Services

- API Gateway v2 (WebSocket API): persistent connections for real-time location updates
- API Gateway v2 (HTTP API): REST endpoints, protected by a Cognito JWT authorizer
- AWS Lambda: three functions, none inside a VPC: `websocket-handler`, `rest-handler`, `fanout-handler`
- Amazon DynamoDB (on-demand billing): four tables, `Users`, `Friendships`, `Connections` (with TTL, a stream and a `geoCell` index) and `FriendRequests`
- Amazon Cognito: user pool and hosted sign-in for the web app
- Amazon S3: profile pictures (server-side encryption) and the hosted web app; CloudFront serves the web app
- AWS SSM Parameter Store: runtime settings
- CloudWatch: log groups and error alarms per Lambda

## AWS SDK

AWS SDK for JavaScript v3, modular clients only:

- `@aws-sdk/client-dynamodb`, `@aws-sdk/lib-dynamodb`
- `@aws-sdk/client-apigatewaymanagementapi`
- `@aws-sdk/client-s3`, `@aws-sdk/s3-request-presigner`
- `@aws-sdk/client-ssm`

## Infrastructure

- Terraform only (no CDK, SAM or Serverless Framework); everything is declarative
- Modules: `api-gateway`, `lambda`, `dynamodb`, `cognito`, `frontend`, `frontend-deploy`, `iam`, `ssm`, `s3`, `monitoring`, plus `cicd.tf` for the GitHub deploy role
- State and locking in HCP Terraform, one workspace per environment (`friendsfinders-dev`, `friendsfinders-prod`) in the `nearbyfriends` organization, with the execution mode set to Local. Terraform still runs on the machine or CI runner that calls it, because it needs `dist/` and the AWS CLI; HCP only stores and locks the state. The organization and workspace come from `TF_CLOUD_ORGANIZATION` and `TF_WORKSPACE`, not from the code.
- CI/CD with GitHub Actions in `.github/workflows/`: `ci.yml` (pull requests: type-check, tests, build, `terraform fmt` and `validate`), `deploy-dev.yml` (push to `develop`) and `deploy-production.yml` (push to `production`, with reviewer approval), both calling the reusable `deploy-environment.yml`. GitHub Environments `develop` and `production` hold the variable `AWS_DEPLOY_ROLE_ARN` and the secret `TF_TOKEN_APP_TERRAFORM_IO`.
- The provider versions are pinned by the committed `terraform/.terraform.lock.hcl`
- One stack per environment (`dev`, `prod`) from the same code. `terraform/envs/<env>.tfvars` sets the `environment`, the `project_name` that prefixes the resource names and the SSM prefix, and its own HCP workspace keeps its state. Without them Terraform builds the original single stack.
- `environment = "prod"` turns on the production safeguards: DynamoDB deletion protection and point-in-time recovery, Cognito deletion protection, S3 versioning for the pictures and longer log retention. `alarm_email` adds an SNS email notification to the Lambda error alarms; it comes from the `ALARM_EMAIL` secret of the production GitHub Environment or from `TF_VAR_alarm_email`, never from a committed file.

## Testing

- Jest with ts-jest. Unit tests are in `tests/unit`, property tests in `tests/property`, web app tests in `tests/frontend`, shared helpers in `tests/helpers`
- fast-check for property-based tests (at least 100 runs per property)
- AWS calls are never made in tests: the wrappers in `src/utils` are tested with `aws-sdk-client-mock`, and the handlers are tested with those wrappers replaced by `jest.mock()`
- The web app is tested by opening the real `frontend/index.html` in `jsdom` (a simulated browser) with a fake API behind it; see `tests/helpers/page.ts`. `jsdom` is pinned to the 26 series because newer versions use ES modules that this Jest setup cannot load.

## Key Constants (configurable through SSM)

- Search radius: 5 miles
- Inactivity TTL: 600 seconds (10 minutes)
- Location update interval: 30 seconds
- Max friends: 5,000
- Nearby strangers limit: 50
- Earth radius: 3958.8 miles (for Haversine)

## SSM Parameters

The paths below are the defaults (`ssm_prefix = /nearby-friends`). An environment sets its own prefix, for example `/nearby-friends-prod`, and the Lambdas receive the full paths through the `SSM_*` environment variables.

- `/nearby-friends/search-radius-miles` (default: 5)
- `/nearby-friends/inactivity-ttl-seconds` (default: 600)
- `/nearby-friends/location-update-interval-seconds` (default: 30)
- `/nearby-friends/max-friends` (default: 5000)
- `/nearby-friends/nearby-strangers-limit` (default: 50)

The Lambdas read them through `src/utils/config.ts`, which caches them for 5 minutes (`CONFIG_CACHE_TTL_SECONDS` overrides that), falls back to the defaults for a missing or invalid value, and logs when SSM cannot be reached.

## Common Commands

```bash
# Install dependencies
npm install

# Type-check (source and tests)
npm run type-check

# Bundle the Lambdas into dist/
npm run build

# Run all tests, or only one kind
npm test
npm run test:unit
npm run test:property
npm run test:frontend

# Coverage
npx jest --coverage

# Terraform (first time: run `terraform login`; then pick the environment)
cd terraform
export TF_CLOUD_ORGANIZATION=nearbyfriends
export TF_WORKSPACE=friendsfinders-dev    # or friendsfinders-prod
terraform init
terraform plan -var-file=envs/dev.tfvars
terraform apply -var-file=envs/dev.tfvars
```
