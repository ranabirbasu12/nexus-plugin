# Nexus Reflect — Passive Self-Improvement

## Overview

Nexus learns from every session. Knowledge capture is passive — triggered by hooks and natural workflow, not manual script calls.

## How Knowledge Flows

```
Commit -> Post-commit hook -> Claude sees prompt -> Writes knowledge entry (or skips)
                                                          |
Session end -> /nexus-retro -> Review knowledge -> Promote patterns
                                                          |
Next session -> Session-start hook -> Shows pending tasks + expiring knowledge
```

## The Post-Commit Prompt

After every `git commit`, you'll see a `[NEXUS KNOWLEDGE CAPTURE]` prompt. When you see it:

**Write an entry if:**
- You discovered a reusable pattern
- You fixed a gotcha others would hit
- You made a design decision worth recording
- You found an anti-pattern to avoid

**Skip if:**
- The commit is a trivial fix (typo, formatting, version bump)
- The knowledge is already in the database or .nexus/conventions.md
- The learning is too specific to this exact situation

## Writing Good Knowledge Entries

Good (specific, actionable):
```sql
INSERT INTO knowledge (id, type, fact, recommendation, confidence, source, tags, files, expires_at, created_at)
VALUES ((SELECT printf('k_%03d', COALESCE(MAX(CAST(SUBSTR(id,3) AS INTEGER)),0)+1) FROM knowledge),
  'pattern',
  'Python __getattr__ in __init__.py enables lazy loading without breaking existing imports',
  'Use module-path mapping dict + importlib.import_module() for heavy sub-packages',
  'high', 'claude', '["python","imports","performance"]', '[]',
  datetime('now', '+90 days'), datetime('now'));
```

Bad (vague, not actionable):
```sql
-- DON'T DO THIS
INSERT INTO knowledge (...) VALUES (..., 'pattern', 'Lazy loading is good', '', 'low', ...);
```

## Knowledge Promotion

At session end (`/nexus-retro`), promote valuable patterns to global DB:
```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/helpers.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/nexus-db.sh"
nexus_knowledge_promote ".nexus/nexus.db" "${HOME}/.nexus/global.db" "k_XXX" "$(basename $(pwd))"
```

Promotion candidates:
- High-confidence entries that apply beyond this project
- Patterns that appeared 3+ times across sessions
- Gotchas that affect common tools/frameworks

## Knowledge Lifecycle

1. **Created** — via post-commit prompt or manual entry (90-day expiry)
2. **Active** — returned in queries, shown in session-start dashboard
3. **Expiring** — flagged at session start within 7 days of expiry
4. **Promoted** — copied to `~/.nexus/global.db` (cross-project, no expiry)
5. **Expired** — old entries that weren't promoted

## Failure Taxonomy

| Type | When to Use |
|---|---|
| timeout | Dispatch exceeded time limit |
| bad_spec | Task failed due to unclear requirements |
| env_missing | Missing tool/dependency in sandbox |
| test_flake | Tests pass sometimes, fail sometimes |
| review_reject | Reviewer found significant issues |
| crash | Non-zero exit with no useful output |
