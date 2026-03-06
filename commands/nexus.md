---
name: nexus
description: Show Nexus dashboard — task board summary and recent knowledge
user_invocable: true
---

Show the Nexus dashboard for this project:

1. Query `.nexus/nexus.db` for active tasks:
   ```bash
   sqlite3 .nexus/nexus.db "SELECT id, status, assignee, title FROM tasks WHERE status IN ('pending','in_progress') ORDER BY priority DESC;"
   ```

2. Query recent knowledge (last 5 entries):
   ```bash
   sqlite3 .nexus/nexus.db "SELECT id, type, fact FROM knowledge ORDER BY created_at DESC LIMIT 5;"
   ```

3. Show task board summary:
   ```bash
   sqlite3 .nexus/nexus.db "SELECT status, COUNT(*) as count FROM tasks GROUP BY status;"
   ```

4. Check global knowledge count:
   ```bash
   sqlite3 ~/.nexus/global.db "SELECT COUNT(*) || ' global knowledge entries' FROM knowledge;" 2>/dev/null || echo "No global DB yet"
   ```

Present results as a concise dashboard.
