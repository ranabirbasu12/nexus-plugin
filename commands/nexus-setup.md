---
name: nexus-setup
description: Initialize Nexus for the current project — creates .nexus/ directory with task board, knowledge base, and project context
user_invocable: true
---

Initialize Nexus for this project. Use the `setup` skill from the Nexus plugin to:

1. Create `.nexus/` directory with SQLite database
2. Detect the project's tech stack
3. Create starter `conventions.md` and `project-state.md`
4. Ensure `~/.nexus/` global directory exists
5. Add `.nexus/nexus.db` to `.gitignore`

If `.nexus/` already exists, offer to re-initialize or skip.
If `nexus/nexus.db` exists (v0.3 layout), offer migration.
