# terraform-apply

Minimal Terraform runner: init → plan → apply from a working directory. Used by the scaffold actions to apply their generated Terraform configuration.

## Behavior

- Installs Terraform.
- `terraform init -upgrade` in `working-directory`.
- `terraform plan -out=tfplan`.
- `terraform apply -auto-approve tfplan`.

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `working-directory` | yes | `.` | Directory containing the Terraform configuration. |
| `terraform-version` | no | `latest` | Terraform version to install. |

## Gotchas

- Always applies — there is no plan-only or destroy mode.
- Does not pass any variables; the working directory must supply its own `terraform.tfvars` (the scaffold actions generate one) and backend configuration.
- Any AWS/GitHub credentials must be available in the environment.
