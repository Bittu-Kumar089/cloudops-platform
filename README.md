# CloudOps Platform

CloudOps Platform is a containerized Node.js application deployed automatically from GitHub Actions
to an AWS EC2 instance. Terraform provisions the compute, network security, IAM, CloudWatch logs,
metrics configuration, and CPU alarm.

## Architecture

GitHub Actions tests and packages the application, publishes the image to GHCR, and connects to EC2
over SSH. EC2 pulls the immutable SHA-tagged image, replaces the running container, and runs an HTTP
health check. A failed deployment can roll back to the previous container image. Docker application
logs are sent to `/cloudops/application` with the AWS logging driver.

```text
GitHub push -> tests/build -> GHCR -> GitHub Actions SSH -> EC2 Docker
                                                        -> CloudWatch
```

## Prerequisites

- Node.js 22 and npm
- Docker
- Terraform
- AWS CLI credentials with permission to manage the project resources
- GitHub repository secrets:
  - `EC2_HOST`
  - `EC2_SSH_KEY`
  - `EC2_KNOWN_HOSTS`

`EC2_KNOWN_HOSTS` should contain the host-key line returned by:

```bash
ssh-keyscan -H <EC2_PUBLIC_IP>
```

## Local development

```bash
npm ci
npm test
npm run lint
npm start
```

The application is available at `http://localhost:3000`.

- `/` displays the application home page.
- `/health` returns service health.
- `/version` reports the deployed image tag.

## Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

`terraform.tfvars` and Terraform state contain local infrastructure details and must not be committed.
Use a remote Terraform backend and state locking for shared environments.

To update all repository-defined infrastructure:

```bash
terraform apply
```

## CI/CD

The `main` branch triggers [deploy.yml](.github/workflows/deploy.yml). Pull requests build and test a
Docker image without publishing or deploying it. Main-branch pushes publish two tags to GHCR:
the commit SHA and `latest`.

The deployment uses strict SSH host verification. A successful health check leaves the new container
running; a failed health check removes the new container and restarts the last known-good image.

## Monitoring

EC2 CPU is an AWS-provided metric. Memory and root disk metrics are published by the CloudWatch Agent
to the custom `CloudOps` namespace. Application stdout and stderr are sent to the
`/cloudops/application` log group.

See [monitoring/README.md](monitoring/README.md) for dashboard, alarm, verification, and
troubleshooting commands.

## Operations

```bash
docker ps
docker logs cloudops-app
docker inspect cloudops-app
docker inspect --format='{{.HostConfig.LogConfig.Type}}' cloudops-app
```

## Placement screenshots

Useful evidence includes the successful GitHub Actions run, GHCR package, EC2 instance, CloudWatch
CPU/memory/disk metrics, dashboard, application log group, alarm state, and automatic redeployment.

## Security and cost controls

- Do not commit private keys, `terraform.tfvars`, or Terraform state.
- Use least-privilege IAM for deployment and monitoring.
- Prefer SSH source restrictions or Systems Manager for production.
- Stop or destroy unused EC2 and supporting resources when the lab is complete.

```bash
cd terraform
terraform destroy
```
