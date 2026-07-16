---
name: pick-item
description: Select, validate, plan, and assign the topmost unblocked Workable Item from the Backlog. Use when the user wants to select the next item to work.
---

# pick-item

You are an AI agent acting as a development lead. Select the topmost actionable Workable Item, scoped to the Active Release first, then to un-milestoned items as a fallback, then validate, plan, and assign it.

## Workflow

### 0. Preflight (MANDATORY)

Read the [preflight contract](../github-backlog-management/preflight-contract.md) for the preflight instruction; follow it exactly.

After preflight succeeds, use `TaskCreate` to create one task per workflow step below. Mark each task `in_progress` when you begin it and `completed` when it finishes.

### 1. Item Selection (MANDATORY)

Run `select-item` via the Bash tool. If it exits non-zero, STOP and surface its stderr verbatim.

Capture the JSON output:

```json
{
  "active_milestone": {"number": N, "title": "...", "due_on": "..."},
  "in_progress": [...],
  "candidate": {...} | null,
  "skipped_blocked": [...],
  "skipped_for_sub_issues": [...],
  "warnings": [...],
  "message": "..." | null
}
```

Surface any `warnings` found before proceeding.

If `candidate` is null surface `message`. When all candidates are blocked: read the [blocker analysis](./blocker-analysis.md) table. Then STOP.

Display each `in_progress` item issue number, title, milestone, labels and PR status.

Then use AskUserQuestion with options built dynamically: one option per in-progress item (title + PR status) plus a final "Pick a new item" option.
- In-progress item chosen: that item becomes the winner. Check out the existing branch, read the open PR if available, and proceed to Step 5.
- Pick a new item chosen: proceed with `candidate`.

Surface the `skipped_blocked` items table in the eventual plan output so the user knows why the queue was deeper than expected.

Log each `skipped_for_sub_issues` as `Skipping parent #N — open sub-issues found.`

If the picked item's `priority:*` label appears mismatched against its Project rank, surface the discrepancy so the user can confirm or reorder.

#### 1.1 Issue Comment History

Display the full comment thread in `candidate.comments` if available; One comment per block, in chronological order, including the author and timestamp.

### 2. Sub-issue Scope Check

Use `candidate.sub_issues_summary` from the script output, when all sub-issues are closed (`completed == total AND total > 0`) read the [Scope Completeness](./scope-completeness.md) for the full review protocol. Then STOP.

#### type:epic Gate

When `candidate.labels` includes `type:epic` AND the item did not enter **Scope Completeness** review above STOP and tell the user to decompose the epic into sub-issues or add them into the project.

### 3. Item Validation (MANDATORY)

Use `candidate.body` and `candidate.labels` from the `select-item` output and parse the body sections (`### What`, `### Why`, `### In Scope`, `### Out of Scope`, `### Acceptance Criteria`, `### INVEST Notes`). Validate against INVEST principles:

- Independent
- Negotiable
- Valuable
- Estimable
- Small
- Testable

If any principle fails:

- STOP
- Explain the specific INVEST violation(s)
- Ask: "Would you like to refine this item now? Run `/refine-item <n>` to walk through a guided refinement session, then re-run `/pick-item` when it is ready."

If priority or effort labels are missing or duplicated, STOP and direct the user to run `/audit`.

### 4. Assignment

Once the item is validated:

1. Self-assign the issue: `gh issue edit <n> --add-assignee @me`
2. Set the Project Status field to `In Progress`:
   - Resolve field/option IDs: `gh project field-list <project-number> --owner <owner> --format json`
   - Find the item ID via `gh project item-list <project-number> --owner <owner> --format json --query "#<n>"`
   - Update: `gh project item-edit --id <item-id> --project-id <project-id> --field-id <status-field-id> --single-select-option-id <in-progress-option-id>`

### 5. Planning

If `candidate.parent` is available:

- Extract `### What` and `### Why` sections from `candidate.parent.body`
- Display the parents issue number, title, what and why sections before the implementation plan
- In case of missing sections show what is available, emit warnings for the missing and proceed

Propose a concise implementation plan that:

- Covers ALL Acceptance Criteria (parsed from `### Acceptance Criteria`)
- Respects defined Scope (`### In Scope` / `### Out of Scope`)
- Avoids out-of-scope work
- Research the solution online if needed
- Aligns with the parent context found

When the item carries `type:spike`, the plan should reflect the investigation approach and likely shape of the findings document, not a code change — it is handed off to `/spike` for execution in Step 6 below.

Evaluate the scope of the work and if you identify that the item is too large for a single iteration consider:

- Draft a split proposal: list each sub-issue with a title, What/Why/Acceptance Criteria, suggested type/priority/effort labels, and how they map to the parent's Acceptance Criteria
- Present the proposal and wait for explicit approval
- After approval invoke `/add-item` for each sub-issue in sequence, passing the parent issue number so it handles the sub-issue relationship
- If two or more sub-issues were just created check the Sibling Dependency Inference below
- Move the current item back to Todo and un-assign it
- STOP. This session is complete. Re-run `/pick-item` to pick the first sub-issue

#### Sibling Dependency Inference

1. Call `dependency-inferrer` with:
   - Prose: the body of each newly created sub-issue, labeled with `#<n> "<title>"`
   - Issue roster: the N newly created sub-issues as `#<n> "<title>"` per line
2. Discard any `blocking` or `sub_issue` candidates — handle `blocked_by` only.
3. Present all `blocked_by` candidates in a single review block:

   ```
   #<this-num> "<this-title>"
     → blocked_by #<target-num> "<target-title>" (evidence: "...")
   ```

   User can accept all, reject all, or cherry-pick.
4. For each accepted candidate, delegate to `/block-item #<this-num> #<target-num>`. Surface any errors verbatim; continue applying remaining confirmed candidates.

#### Branching Prefix

Skip for continued work (items already in progress)

Determine the Conventional Commits prefix from the issue's `type:*` label:

- `type:feature` → `feat/`
- `type:performance` → `perf/`
- `type:tech-debt` → `refactor/`
- `type:bug`, `type:security`, `type:reliability`, `type:compliance` → `fix/`
- `type:dx` → `chore/`
- `type:spike` → `spike/`
- For any other custom `type:*` label use the label value as the prefix (e.g. `type:data-pipeline` → `data-pipeline/`); if the value contains `:`, strip it

Branch name format: `<prefix>/<slug>` (e.g. `fix/null-pointer-in-authn`).

### 6. Handoff

Close with a hand-off including:

- Issue URL and number
- Suggested branch name (`<prefix>/<slug>`)
- A brief recap of the plan approved in Step 5
- Whether the issue was assigned to the Active Release
- Items skipped above this one because they were blocked (with `#N` and the open blockers that gated them; `type:external-blocker` blockers shown as `External: <stub title>`)
- Parent items skipped because open sub-issues were found in the Project's Todo column
- Whether this item was **resumed** (was already In Progress) or **newly picked** (was Todo)

Then suggest any contextually relevant skills for continuing this item's work.

## Rules & Constraints

- Do NOT proceed without plan approval
- Do NOT make assumptions, ask questions if needed
- Do NOT pick items outside the linked Project
- Do NOT pick a blocked item, even with user confirmation, block-skipping is strict
- Do NOT close the issue manually, always rely on `Closes #N` in the PR. Exceptions: closing a parent after Scope Completeness Review, or a spike's own PR closing the spike issue.
- A blocker is satisfied ONLY when its issue state is `closed`
