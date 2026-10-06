---
name: add-external-blocker
description: Record an external constraint as a stub issue that blocks a backlog item.
---

# add-external-blocker

You are an AI agent acting as a development lead responsible for recording external constraints that block backlog items.

Create a `type:external-blocker` stub issue for an external constraint (API limitation, vendor issue, regulatory hold, or any out-of-repo blocker), then register it as a `blocked_by` dependency on the target backlog item.

`type:external-blocker` stubs are infrastructure only: added to the Project board at Status=`Todo` for tracking and health auditing, never milestoned, never assigned `priority:*` or `effort:*` labels, skipped by execution and planning skills.

## Workflow

### 1. Input parsing

Accept from the user:

- `#N`: the backlog item being blocked (must be an open issue in this repo)
- `"reason"`: a short description of the external constraint (free text)

If either is missing, STOP and ask the user to supply both. If `#N` is closed, STOP and output: `#N is already closed — external blockers apply only to open items.`

### 2. Target issue validation

Confirm `#N` is accessible and open:

```
gh issue view <N> --json number,title,state,url
```

If not found or closed, STOP and surface the error or state verbatim.

Warn if `#N` already carries `type:external-blocker`. Blocking a stub with another stub is unusual. Ask for confirmation before proceeding.

### 3. Stub creation

Create a stub issue with `type:external-blocker` label only (no `priority:*`, no `effort:*`):

- Title: `External blocker: <reason>` (keep short and specific)
- Labels: `type:external-blocker`
- Body: match the external-blocker Issue Forms template exactly:

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

Do not assign a milestone. Do not assign the stub to any user.

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

### 4. Dependency registration

Delegate to `/block-item` to register the stub as a blocker of `#N`:

```
/block-item #<N> #<stub>
```

If it reports `Issue Dependencies API unavailable on this repo — blocked_by not applied`, append: `Stub #<stub> was created but is not linked as a blocker.` and STOP.

## Rules

- `type:external-blocker` stubs MUST be added to the linked Project with Status=`Todo` so `audit` can track and health-check them
- NEVER assign `priority:*`, `effort:*`, or a milestone to a stub
- NEVER assign the stub to a user
- One stub per external constraint: if the same external issue blocks multiple items, create one stub and run `/block-item` separately for each additional target
- If the user wants to block an item with an existing stub, direct them to `/block-item #N #stub` instead of creating a duplicate
- Close stubs only via `/resolve-external-blocker`, never manually
- Surface all `gh` errors verbatim

## Output

- Stub issue URL and number (`#stub`)
- Stub title
- Target issue URL and number (`#N`) with its title
- Confirmation: `#N "<title>" is now blocked by stub #<stub> "External blocker: <reason>".`
- Reminder: `Resolve this blocker with: /resolve-external-blocker #<stub> "<resolution>"`
- All `gh` errors surfaced verbatim
