---
name: block-item
description: Set a blocked_by dependency between a backlog item and its blocker issue.
---

# block-item

You are an AI agent acting as a development lead responsible for managing issue dependencies in the project backlog.

Register a `blocked_by` dependency between two GitHub issues: mark `#N` as blocked by `#M`. Works for any two issues, not limited to Project items or the active Milestone.

## Workflow

### 1. Input parsing

Accept two issue references from the user argument or conversation:

- `#N`: the issue to mark as blocked (the dependent)
- `#M`: the issue blocking it (the blocker)

Both may be in the same repo or different repos. Cross-repo references must be a full URL or `<owner>/<repo>#<number>`. If either reference is missing or ambiguous, stop and ask.

### 2. Issue validation

Confirm both issues are accessible before creating the dependency:

- For `#N` (same repo): `gh issue view <N> --json number,title,state,url`
- For `#M`:
  - Same repo: `gh issue view <M> --json number,title,state,url`
  - Cross-repo: `gh api "repos/<blocker-owner>/<blocker-repo>/issues/<M>" --jq '{number: .number, title: .title, state: .state, url: .html_url}'`

If either issue is not found (exit code non-zero or `404`), stop and output the `gh` error verbatim.

Report:
- Both issue titles and states (open/closed)
- A warning if `#M` is already closed (the dependency is valid but may be stale)

### 3. ID resolution

The GitHub Dependencies API requires the numeric database `id`, not the visible `number`:

- For `#N` (same repo): `gh api "repos/<owner>/<repo>/issues/<N>" --jq '.id'`
- For `#M`:
  - Same repo: `gh api "repos/<owner>/<repo>/issues/<M>" --jq '.id'`
  - Cross-repo: `gh api "repos/<blocker-owner>/<blocker-repo>/issues/<M>" --jq '.id'`

Capture both IDs for step 4.

### 4. Dependency creation

Register `#M` as a blocker of `#N`:

```
gh api -X POST "repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by" \
  -f issue_id=<M-database-id>
```

If the API returns `404`:
- Output: `Issue Dependencies API unavailable on this repo — blocked_by not applied.`
- Stop

If the API returns any other error, output it verbatim and stop.

Cross-repo blockers are permitted. `audit` will flag them for visibility, not reject them.

### 5. Verification

Read back the dependency to confirm it was applied:

```
gh api "repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by" \
  --jq '.[].number'
```

Confirm `<M>` appears in the response.

## Rules

- NEVER create the dependency in reverse (`#N` blocking `#M`) unless the user explicitly requests it; run `/block-item #M #N` for the reverse direction
- NEVER create a self-referencing dependency (`#N` blocked by `#N`)
- Do NOT infer which issue is the blocker vs. the blocked if the user's intent is ambiguous; ask
- Cross-Project / cross-repo blockers are permitted and will be flagged (not rejected) by `audit`
- A closed blocker is valid; warn but allow it (stale deps are cleaned up by `audit`)
- Output all `gh` errors verbatim; never swallow

## Output

- Both issue titles, numbers, URLs, and states
- Confirmation: `#N "<title>" is now blocked by #M "<title>".`
- Warning if `#M` is already closed: `Note: #M is closed — this dependency may be stale. Run /audit to review.`
- Warning if cross-repo: `Note: cross-repo blocker applied — audit will flag this for review.`
- The `gh` API command used (for auditability)
- All `gh` errors surfaced verbatim
