# add-external-blocker

You are an AI agent acting as a development lead responsible for recording external constraints that block backlog items.

The backlog lives in GitHub: items are GitHub Issues, prioritization happens inside a linked GitHub Project (v2), and version planning happens through GitHub Milestones.

---

## Objective

Create a lightweight stub issue (`type:external-blocker`) that represents an external constraint — an API limitation, vendor issue, regulatory hold, or any other blocker that cannot be expressed as a standard GitHub issue — and immediately register it as a `blocked_by` dependency on the target backlog item.

`type:external-blocker` stubs are **infrastructure only**: they are added to the Project board with Status=`Todo` so they can be tracked and have their health audited, but never milestoned, never assigned `priority:*` or `effort:*` labels, and skipped by execution and planning commands.

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

- `#N` — the backlog item being blocked (must be an open issue in this repo)
- `"reason"` — a short description of the external constraint (free text)

If either is missing, STOP and ask the user to supply both. If `#N` is closed, STOP and output: `#N is already closed — external blockers apply only to open items.`

---

### 2. Target Issue Validation (MANDATORY)

Confirm `#N` is accessible and open:

```
gh issue view <N> --json number,title,state,url
```

If not found or closed, STOP and surface the error or state verbatim.

Warn if `#N` already carries `type:external-blocker` — it is unusual to block a stub with another stub. Ask for confirmation before proceeding.

---

### 3. Stub Creation (STRICT)

Create a stub issue with `type:external-blocker` label only (no `priority:*`, no `effort:*`):

- **Title**: `External blocker: <reason>` (keep short and specific)
- **Labels**: `type:external-blocker`
- **Body**: match the external-blocker Issue Forms template shape exactly:

  ```
  ### Reason

  <reason>

  ### External Reference / URL

  _None provided_

  ### Expected Resolution Path

  _Unknown_
  ```

  If the user supplies an external URL or expected resolution path, substitute them in the appropriate fields.

Create via:

```
gh issue create \
  --title "External blocker: <reason>" \
  --label "type:external-blocker" \
  --body-file <tmp>
```

Capture the returned stub URL and number (`#stub`).

Do NOT assign a milestone, do NOT assign the stub to any user.

Add the stub to the linked Project and set its Status to `Todo`:

```
gh project item-add <project-number> --owner <owner> --url <stub-url>
```

Resolve the new item's ID, then set Status:

```
gh project item-edit \
  --id <item-id> \
  --project-id <project-id> \
  --field-id <status-field-id> \
  --single-select-option-id <todo-option-id>
```

Use the `project_id`, `project_number`, and `status_field_id` / `status_options.Todo` values already loaded from `.claude/backlog-project.json`.

---

### 4. Dependency Registration (STRICT)

Delegate to `/block-backlog-item` to register the stub as a blocker of `#N`:

```
/block-backlog-item #<N> #<stub>
```


If it reports `Issue Dependencies API unavailable on this repo — blocked_by not applied`, append: `Stub #<stub> was created but is not linked as a blocker.` and STOP.

---

## Rules & Constraints

- `type:external-blocker` stubs MUST be added to the linked Project with Status=`Todo` — this makes them visible to `validate-backlog` for health auditing and project tracking
- NEVER assign `priority:*`, `effort:*`, or milestone to a stub
- NEVER assign the stub to a user
- One stub per external constraint — if the same external issue blocks multiple items, create one stub and run `/block-backlog-item` separately for each additional target
- If the user wants to block an item with an existing stub (already created), direct them to `/block-backlog-item #N #stub` instead of creating a duplicate
- Stubs are resolved (closed) via `/resolve-external-blocker` — never close them manually
- Surface all `gh` errors verbatim — never swallow

---

## Output Expectations

- Stub issue URL and number (`#stub`)
- Stub title
- Target issue URL and number (`#N`) with its title
- Confirmation: `#N "<title>" is now blocked by stub #<stub> "External blocker: <reason>".`
- Reminder: `Resolve this blocker with: /resolve-external-blocker #<stub> "<resolution>"`
- All `gh` errors surfaced verbatim
