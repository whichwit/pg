# scaffold-environment

Create a repository's GitHub deployment environments (with their secrets and variables) via Terraform + the GitHub provider.

## Behavior

- Writes a `terraform.tfvars` from the `variables` input and applies it with [`terraform-apply`](../terraform-apply).
- Creates environments: `development`, `pr`, `staging`, `uat`, `infrastructure-review`, `production`.
  - Long-lived environments use custom branch policies (e.g. `develop`, `zp-hotfix/*`). Both gates enable self-review prevention: `infrastructure-review` (an approval-only gate with no deploy target) requires the `Infrastructure-Admins` reviewer team for technical sign-off, and `production` requires the `Data-Platform-PO` (product owners) team for the release approval.
  - The `pr` environment has **no** branch policy, so PR merge refs (`refs/pull/<n>/merge`) can deploy.
- Sets environment **secrets** with the GitHub provider (idempotent PUT).
- Sets environment and repository **variables** via the `gh` CLI (`gh variable set`), which upserts.
- Seeds repository variable **`HAS_UAT=false`** by default (opt in to UAT hotfix entry by setting `HAS_UAT=true` in `repository_variables`).

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `repository` | yes | — | Repository name (name only). |
| `token` | yes | — | GitHub token with repo + environment permissions. |
| `variables` | no | `''` | HCL content for `terraform.tfvars` (maps of `environment_secrets`, `environment_variables`, `repository_variables`). |

## Gotchas

- **The `pr` environment mirrors `development`.** Its secrets/variables default to the `development` entries so ephemeral PR workspaces deploy into the dev account. Override by supplying an explicit `pr` key in `environment_secrets` / `environment_variables`.
- **Variables are managed via `gh` CLI, not Terraform state.** State here is ephemeral (no remote backend), and the GitHub provider's variable resource errors when a variable already exists. Upserting via `gh` makes re-runs idempotent — but variables removed from tfvars are **not** pruned from GitHub.
- Secrets use the provider's idempotent PUT, so they overwrite cleanly on re-runs.
- Requires the `gh` CLI (preinstalled on GitHub-hosted runners) and passes `GITHUB_TOKEN` through for the variable upserts.
