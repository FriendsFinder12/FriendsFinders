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
- CloudWatch dashboard `<project_name>-overview` (`terraform/modules/monitoring/dashboard.tf`): per-Lambda invocations, errors, throttles, duration (average and p95) and memory used against the configured size (a Logs Insights query over the `REPORT` lines), REST API requests, errors and latency, WebSocket connections and messages, and CloudFront requests and error rates. Lambda has no CPU metric: CPU scales with the memory setting
- X-Ray: active tracing on the three Lambdas; `src/utils/tracing.ts` wraps the AWS SDK clients (DynamoDB, SSM, S3, API Gateway management) with `aws-xray-sdk-core` so each call is a subsegment. It only instruments inside Lambda, so tests and local runs are unaffected. API Gateway HTTP and WebSocket APIs cannot be traced, so a trace starts at the Lambda

## AWS SDK

AWS SDK for JavaScript v3, modular clients only:

- `@aws-sdk/client-dynamodb`, `@aws-sdk/lib-dynamodb`
- `@aws-sdk/client-apigatewaymanagementapi`
- `@aws-sdk/client-s3`, `@aws-sdk/s3-request-presigner`
- `@aws-sdk/client-ssm`

## Infrastructure

- Terraform only (no CDK, SAM or Serverless Framework); everything is declarative
- Modules: `api-gateway`, `lambda`, `dynamodb`, `cognito`, `frontend`, `iam`, `ssm`, `s3`, `monitoring`, plus `cicd.tf` for the GitHub deploy role
- State and locking in HCP Terraform, one workspace per environment (`friendsfinders-dev`, `friendsfinders-prod`) in the `nearbyfriends` organization, with the execution mode set to Local. Terraform still runs on the machine or CI runner that calls it, because it needs `dist/` and the AWS CLI; HCP only stores and locks the state. The organization and workspace come from `TF_CLOUD_ORGANIZATION` and `TF_WORKSPACE`, not from the code.
- CI/CD with GitHub Actions in `.github/workflows/`: `ci.yml` checks every pull request (type-check, tests, build, `terraform fmt` and `validate`). Two pipelines deploy, each on pushes to `develop` (dev) and to `production` (prod, with reviewer approval): `backend.yml` (test and build with `npm run test:backend`, then Terraform apply) and `frontend.yml` (the jsdom tests, then the page is published). They call the reusable `backend-environment.yml` and `frontend-environment.yml`, which run the tests in a job that needs no AWS access before the job that waits for approval. The page is published by the Frontend pipeline, not by Terraform: `scripts/render-frontend.js` injects the settings from `terraform output -json` into `frontend/index.html`, and the job copies it to the frontend bucket and invalidates CloudFront. GitHub Environments `develop` and `production` hold the variable `AWS_DEPLOY_ROLE_ARN` and the secret `TF_TOKEN_APP_TERRAFORM_IO`.
- The provider versions are pinned by the committed `terraform/.terraform.lock.hcl`
- One stack per environment (`dev`, `prod`) from the same code. `terraform/envs/<env>.tfvars` sets the `environment`, the `project_name` that prefixes the resource names and the SSM prefix, and its own HCP workspace keeps its state. Without them Terraform builds the original single stack.
- `environment = "prod"` turns on the production safeguards: DynamoDB deletion protection and point-in-time recovery, Cognito deletion protection, S3 versioning for the pictures and longer log retention. `alarm_email` adds an SNS email notification to the Lambda error alarms; it comes from the `ALARM_EMAIL` secret of the production GitHub Environment or from `TF_VAR_alarm_email`, never from a committed file. The same address receives the monthly cost budget of the AWS account (`terraform/budget.tf`, 10 USD, set with `create_account_budget = true` in `prod.tfvars` only), which warns at 50% and 100% of the limit and when 100% is forecast. Without the address no budget is created.

## Testing

- Jest with ts-jest. Unit tests are in `tests/unit`, property tests in `tests/property`, web app tests in `tests/frontend`, shared helpers in `tests/helpers`
- fast-check for property-based tests (at least 100 runs per property)
- Coverage thresholds in `jest.config.ts`: 80% for `src/utils` and 70% for the rest (the handlers). They are checked by `npm run test:coverage`, which CI runs on every pull request; plain `npm test` does not check them. `scripts/coverage-summary.js` turns the report (`coverage/coverage-summary.json`) into a table that `ci.yml` and the Backend pipeline write to the page of the run, even when a threshold fails, and the Backend pipeline also keeps the HTML report as an artifact for 14 days
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
npm run test:backend

# Coverage report; fails below the thresholds in jest.config.ts
npm run test:coverage

# Terraform (first time: run `terraform login`; then pick the environment)
cd terraform
export TF_CLOUD_ORGANIZATION=nearbyfriends
export TF_WORKSPACE=friendsfinders-dev    # or friendsfinders-prod
terraform init
terraform plan -var-file=envs/dev.tfvars
terraform apply -var-file=envs/dev.tfvars
```
