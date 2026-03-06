# Nexus Review — Codex as Adversarial Reviewer

## Overview

Codex's sole role is adversarial review. Claude builds, Codex finds what Claude missed. This is Codex's highest-value contribution.

## When to Request Codex Review

**Always request review after:**
- Completing a feature or significant refactor (5+ files changed)
- Fixing a security-related bug
- Changing database schema or API contracts
- Any work touching authentication, authorization, or data handling

**Skip review for:**
- Formatting/style-only changes
- Adding comments or documentation
- Single-file, low-risk changes
- Changes already covered by passing tests

## How to Dispatch a Review

```bash
"${CLAUDE_PLUGIN_ROOT}/lib/nexus-dispatch.sh" \
  --mode reviewer \
  --task-id TXXX-review \
  --prompt "Review the recent changes (git diff HEAD~N). Check for:
1. Bugs and logic errors
2. Security vulnerabilities (OWASP top 10)
3. Edge cases and error handling gaps
4. Convention violations
5. What would you do differently?
Be adversarial — your job is to find what I missed." \
  --dir "$(pwd)"
```

## Interpreting Review Results

After Codex returns:

1. **Read the output file** from `.nexus/logs/output-TXXX-review-*.md`
2. **Triage each finding:**
   - Real issue -> fix it, log knowledge entry
   - False positive -> note why in the task
   - Style disagreement -> follow .nexus/conventions.md, ignore if not covered
3. **Log the review result:**
```bash
sqlite3 .nexus/nexus.db "UPDATE dispatches SET reviewed_by = 'codex', review_result = 'approved' WHERE task_id = 'TXXX-review';"
```

## Three Review Templates

### 1. Post-Feature Review
```
Review git diff HEAD~N. I just implemented [feature]. Find bugs, edge cases, and security issues I missed. Be critical.
```

### 2. Security Audit
```
Security audit of [files/area]. Check for: injection (SQL, command, XSS), authentication bypass, authorization gaps, sensitive data exposure, insecure defaults. Reference OWASP top 10.
```

### 3. Architecture Review
```
I designed [system] using [approach]. Here's the architecture: [summary]. What would you do differently? What assumptions am I making that could bite us later?
```

## Anti-Patterns

- **Don't use Codex as a worker** — Claude's Explore subagents are faster with better context
- **Don't skip review for significant changes** — Codex finds real issues
- **Don't blindly accept all findings** — triage each one, Codex has false positives
- **Don't retry reviews** — if Codex's review is unhelpful, just move on (it's advisory)
