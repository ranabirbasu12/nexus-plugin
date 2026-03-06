#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# nexus-dispatch.sh — Portable Codex Dispatch Script
# Works with any project that has .nexus/ initialized.
# ─────────────────────────────────────────────────────────────

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helpers
source "${LIB_DIR}/helpers.sh"

# ── Defaults ────────────────────────────────────────────────
MODE=""
TASK_ID=""
PROMPT=""
DIR="$(pwd)"
DRY_RUN=false
OUTPUT_FILE=""
PROJECT_ROOT=""

# ── Parse arguments ─────────────────────────────────────────
usage() {
  cat <<EOF
Usage: nexus-dispatch.sh [OPTIONS]

Options:
  --mode          worker|reviewer|sub-conductor  (required)
  --task-id       Task identifier, e.g. T001      (required)
  --prompt        The task prompt                  (required)
  --dir           Working directory (default: pwd)
  --project-root  Project root with .nexus/ (auto-detected if omitted)
  --output        Output file path
  --dry-run       Print enriched prompt without executing
  -h, --help      Show this help message
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)         MODE="$2"; shift 2 ;;
    --task-id)      TASK_ID="$2"; shift 2 ;;
    --prompt)       PROMPT="$2"; shift 2 ;;
    --dir)          DIR="$2"; shift 2 ;;
    --project-root) PROJECT_ROOT="$2"; shift 2 ;;
    --output)       OUTPUT_FILE="$2"; shift 2 ;;
    --dry-run)      DRY_RUN=true; shift ;;
    -h|--help)      usage ;;
    *)              echo "Error: unknown option '$1'" >&2; usage ;;
  esac
done

# ── Validate required args ──────────────────────────────────
if [[ -z "${MODE}" ]]; then
  echo "Error: --mode is required" >&2; usage
fi
if [[ "${MODE}" != "worker" && "${MODE}" != "reviewer" && "${MODE}" != "sub-conductor" ]]; then
  echo "Error: --mode must be worker, reviewer, or sub-conductor" >&2; usage
fi
if [[ -z "${TASK_ID}" ]]; then
  echo "Error: --task-id is required" >&2; usage
fi
if [[ -z "${PROMPT}" ]]; then
  echo "Error: --prompt is required" >&2; usage
fi

# ── Find project root ──────────────────────────────────────
if [[ -z "${PROJECT_ROOT}" ]]; then
  PROJECT_ROOT="$(nexus_find_project_root "${DIR}")" || {
    echo "Error: No .nexus/ found. Run /nexus-setup first." >&2
    exit 1
  }
fi

DB_FILE="${PROJECT_ROOT}/.nexus/nexus.db"
GLOBAL_DB="${HOME}/.nexus/global.db"
CONFIG_FILE="${HOME}/.nexus/config.json"

# ── Check required tools ───────────────────────────────────
if ! command -v codex &>/dev/null; then
  echo "Error: codex CLI is required but not installed." >&2; exit 1
fi

# ── Read config ─────────────────────────────────────────────
MODEL="gpt-5.3-codex"
TIMEOUT="300"

if [[ -f "${CONFIG_FILE}" ]] && command -v jq &>/dev/null; then
  MODEL="$(jq -r '.codex.model // "gpt-5.3-codex"' "${CONFIG_FILE}")"
  TIMEOUT="$(jq -r '.codex.timeoutSeconds // 300' "${CONFIG_FILE}")"
fi

# ── Build context-enriched prompt ───────────────────────────
ENRICHED_PROMPT=""

# [PROJECT CONTEXT]
PROJECT_STATE_FILE="${PROJECT_ROOT}/.nexus/project-state.md"
if [[ -f "${PROJECT_STATE_FILE}" ]]; then
  ENRICHED_PROMPT+="[PROJECT CONTEXT]
$(cat "${PROJECT_STATE_FILE}")

"
fi

# [CONVENTIONS]
CONVENTIONS_FILE="${PROJECT_ROOT}/.nexus/conventions.md"
if [[ -f "${CONVENTIONS_FILE}" ]]; then
  ENRICHED_PROMPT+="[CONVENTIONS]
$(cat "${CONVENTIONS_FILE}")

"
fi

# [RELEVANT KNOWLEDGE] — local + global
if [[ -f "${DB_FILE}" ]] && command -v sqlite3 &>/dev/null; then
  KNOWLEDGE="$(sqlite3 "${DB_FILE}" "SELECT json_object('id',id,'type',type,'fact',fact,'recommendation',recommendation,'confidence',confidence) FROM knowledge WHERE expires_at IS NULL OR expires_at > datetime('now') LIMIT 10;" 2>/dev/null || true)"
  if [[ -n "${KNOWLEDGE}" ]]; then
    ENRICHED_PROMPT+="[RELEVANT KNOWLEDGE (local)]
${KNOWLEDGE}

"
  fi
fi

if [[ -f "${GLOBAL_DB}" ]] && command -v sqlite3 &>/dev/null; then
  GLOBAL_KNOWLEDGE="$(sqlite3 "${GLOBAL_DB}" "SELECT json_object('id',id,'type',type,'fact',fact,'recommendation',recommendation,'confidence',confidence) FROM knowledge WHERE expires_at IS NULL OR expires_at > datetime('now') LIMIT 5;" 2>/dev/null || true)"
  if [[ -n "${GLOBAL_KNOWLEDGE}" ]]; then
    ENRICHED_PROMPT+="[RELEVANT KNOWLEDGE (global)]
${GLOBAL_KNOWLEDGE}

"
  fi
fi

# [TASK]
ENRICHED_PROMPT+="[TASK]
${PROMPT}

"

# [DELIVERABLES]
ENRICHED_PROMPT+="[DELIVERABLES]
Report the following when done:
1. List all files changed (created, modified, deleted)
2. List any issues encountered or decisions made
3. Confirm task completion status
"

# ── Ensure log directories exist ───────────────────────────
mkdir -p "${PROJECT_ROOT}/.nexus/logs"

# ── Determine output file ──────────────────────────────────
if [[ -z "${OUTPUT_FILE}" ]]; then
  OUTPUT_FILE="${PROJECT_ROOT}/.nexus/logs/output-${TASK_ID}-$(date +%s).md"
fi

# ── Build command ───────────────────────────────────────────
CODEX_CMD=(
  codex exec
  --full-auto
  -C "${DIR}"
  -m "${MODEL}"
  --ephemeral
  -o "${OUTPUT_FILE}"
)

# ── Dry-run mode ────────────────────────────────────────────
if [[ "${DRY_RUN}" == true ]]; then
  echo "============================================"
  echo "  NEXUS DISPATCH — DRY RUN"
  echo "============================================"
  echo ""
  echo "── Configuration ──"
  echo "  Model:        ${MODEL}"
  echo "  Timeout:      ${TIMEOUT}s"
  echo "  Mode:         ${MODE}"
  echo "  Task ID:      ${TASK_ID}"
  echo "  Project Root: ${PROJECT_ROOT}"
  echo "  Directory:    ${DIR}"
  echo "  Output:       ${OUTPUT_FILE}"
  echo ""
  echo "── Command ──"
  echo "  ${CODEX_CMD[*]}"
  echo ""
  echo "── Enriched Prompt ──"
  echo "${ENRICHED_PROMPT}"
  echo "============================================"
  echo "Dry run complete. No execution performed."
  exit 0
fi

# ── Execute ─────────────────────────────────────────────────
START_TS="$(date +%s)"
START_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

EXIT_CODE=0
if command -v gtimeout &>/dev/null; then
  echo "${ENRICHED_PROMPT}" | gtimeout "${TIMEOUT}" "${CODEX_CMD[@]}" || EXIT_CODE=$?
elif command -v timeout &>/dev/null; then
  echo "${ENRICHED_PROMPT}" | timeout "${TIMEOUT}" "${CODEX_CMD[@]}" || EXIT_CODE=$?
else
  echo "${ENRICHED_PROMPT}" | "${CODEX_CMD[@]}" || EXIT_CODE=$?
fi

END_TS="$(date +%s)"
DURATION=$(( END_TS - START_TS ))

# ── Detect changed files
FILES_CHANGED="[]"
if command -v git &>/dev/null && command -v jq &>/dev/null && git -C "${DIR}" rev-parse --git-dir &>/dev/null 2>&1; then
  FILES_CHANGED="$(git -C "${DIR}" diff --name-only HEAD 2>/dev/null | jq -R -s 'split("\n") | map(select(length > 0))')" || FILES_CHANGED="[]"
fi

# ── Detect failure type
FAILURE_TYPE=""
if [[ "${EXIT_CODE}" -ne 0 ]]; then
  if [[ "${DURATION}" -ge "${TIMEOUT}" ]]; then
    FAILURE_TYPE="timeout"
  elif [[ ! -s "${OUTPUT_FILE}" ]]; then
    FAILURE_TYPE="crash"
  fi
fi

# ── Log to SQLite
PROMPT_SUMMARY="$(echo "${PROMPT}" | cut -c1-100 | sed "s/'/''/g")"
DISPATCH_ID="d-${TASK_ID}-$(date +%s)"
TODAY="$(date +%Y-%m-%d)"

if [[ -f "${DB_FILE}" ]] && command -v sqlite3 &>/dev/null; then
  sqlite3 "${DB_FILE}" "INSERT INTO dispatches (id, timestamp, task_id, mode, model, backend, prompt_summary, duration_seconds, exit_code, failure_type, files_changed, validated) VALUES ('${DISPATCH_ID}', '${START_ISO}', '${TASK_ID}', '${MODE}', '${MODEL}', 'shell', '${PROMPT_SUMMARY}', ${DURATION}, ${EXIT_CODE}, $(if [[ -n "${FAILURE_TYPE}" ]]; then echo "'${FAILURE_TYPE}'"; else echo "NULL"; fi), '${FILES_CHANGED}', 0);"

  sqlite3 "${DB_FILE}" "INSERT OR REPLACE INTO usage (date, dispatches, duration_seconds) VALUES ('${TODAY}', COALESCE((SELECT dispatches FROM usage WHERE date='${TODAY}'),0)+1, COALESCE((SELECT duration_seconds FROM usage WHERE date='${TODAY}'),0)+${DURATION});"

  sqlite3 "${DB_FILE}" "INSERT INTO events (timestamp, event_type, task_id, agent, payload) VALUES ('${START_ISO}', 'dispatched', '${TASK_ID}', 'codex', json_object('dispatch_id','${DISPATCH_ID}','mode','${MODE}','duration',${DURATION},'exit_code',${EXIT_CODE}));"
fi

# ── Summary ─────────────────────────────────────────────────
echo ""
echo "── Dispatch Complete ──"
echo "  ID:        ${DISPATCH_ID}"
echo "  Task:      ${TASK_ID}"
echo "  Mode:      ${MODE}"
echo "  Duration:  ${DURATION}s"
echo "  Exit Code: ${EXIT_CODE}"
echo "  Output:    ${OUTPUT_FILE}"
