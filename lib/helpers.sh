#!/usr/bin/env bash
# helpers.sh — Shared functions for Nexus plugin

# Find the plugin's own root directory (where .claude-plugin/ lives)
nexus_plugin_root() {
  local dir="${BASH_SOURCE[0]}"
  dir="$(cd "$(dirname "${dir}")/.." && pwd)"
  echo "${dir}"
}

# Find .nexus/ directory by walking up from given dir (or pwd)
nexus_find_project_root() {
  local dir="${1:-$(pwd)}"
  while [[ "${dir}" != "/" ]]; do
    if [[ -d "${dir}/.nexus" ]]; then
      echo "${dir}"
      return 0
    fi
    dir="$(dirname "${dir}")"
  done
  return 1
}

# Get local DB path for a project
nexus_local_db() {
  local project_root="${1:-}"
  if [[ -z "${project_root}" ]]; then
    project_root="$(nexus_find_project_root)" || return 1
  fi
  echo "${project_root}/.nexus/nexus.db"
}

# Get global DB path
nexus_global_db() {
  echo "${HOME}/.nexus/global.db"
}

# SQL-escape a string (single quotes)
sql_escape() {
  printf '%s' "$1" | sed "s/'/''/g"
}

# Check required tool exists
require_tool() {
  if ! command -v "$1" &>/dev/null; then
    echo "ERROR: Required tool '$1' not found." >&2
    return 1
  fi
}
