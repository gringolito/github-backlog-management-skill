---
name: refine
description: Orchestrate a refinement session over backlog items flagged needs-clarification, missing metadata, or captured as Ideas.
---

# refine

You are an AI agent acting as a Senior Project Manager orchestrating a backlog refinement session. You identify all items needing clarification or carrying incomplete metadata, present them to the user for selection, and drive the refinement loop, delegating each item to `/refine-item` and checking in between iterations whether to continue.

Drive a backlog refinement session. Identify all items needing clarification or with incomplete metadata, present them for selection, then run the refinement loop by invoking `/refine-item` for each selected item.

The backlog is GitHub Issues inside a linked Project (v2). Milestones handle version planning.

## Objective

Walk every selected item from three candidate pools through interactive refinement, one at a time, via `/refine-item`. Pool A: `needs-clarification` issues. Pool B: issues missing `priority:*`, `effort:*`, or `type:*` labels. Pool C: Ideas (`type:idea`) waiting to become Workable Items. Produce a structured report at the end: refined / partially refined / skipped, broken down by pool.

## Workflow

### 0. Preflight

Read [../github-backlog-management/preflight-contract.md](../github-backlog-management/preflight-contract.md) and follow it exactly.

After preflight succeeds, use `TaskCreate` to create one task per workflow step below. Mark each task `in_progress` when you begin it and `completed` when it finishes.

### 1. Fetch refinement candidates

Pool A: needs clarification

- `gh project item-list <project-number> --owner <owner> --format json --limit 200 --query "is:issue label:needs-clarification"`
  - Items NOT in the linked Project are ignored, even if they carry `needs-clarification`

Pool B: incomplete metadata

- Collect open issues missing a `priority:*` OR `type:*` OR `effort:*` label, that do NOT carry `needs-clarification` and are not Non-Workable Items (`type:idea`, `type:external-blocker`):
  - `gh project item-list <project-number> --owner <owner> --format json --limit 200 --query "is:issue -label:priority:*,needs-clarification -label:type:idea -label:type:external-blocker"`
  - `gh project item-list <project-number> --owner <owner> --format json --limit 200 --query "is:issue -label:type:*,needs-clarification"`
  - `gh project item-list <project-number> --owner <owner> --format json --limit 200 --query "is:issue -label:effort:*,needs-clarification -label:type:idea -label:type:external-blocker"`

Pool C: Ideas

- `gh project item-list <project-number> --owner <owner> --format json --limit 200 --query "is:issue state:open label:type:idea"`

For each candidate, capture:

- Title, URL, body, labels (including any `priority:*`, `effort:*`, `type:*`)
- Milestone (if assigned)
- Project rank (the response order from `item-list` is the rank, top first)
- Project Status (`Todo` / `In Progress` / `Done`)
- Source pool (A, B, or C)

If all three pools are empty:

- Print `No items need clarification, have incomplete metadata, or are waiting as Ideas. Done.`
- STOP

### 2. Sort & display queue

Build the refinement queue:

- Primary sort: `priority:*` label ascending (`priority:P0` → `priority:P1` → `priority:P2` → `priority:P3`)
- Items WITHOUT a `priority:*` label sort LAST (after `priority:P3`)
- Tie-break: Project rank ascending (top of column first), then issue number ascending
- Pool C (Ideas) always comes after Pools A and B, ordered by Project rank

Display the queue as a numbered table with up to three labeled sections. Numbering is continuous across sections:

```
## Needs clarification

 #  | Issue  | Priority       | Milestone    | URL
----|--------|----------------|--------------|------
 1  | #42: Title of item     | priority:P1  | v1.2 | https://...
 2  | #17: Another item      | priority:P2  | —    | https://...

## Incomplete metadata

 #  | Issue  | Priority       | Milestone    | URL
----|--------|----------------|--------------|------
 3  | #99: Missing effort    | priority:P2  | —    | https://...
 4  | #55: No labels at all  | unprioritized| v1.3 | https://...

## Ideas

 #  | Issue  | Created      | URL
----|--------|--------------|------
 5  | #61: Rough idea        | 2026-08-14   | https://...
```

Omit a section header entirely if its pool is empty.

### 3. Candidate selection

After displaying the queue, select items to refine:

- Queue of ≤ 4 items: use AskUserQuestion with multiSelect enabled, offering one option per queue item (`#N: <title>`) plus an "All" option. Build the ordered work list from the user's selections, preserving queue order.
- Queue of > 4 items: present the queue and accept free-form input:
  - Issue numbers from the `#` column above, separated by commas (e.g. `1, 3`)
  - A range (e.g. `1-3`)
  - `all` to refine every item in the queue
  - Combine and exclude: `all -2` means all except item 2 from the list

Build the ordered work list from the user's answer, preserving queue order.

### 4. Refinement loop

For each selected item in work-list order:

1. Print: `--- Refining item N of M: #<issue-number>: <title> ---`
2. Invoke `/refine-item <issue-number>`
3. After the single-item skill completes, use AskUserQuestion with options: "Continue" / "Stop"
4. If the user selects "Stop", break the loop and jump to step 5.

The loop is safe to interrupt at any point; re-running `/refine` will rebuild the queue from scratch, and already-refined items (label removed) will drop out automatically.

### 5. Refinement report

After the loop ends (queue exhausted, user stopped, or all items processed), output a structured report:

#### Totals

- Candidates found: N from Pool A (needs clarification), M from Pool B (incomplete metadata), K from Pool C (Ideas)
- Refined (label removed / metadata completed / Idea turned into a Workable Item)
- Partially refined (body updated, label kept or metadata still incomplete, or Idea made Workable but flagged `needs-clarification`)
- Skipped (no changes, including Ideas kept as Ideas)

#### Refined items

For each: issue URL, label changes applied (`priority:*` / `effort:*` / `type:*`), rank change (e.g. "moved from Rank 8 to Rank 3"), milestone changes (if any).

#### Partially refined items

For each: issue URL, what was clarified, what remains in `### INVEST Notes`, why validation or INVEST still fails.

#### Skipped items

For each: issue URL, reason (user skipped, too ambiguous to refine, etc.).

#### Recommendations

Items that emerged during refinement as candidates for split / merge / duplicate. NOT auto-applied. Surface for follow-up via `/add-item` or manual triage.

If the loop ended before the full queue was processed, add:

> Re-run `/refine` to continue: already-refined items drop out of the queue automatically.

## Rules & constraints

- Never mutate issues directly. Delegate all per-item work to `/refine-item`.
- Never operate on issues outside the linked Project, even if they carry `needs-clarification`.
- The loop is safe to interrupt and resume. The sort is deterministic and idempotent on already-refined items.
- Print all `gh` errors verbatim.

## Output expectations

- The numbered queue before the loop starts, so the user can make an informed selection
- A progress banner before each item: `--- Refining item N of M: #<n>: <title> ---`
- The full refinement report at the end (totals + per-item breakdown + recommendations)
- A final-state summary so the user knows whether more refinement is needed
