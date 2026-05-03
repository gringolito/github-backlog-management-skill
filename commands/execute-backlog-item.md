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

**Pre-filter (MANDATORY):** Before building the candidate lists for either tier, discard any issue whose labels include `type:external-blocker`. External-blocker stubs are infrastructure placeholders — they are never executable work items. Their titles surface in the "skipped because blocked" output when they are open blockers gating a real candidate (see step 2.5).

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

1. **A candidate wins** — proceed to step 2.6 (Sub-issue Check). In the eventual plan output, list every item that was skipped above this one with their open blockers, so the user knows why the queue was deeper than expected. When a blocker carries `type:external-blocker`, show it as `External: <stub title>` rather than a plain issue reference.
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

### 2.6. Sub-issue Check (STRICT)

After block-skipping yields a winning candidate, check whether it has open sub-issues that should be executed first.

1. Fetch sub-issues: `gh issue view <n> --json subIssues`
2. Filter to sub-issues whose state is `open`.
3. Cross-reference against the already-fetched Project item list (from Step 2) to find which open sub-issues are present in the Project with Status = `Todo`.
4. **If one or more open sub-issues are in the Project's Todo column:**
   - Log: `Skipping parent #N — open sub-issues found. Picking #M.`
   - Apply the same block-skipping logic (Step 2.5) to the sub-issues ranked in the Project's Todo column; pick the first unblocked one.
   - If all sub-issues are blocked, report them using the same per-blocker analysis table from Step 2.5 and STOP.
   - The selected sub-issue becomes the new winner and proceeds to Step 3.
5. **If no open sub-issues are in the Project's Todo column** (none exist, all are closed, or none were added to the Project): proceed with the parent normally — it becomes the winner and proceeds to Step 3.

The `gh issue view <n> --json subIssues` endpoint returns `[]` when the issue has no sub-issues; treat this the same as case 5.

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

- If the item carries `type:spike`, apply the **Spike Lifecycle** described in Step 7 (`#### For Spikes`) instead of the standard implementation flow. The plan should reflect the investigation approach and likely shape of the findings document, not a code change.

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

#### For Spikes (`type:spike`)

A spike's deliverable is **knowledge** — a findings document plus the follow-on backlog items it surfaces — not a shippable feature. Apply this flow:

1. **Investigate** the question framed in `### What` / `### Why` within the time-box implied by the `effort:*` label. Prototyping is permitted in throwaway branches but is NOT the deliverable.
2. **Author the findings document** at `docs/spikes/<issue-number>-<slug>.md` with these sections (in this order):
   - `## Question` — restate the spike's investigative question
   - `## Approach` — what was investigated, sources consulted, prototypes built
   - `## Findings` — what was learned, including dead-ends
   - `## Recommendation` — the recommended path forward (or "abandon — see Findings")
   - `## Follow-on Work` — bulleted list of new backlog items this spike surfaces (filled in step 4)
3. **Present the findings summary to the user** for confirmation/edits before the document is finalized. Do NOT proceed until the user signs off on the findings.
4. **Determine parent context**: check whether the spike is itself a sub-issue of a parent. Use `gh api "repos/<owner>/<repo>/issues/<n>/parent"` (returns `404` if the spike has no parent — treat as standalone). Record the parent issue number if present.
5. **Propose follow-on backlog items** for each piece of surfaced work — one per item — with title, What, Why, draft Acceptance Criteria, and suggested `type:*` / `priority:*` / `effort:*` labels. Present the full list to the user and wait for explicit approval per item (some may be discarded).
6. **Create the approved follow-ons** by invoking `/add-backlog-item` for each in sequence:
   - If the spike has NO parent → create as **standalone top-level items** (do NOT pass a parent number; the new items are NOT sub-issues of the spike)
   - If the spike HAS a parent → pass the **spike's parent issue number** so the new items become **peer sub-issues of the spike** (children of the same parent), NOT children of the spike itself
   - Record the resulting issue numbers and update the `## Follow-on Work` section of the findings document with `#<n>` references
7. The spike's PR diff is typically only the findings document. Code changes (if any) belong in the follow-on items, not in the spike's PR.

---

### 8. Validation

- Verify ALL Acceptance Criteria are satisfied
- Run full test suite
- Ensure no regressions

For `type:spike` items, additionally:

- Confirm the findings document exists at `docs/spikes/<issue-number>-<slug>.md` with all required sections
- Confirm every approved follow-on was created and that its issue number is referenced in the `## Follow-on Work` section
- Confirm follow-on parentage matches the rule in Step 7 (standalone if spike had no parent; peer sub-issues of the spike's parent otherwise)

---

### 9. Delivery Workflow

- Commit using Conventional Commits format. Include `Refs #<issue-number>` in the commit body.
- Push the branch.
- Open a Pull Request via `gh pr create`. PR body MUST include:
  - `Closes #<issue-number>` (so GitHub auto-links and auto-closes the issue on merge)
  - A summary of changes mapped to each Acceptance Criterion

For `type:spike` items, the PR is typically a **findings-document-only** diff:

- PR title uses the `spike:` Conventional Commits prefix (matching the `spike/` branch prefix)
- PR body MUST additionally list every follow-on item created (`#<n> — <title>`), so reviewers can audit that the surfaced work landed in the backlog
- It is normal and expected for a spike PR to contain no code changes

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
- Items skipped above this one because they were blocked (with `#N` and the open blockers that gated them; `type:external-blocker` blockers shown as `External: <stub title>`) — surfaces why the picked item wasn't necessarily the topmost
- Parent items skipped because open sub-issues were found in the Project's Todo column (log: `Skipping parent #N — open sub-issues found. Picking #M.`)

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
