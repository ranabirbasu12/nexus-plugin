---
name: nexus-board
description: Show the full Nexus task board with all tasks and their status
user_invocable: true
---

Show the full task board from `.nexus/nexus.db`:

```bash
sqlite3 -header -column .nexus/nexus.db "SELECT id, status, assignee, priority, title, created_at FROM tasks ORDER BY CASE status WHEN 'in_progress' THEN 1 WHEN 'pending' THEN 2 WHEN 'review' THEN 3 WHEN 'done' THEN 4 WHEN 'failed' THEN 5 ELSE 6 END, priority DESC;"
```

Also show the summary:
```bash
sqlite3 .nexus/nexus.db "SELECT status, COUNT(*) as count FROM tasks GROUP BY status;"
```

If no `.nexus/` exists, tell the user to run `/nexus-setup`.
