# Re-planning release workflow

Fetch the milestone's current state:

- `gh api "repos/<owner>/<repo>/milestones/<number>"` — confirm title, `due_on`, open/closed issue counts
- `gh project item-list <project-number> --owner <owner> --query "is:issue milestone:<milestone-title>" --format json --limit 200`

Compute the current capacity estimate using Fibonacci weights (XS=1 / S=2 / M=3 / L=5 / XL=8; items with no effort label counted as M=3 with a note).

Display:

```text
Milestone: <title> | Due: <due_on> | Capacity: N pts (band)

In Progress (N): #n title [effort]  ...
Done (N):        #n title [effort]  ...
Todo (N):        #n title [effort]  ...
```

Items with In Progress or Done status are shown as read-only context throughout the session — they cannot be added to or removed from the milestone via this skill.

## Actions

Use `AskUserQuestion` to open the main session menu:

```yaml
question: "What would you like to do with <milestone title>?"
header: "Action"
options:
  - label: "Add items"
    description: "Pull unassigned Todo items into this milestone."
  - label: "Remove items"
    description: "Remove items from this milestone with a disposition choice."
  - label: "Both"
    description: "Add items first, then remove items."
  - label: "Done — show summary"
    description: "End the session and print the summary."
```

### Add flow

Triggered when the user chooses "Add items" or "Both".

Fetch unassigned candidates via `gh project item-list <project-number> --owner <owner> --query "is:issue status:Todo no:milestone -label:type:external-blocker" --format json --limit 200`

Display the candidate table in plain text before calling `AskUserQuestion`:

```text
Rank | #  | Title | Type | Priority | Effort
```

Use `AskUserQuestion` (multiSelect) to let the user pick items:

```yaml
question: "Select items to add to <milestone title> (current capacity: N pts)."
header: "Add items"
multiSelect: true
options:
  - label: "#N — <title>"
    description: "<type> · <priority> · <effort>"
  # one entry per candidate
```

After the selection is confirmed, recompute and display the updated capacity estimate and ask user confirmation.

Apply additions: `gh issue edit <n> --milestone "<milestone-title>"` for each confirmed item.

### Remove flow

Triggered when the user chooses "Remove items" or "Both".

Fetch all open issues currently assigned to the milestone via `gh project item-list <project-number> --owner <owner> --query "is:issue status:Todo milestone:<milestone-title> -label:type:external-blocker" --format json --limit 200`

Display the Milestone's Todo items in plain text before calling `AskUserQuestion`:

```text
# | Title | Type | Priority | Effort
```

Use `AskUserQuestion` (multiSelect) to let the user pick items to remove:

```yaml
question: "Select items to remove from <milestone title>."
header: "Remove items"
multiSelect: true
options:
  - label: "#N — <title>"
    description: "<type> · <priority> · <effort>"
  # one entry per Todo item in this milestone
```

For each selected item, use `AskUserQuestion` (single-select) to collect its disposition:

```yaml
question: "How should #N — <title> be handled?"
header: "Disposition"
options:
  - label: "Back to backlog"
    description: "Remove milestone assignment; leave open in Todo column."
  - label: "Carry forward"
    description: "Reassign to another open milestone."
  - label: "Close as won't fix"
    description: "Close the issue with a won't-fix comment."
```

Apply the disposition:

- **Back to backlog**: `gh issue edit <n> --milestone ""`
- **Carry forward**:
  - `gh api "repos/<owner>/<repo>/milestones?state=open&per_page=100"` — collect other open milestones (exclude the current one)
  - If no other open milestone exists: surface a clear error and fall back to "Back to backlog"
  - Otherwise, use `AskUserQuestion` to let the user pick the target milestone:

    ```yaml
    question: "Which milestone should #N — <title> be moved to?"
    header: "Target milestone"
    options:
      - label: "<milestone title>"
        description: "Due: <due_on>"
      # one entry per other open milestone
    ```

  - Apply: `gh issue edit <n> --milestone "<target-milestone-title>"`
- **Close as won't fix**:
  - `gh issue comment <n> --body "Closing as won't fix."`
  - `gh issue edit <n> --state closed`

After processing all selected items, recompute and display the updated capacity estimate.

## Session Loop

After completing an Add or Remove flow, re-issue the main `AskUserQuestion` from the Actions step so the user can continue adjusting or exit.

Proceed to the next step ONLY when the user chooses "Done — show summary".

## Session Summary

Print:

- Milestone title, number, `html_url`, `due_on`
- Items added: `#number — title — effort` (or "None")
- Items removed by disposition:
  - Back to backlog: list of `#number — title`
  - Carry forward: list of `#number — title → milestone`
  - Closed as won't fix: list of `#number — title`
- Final capacity estimate (points + qualitative band)
- Pointer to next steps:
  - "Run `/add-item` to add more items to this milestone"
  - "Run `/pick-item` to start working on this milestone"

## Rules & Constraints

- All `gh` errors must be surfaced verbatim, never silent skip errors

## Output Expectations

- Clear summary of the updated milestone with URL
- Full list of scoped issues assigned to the milestone
- Milestone size estimate (effort points + qualitative band)
