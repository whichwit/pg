# scaffold-branch

Seed a repository's default branch from the template's `repository_seed/` files and push it.

## Behavior

- Copies `./repository_seed` to a temp dir.
- Initializes a git repo, commits the seed files, and creates the branch (`develop` by default).
- Adds a token-authenticated `origin` pointing at `Zotec-Product-Development/<repository>` and pushes the branch.

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `repository` | yes | — | Target repository name (name only). |
| `token` | yes | — | GitHub token with repo permissions. |
| `branch` | no | `develop` | Default branch name to create. |

## Gotchas

- Expects a `repository_seed/` directory to exist in the checkout (the template's seed files).
- The commit is authored as `github-actions[bot]`.
- Pushing to an existing branch will fail; callers typically check branch existence first (see `scaffold.yml`).
