# scaffold-repository

Create a new GitHub repository via Terraform + the GitHub provider.

## Behavior

- Writes a `terraform.tfvars` from the `variables` input.
- Applies it with [`terraform-apply`](../terraform-apply) to create the repository.

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `repository` | yes | — | Name for the new repository (name only). |
| `token` | yes | — | GitHub token with repo permissions. |
| `variables` | no | `''` | HCL content for `terraform.tfvars` (typically `github_token`, `github_repository`). |

## Gotchas

- Runs against this action's own Terraform config; state is local/ephemeral.
- The token must have permission to create repositories in the `Zotec-Product-Development` org.
