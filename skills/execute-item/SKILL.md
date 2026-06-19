---
name: execute-item
description: Pick and execute the topmost unblocked Workable Item from the Queue.
---

# execute-item

You are an AI agent acting as a development lead responsible for executing backlog items.

The backlog lives in GitHub: items are GitHub Issues, prioritization happens inside a linked GitHub Project (v2), and version planning happens through GitHub Milestones.

---

## Objective

Select and execute the topmost actionable Workable Item, scoped to the Active Release first, then to un-milestoned items as a fallback.

---

## Workflow

### 0. Preflight (MANDATORY)

Run `backlog-preflight` via the Bash tool. If it exits non-zero, STOP and surface its output verbatim. On success, capture the JSON it prints to stdout — this is the metadata used throughout the workflow (owner, repo, projectNumber, projectId, statusFieldId, statusOptions).

---

### 1. Item Selection (MANDATORY)

Run `pick-item` via the Bash tool. If it exits non-zero, STOP and surface its stderr verbatim.

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

**If `candidate` is null:** Surface `message`. If `skipped_blocked` is non-empty, render the per-blocker analysis table (see Step 2.5) using the facts already in the JSON — no extra API calls needed. Then STOP.

**If `in_progress` is non-empty:** Display each item:

| # | Title | Milestone | Labels | PR Status |
|---|-------|-----------|--------|-----------|
| #N | ... | v0.x.x | type:... | ✅ PR #M open (waiting review) |
| #N | ... | — | type:... | 🔧 No PR yet (work in progress) |

Then use AskUserQuestion with options built dynamically: one option per in-progress item (title + PR status, e.g. "fix/auth-bug — PR #42 open" or "feat/dashboard — no PR yet") plus a final "Pick a new item" option.
- **In-progress item chosen:** that item becomes the winner. Skip Steps 3, 4, 6, and 7. Advise the user to check out the existing branch (`<type>/<slug>`). If a linked PR exists, skip Step 10 as well. Proceed to Step 5.
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

---

### 2. Per-Blocker Analysis Table

Rendered when all candidates are blocked (`candidate` null, `skipped_blocked` non-empty). All facts come from the script output — no extra API calls needed.

- Report: `All actionable items are blocked. Resolve a blocker or re-rank.`
- Render:

  | Blocked item | Blocker | Blocker state | Suggested action |
  |---|---|---|---|
  | #N title | #M title | open / closed | see rules below |

- **Suggested action rules** (apply first match; use `cross_repo`, `assignees`, `labels` from `skipped_blocked[].open_blockers`):
  - Blocker `closed` + dependency still active → `Stale — clear with: gh api -X DELETE repos/<owner>/<repo>/issues/<n>/dependencies/blocked_by/<m>`
  - Blocker `open`, `cross_repo: true` → `External — coordinate with owning team`
  - Blocker `open`, `assignees` non-empty → `In Progress — monitor`
  - Blocker `open`, `assignees` empty → `Unassigned — assign or re-plan`
  - Blockers with `"type:external-blocker"` in labels: show as `External: <stub title>`.
- Close with: `N of M blockers may be resolvable without new work` (stale + in-progress count as resolvable).
- DO NOT pick a blocked item even with user confirmation — re-run `/execute-item` after resolving a blocker.

---

### 3. Sub-issue Scope Check

Use `candidate.sub_issues_summary` from the script output — no API call needed.

- **If `completed == total AND total > 0`:** All sub-issues are closed. Enter **Scope Completeness Review** below.
- **Otherwise:** proceed to Step 3.

Note: Open sub-issue routing is already handled by `pick-item` — if the script selected a sub-issue as `candidate`, no further parent/sub-issue traversal is needed here.

#### Scope Completeness Review

Entered when `candidate.sub_issues_summary.completed == total AND total > 0`.

1. Extract `### In Scope` and `### Acceptance Criteria` from `candidate.body` — no `gh issue view` call needed.

2. Fetch each closed sub-issue body:
   - Use the sub-issue list from the API call above for their numbers.
   - For each: `gh issue view <m> --json number,title,body`

3. Perform coverage analysis:
   - For each criterion in `### Acceptance Criteria`, determine which closed sub-issue (if any) addressed it, based on sub-issue titles and bodies.
   - Format as a checklist:

     ```
     **Coverage analysis — #N: <parent title>**

     Acceptance Criteria:
     - [x] AC1: <text> → covered by #M (<sub-issue title>)
     - [x] AC2: <text> → covered by #P (<sub-issue title>)
     - [ ] AC3: <text> → not addressed by any closed sub-issue
     ```

4. Present the coverage checklist to the user. Then use AskUserQuestion with two options:
   - **"Close parent — scope complete"**
   - **"Create sub-issues for uncovered gaps"**

5. **If "Close parent — scope complete":**
   - Post a comment with the full coverage checklist: `gh issue comment <n> --body "..."`
   - Close the issue: `gh issue close <n>`
   - STOP — do not proceed to Step 4.

6. **If "Create sub-issues for gaps":**
   - For each uncovered criterion (marked `[ ]` in the checklist), invoke `/add-item` with the parent issue number so the new items become sub-issues.
   - STOP after sub-issues are created — re-run `/execute-item` to pick the first one.

---

### 4. Item Validation (MANDATORY)

Use `candidate.body` and `candidate.labels` from the `pick-item` output — no `gh issue view` call needed.

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
- Ask: "Would you like to refine this item now? Run `/refine-item <n>` to walk through a guided refinement session, then re-run `/execute-item` when it is ready."

If priority or effort labels are missing or duplicated, STOP and direct the user to run `/audit`.

---

### 5. Planning

#### 5.1. Parent Context (RELATIVE)

Use `candidate.parent` from the `pick-item` output — no additional API call needed.

1. **If `candidate.parent` is `null`** → proceed silently. No warning, no block.
2. **If `candidate.parent` is present:**
   - Extract `### What` and `### Why` sections from `candidate.parent.body` (matched by exact heading text).
   - Emit the following block **before** the implementation plan:

     ```
     **Parent context — #N: <parent title>**
     > **What:** <text from ### What>
     > **Why:** <text from ### Why>
     ```

   - If one section is absent, show the available one and omit the missing line.
   - If neither section exists, emit `(Parent body does not follow standard template — no What/Why sections found)` and proceed.
3. Continue to the implementation plan below.

- Propose a concise implementation plan that:
  - Covers ALL Acceptance Criteria (parsed from `### Acceptance Criteria`)
  - Respects defined Scope (`### In Scope` / `### Out of Scope`)
  - Avoids out-of-scope work
  - Research the solution online if needed

- If the item carries `type:spike`, apply the **Spike Lifecycle** described in Step 7 (`#### For Spikes`) instead of the standard implementation flow. The plan should reflect the investigation approach and likely shape of the findings document, not a code change.

- If the item is too large for a single iteration (based on `effort:*`):
  - Draft a split proposal: list each sub-issue with a title, What/Why/Acceptance Criteria, suggested type/priority/effort labels, and how they map to the parent's Acceptance Criteria
  - Present the proposal and wait for explicit approval
  - After approval, invoke `/add-item` for each sub-issue in sequence, passing the parent issue number so it handles the sub-issue relationship
  - STOP after the sub-issues are created — re-run `/execute-item` to pick the first sub-issue

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

---

### 6. Status → In Progress (BEFORE BRANCH)

Once the plan is approved:

1. Self-assign the issue: `gh issue edit <n> --add-assignee @me`
2. Set the Project Status field to `In Progress`:
   - Resolve field/option IDs: `gh project field-list <project-number> --owner <owner> --format json`
   - Find the item ID via `gh project item-list <project-number> --owner <owner> --format json --query "#<n>"`
   - Update: `gh project item-edit --id <item-id> --project-id <project-id> --field-id <status-field-id> --single-select-option-id <in-progress-option-id>`

This makes the in-flight work visible on the Project board immediately.

---

### 7. Branching

Determine the Conventional Commits prefix from the issue's `type:*` label:

- `type:bug` → `fix/`
- `type:feature` → `feat/`
- `type:performance` → `perf/`
- `type:tech-debt` → `refactor/`
- `type:dx` → `chore/`
- `type:security`, `type:reliability`, `type:compliance` → `fix/` (security/correctness scope)
- `type:spike` → `spike/`

Branch name format: `<prefix>/<slug>` (e.g. `fix/null-pointer-in-authn`).

---

### 8. Implementation

#### For Bugs

- Write or update tests that reproduce the issue
- Ensure tests FAIL before fixing
- Implement the fix
- Ensure tests PASS after fix

#### For Features / Others

- Implement functionality
- Add tests that validate Acceptance Criteria

#### For Spikes (`type:spike`)

A spike's deliverable is **knowledge** — a findings document plus the follow-on backlog items it surfaces — not a shippable feature. Apply this flow:

1. **Investigate** the question framed in `### What` / `### Why` within the time-box implied by the `effort:*` label. Prototyping is permitted in throwaway branches but is NOT the deliverable.
2. **Author the findings document** at `docs/spikes/####-<slug>.md`, use sequential numbering (e.g. `0001-slug.md`, `0002-slug.md`, etc.), with these sections (in this order):
   - `## Question` — restate the spike's investigative question
   - `## Approach` — what was investigated, sources consulted, prototypes built
   - `## Findings` — what was learned, including dead-ends
   - `## Recommendation` — the recommended path forward (or "abandon — see Findings")
   - `## Follow-on Work` — bulleted list of new backlog items this spike surfaces (filled in step 4)
3. **Present the findings summary to the user** for confirmation/edits before the document is finalized. Do NOT proceed until the user signs off on the findings.
4. **Determine parent context**: check whether the spike is itself a sub-issue of a parent. Use `gh api "repos/<owner>/<repo>/issues/<n>/parent"` (returns `404` if the spike has no parent — treat as standalone). Record the parent issue number if present.
5. **Propose follow-on backlog items** for each piece of surfaced work — one per item — with title, What, Why, draft Acceptance Criteria, and suggested `type:*` / `priority:*` / `effort:*` labels. Present the full list to the user and wait for explicit approval per item (some may be discarded).
6. **Create the approved follow-ons** by invoking `/add-item` for each in sequence:
   - If the spike has NO parent → create as **standalone top-level items** (do NOT pass a parent number; the new items are NOT sub-issues of the spike)
   - If the spike HAS a parent → pass the **spike's parent issue number** so the new items become **peer sub-issues of the spike** (children of the same parent), NOT children of the spike itself
   - Record the resulting issue numbers and update the `## Follow-on Work` section of the findings document with `#<n>` references
7. The spike's PR diff is typically only the findings document. Code changes (if any) belong in the follow-on items, not in the spike's PR.

---

### 9. Validation

- Verify ALL Acceptance Criteria are satisfied
- Run full test suite
- Ensure no regressions

For `type:spike` items, additionally:

- Confirm the findings document exists at `docs/spikes/<number>-<slug>.md` with all required sections
- Confirm every approved follow-on was created and that its issue number is referenced in the `## Follow-on Work` section
- Confirm follow-on parentage matches the rule in Step 8 (standalone if spike had no parent; peer sub-issues of the spike's parent otherwise)

---

### 10. Delivery Workflow

- Commit using Conventional Commits format. Include `Refs #<issue-number>` in the commit body.
- Push the branch.
- Open a Pull Request via `gh pr create`, passing `--milestone "<milestone-title>"` when the issue has one (from the Step 3 fetch; omit for un-milestoned items). PR body MUST include:
  - `Closes #<issue-number>` (so GitHub auto-links and auto-closes the issue on merge)
  - A summary of changes mapped to each Acceptance Criterion

For `type:spike` items, the PR is typically a **findings-document-only** diff:

- PR title uses the `spike:` Conventional Commits prefix (matching the `spike/` branch prefix)
- PR body MUST additionally list every follow-on item created (`#<new-issue-number> — <title>`), so reviewers can audit that the surfaced work landed in the backlog
- It is normal and expected for a spike PR to contain no code changes

---

### 11. Status & Closure (POST-PR)

GitHub handles the rest automatically:

- Issue closes when the PR is merged (via `Closes #N`)
- The Project's default workflow flips Status from `In Progress` to `Done` when the issue closes
- The merged PR appears as an automatic timeline link on the issue

If the Project's `Issue closed → Status: Done` workflow is disabled, manually update Status:

- `gh project item-edit --id <item-id> --project-id <project-id> --field-id <status-field-id> --single-select-option-id <done-option-id>`

---

### 12. Output

Print:

- Issue URL and number
- PR URL and number
- Branch name
- Assignee (the authenticated user, assigned in step 6)
- Final Project Status (typically `In Progress` until PR merges)
- Whether the issue was assigned to the Active Release
- Items skipped above this one because they were blocked (with `#N` and the open blockers that gated them; `type:external-blocker` blockers shown as `External: <stub title>`) — surfaces why the picked item wasn't necessarily the topmost
- Parent items skipped because open sub-issues were found in the Project's Todo column (log: `Skipping parent #N — open sub-issues found. Picking #M.`)
- Whether this item was **resumed** (was already In Progress) or **newly picked** (was Todo)

---

## Rules & Constraints

- Do NOT proceed without plan approval
- Do NOT exceed defined Scope
- Do NOT ignore Acceptance Criteria
- Do NOT make assumptions -> ask questions
- Keep changes minimal and focused
- Do NOT pick items outside the linked Project
- Do NOT pick items from non-active open milestones (use Tier 2 fallback only when active-milestone Tier 1 is empty)
- Do NOT pick a blocked item, even with user confirmation — block-skipping is strict
- A blocker is satisfied ONLY when its issue state is `closed`; the manner of closure (merge / manual / transfer / delete) is irrelevant
- Never close the issue manually — always rely on `Closes #N` in the PR. Exception: closing a parent after Scope Completeness Review is an organisational closure (`gh issue close <n>` is correct there — no PR is involved).

---

## Completion Definition

An item is ONLY complete when:

- All Acceptance Criteria are satisfied
- Tests validate the behavior
- PR is opened with `Closes #<n>`
- Project Status reflects current state (`In Progress` while open, `Done` after merge)
