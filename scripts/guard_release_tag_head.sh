#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"

HEAD_SHA="$(git rev-parse HEAD)"

while read -r LOCAL_REF LOCAL_SHA REMOTE_REF REMOTE_SHA; do
  if [[ "${REMOTE_REF}" != refs/tags/v* ]]; then
    continue
  fi

  if [[ "${LOCAL_SHA}" == "0000000000000000000000000000000000000000" ]]; then
    continue
  fi

  TAG_COMMIT_SHA="$(git rev-parse "${LOCAL_REF}^{commit}")"
  if [[ "${TAG_COMMIT_SHA}" == "${HEAD_SHA}" ]]; then
    continue
  fi

  cat >&2 <<EOF
Release tag push blocked: ${REMOTE_REF} resolves to ${TAG_COMMIT_SHA:0:7}, but current HEAD is ${HEAD_SHA:0:7}.
Checkout the intended release commit before tagging, or retag the current HEAD.
EOF
  exit 1
done
