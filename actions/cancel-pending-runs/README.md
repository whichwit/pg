# cancel-pending-runs

Cancel older *pending* (waiting) runs of the current workflow on the current branch, to avoid redundant pipelines.

## Behavior

- Lists runs for the current branch + workflow with status `waiting`.
- Cancels any whose run number is **less than** the current run number.

## Inputs

None.

## Gotchas

- Only targets `waiting` runs (e.g. queued behind an environment gate), not in-progress ones.
- Uses `github.token`; the workflow needs `actions: write` permission to cancel runs.
- Complements a `concurrency` group but is scoped to earlier run numbers only.
