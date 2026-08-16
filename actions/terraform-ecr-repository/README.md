# terraform-ecr-repository

Create / check (or destroy) one or more ECR repositories via Terraform, including their lifecycle and cross-account repository policies.

## Behavior

- Runs `terraform init` against this action's own directory using a per-project state key (`<project>/<project>-ecr-terraform.tfstate`).
- Writes a `terraform.tfvars` from the inputs (AWS creds from env, project, repositories, etc.).
- Always runs `terraform plan`. Then:
  - `apply: true` → `terraform apply`.
  - `destroy: true` (and `apply` not `true`) → `terraform destroy`.
  - Neither → plan only.
- Repository name resolution: if `repository` is set it is used verbatim; otherwise each comma-separated sub-name in `repositories` becomes `<project>/<sub-name>`.
- Applies `IMMUTABLE_WITH_EXCLUSION` tag mutability (mutable pointer tags: `local*`, `development`, `staging`, `uat`, `production`), a lifecycle policy, and a repository policy granting higher-environment accounts pull/PutImage and the Lambda service principal pull access.

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `project` | yes | — | Infrastructure project name. |
| `aws-role-to-assume` | yes | — | IAM role **name** to assume for deployment. |
| `repositories` | no | `default` | Comma-separated ECR sub-names (each becomes `<project>/<name>`). Ignored when `repository` is set. |
| `repository` | no | `''` | Full ECR repo name, overriding the convention. |
| `destroy` | no | `false` | Destroy instead of create/update. |
| `force-delete` | no | `false` | Allow deleting a repo that still contains images. |
| `apply` | no | `false` | Apply the plan (otherwise plan-only). |
| `aws-account-id` | no | `559587901710` | Account that owns the ECR registry. |
| `terraform-version` | no | `latest` | Terraform version to install. |

## Outputs

| Name | Description |
|------|-------------|
| `ecr-repository-url` | JSON map of repo key → repository URL (only on apply). |
| `ecr-repository-name` | JSON map of repo key → repository name (only on apply). |

## Gotchas

- **AWS credentials come from the environment** (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`) — configure them in a preceding step.
- Outputs are only populated when `apply: true`.
- Destroying a non-empty repo fails unless `force-delete: true`.
- The repository policy is scoped to the Data Platform dev/staging/prod accounts; the Lambda pull statement is controlled by the `lambda_pull_account_ids` variable (defaults to those three accounts).
- Provision the repo with this action **before** pushing images with `docker-build-push-ecr`.
