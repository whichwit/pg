# docker-build-push-ecr

Build a project's Docker image and push it to an **existing** ECR repository.

The repository is **not** provisioned here — run [`terraform-ecr-repository`](../terraform-ecr-repository) in a preceding step. This action only logs in, builds, and pushes.

## Behavior

- Always computes a CI tag `ci-<git-sha>` and pushes it (unless it already exists).
- When `release-version` is set, additionally pushes the durable release tag `r<version>`.
- Skips building/pushing a tag that already exists in ECR (idempotent re-runs) by checking with `aws ecr describe-images`. If both `ci-<sha>` and `r<version>` already exist, the build step is skipped entirely.
- Assumes `aws-role-to-assume` in `aws-account-id` for ECR access, then uses Buildx with GitHub Actions cache (`type=gha`).
- Stamps OCI labels onto the image for traceability back to the producing run/commit:
  - `org.opencontainers.image.revision` — commit SHA
  - `org.opencontainers.image.source` — repository URL
  - `com.github.run-id` — workflow `run_id`
  - `com.github.run-url` — direct link to the run

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `project` | yes | — | Infrastructure project name. ECR repo defaults to `<project>/default`. |
| `repository` | no | `''` | Full ECR repo name, overriding the `<project>/default` convention. |
| `aws-access-key-id` | yes | — | AWS access key ID. |
| `aws-secret-access-key` | yes | — | AWS secret access key. |
| `aws-region` | yes | — | AWS region. |
| `aws-account-id` | yes | — | Account hosting the ECR registry. |
| `aws-role-to-assume` | yes | — | Deployment role **name** to assume for ECR access. |
| `release-version` | no | `''` | When set, also build/push the durable `r<version>` tag. |
| `platforms` | no | `linux/arm64` | Target build platforms. |
| `context` | no | `.` | Docker build context. |
| `file` | no | `Dockerfile` | Path to the Dockerfile. |
| `target` | no | `''` | Target build stage (optional). |
| `build-args` | no | `''` | Newline-delimited `KEY=value` build args. |
| `provenance` | no | `false` | Generate provenance attestation. |
| `sbom` | no | `false` | Generate SBOM attestation. |
| `cache-scope` | no | `image` | GHA build cache scope (used only when `cache-from`/`cache-to` are not set). Keep distinct from other builds in the same repo so their `mode=max` caches don't overwrite each other. |
| `cache-from` | no | `''` | Override the cache source, e.g. `type=registry,ref=ghcr.io/<owner>/<repo>/buildcache:image`. Defaults to `type=gha` with `cache-scope`. |
| `cache-to` | no | `''` | Override the cache export, e.g. `type=registry,ref=...,mode=max,image-manifest=true,oci-mediatypes=true`. Defaults to `type=gha,mode=max` with `cache-scope`. |

## Outputs

| Name | Description |
|------|-------------|
| `image-tag` | The CI image tag (`ci-<sha>`) that was built. |

## Gotchas

- **AWS Lambda container images require a single manifest.** `provenance` and `sbom` default to `false` on purpose — enabling either makes `build-push-action` publish a multi-manifest OCI image index, which Lambda **cannot** deploy. Leave them off for Lambda images.
- `aws-role-to-assume` is a role **name**, not an ARN; the ARN is composed as `arn:aws:iam::<aws-account-id>:role/<aws-role-to-assume>`.
- The repo must already exist — provision it first with `terraform-ecr-repository`.
- **Cache scope collisions.** `type=gha` caches are keyed by `cache-scope`; two `mode=max` builds sharing a scope overwrite each other's manifests and tank the hit rate. Give each distinct build (e.g. a `test`-target build vs. this image build) its own scope.
- **GHA caches are branch-isolated.** A branch only restores caches created on itself or the repo's default branch, so feature-branch builds start cold unless the default branch has built recently. For cross-branch reuse, override `cache-from`/`cache-to` with a registry cache (`type=registry`). GHCR works well and only needs a `docker/login-action` with `GITHUB_TOKEN` (no ECR role); use a distinct tag per build (e.g. `:test` vs `:image`) and give the cache package a retention policy.
- Tag existence is checked per-tag; an image is only rebuilt/pushed for the tags that are missing.
