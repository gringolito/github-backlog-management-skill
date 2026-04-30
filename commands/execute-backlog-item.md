# execute-backlog-item

You are an AI agent acting as a development lead responsible for executing backlog items.

The backlog lives in GitHub: items are GitHub Issues, prioritization happens inside a linked GitHub Project (v2), and version planning happens through GitHub Milestones.

---

## Objective

Select and execute the highest-priority actionable backlog item, scoped to the active milestone first, then to un-milestoned items as a fallback.

---

## Workflow

### 0. Preflight (MANDATORY)

- Read `.claude/backlog-project.json`. If the file does not exist, STOP and output exactly:
  `No Backlog project linked to <owner>/<repo>. Run /initialize-backlog first.`

---

### 1. Active Milestone Detection

The active milestone is determined as follows:

- `gh api "repos/<owner>/<repo>/milestones?state=open&per_page=100"`
- Primary sort: `due_on` ascending (milestones without a `due_on` are sorted last)
- Tie-break: lowest version, parsed from milestone title (e.g. `v1.2.0` < `v1.3.0`; `2026-Q2` < `2026-Q3`). For non-parseable titles, fall back to milestone `number` ascending (creation order).
- Fallback: if NO open milestone has a `due_on`, the active milestone is the open milestone with the lowest version (same parsing rule). For non-parseable titles, fall back to milestone `number` ascending (creation order).
- Record the active milestone (or note that there are no open milestones at all).

---

### 2. Candidate Selection (PRIORITIZED)

Find the next item to execute by walking these tiers in order. Stop at the first tier that yields candidates.

Execution order is determined by the Project's rank — the topmost item in the `Todo` column wins. The `priority:*` label is severity classification ONLY and does NOT influence ordering.

#### Tier 1 — Active milestone, in Project, status Todo

- Open issues assigned to the active milestone
- Present in the linked Project
- Project Status = `Todo`
- Sorted by Project rank (top of column = next). The order is the position field returned by `gh project item-list <project-number> --owner <owner> --format json` (items appear in rank order in the response).

#### Tier 2 — In Project, no milestone, status Todo

- Open issues with NO milestone assigned
- Present in the linked Project
- Project Status = `Todo`
- Sorted by Project rank, same as Tier 1

#### Tier 3 — None

- If both tiers are empty:
  - Report `No actionable backlog items.`
  - STOP (do NOT pick items outside the Project, do NOT pick items in milestones other than the active one, do NOT pick by `priority:*` label as a fallback)

If the picked item's `priority:*` label appears mismatched against its Project rank (e.g. a `priority:P3` is at the top while a `priority:P0` is below it), proceed anyway with the topmost item but surface the discrepancy in the proposed plan so the user can confirm or reorder.

Use these `gh` calls to gather data:

- Issues: `gh issue list --state open --json number,title,labels,milestone,url --limit 200`
- Project membership and status: `gh project item-list <project-number> --owner <owner> --format json`

---

### 2.5. Block-skipping (STRICT)

Before declaring a winner, walk the rank-ordered candidate list and skip any item that is currently blocked by an open issue. The first unblocked item wins.

For each candidate in rank order (Tier 1 first, then Tier 2):

- Fetch its blockers: `gh api "repos/<owner>/<repo>/issues/<n>/dependencies/blocked_by"`
- For each blocker:
  - If `state == "open"`, the candidate is BLOCKED. Skip it. Record the candidate + its open blockers in a "skipped because blocked" list.
  - If `state == "closed"`, the blocker is satisfied (regardless of how it was closed — merged PR, manual close, transferred, deleted)
  - **Cross-Project / cross-repo blockers are permitted.** If the blocker lives in a different repo, query it via `gh api "repos/<blocker-owner>/<blocker-repo>/issues/<blocker-number>" --jq '.state'`. The blocker URL on the dependency response includes the full repo reference.
- If a candidate has no blockers OR every blocker is closed, it is the winner. Stop walking.

Outcomes:

1. **A candidate wins** — proceed to step 3 (Item Validation). In the eventual plan output, list every item that was skipped above this one with their open blockers, so the user knows why the queue was deeper than expected.
2. **Every candidate is blocked** — STOP. Report:
   - `All actionable items are blocked. Resolve a blocker or re-rank.`
   - Followed by a **per-blocker analysis table** with these columns:

     | Blocked item | Blocker   | Blocker state  | Suggested action |
     |--------------|-----------|----------------|------------------|
     | #N title     | #M title  | open / closed  | see rules below  |

   - **Suggested action rules** (apply the first matching rule):
     - Blocker `closed` + dependency still active → `Stale — clear with: gh api -X DELETE repos/<owner>/<repo>/issues/<n>/dependencies/blocked_by/<m>`
     - Blocker `open`, cross-repo → `External — coordinate with owning team (<blocker-repo>)`
     - Blocker `open`, has assignee → `In Progress — monitor`
     - Blocker `open`, no assignee → `Unassigned — assign or re-plan`
   - Close with a summary line: `N of M blockers may be resolvable without new work` (count stale + in-progress blockers as resolvable)
   - DO NOT pick a blocked item even with user confirmation — re-running `execute-backlog-item` after the user resolves a blocker is the correct loop.

The Issue Dependencies API is GA on public repos and on paid plans for private repos. If the API returns `404` (feature unavailable), treat all items as unblocked and emit a one-time warning: `Issue Dependencies API unavailable on this repo — block-skipping disabled.`

---

### 3. Item Validation (MANDATORY)

Once a candidate is selected, fetch its full body and labels:

- `gh issue view <n> --json number,title,body,labels,milestone,url`

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
- Ask: "Would you like to refine this item now? Run `/refine-backlog-item <n>` to walk through a guided refinement session, then re-run `/execute-backlog-item` when it is ready."

If priority or effort labels are missing or duplicated, STOP and direct the user to run `/validate-backlog`.

---

### 4. Planning

- Propose a concise implementation plan that:
  - Covers ALL Acceptance Criteria (parsed from `### Acceptance Criteria`)
  - Respects defined Scope (`### In Scope` / `### Out of Scope`)
  - Avoids out-of-scope work
  - Research the solution online if needed

- If the item is too large for a single iteration (based on `effort:*`):
  - Draft a split proposal: list each sub-issue with a title, What/Why/Acceptance Criteria, suggested type/priority/effort labels, and how they map to the parent's Acceptance Criteria
  - Present the proposal and wait for explicit approval
  - After approval, invoke `/add-backlog-item` for each sub-issue in sequence, passing the parent issue number so it handles the sub-issue relationship
  - STOP after the sub-issues are created — re-run `/execute-backlog-item` to pick the first sub-issue

- Wait for explicit approval before proceeding

---

### 5. Status → In Progress (BEFORE BRANCH)

Once the plan is approved:

1. Self-assign the issue: `gh issue edit <n> --add-assignee @me`
2. Set the Project Status field to `In Progress`:
   - Resolve field/option IDs: `gh project field-list <project-number> --owner <owner> --format json`
   - Find the item ID via `gh project item-list ... --format json`
   - Update: `gh project item-edit --id <item-id> --project-id <project-id> --field-id <status-field-id> --single-select-option-id <in-progress-option-id>`

This makes the in-flight work visible on the Project board immediately.

---

### 6. Branching

Determine the Conventional Commits prefix from the issue's `type:*` label:

- `type:bug` → `fix/`
- `type:feature` → `feat/`
- `type:performance` → `perf/`
- `type:tech-debt` → `refactor/`
- `type:dx` → `chore/`
- `type:security`, `type:reliability`, `type:compliance` → `fix/` (security/correctness scope)
- `type:spike` → `spike/`

Branch name format: `<prefix><slug>-<issue-number>` (e.g. `fix/null-pointer-in-authn-42`).

---

### 7. Implementation

#### For Bugs

- Write or update tests that reproduce the issue
- Ensure tests FAIL before fixing
- Implement the fix
- Ensure tests PASS after fix

#### For Features / Others

- Implement functionality
- Add tests that validate Acceptance Criteria

---

### 8. Validation

- Verify ALL Acceptance Criteria are satisfied
- Run full test suite
- Ensure no regressions

---

### 9. Delivery Workflow

- Commit using Conventional Commits format. Include `Refs #<issue-number>` in the commit body.
- Push the branch.
- Open a Pull Request via `gh pr create`. PR body MUST include:
  - `Closes #<issue-number>` (so GitHub auto-links and auto-closes the issue on merge)
  - A summary of changes mapped to each Acceptance Criterion

---

### 10. Status & Closure (POST-PR)

GitHub handles the rest automatically:

- Issue closes when the PR is merged (via `Closes #N`)
- The Project's default workflow flips Status from `In Progress` to `Done` when the issue closes
- The merged PR appears as an automatic timeline link on the issue

If the Project's `Issue closed → Status: Done` workflow is disabled, manually update Status:

- `gh project item-edit --id <item-id> --project-id <project-id> --field-id <status-field-id> --single-select-option-id <done-option-id>`

---

### 11. Output

Print:

- Issue URL and number
- PR URL and number
- Branch name
- Assignee (the authenticated user, assigned in step 5)
- Final Project Status (typically `In Progress` until PR merges)
- Whether the issue was assigned to the active milestone
- Items skipped above this one because they were blocked (with `#N` and the open blockers that gated them) — surfaces why the picked item wasn't necessarily the topmost

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
- Never close the issue manually — always rely on `Closes #N` in the PR

---

## Completion Definition

An item is ONLY complete when:

- All Acceptance Criteria are satisfied
- Tests validate the behavior
- PR is opened with `Closes #<n>`
- Project Status reflects current state (`In Progress` while open, `Done` after merge)
