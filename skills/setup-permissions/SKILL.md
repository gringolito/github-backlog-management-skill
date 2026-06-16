---
name: setup-permissions
description: Write the Claude Code permissions allowlist for this skill into the target settings file.
---

# setup-permissions

You are an AI agent acting as an installation assistant responsible for configuring Claude Code permission settings for the GitHub Backlog Management skill.

---

## Objective

Write the correct `permissions.allow` block into the user's chosen Claude Code settings file, based on their configured or requested permission mode. This skill is idempotent — re-running with the same mode and target is a safe no-op.

---

## Allowlist reference

These are the canonical allowlist blocks for each mode:

**yolo** — no prompts during any multi-step skill:
```json
["Bash(gh *)", "Bash(git *)", "Bash(backlog-preflight)", "Bash(resolve-milestone*)"]
```

**safe** — read-only `gh` calls run silently; write commands still prompt:
```json
[
  "Bash(gh auth status *)",
  "Bash(gh repo view *)",
  "Bash(gh issue list *)",
  "Bash(gh issue view *)",
  "Bash(gh label list *)",
  "Bash(gh project list *)",
  "Bash(gh project view *)",
  "Bash(gh project item-list *)",
  "Bash(gh project field-list *)",
  "Bash(gh release list *)",
  "Bash(backlog-preflight)",
  "Bash(resolve-milestone*)"
]
```

---

## Workflow

### 0. Preflight (MANDATORY)

- `gh auth status` — if unauthenticated, STOP and output: `gh auth status failed. Run gh auth login and retry.`
- Parse `<owner>/<repo>` from `gh repo view --json owner,name`

---

### 1. Mode Resolution (MANDATORY)

Determine the effective permission mode using this precedence:

1. **Explicit argument** — if the user passed a mode as an argument to this skill (e.g. `/setup-permissions safe`), use it. This overrides the configured value for this invocation only; it does not change the stored `userConfig`.
2. **`${CLAUDE_PLUGIN_OPTION_PERMISSION_MODE}`** — the value set at plugin enable time via `userConfig`.
3. **Fallback** — treat as `off` if neither is set.

Valid values: `yolo`, `safe`, `off`. If the resolved value is anything else, STOP and output: `Unknown permission mode "<value>". Valid values: yolo, safe, off.`

---

### 2. Off / Unset path (STRICT)

If the resolved mode is `off`:

- Print exactly: `Permission mode is "off" — no settings written. See README "Authentication & Permissions" for manual configuration.`
- STOP. Do not read, write, or touch any settings file.

---

### 3. Target file selection (MANDATORY)

Ask the user which file to write. Present exactly three options:

1. `.claude/settings.local.json` — per-project, gitignored (recommended for personal setups)
2. `.claude/settings.json` — per-project, version-controlled (for shared team config)
3. `~/.claude/settings.json` — user-global (applies to every Claude Code session)

Wait for the user to select one before proceeding.

---

### 4. Idempotent merge and write (STRICT)

1. **Read** the chosen target file. If it does not exist, treat its content as `{}`.
2. Parse the JSON. If parsing fails, STOP and output: `Could not parse <target>: <parse error>. Fix the file manually before retrying.`
3. Resolve `permissions.allow` as a list (default `[]` if absent).
4. Determine the rules to add from the **Allowlist reference** section for the resolved mode.
5. **Merge idempotently**: for each rule in the mode's list, append it only if it is not already present. Never remove or reorder existing entries.
6. If no new rules were added (all already present): print `No changes — all rules already present in <target>.` and STOP.
7. Write the updated JSON back to the target file with 2-space indentation.

---

### 5. Verification (MANDATORY)

Re-read the target file and confirm all expected rules are present. Output the result summary (see Output Expectations).

---

## Rules & Constraints

- NEVER write to a settings file without explicit user confirmation of the target (step 3)
- NEVER remove or reorder existing entries in `permissions.allow`
- NEVER write settings when mode is `off` — that path is strictly read-only and exit-only
- An explicit argument overrides `userConfig` for this invocation ONLY — do NOT persist or modify the stored `userConfig` value
- Surface all `gh` errors and file I/O errors verbatim — never swallow
- If the target file path contains `~`, expand it to the user's home directory using `$HOME`

---

## Output Expectations

**Off mode:**
```
Permission mode is "off" — no settings written. See README "Authentication & Permissions" for manual configuration.
```

**Successful write:**
```
✓ Wrote <N> rules to <target> (mode: <mode>)
Rules added:
  - Bash(gh *)
  - Bash(git *)
Rules already present: (none | <list>)
```

**No-op (all rules already present):**
```
No changes — all rules already present in <target>.
```

**Error cases:**
- Auth failure: `gh auth status failed. Run gh auth login and retry.`
- Unknown mode: `Unknown permission mode "<value>". Valid values: yolo, safe, off.`
- JSON parse error: `Could not parse <target>: <parse error>. Fix the file manually before retrying.`
- All `gh` errors surfaced verbatim
