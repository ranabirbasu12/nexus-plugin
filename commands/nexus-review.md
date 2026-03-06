---
name: nexus-review
description: Dispatch Codex adversarial review of recent changes
user_invocable: true
---

Dispatch a Codex adversarial review. Use the `review` skill from the Nexus plugin.

1. Determine scope — the user may specify files or a commit range. Default: `git diff HEAD~1`
2. Create a review task in `.nexus/nexus.db`
3. Dispatch via the plugin's dispatch library:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/lib/nexus-dispatch.sh" \
     --mode reviewer \
     --task-id TXXX-review \
     --prompt "Review the recent changes. Find: bugs, security issues, missed edge cases, convention violations. Be adversarial." \
     --dir "$(pwd)"
   ```
4. Read the output and triage findings
5. Log results to `.nexus/nexus.db`

If Codex is not available, fall back to using Claude's own review capabilities and note the limitation.
