# check-conventional-commit

Validate a title or commit message against conventional commit format, with optional scope, breaking-change marker, and Azure Boards (`AB#`) reference.

## Behavior

Fails the step when the input does not match the expected pattern. Emits a `::error::` annotation with format guidance.

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `title` | yes | — | String to validate (typically `github.event.pull_request.title`). |

## Accepted formats

```
feat: add retry logic
fix(api): handle timeout edge case
feat(prompt):AB#86798: improve SF case handling
chore!: drop legacy endpoint
refactor: rename call getValue() helper
```

### Rules

- **type** (required): `feat`, `fix`, `chore`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`, `style`, or `revert`
- **scope** (optional): alphanumeric with `_`, `.`, `-`, in parentheses
- **breaking** (optional): `!` before the colon
- **AB# reference** (optional): e.g. `AB#86798:` after the colon
- **description**: starts lowercase, 10–72 characters, parentheses allowed (e.g. `getValue()`), no trailing period

## Example: PR title check

```yaml
jobs:
  pr-title:
    name: PR Title Format
    runs-on: ubuntu-24.04-arm
    steps:
      - uses: Zotec-Product-Development/DataPlatform/actions/check-conventional-commit@main
        with:
          title: ${{ github.event.pull_request.title }}
```

## Gotchas

- Intended for PR workflows; pass any string via `title` for other use cases (e.g. squash-merge title linting).
- Repos that do not want conventional commits can omit the `pr-title` job entirely — the baseline deploy flow does not require it.
