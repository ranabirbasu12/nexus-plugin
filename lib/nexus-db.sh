#!/usr/bin/env bash
# nexus-db.sh — Database init, query helpers for Nexus plugin
# All functions take a project_root argument instead of hardcoding paths.

NEXUS_DB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helpers if not already loaded
if ! type nexus_plugin_root &>/dev/null 2>&1; then
  source "${NEXUS_DB_DIR}/helpers.sh"
fi

# Initialize .nexus/ directory and local DB for a project
nexus_db_init() {
  local project_root="${1:?Usage: nexus_db_init <project_root>}"
  local schema="${NEXUS_DB_DIR}/schema.sql"

  require_tool sqlite3

  mkdir -p "${project_root}/.nexus"
  sqlite3 "${project_root}/.nexus/nexus.db" < "${schema}"
}

# Initialize global ~/.nexus/ directory and DB
nexus_db_init_global() {
  local schema="${NEXUS_DB_DIR}/schema.sql"
  local global_dir="${HOME}/.nexus"

  require_tool sqlite3

  mkdir -p "${global_dir}"

  if [[ ! -f "${global_dir}/global.db" ]]; then
    sqlite3 "${global_dir}/global.db" < "${schema}"
    # Add project column to global knowledge table
    sqlite3 "${global_dir}/global.db" "ALTER TABLE knowledge ADD COLUMN project TEXT;" 2>/dev/null || true
  fi

  if [[ ! -f "${global_dir}/config.json" ]]; then
    cat > "${global_dir}/config.json" <<'JSON'
{
  "codex": {
    "model": "gpt-5.3-codex",
    "defaultMode": "reviewer",
    "timeoutSeconds": 300,
    "dispatchBackend": "shell"
  }
}
JSON
  fi
}

# Run a query against a DB (with headers)
nexus_db_query() {
  local db_path="${1:?Usage: nexus_db_query <db_path> <sql>}"
  local sql="${2:?}"
  sqlite3 -header -column "${db_path}" "${sql}"
}

# Run a query against a DB (raw output, no headers)
nexus_db_query_raw() {
  local db_path="${1:?}"
  local sql="${2:?}"
  sqlite3 "${db_path}" "${sql}"
}

# Query knowledge from local DB first, then global, merged
nexus_knowledge_query() {
  local local_db="${1:?Usage: nexus_knowledge_query <local_db> <global_db> [max]}"
  local global_db="${2:?}"
  local max="${3:-20}"

  local query="SELECT id, type, fact, recommendation, confidence, source FROM knowledge WHERE (expires_at IS NULL OR expires_at > datetime('now')) ORDER BY CASE confidence WHEN 'high' THEN 1 WHEN 'medium' THEN 2 WHEN 'low' THEN 3 END, created_at DESC LIMIT ${max};"

  local result=""

  if [[ -f "${local_db}" ]]; then
    result+="$(sqlite3 "${local_db}" "${query}" 2>/dev/null || true)"
  fi

  if [[ -f "${global_db}" ]]; then
    if [[ -n "${result}" ]]; then
      result+=$'\n'
    fi
    result+="$(sqlite3 "${global_db}" "${query}" 2>/dev/null || true)"
  fi

  echo "${result}"
}

# Promote a knowledge entry from local to global
nexus_knowledge_promote() {
  local local_db="${1:?Usage: nexus_knowledge_promote <local_db> <global_db> <knowledge_id> <project_name>}"
  local global_db="${2:?}"
  local kid="${3:?}"
  local project="${4:?}"

  require_tool sqlite3

  sqlite3 "${local_db}" "SELECT id, type, fact, recommendation, confidence, source, tags, files, created_at FROM knowledge WHERE id = '${kid}';" | while IFS='|' read -r id type fact rec conf src tags files created; do
    sqlite3 "${global_db}" "INSERT OR IGNORE INTO knowledge (id, type, fact, recommendation, confidence, source, tags, files, created_at, project) VALUES ('$(sql_escape "${id}")', '$(sql_escape "${type}")', '$(sql_escape "${fact}")', '$(sql_escape "${rec}")', '$(sql_escape "${conf}")', '$(sql_escape "${src}")', '$(sql_escape "${tags}")', '$(sql_escape "${files}")', '$(sql_escape "${created}")', '$(sql_escape "${project}")');"
  done
}
