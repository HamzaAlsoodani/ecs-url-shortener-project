# URL Shortener - ECS Fargate Project

A URL shortener with click analytics, deployed on AWS ECS Fargate. It uses rolling deployments with automatic rollback, AWS WAF protection, and CI/CD through GitHub Actions with OIDC.

## Demo

Shortening a URL through the load balancer:

![Shortening a URL](images/terminal-step-1.png)

Opening the short link redirects to the original site:

![Short link redirecting](images/proof-url-shortener.gif)

Each click is published to SQS, processed by the worker and saved to PostgreSQL. The dashboard's `/recent` endpoint then shows the click history:

![Click history from the dashboard](images/history-of-clicks.png)

The screenshots were taken while the stack was running on AWS. It has since been torn down with `terraform destroy` to avoid ongoing costs.

## Architecture Overview

- **Compute:** ECS Fargate running three services (api, worker, dashboard) in one cluster
- **Load Balancing:** Application Load Balancer (ALB) with AWS WAF
- **Storage:** RDS PostgreSQL 16, ElastiCache Redis, SQS with a dead-letter queue
- **Networking:** VPC with private subnets for all services, VPC endpoints (no NAT gateways)
- **Deployments:** ECS rolling deployments with the deployment circuit breaker for automatic rollback
- **CI/CD:** GitHub Actions with OIDC authentication and Trivy security scanning

## How It's Built

### Containers

- **Multi-stage builds:** Each Dockerfile has a build stage and a runtime stage. Build tools, compilers and caches stay in the build stage, and only what the service needs to run is copied into the final image. The Go services ship a single binary, and the api ships its virtualenv and source code.
- **Non-root user:** Every container creates a dedicated system user and switches to it with `USER`, so a compromised process has no root access inside the container.
- **Slim, pinned base images:** Images are built on `python:3.12-slim`, `golang:1.26` and `debian:bookworm-slim`, not `latest`, so builds are small and repeatable.
- **Layer caching:** Dependency files (`requirements.txt`, `go.mod`) are copied and installed before the source code, so a code change doesn't reinstall every dependency.
- **Static Go binaries:** Built with `CGO_ENABLED=0`, so they have no runtime dependency on system libraries.
- **Graceful shutdown:** `CMD` uses exec form, so the process receives `SIGTERM` directly from ECS and can finish in-flight requests during a deployment.
- **Minimal build context:** A `.dockerignore` keeps tests, caches and local files out of the api image.

### Infrastructure as Code

- **Modular design:** The infrastructure is split into eight modules (`vpc`, `ecr`, `sqs`, `database`, `alb`, `iam`, `ecs`, `github-oidc`), each with its own `main.tf`, `variables.tf` and `outputs.tf`. The root `main.tf` only wires modules together by passing outputs into inputs, so each part can be read, reviewed and changed on its own.
- **Remote state:** State is stored in S3, not on a laptop, so the whole team works from the same source of truth. The bucket has versioning, encryption, all public access blocked, a policy that rejects non-TLS requests, and `prevent_destroy`.
- **State locking:** Uses Terraform's native S3 lockfile (`use_lockfile`), so two people or pipelines can never apply at the same time and corrupt the state. No separate DynamoDB lock table is needed.
- **Bootstrap stack:** The state bucket is created by a separate `bootstrap` stack, which avoids the problem of Terraform needing a bucket before it can create one.
- **No account details in the repo:** The backend uses partial configuration. The bucket name is supplied at `init` time from a local, gitignored `backend.hcl`.
- **Pinned versions:** Terraform and provider versions are constrained, and `.terraform.lock.hcl` is committed with hashes for both macOS and Linux, so local runs and CI use identical providers.
- **Consistent tagging:** `default_tags` adds `Project` and `ManagedBy` tags to every resource.
- **Plan before apply:** Every change is reviewed with `terraform plan` and applied from the saved plan, so what gets applied is exactly what was reviewed.

### CI/CD

- **No long-lived credentials:** GitHub Actions authenticates to AWS with OIDC and receives short-lived credentials for each run. There are no AWS access keys stored in GitHub or anywhere else.
- **Tightly scoped trust:** The deploy role can only be assumed by this repository's `main` branch. The trust policy uses GitHub's immutable owner and repository IDs, so a renamed or recreated repository can't take it over.
- **Least-privilege deploy role:** The role can only push to the three ECR repositories, update the three ECS services, and pass the three task roles to ECS.
- **Review gate:** CI and Terraform checks run on every pull request. Nothing is deployed until a change is reviewed and merged.
- **Security scanning:** Trivy scans every image on pull requests and again before push, and scans the Terraform for insecure settings. Accepted risks are documented with reasons in `.trivyignore` instead of being silently ignored.
- **Supply chain protection:** Every third-party action is pinned to a full commit SHA, so a compromised tag can't inject code into a pipeline that has AWS access.
- **Least-privilege workflows:** Each workflow declares minimal `permissions`, and only CD can request an OIDC token.
- **Traceable releases:** Images are tagged with the git commit SHA in ECR repositories with immutable tags, so every running container maps to an exact commit.
- **Safe deployments:** `concurrency` stops two deployments from running at once. Documentation-only changes don't trigger a deployment. After each deploy, the pipeline checks that ECS didn't roll back, so a failed release never shows as green.

### Security

- **Private by default:** All services, the database and the cache run in private subnets with no public IPs and no route to the internet. The ALB is the only public entry point, and it sits behind WAF.
- **Per-service IAM roles:** The api can only send to the click-events queue. The worker can only receive and delete from it. The dashboard has no AWS permissions at all. The execution role can only pull this project's images, write to its log groups and read one secret.
- **Security groups reference each other:** Rules allow traffic from a security group, not an IP range, so new tasks created during a deployment are trusted automatically and nothing else is.
- **No hardcoded secrets:** The database password is generated by Terraform, stored in Secrets Manager and injected at startup. It never appears in code, config or environment variable definitions.
- **Encryption:** RDS storage, Redis (at rest and in transit), SQS messages, ECR images and Terraform state are all encrypted.

### Reliability

- **High availability:** Subnets and the ALB span two availability zones, and the api runs two tasks.
- **Health checks everywhere:** The ALB checks `/healthz` on the api and dashboard. The worker has no load balancer, so ECS runs a container health check on it instead.
- **Automatic rollback:** The ECS deployment circuit breaker returns a service to its last working version if new tasks keep failing.
- **No lost events:** The worker only deletes a message after it has been saved, so failures are retried. Messages that fail 5 times go to a dead-letter queue instead of looping forever.
- **Cost awareness:** Fargate runs on ARM64 (Graviton), ECR keeps only the last 10 images, logs are kept for 7 days, and the whole environment can be removed with a single `terraform destroy`.

## Architecture Explanation

The service is split into three containers. The **api** (Python, FastAPI) shortens URLs and handles redirects. The **worker** (Go) processes click events in the background. The **dashboard** (Go) serves analytics. All three run on ECS Fargate in private subnets and are managed with Terraform.

### Traffic Flow

1. **Internet** → Requests enter through the public internet.
2. **AWS WAF** → Blocks IPs sending more than 1000 requests in 5 minutes, and filters common attacks using the AWS managed rule set.
3. **Application Load Balancer** → Sits in the public subnets across two availability zones and routes by path:
   - `/summary`, `/top`, `/recent` and `/url/*` go to the dashboard
   - all other paths go to the api

   ![Application Load Balancer](images/alb.png)

4. **ECS Services** → The api, worker and dashboard run as three services in one ECS cluster, in private subnets with no public IPs. The load balancer only sends traffic to tasks that pass the `/healthz` check.

   ![ECS cluster running the three services](images/ecs.png)

5. **Click events** → When a short link is opened, the api returns a redirect and publishes a click event to SQS.
6. **Worker** → Long-polls SQS, writes each event to PostgreSQL, and deletes the message only after it has been saved.

### Networking

All resources live in one VPC (`10.0.0.0/16`) spread across two availability zones:

![Project VPC](images/vpc.png)

- **Public Subnets (2 AZs):** Host only the ALB, with an Internet Gateway for inbound traffic.
- **Private Subnets (2 AZs):** Host the ECS tasks, RDS and Redis. The private route table has no route to the internet.
- **VPC Endpoints:** Give the tasks private access to ECR, S3, CloudWatch Logs, SQS and Secrets Manager without a NAT gateway.

  ![VPC endpoints](images/vpc-endpoints.png)

- **Security Groups:** The api and dashboard only accept traffic from the ALB. RDS only accepts the three services, and Redis only accepts the api. The worker accepts no inbound traffic. Outbound traffic from the services is limited to the VPC and S3.

### Data Layer

- **RDS PostgreSQL:** Stores URL mappings, click events and hourly click stats. I chose PostgreSQL over DynamoDB because the worker and dashboard are written for Postgres, and the dashboard depends on relational queries such as totals, hourly grouping and upserts.

  ![RDS PostgreSQL instance](images/rds.png)

- **SQS:** Decouples redirects from analytics, so a slow database write never slows down a redirect. Messages that fail 5 times move to a dead-letter queue.
- **ElastiCache Redis:** The caching layer for the api, encrypted at rest and in transit.
- **Secrets Manager:** Holds the database connection string. The password is generated by Terraform and injected into the containers at startup, so it never appears in code.
- **CloudWatch Logs:** Centralised logs for all three services, kept for 7 days.

### Container Registry

ECR holds one private repository per service. Images are tagged with the git commit SHA, and tags are immutable, so every deployment can be traced to an exact commit. Images are encrypted and scanned on push.

![ECR repositories](images/ecr.png)

### CI/CD Pipeline

- **GitHub Actions:** Three workflows. `ci.yml` builds and scans the images on every pull request. `terraform.yml` formats, validates and scans the infrastructure code. `cd.yml` deploys on merge to main.
- **OIDC:** GitHub authenticates to AWS with short-lived credentials. The deploy role can only be used by this repository's main branch, and can only push to the three image repositories and update the three services.
- **Trivy:** Scans every image before it is pushed, and fails the pipeline on any high or critical vulnerability that has a fix.
- **Terraform:** All infrastructure is split into modules, with remote state in S3 and native state locking.

### Key Features Highlighted

- High availability across 2 availability zones
- Security: private subnets, WAF protection, least-privilege IAM roles for each service, no stored credentials
- No NAT gateways: VPC endpoints for all AWS service access
- Zero-downtime deployments with automatic rollback
- Vulnerability scanning on every pull request and deployment

## Rolling Deployment Process

Every merge to main is deployed by the CD pipeline. ECS replaces the running tasks gradually, so users are never left without a healthy version.

### Step 1: New Image Built and Pushed

The pipeline builds the image, scans it with Trivy, tags it with the commit SHA and pushes it to ECR. A new task definition revision is registered with the new image.

### Step 2: New Tasks Started

ECS starts the new tasks alongside the existing ones. The deployment is set to a minimum of 100% and a maximum of 200% healthy capacity, so the old version keeps serving all traffic while the new tasks start up.

### Step 3: Health Checks

The ALB checks `/healthz` on each new task. A task needs 2 passing checks before it receives traffic, and it gets a 60-second grace period to start. The worker has no load balancer, so ECS runs a container health check against its own `/healthz` endpoint instead.

### Step 4: Traffic Shift Complete

Once the new tasks are healthy, the ALB sends traffic to them and the old tasks are drained. Old tasks get 30 seconds to finish their in-flight requests before they stop.

### Step 5: Automatic Rollback on Failure

If the new tasks keep failing their health checks, the ECS deployment circuit breaker stops the rollout and restores the last working version. The pipeline then checks which version is running. If ECS rolled back, the pipeline fails, so the developer knows the release did not go out.
