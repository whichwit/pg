# terraform-aws

Run Terraform for an environment's AWS infrastructure (plan / apply / destroy), with support for a separate workspace from the tfvars environment.

## Behavior

- Installs Terraform, runs `terraform init -upgrade` in `working-directory`.
- Selects (or creates) the workspace: `workspace` if provided, else `environment`.
- Always runs `terraform plan` with `-var-file="<environment>.tfvars"`, injecting `aws_access_key`, `aws_secret_key`, `release_version`, and any extra `args`.
- Then, based on flags:
  - `apply: true` → `terraform apply tfplan`.
  - `destroy: true` (and `apply` not `true`) → `terraform destroy` (re-passing the same vars/tfvars).
  - Neither → plan only.

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `environment` | yes | — | Environment whose tfvars file to use (selects `<environment>.tfvars`). |
| `workspace` | no | `''` | Workspace to select/create. Use to isolate state for a PR while reusing an environment's tfvars. Defaults to `environment`. |
| `release-version` | yes | — | Release version for resource tagging. |
| `working-directory` | no | `infrastructure` | Terraform working directory. |
| `destroy` | no | `false` | Destroy instead of create/update. |
| `apply` | no | `false` | Apply the plan (otherwise plan-only). |
| `args` | no | `''` | Extra arguments appended to the plan (e.g. `-var` flags). |
| `terraform-version` | no | `latest` | Terraform version to install. |

## Gotchas

- **`environment` vs `workspace`**: `environment` picks the tfvars file; `workspace` isolates Terraform state. A PR deploy typically uses `environment: development` with `workspace: pr-<number>`.
- **AWS credentials come from the environment** (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) and are passed into Terraform as `aws_access_key` / `aws_secret_key` vars.
- Both destroy and apply run a plan first; the plan requires all required variables to resolve (`-input=false` fails fast rather than prompting).
- Extra `-var` values (e.g. Okta secrets) are passed via `args` and are re-applied on destroy.
