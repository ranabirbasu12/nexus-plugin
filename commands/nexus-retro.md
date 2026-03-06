---
name: nexus-retro
description: Run session retrospective — review work done, promote knowledge, update memory
user_invocable: true
---

Run a Nexus session retrospective. Use the `reflect` skill from the Nexus plugin.

1. Show tasks completed this session:
   ```bash
   sqlite3 .nexus/nexus.db "SELECT id, title, status FROM tasks WHERE completed_at >= datetime('now', '-8 hours') ORDER BY completed_at DESC;"
   ```

2. Show dispatches this session:
   ```bash
   sqlite3 .nexus/nexus.db "SELECT id, task_id, mode, duration_seconds, exit_code FROM dispatches WHERE timestamp >= datetime('now', '-8 hours');"
   ```

3. Show knowledge added this session:
   ```bash
   sqlite3 .nexus/nexus.db "SELECT id, type, fact FROM knowledge WHERE created_at >= datetime('now', '-8 hours');"
   ```

4. Suggest knowledge promotion candidates:
   - Entries with confidence='high' that apply beyond this project
   - Offer to promote to `~/.nexus/global.db` using:
     ```bash
     source "${CLAUDE_PLUGIN_ROOT}/lib/nexus-db.sh"
     nexus_knowledge_promote ".nexus/nexus.db" "${HOME}/.nexus/global.db" "k_XXX" "$(basename $(pwd))"
     ```

5. Prompt MEMORY.md update if significant learnings occurred.
