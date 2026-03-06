# Nexus — Multi-Agent Orchestration Plugin for Claude Code

Nexus orchestrates Claude Code and Codex CLI as a coordinated agent pair. Claude builds, Codex reviews. Per-project task board, knowledge base, and adversarial review dispatch.

## Install

Register the plugin in `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "nexus-marketplace": {
      "source": {
        "source": "github",
        "repo": "ranabirbasu12/nexus-plugin"
      }
    }
  },
  "enabledPlugins": {
    "nexus@nexus-marketplace": true
  }
}
```

Restart Claude Code after adding the config.

## Quick Start

```
cd ~/GitHub/your-project
/nexus-setup          # Initialize Nexus for this project
/nexus                # Show dashboard
```

## Commands

| Command | Description |
|---------|-------------|
| `/nexus-setup` | Initialize Nexus for the current project |
| `/nexus` | Show dashboard — active tasks + recent knowledge |
| `/nexus-board` | Full task board view |
| `/nexus-review` | Dispatch Codex adversarial review |
| `/nexus-retro` | Session retrospective + knowledge promotion |

## How It Works

**Per-project data** (`.nexus/` in your project root):
- `nexus.db` — SQLite database (tasks, knowledge, dispatches, events, usage)
- `conventions.md` — Project-specific code conventions (version-controlled)
- `project-state.md` — Living architecture doc (version-controlled)

**Global data** (`~/.nexus/`):
- `global.db` — Promoted knowledge from all projects
- `config.json` — Codex model, dispatch settings

**Hooks** (automatic):
- **Session start** — Shows pending tasks + expiring knowledge
- **Post-commit** — Prompts knowledge capture after git commits

**Knowledge flow:**
1. You code and commit normally
2. Post-commit hook prompts Claude to capture learnings
3. Knowledge lives in local `.nexus/nexus.db`
4. At session end (`/nexus-retro`), promote patterns to global DB
5. Next project session sees both local + global knowledge

## Design Principles

1. **Verify, never trust** — independently validate all agent work
2. **Knowledge compounds** — extract learnings after every task
3. **Escalate, don't loop** — 3 retries max, then ask the human
4. **Codex reviews, Claude builds** — different models = different perspectives
5. **Zero friction** — hooks and SQLite, no script ceremony
6. **Portable** — works in any project with `/nexus-setup`
7. **Cost-aware** — track every Codex dispatch
8. **Lightweight** — 2 agents, simple tools, no heavy framework

## Running Tests

```bash
bash tests/test-plugin.sh
```

## License

MIT
