# create-release

Tag the current commit and create a GitHub release for it using the GitHub CLI.

## Behavior

- Creates and pushes an annotated git tag `r<version>` on the deployed commit (`github.sha`), unless the tag already exists.
- Prepends a traceability line (commit SHA + link to the producing workflow run) to all release notes.
- Idempotent across re-runs of the same workflow run (the tag is derived from a stable version).

Consumers of this action follow [Conventional Commits](https://www.conventionalcommits.org/). Notes are generated from commit subjects by default.

### Release notes pathway

| `mode` | Behavior |
| --- | --- |
| **`conventional`** (default) | [git-cliff](https://git-cliff.org/) groups commits by type (`feat`, `fix`, …). Scopes are omitted from each line. Subjects that are not conventional go under **Uncategorized**. |
| **`scoped`** | Same grouping as `conventional`, but each line includes the scope when present (`**api:** add retry logic`). |
| **`auto`** | If `release-notes` is set and the file exists, use that markdown. Otherwise `gh release create --generate-notes` (GitHub lists merged PRs since the previous release). |

`release-notes` is ignored unless `mode` is `auto`.

git-cliff is used (a local binary, pinned in this action) rather than Commitizen. Commitizen is for *authoring* conventional commits and bumping versions; git-cliff is the changelog generator and supports CalVer `r*` tags plus an Uncategorized bucket.

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `tag` | yes | — | The release version without prefix; the release tag is `r<version>`. |
| `mode` | no | `conventional` | `conventional`, `scoped`, or `auto`. |
| `release-notes` | no | `''` | Path to repo-generated release notes markdown. Only used when `mode=auto`. |

## Example: conventional notes (default)

```yaml
- uses: Zotec-Product-Development/DataPlatform/actions/create-release@main
  with:
    tag: ${{ needs.release-management.outputs.version }}
```

## Example: include scopes

```yaml
- uses: Zotec-Product-Development/DataPlatform/actions/create-release@main
  with:
    tag: ${{ needs.release-management.outputs.version }}
    mode: scoped
```

## Example: GitHub notes or a supplied file

```yaml
- uses: Zotec-Product-Development/DataPlatform/actions/create-release@main
  with:
    tag: ${{ needs.release-management.outputs.version }}
    mode: auto
    release-notes: CHANGELOG.md   # optional; omit to use --generate-notes
```

## Changelog grouping

Types match `actions/check-conventional-commit`: `feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `build`, `ci`, `chore`, `style`, `revert`. A `type!` / `BREAKING CHANGE` commit is listed under **Breaking Changes**. Merge commits are skipped. The previous release is the latest `r*` tag (CalVer, not semver).

## Gotchas

- The release tag is prefixed with `r` (e.g. input `26.07.09.16428739205` → tag/release `r26.07.09.16428739205`).
- Uses `github.token`; the workflow needs `contents: write` permission to push the tag and create the release.
- `conventional` / `scoped` check out full history and tags inside the action (the caller does not need `fetch-depth: 0`).
- If `mode=auto` and `release-notes` is set but the file is missing, the action **falls back** to GitHub auto-generated notes with a warning.
- Run this only after a successful production deploy.
