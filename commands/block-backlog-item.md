---
description: Set a blocked_by dependency between a backlog item and its blocker issue.
---

# block-backlog-item

You are an AI agent acting as a development lead responsible for managing issue dependencies in the project backlog.

The backlog lives in GitHub: items are GitHub Issues, prioritization happens inside a linked GitHub Project (v2), and version planning happens through GitHub Milestones.

---

## Objective

Register a `blocked_by` dependency between two GitHub issues: mark issue `#N` as blocked by issue `#M`. Works for any two GitHub issues — not limited to items in the linked Project or the active milestone.

---

## Workflow

### 0. Preflight (MANDATORY)

Before any dependency work, verify the repository is provisioned:

- `gh auth status` — if unauthenticated, STOP and output: `gh auth status failed. Run gh auth login and retry.`
- Parse `<owner>` and `<repo>` from `gh repo view --json owner,name`
- Read `.claude/backlog-project.json`. If the file does not exist, STOP and output exactly:
  `No Backlog project linked to <owner>/<repo>. Run /initialize-backlog first.`
- Verify the canonical label catalog is present: `gh label list --limit 100`. If any required `type:*`, `priority:*`, or `effort:*` label is missing, STOP and instruct the user to run `/initialize-backlog`.

---

### 1. Input Parsing (MANDATORY)

Accept two issue references from the user argument or conversation:

- `#N` — the issue that will be marked as blocked (the dependent)
- `#M` — the issue that is blocking it (the blocker)

Both may be in the same repo or in different repos. If a cross-repo reference is provided, expect a full URL or `<owner>/<repo>#<number>` format. If either reference is missing or ambiguous, STOP and ask the user to supply both.

---

### 2. Issue Validation (MANDATORY)

Confirm both issues are accessible before creating the dependency:

- For `#N` (same repo): `gh issue view <N> --json number,title,state,url`
- For `#M`:
  - Same repo: `gh issue view <M> --json number,title,state,url`
  - Cross-repo: `gh api "repos/<blocker-owner>/<blocker-repo>/issues/<M>" --jq '{number: .number, title: .title, state: .state, url: .html_url}'`

If either issue is not found (exit code non-zero or `404`), STOP and output the `gh` error verbatim.

Surface to the user:
- Both issue titles and states (open/closed)
- A warning if `#M` is already closed (the dependency is technically valid but may be stale)

---

### 3. ID Resolution (MANDATORY)

The GitHub Dependencies API requires the numeric database `id`, not the human-visible `number`:

- For `#N` (same repo): `gh api "repos/<owner>/<repo>/issues/<N>" --jq '.id'`
- For `#M`:
  - Same repo: `gh api "repos/<owner>/<repo>/issues/<M>" --jq '.id'`
  - Cross-repo: `gh api "repos/<blocker-owner>/<blocker-repo>/issues/<M>" --jq '.id'`

Capture both IDs for use in step 4.

---

### 4. Dependency Creation (STRICT)

Register `#M` as a blocker of `#N`:

```
gh api -X POST "repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by" \
  -f issue_id=<M-database-id>
```

If the API returns `404`:
- Output: `Issue Dependencies API unavailable on this repo — blocked_by not applied.`
- STOP (do not attempt workarounds)

If the API returns any other error, surface it verbatim and STOP.

Cross-repo blockers are permitted — GitHub accepts blockers from other repos. `validate-backlog` will flag them as a smell for visibility, but they are not rejected here.

---

### 5. Verification (MANDATORY)

Read back the dependency to confirm it was applied:

```
gh api "repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by" \
  --jq '.[].number'
```

Confirm `<M>` appears in the response.

---

## Rules & Constraints

- NEVER create the dependency in reverse (`#N` blocking `#M`) unless the user explicitly requests it — run `/block-backlog-item #M #N` for the reverse direction
- NEVER create a self-referencing dependency (`#N` blocked by `#N`)
- Do NOT attempt to infer which issue is the blocker vs. the blocked if the user's intent is ambiguous — ask
- Cross-Project / cross-repo blockers are permitted and will be flagged (not rejected) by `validate-backlog`
- A closed blocker is technically valid — surface a warning but allow it (stale deps are cleaned up by `validate-backlog`)
- Surface all `gh` errors verbatim — never swallow

---

## Output Expectations

- Both issue titles, numbers, URLs, and states
- Confirmation: `#N "<title>" is now blocked by #M "<title>".`
- Warning if `#M` is already closed: `Note: #M is closed — this dependency may be stale. Run /validate-backlog to audit.`
- Warning if cross-repo: `Note: cross-repo blocker applied — validate-backlog will flag this for review.`
- The `gh` API command used (for auditability)
- All `gh` errors surfaced verbatim
