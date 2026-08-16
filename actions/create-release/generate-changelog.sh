#!/usr/bin/env bash
# Generate conventional-commit release notes with git-cliff.
# Commitizen (cz) is for authoring/bumping commits, not changelog generation.
set -euo pipefail

GIT_CLIFF_VERSION="2.13.1"
MODE="${MODE:-conventional}"
ACTION_PATH="${ACTION_PATH:-$(cd "$(dirname "$0")" && pwd)}"
REPO="${GITHUB_WORKSPACE:-.}"
TAG="${TAG:-}"
TMP_DIR="${RUNNER_TEMP:-$(mktemp -d)}"
NOTES_FILE="${TMP_DIR}/CHANGELOG.md"

case "${MODE}" in
  conventional) CONFIG="${ACTION_PATH}/cliff.toml" ;;
  scoped) CONFIG="${ACTION_PATH}/cliff-scoped.toml" ;;
  *)
    echo "::error::Changelog generation is only valid for mode=conventional or mode=scoped (got '${MODE}')."
    exit 1
    ;;
esac

if [[ ! -f "${CONFIG}" ]]; then
  echo "::error::git-cliff config not found: ${CONFIG}"
  exit 1
fi

CLIFF=""
if command -v git-cliff >/dev/null 2>&1 && git-cliff --version 2>/dev/null | grep -q "${GIT_CLIFF_VERSION}"; then
  CLIFF="$(command -v git-cliff)"
  echo "Using local git-cliff ${GIT_CLIFF_VERSION} at ${CLIFF}"
else
  os="$(uname -s)"
  arch="$(uname -m)"
  case "${os}-${arch}" in
    Linux-x86_64) target="x86_64-unknown-linux-gnu" ;;
    Linux-aarch64) target="aarch64-unknown-linux-gnu" ;;
    Darwin-x86_64) target="x86_64-apple-darwin" ;;
    Darwin-arm64) target="aarch64-apple-darwin" ;;
    *)
      echo "::error::Unsupported platform ${os}-${arch} for git-cliff."
      exit 1
      ;;
  esac
  asset="git-cliff-${GIT_CLIFF_VERSION}-${target}.tar.gz"
  echo "Downloading git-cliff ${GIT_CLIFF_VERSION} (${target})"
  gh release download "v${GIT_CLIFF_VERSION}" \
    --repo orhun/git-cliff \
    --pattern "${asset}" \
    --dir "${TMP_DIR}" \
    --clobber
  tar -xzf "${TMP_DIR}/${asset}" -C "${TMP_DIR}"
  CLIFF="$(find "${TMP_DIR}" -type f -name git-cliff -print -quit)"
  if [[ -z "${CLIFF}" ]]; then
    echo "::error::git-cliff binary not found in ${asset}"
    exit 1
  fi
  chmod +x "${CLIFF}"
fi

cd "${REPO}"

# The r<version> tag is created after this step. Use --unreleased for the first
# pass; on a re-run the tag already exists and --current covers that tag.
cliff_args=(
  --config "${CONFIG}"
  --repository "${REPO}"
  --output "${NOTES_FILE}"
  --strip header
  --tag-pattern "^r[0-9]"
)

if [[ -n "${TAG}" ]] && git show-ref --tags --verify --quiet "refs/tags/${TAG}"; then
  cliff_args+=(--current)
else
  cliff_args+=(--unreleased)
fi

"${CLIFF}" "${cliff_args[@]}"

if [[ ! -s "${NOTES_FILE}" ]]; then
  echo "- no changes" > "${NOTES_FILE}"
fi

echo "notes=${NOTES_FILE}" >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
echo "Generated ${MODE} changelog at ${NOTES_FILE}"
