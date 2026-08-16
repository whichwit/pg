# tag-ecr-repository

Add one or more tags to an existing image in Amazon ECR, by copying the source image's manifest to the new tags. Used to promote a durable release image (`r<version>`) to mutable environment pointer tags (`development` / `staging` / `production`).

## Behavior

- Assumes `aws-role-to-assume` in `aws-account-id` (with session tagging skipped).
- Logs in to the registry in `ecr-account-id`.
- Fetches the manifest of `source-tag` via `batch-get-image`, then `put-image` for each tag in `tags`, all targeting `--registry-id <ecr-account-id>` so it works cross-account.

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `repository` | yes | — | ECR repository name. |
| `source-tag` | yes | — | Existing image tag to copy from. |
| `tags` | yes | — | Comma-separated list of tags to apply. |
| `aws-role-to-assume` | yes | — | IAM role **name** to assume (e.g. `d-/s-/p-zeus-deployment`). |
| `aws-account-id` | no | `559587901710` | Account that owns the assumed role. |
| `ecr-account-id` | no | `559587901710` | Account that owns the ECR registry (may differ for cross-account tagging). |

## Gotchas

- **AWS credentials come from the environment** (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`).
- Session tagging is intentionally skipped (`role-skip-session-tagging: true`) because cross-account CI users aren't granted `sts:TagSession` on the central deployment role.
- For cross-account promotion, the assumed role must be granted `ecr:PutImage` on the central registry via the repository policy (see `terraform-ecr-repository`).
- Re-tagging is a manifest copy, so it does not re-upload layers; the "latest wins" pointer semantics apply.
