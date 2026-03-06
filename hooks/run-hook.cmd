#!/usr/bin/env bash
set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_NAME="${1:?Usage: run-hook.cmd <hook-name>}"

# Find project root (walk up from pwd looking for .nexus/)
find_nexus_root() {
  local dir="$(pwd)"
  while [[ "${dir}" != "/" ]]; do
    if [[ -d "${dir}/.nexus" ]]; then
      echo "${dir}"
      return 0
    fi
    dir="$(dirname "${dir}")"
  done
  return 1
}

export NEXUS_PROJECT_ROOT="$(find_nexus_root 2>/dev/null || true)"
export NEXUS_PLUGIN_ROOT="$(cd "${HOOK_DIR}/.." && pwd)"

if [[ -f "${HOOK_DIR}/${HOOK_NAME}" ]]; then
  exec bash "${HOOK_DIR}/${HOOK_NAME}"
fi
