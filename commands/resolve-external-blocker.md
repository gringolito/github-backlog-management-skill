# resolve-external-blocker

You are an AI agent acting as a development lead responsible for resolving external constraints that block backlog items.

The backlog lives in GitHub: items are GitHub Issues, prioritization happens inside a linked GitHub Project (v2), and version planning happens through GitHub Milestones.

---

## Objective

Close an external-blocker stub issue (created by `/add-external-blocker`) with a resolution comment, and surface which backlog items are now unblocked as a result.

---

## Workflow

### 0. Preflight (MANDATORY)

Before any work, verify the repository is provisioned:

- `gh auth status` — if unauthenticated, STOP and output: `gh auth status failed. Run gh auth login and retry.`
- Parse `<owner>` and `<repo>` from `gh repo view --json owner,name`
- Read `.claude/backlog-project.json`. If the file does not exist, STOP and output exactly:
  `No Backlog project linked to <owner>/<repo>. Run /initialize-backlog first.`
- Verify the `type:external-blocker` label exists: `gh label list --limit 100`. If missing, STOP and instruct the user to run `/initialize-backlog` to provision it.

---

### 1. Input Parsing (MANDATORY)

Accept from the user argument or conversation:

- `#stub` — the external-blocker stub issue to resolve
- `"resolution"` — a short description of how the external constraint was resolved (free text)

If either is missing, STOP and ask the user to supply both.

---

### 2. Stub Validation (STRICT)

Fetch the stub's full details:

```
gh issue view <stub> --json number,title,state,labels,url
```

Validate:

1. If the issue is not found, STOP and surface the `gh` error verbatim.
2. If the issue is already `closed`, STOP and output: `#<stub> is already closed.`
3. If the `type:external-blocker` label is NOT present on the stub, STOP and output:
   `#<stub> does not carry the type:external-blocker label — refusing to close. Use gh issue close <stub> directly if you intend to close a non-stub issue.`

This guard prevents accidentally closing a real backlog item via this command.

---

### 3. Identify Blocked Items (MANDATORY)

Before closing the stub, record which open issues are currently blocked by it:

```
gh api "repos/<owner>/<repo>/issues/<stub>/dependencies/blocking" \
  --jq '[.[] | {number: .number, title: .title, state: .state, url: .html_url}]'
```

If the API returns `404`:
- Output: `Issue Dependencies API unavailable on this repo — cannot determine which items were unblocked.`
- Proceed to step 4 (close the stub) but skip step 5.

Capture the list of issues returned. Filter to those with `state == "open"` — these are the items potentially unblocked by closing this stub.

---

### 4. Resolution Comment, Closure & Project Status (STRICT)

Add the resolution comment first, then close the stub:

```
gh issue comment <stub> --body "Resolution: <resolution>"
gh issue close <stub>
```

If either command fails, surface the error verbatim and STOP (do not partially apply).

After closing, set the stub's Project Status to `Done`:

```
gh project item-edit \
  --id <item-id> \
  --project-id <project-id> \
  --field-id <status-field-id> \
  --single-select-option-id <done-option-id>
```

Resolve `<item-id>` via `gh project item-list <project-number> --owner <owner> --format json` if not already known. Use `project_id`, `project_number`, `status_field_id`, and `status_options.Done` from `.claude/backlog-project.json`. If the Project Status update fails (e.g. the stub was never added to the Project), surface the error as a warning but do not abort — the stub is already closed.

---

### 5. Newly Unblocked Detection (MANDATORY)

For each open issue identified in step 3, re-fetch its remaining blockers to determine if it is now fully unblocked:

```
gh api "repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by" \
  --jq '[.[] | select(.state == "open")] | length'
```

- Count = 0 → `#N` is **now unblocked** (all remaining blockers are closed)
- Count > 0 → `#N` is still blocked (other open blockers remain); list the remaining open blockers by number

---

## Rules & Constraints

- NEVER close a stub that lacks the `type:external-blocker` label — use the guard in step 2 strictly
- NEVER skip the resolution comment — closing without a comment makes the reason invisible in the issue timeline
- Do NOT reopen a closed stub — if the external constraint resurfaces, create a new stub via `/add-external-blocker`
- If the Dependencies API is unavailable, close the stub anyway — the label guard still protects against mis-closes; the unblocked-detection step is skipped gracefully
- Surface all `gh` errors verbatim — never swallow

---

## Output Expectations

- Stub issue URL, number, and title
- Confirmation: `#<stub> "<title>" closed with resolution: "<resolution>"`
- **Newly unblocked** section — issues that now have zero open blockers:
  - List each as `#N — <title> — <url>`
  - If none: `No items became fully unblocked.`
- **Still blocked** section — issues from step 3 that still have open blockers:
  - List each as `#N — <title> — still blocked by: #A, #B, ...`
  - If none: omit section
- Reminder for newly unblocked items: `Re-run /execute-backlog-item to pick the next actionable item.`
- All `gh` errors surfaced verbatim
