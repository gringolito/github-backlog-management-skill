---
name: pick-item
description: Select, validate, plan, and assign the topmost unblocked Workable Item — for spikes, runs the full investigate-through-PR protocol end-to-end.
---

# pick-item

You are an AI agent acting as a development lead. Select the topmost actionable Workable Item, scoped to the Active Release first, then to un-milestoned items as a fallback, then validate, plan, and assign it.

## Workflow

### 0. Preflight (MANDATORY)

Read [../github-backlog-management/preflight-contract.md](../github-backlog-management/preflight-contract.md) for the preflight instruction; follow it exactly.

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

If any `warnings` are present, surface them before proceeding.

**If `candidate` is null:** Surface `message`. When all candidates are blocked: read [blocker-analysis.md](./blocker-analysis.md) for the per-blocker analysis table. Then STOP.

**If `in_progress` is non-empty:** Display each item:

| # | Title | Milestone | Labels | PR Status |
|---|-------|-----------|--------|-----------|
| #N | ... | v0.x.x | type:... | ✅ PR #M open (waiting review) |
| #N | ... | — | type:... | 🔧 No PR yet (work in progress) |

Then use AskUserQuestion with options built dynamically: one option per in-progress item (title + PR status, e.g. "fix/auth-bug — PR #42 open" or "feat/dashboard — no PR yet") plus a final "Pick a new item" option.
- **In-progress item chosen:** that item becomes the winner. Skip Steps 3, 4, 6, and 7. Advise the user to check out the existing branch (`<type>/<slug>`). If a linked PR exists, skip the Delivery portion of Step 8 as well. Proceed to Step 5.
- **"Pick a new item" chosen:** proceed with `candidate`.

If `skipped_blocked` is non-empty but `candidate` is not null, surface the blocked items table in the eventual plan output so the user knows why the queue was deeper than expected.

If `skipped_for_sub_issues` is non-empty, log each as: `Skipping parent #N — open sub-issues found.`

If the picked item's `priority:*` label appears mismatched against its Project rank, surface the discrepancy so the user can confirm or reorder.

#### 1.1 Issue Comment History

If `candidate.comments` is non-empty, display the full comment thread before proceeding to Step 3:

```
**Comment history — #N: <title>** (<count> comments)

@<author> · <created_at>
<body>

@<author> · <created_at>
<body>
```

One block per comment, in chronological order. Skip this section entirely when `candidate.comments` is empty.

### 3. Sub-issue Scope Check

Use `candidate.sub_issues_summary` from the script output — no API call needed.

- **If `completed == total AND total > 0`:** All sub-issues are closed: read [scope-completeness.md](./scope-completeness.md) for the full review protocol. Then STOP.
- **Otherwise:** proceed to Step 4.

Note: Open sub-issue routing is already handled by `select-item` — if the script selected a sub-issue as `candidate`, no further parent/sub-issue traversal is needed here.

#### type:epic Gate

If `candidate.labels` includes `type:epic` AND the item did not enter Scope Completeness Review above: STOP and tell the user to decompose the epic into sub-issues or add them into the project.

### 4. Item Validation (MANDATORY)

Use `candidate.body` and `candidate.labels` from the `select-item` output — no `gh issue view` call needed.

Parse the body sections (`### What`, `### Why`, `### In Scope`, `### Out of Scope`, `### Acceptance Criteria`, `### INVEST Notes`). Validate against INVEST principles:

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

### 5. Planning

#### 5.1. Parent Context (RELATIVE)

Use `candidate.parent` from the `select-item` output — no additional API call needed.

- **If `candidate.parent` is `null`** → proceed silently. No warning, no block.

- **If `candidate.parent` is present:**
   - Extract `### What` and `### Why` sections from `candidate.parent.body` (matched by exact heading text).
   - Emit the following block **before** the implementation plan:

     ```
     **Parent context — #N: <parent title>**
     > **What:** <text from ### What>
     > **Why:** <text from ### Why>
     ```

   - If one section is absent, show the available one and omit the missing line.
   - If neither section exists, emit `(Parent body does not follow standard template — no What/Why sections found)` and proceed.

- Propose a concise implementation plan that:
  - Covers ALL Acceptance Criteria (parsed from `### Acceptance Criteria`)
  - Respects defined Scope (`### In Scope` / `### Out of Scope`)
  - Avoids out-of-scope work
  - Research the solution online if needed

- If the item carries `type:spike`, apply the **Spike Lifecycle** described in Step 8 below instead of the standard implementation flow. The plan should reflect the investigation approach and likely shape of the findings document, not a code change.

- If the item is too large for a single iteration (based on `effort:*`):
  - Draft a split proposal: list each sub-issue with a title, What/Why/Acceptance Criteria, suggested type/priority/effort labels, and how they map to the parent's Acceptance Criteria
  - Present the proposal and wait for explicit approval
  - After approval, invoke `/add-item` for each sub-issue in sequence, passing the parent issue number so it handles the sub-issue relationship
  - STOP after the sub-issues are created — re-run `/pick-item` to pick the first sub-issue

#### 5.2 Sibling Dependency Inference (RELATIVE)

If two or more sub-issues were just created:

1. **Call `dependency-inferrer`** with:
   - **Prose**: the body of each newly created sub-issue, labeled with `#<n> "<title>"`
   - **Issue roster**: the N newly created sub-issues as `#<n> "<title>"` per line
2. **Discard** any `blocking` or `sub_issue` candidates — handle `blocked_by` only.
3. **If `CANDIDATES: none`** or all candidates are non-`blocked_by` → skip the rest of this step.
4. **Present all `blocked_by` candidates in a single review block** (same format as `migrate` step 8e):

   ```
   #<this-num> "<this-title>"
     → blocked_by #<target-num> "<target-title>" (evidence: "...")
   ```

   User can accept all, reject all, or cherry-pick.
5. **For each accepted candidate**, delegate to `/block-item #<this-num> #<target-num>`.
   Surface any errors verbatim; continue applying remaining confirmed candidates.
6. If the Dependencies API returns `404`, emit:
   `Issue Dependencies API unavailable — sibling dependency inference skipped.`
   and skip this step.

- Wait for explicit approval before proceeding

### 6. Status → In Progress (BEFORE BRANCH)

Once the plan is approved:

1. Self-assign the issue: `gh issue edit <n> --add-assignee @me`
2. Set the Project Status field to `In Progress`:
   - Resolve field/option IDs: `gh project field-list <project-number> --owner <owner> --format json`
   - Find the item ID via `gh project item-list <project-number> --owner <owner> --format json --query "#<n>"`
   - Update: `gh project item-edit --id <item-id> --project-id <project-id> --field-id <status-field-id> --single-select-option-id <in-progress-option-id>`

### 7. Branching Prefix

Determine the Conventional Commits prefix from the issue's `type:*` label:

- `type:bug` → `fix/`
- `type:feature` → `feat/`
- `type:performance` → `perf/`
- `type:tech-debt` → `refactor/`
- `type:dx` → `chore/`
- `type:security`, `type:reliability`, `type:compliance` → `fix/` (security/correctness scope)
- `type:spike` → `spike/`
- Any other custom `type:*` label → use the label value as the prefix (e.g. `type:data-pipeline` → `data-pipeline/`); if the value contains `:`, strip it

Branch name format: `<prefix>/<slug>` (e.g. `fix/null-pointer-in-authn`). This prefix feeds both the spike branch created in Step 8 and the branch-name suggestion in the non-spike hand-off.

### 8. Post-Assignment Continuation

**If `candidate.labels` includes `type:spike`:** continue directly through the full spike protocol — do not stop or hand off to another skill.

1. Create and check out branch `spike/<slug>` (per Step 7).
2. Read [spike-lifecycle.md](./spike-lifecycle.md) and execute the full protocol end-to-end: investigate, author the findings document, get user sign-off, propose and create approved follow-on items.
3. Commit using Conventional Commits format. Include `Refs #<issue-number>` in the commit body. Push the branch.
4. Open a Pull Request via `gh pr create`, passing `--milestone "<milestone-title>"` when the issue has one. PR body MUST include `Closes #<issue-number>` and list every follow-on item created (per spike-lifecycle.md).
5. Print: issue URL/number, PR URL/number, branch name, assignee, final Project Status, follow-on items created, and whether this item was **resumed** or **newly picked**.
6. STOP — this item's `pick-item` run is complete.

**Otherwise (non-spike):** close with a neutral hand-off. Do not name a specific next skill — this skill only selects, validates, plans, and assigns.

Print:

- Issue URL and number
- Suggested branch name (`<prefix>/<slug>` from Step 7)
- Assignee (the authenticated user, assigned in Step 6)
- Final Project Status (`In Progress`)
- A brief recap of the plan approved in Step 5
- Whether the issue was assigned to the Active Release
- Items skipped above this one because they were blocked (with `#N` and the open blockers that gated them; `type:external-blocker` blockers shown as `External: <stub title>`) — surfaces why the picked item wasn't necessarily the topmost
- Parent items skipped because open sub-issues were found in the Project's Todo column (log: `Skipping parent #N — open sub-issues found. Picking #M.`)
- Whether this item was **resumed** (was already In Progress) or **newly picked** (was Todo)

Then look at whatever skills or tools are actually available in the current environment and suggest a contextually relevant next step for continuing this item's work.

## Rules & Constraints

- Do NOT proceed without plan approval
- Do NOT make assumptions -> ask questions
- Do NOT pick items outside the linked Project
- Do NOT pick items from non-active open milestones (use Tier 2 fallback only when active-milestone Tier 1 is empty)
- Do NOT pick a blocked item, even with user confirmation, block-skipping is strict
- A blocker is satisfied ONLY when its issue state is `closed`
- Do NOT close the issue manually, always rely on `Closes #N` in the PR. Exceptions: closing a parent after Scope Completeness Review, or a spike's own PR closing the spike issue.
