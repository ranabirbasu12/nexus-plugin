# Nexus Setup — Project Initialization

## Overview

This skill initializes Nexus for a new project. It creates the `.nexus/` directory, SQLite database, and starter context files. Also ensures `~/.nexus/` global directory exists.

## When to Use

- When entering a project that doesn't have `.nexus/` yet
- When the user runs `/nexus-setup`
- When session-start detects no `.nexus/`

## The Flow

1. Check if `.nexus/` already exists in project root
   - If yes: offer re-init or skip
   - If no: proceed with init

2. Create `.nexus/` directory and initialize DB:
   ```bash
   source "${CLAUDE_PLUGIN_ROOT}/lib/helpers.sh"
   source "${CLAUDE_PLUGIN_ROOT}/lib/nexus-db.sh"
   nexus_db_init "$(pwd)"
   nexus_db_init_global
   ```

3. Detect project stack:
   - Check for `package.json` -> Node.js
   - Check for `pyproject.toml` / `requirements.txt` -> Python
   - Check for `Cargo.toml` -> Rust
   - Check for `go.mod` -> Go
   - Check for `Gemfile` -> Ruby
   - Fallback: "unknown"

4. Create starter `.nexus/conventions.md`:
   ```markdown
   # Project Conventions

   ## Stack
   - Language: [detected]
   - Framework: [detected from package.json/pyproject.toml]

   ## Code Style
   - [to be filled as patterns emerge]

   ## Testing
   - [to be filled]
   ```

5. Create starter `.nexus/project-state.md`:
   ```markdown
   # Project State

   ## Architecture
   [To be documented as work progresses]

   ## Key Files
   [To be documented]

   ## Key Decisions
   - [date]: Initialized Nexus for this project
   ```

6. Add `.nexus/nexus.db` to `.gitignore` (DB is local state, not version-controlled)

7. Suggest committing `.nexus/conventions.md` and `.nexus/project-state.md`

## Migration from v0.3

If `nexus/nexus.db` exists in the project (old WhatToBuildNext? layout):
1. Ask user if they want to import
2. Copy knowledge entries to `.nexus/nexus.db`
3. Promote cross-project patterns to `~/.nexus/global.db`
4. Copy pending tasks to new local DB

## Anti-Patterns

- Don't run setup in a directory without a `.git` — it's probably not a project root
- Don't overwrite existing `.nexus/nexus.db` without asking
- Don't commit `nexus.db` to git (it's local state)
