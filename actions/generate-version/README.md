# generate-version

Generate a fully-numeric release version string from the current date and a selectable run-based suffix.

## Behavior

- Supports three schemes:
  - `daily-counter` (default): `<yy.mm.dd>.<count_for_this_repo_today>`
  - `run-number`: `<yy.mm.dd>.<run_number>`
  - `run-id`: `<yy.mm.dd>.<run_id>`
- Publishes a release summary to `GITHUB_STEP_SUMMARY` by default (can be disabled).
- Date and daily boundaries are computed in `America/Indianapolis` timezone.
- For counter-based schemes (`daily-counter` and `run-number`), counters are zero-padded to at least 3 digits.
  - Examples: `1 -> 001`, `7 -> 007`, `99 -> 099`, `100 -> 100`.
- Logs the associated commit SHA and workflow run id for traceability.

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `scheme` | No | `daily-counter` | Versioning scheme to use: `daily-counter`, `run-number`, or `run-id`. |
| `publish-summary` | No | `true` | Whether to publish the release summary to `GITHUB_STEP_SUMMARY`. |

## Outputs

| Name | Description |
|------|-------------|
| `version` | The generated version string based on the selected scheme. |

## Gotchas

- The value is all-numeric and sorts naturally, which suits it for use as a durable release tag.
- `run-id` is globally unique within the repository and maps directly to the run URL (`.../actions/runs/<run_id>`).
- `run-number` is shorter, but uniqueness is only per workflow file.
- `daily-counter` is the shortest and is scoped to repository + day in `America/Indianapolis` by converting local midnight-to-midnight boundaries to UTC, then counting runs in that UTC interval.
- If daily-counter cannot be resolved (CLI/API issues), the action falls back to `run_number` (with the same counter formatting rule).

## Usage

Default behavior (daily counter):

```yaml
- uses: your-org/data-platform/actions/generate-version@main
```

Use workflow run number instead:

```yaml
- uses: your-org/data-platform/actions/generate-version@main
  with:
    scheme: run-number
```

Use globally unique repository run id:

```yaml
- uses: your-org/data-platform/actions/generate-version@main
  with:
    scheme: run-id
```

Disable release summary publishing:

```yaml
- uses: your-org/data-platform/actions/generate-version@main
  with:
    publish-summary: "false"
```
