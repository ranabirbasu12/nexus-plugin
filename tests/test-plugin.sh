#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0
TMP_ROOT=""
ORIG_HOME="${HOME}"

cleanup() {
  export HOME="${ORIG_HOME}"
  if [[ -n "${TMP_ROOT}" && -d "${TMP_ROOT}" ]]; then
    rm -rf "${TMP_ROOT}"
  fi
}
trap cleanup EXIT

pass() {
  echo "PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "FAIL: $1 -- $2"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

assert_contains() {
  [[ "$1" == *"$2"* ]]
}

run_test() {
  local name="$1"
  shift
  if "$@"; then
    pass "${name}"
  else
    fail "${name}" "assertion failed"
  fi
}

setup_test_env() {
  TMP_ROOT="$(mktemp -d)"
  export HOME="${TMP_ROOT}/fakehome"
  mkdir -p "${HOME}"
}

# ── Test 1: DB init creates all 5 tables ─────────────────────
test_db_init() {
  local project_dir="${TMP_ROOT}/test-project-1"
  mkdir -p "${project_dir}"

  source "${PLUGIN_ROOT}/lib/helpers.sh"
  source "${PLUGIN_ROOT}/lib/nexus-db.sh"

  nexus_db_init "${project_dir}"

  local tables
  tables="$(sqlite3 "${project_dir}/.nexus/nexus.db" ".tables")"

  assert_contains "${tables}" "dispatches" || return 1
  assert_contains "${tables}" "events" || return 1
  assert_contains "${tables}" "knowledge" || return 1
  assert_contains "${tables}" "tasks" || return 1
  assert_contains "${tables}" "usage" || return 1
}

# ── Test 2: Global DB has project column ──────────────────────
test_global_db_init() {
  source "${PLUGIN_ROOT}/lib/helpers.sh"
  source "${PLUGIN_ROOT}/lib/nexus-db.sh"

  nexus_db_init_global

  [[ -f "${HOME}/.nexus/global.db" ]] || return 1
  [[ -f "${HOME}/.nexus/config.json" ]] || return 1

  # global.db should have the project column on knowledge
  local cols
  cols="$(sqlite3 "${HOME}/.nexus/global.db" "PRAGMA table_info(knowledge);")"
  assert_contains "${cols}" "project" || return 1
}

# ── Test 3: Knowledge resolution (local + global merge) ──────
test_knowledge_resolution() {
  local project_dir="${TMP_ROOT}/test-project-3"
  mkdir -p "${project_dir}"

  source "${PLUGIN_ROOT}/lib/helpers.sh"
  source "${PLUGIN_ROOT}/lib/nexus-db.sh"

  nexus_db_init "${project_dir}"
  # Re-init global in case test 2 didn't run
  nexus_db_init_global

  local local_db="${project_dir}/.nexus/nexus.db"
  local global_db="${HOME}/.nexus/global.db"

  # Insert local knowledge
  sqlite3 "${local_db}" "INSERT INTO knowledge (id, type, fact, recommendation, confidence, source, tags, files, created_at) VALUES ('k_local', 'pattern', 'Local fact', 'Local rec', 'high', 'claude', '[]', '[]', datetime('now'));"

  # Insert global knowledge
  sqlite3 "${global_db}" "INSERT INTO knowledge (id, type, fact, recommendation, confidence, source, tags, files, created_at, project) VALUES ('k_global', 'gotcha', 'Global fact', 'Global rec', 'medium', 'claude', '[]', '[]', datetime('now'), 'other-project');"

  # Query merged knowledge
  local result
  result="$(nexus_knowledge_query "${local_db}" "${global_db}")"

  assert_contains "${result}" "Local fact" || return 1
  assert_contains "${result}" "Global fact" || return 1
}

# ── Test 4: Knowledge promotion ───────────────────────────────
test_knowledge_promote() {
  local project_dir="${TMP_ROOT}/test-project-4"
  mkdir -p "${project_dir}"

  source "${PLUGIN_ROOT}/lib/helpers.sh"
  source "${PLUGIN_ROOT}/lib/nexus-db.sh"

  nexus_db_init "${project_dir}"
  nexus_db_init_global

  local local_db="${project_dir}/.nexus/nexus.db"
  local global_db="${HOME}/.nexus/global.db"

  # Insert local knowledge to promote
  sqlite3 "${local_db}" "INSERT INTO knowledge (id, type, fact, recommendation, confidence, source, tags, files, created_at) VALUES ('k_promote', 'pattern', 'Promotable fact', 'Do this always', 'high', 'claude', '[\"test\"]', '[]', datetime('now'));"

  # Promote it
  nexus_knowledge_promote "${local_db}" "${global_db}" "k_promote" "test-project"

  # Verify it's in global DB with project tag
  local promoted
  promoted="$(sqlite3 "${global_db}" "SELECT fact, project FROM knowledge WHERE id = 'k_promote';")"
  assert_contains "${promoted}" "Promotable fact" || return 1
  assert_contains "${promoted}" "test-project" || return 1
}

# ── Test 5: Dispatch dry-run ──────────────────────────────────
test_dispatch_dry_run() {
  local project_dir="${TMP_ROOT}/test-project-5"
  mkdir -p "${project_dir}"

  source "${PLUGIN_ROOT}/lib/helpers.sh"
  source "${PLUGIN_ROOT}/lib/nexus-db.sh"

  nexus_db_init "${project_dir}"
  nexus_db_init_global

  # Add context files
  echo "# Test Project State" > "${project_dir}/.nexus/project-state.md"
  echo "# Test Conventions" > "${project_dir}/.nexus/conventions.md"

  # Add a knowledge entry
  sqlite3 "${project_dir}/.nexus/nexus.db" "INSERT INTO knowledge (id, type, fact, recommendation, confidence, source, tags, files, created_at) VALUES ('k_disp', 'pattern', 'Dispatch test fact', 'Use this', 'high', 'claude', '[]', '[]', datetime('now'));"

  local out
  out="$("${PLUGIN_ROOT}/lib/nexus-dispatch.sh" --mode reviewer --task-id T999 --prompt "Test dispatch" --project-root "${project_dir}" --dry-run 2>&1)"

  assert_contains "${out}" "NEXUS DISPATCH" || return 1
  assert_contains "${out}" "[PROJECT CONTEXT]" || return 1
  assert_contains "${out}" "Test Project State" || return 1
  assert_contains "${out}" "[CONVENTIONS]" || return 1
  assert_contains "${out}" "[RELEVANT KNOWLEDGE" || return 1
  assert_contains "${out}" "Dispatch test fact" || return 1
  assert_contains "${out}" "[TASK]" || return 1
  assert_contains "${out}" "Test dispatch" || return 1
  assert_contains "${out}" "Dry run complete" || return 1
}

# ── Test 6: Helpers find_project_root ─────────────────────────
test_find_project_root() {
  local project_dir="${TMP_ROOT}/test-project-6"
  mkdir -p "${project_dir}/.nexus"
  mkdir -p "${project_dir}/src/deep/nested"

  source "${PLUGIN_ROOT}/lib/helpers.sh"

  # From nested dir, should find project root
  local found
  found="$(nexus_find_project_root "${project_dir}/src/deep/nested")"
  [[ "${found}" == "${project_dir}" ]] || return 1
}

# ── Test 7: Session-start hook with tasks ─────────────────────
test_session_start_hook() {
  local project_dir="${TMP_ROOT}/test-project-7"
  mkdir -p "${project_dir}"

  source "${PLUGIN_ROOT}/lib/helpers.sh"
  source "${PLUGIN_ROOT}/lib/nexus-db.sh"
  nexus_db_init "${project_dir}"

  # Add a pending task
  sqlite3 "${project_dir}/.nexus/nexus.db" "INSERT INTO tasks (id, title, description, assignee, priority, status, mode, created_at) VALUES ('T001', 'Hook test task', 'A test', 'claude', 1, 'pending', 'worker', datetime('now'));"

  local out
  out="$(NEXUS_PROJECT_ROOT="${project_dir}" bash "${PLUGIN_ROOT}/hooks/session-start" 2>&1)"

  assert_contains "${out}" "T001" || return 1
  assert_contains "${out}" "Hook test task" || return 1
}

# ── Test 8: Session-start hook without .nexus/ ────────────────
test_session_start_no_nexus() {
  local out
  out="$(NEXUS_PROJECT_ROOT="" bash "${PLUGIN_ROOT}/hooks/session-start" 2>&1)"

  assert_contains "${out}" "Run /nexus-setup" || return 1
}

# ── Test 9: Post-commit hook outputs marker ───────────────────
test_post_commit_hook() {
  local project_dir="${TMP_ROOT}/test-project-9"
  mkdir -p "${project_dir}"

  source "${PLUGIN_ROOT}/lib/helpers.sh"
  source "${PLUGIN_ROOT}/lib/nexus-db.sh"
  nexus_db_init "${project_dir}"

  # Initialize git repo
  cd "${project_dir}"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "test commit"

  local out
  out="$(cd "${project_dir}" && NEXUS_PROJECT_ROOT="${project_dir}" TOOL_INPUT="git commit -m 'test'" bash "${PLUGIN_ROOT}/hooks/post-commit" 2>&1)"

  assert_contains "${out}" "NEXUS KNOWLEDGE CAPTURE" || return 1
  assert_contains "${out}" "test commit" || return 1

  cd "${PLUGIN_ROOT}"
}

# ── Main ──────────────────────────────────────────────────────
main() {
  setup_test_env

  run_test "test_db_init: schema creates all 5 tables" test_db_init
  run_test "test_global_db_init: global DB has project column" test_global_db_init
  run_test "test_knowledge_resolution: local + global merge" test_knowledge_resolution
  run_test "test_knowledge_promote: entry promoted with project tag" test_knowledge_promote
  run_test "test_dispatch_dry_run: enriched prompt with all sections" test_dispatch_dry_run
  run_test "test_find_project_root: walks up to find .nexus/" test_find_project_root
  run_test "test_session_start_hook: shows pending tasks" test_session_start_hook
  run_test "test_session_start_no_nexus: suggests /nexus-setup" test_session_start_no_nexus
  run_test "test_post_commit_hook: outputs NEXUS KNOWLEDGE CAPTURE" test_post_commit_hook

  echo ""
  echo "Tests complete: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"

  if [[ ${FAIL_COUNT} -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
