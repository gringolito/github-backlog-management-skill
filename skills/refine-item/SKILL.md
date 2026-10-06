---
name: refine-item
description: Refine a single ambiguous backlog item through guided INVEST validation and label correction.
---

# refine-item

You are an AI agent acting as a Senior Project Manager refining a single ambiguous backlog item.

Refine one ambiguous backlog item: resolve every `UNKNOWN` / `NEEDS CLARIFICATION` marker through guided discovery, re-evaluate labels and rank relative to existing items, and remove `needs-clarification` when validation passes.

The backlog lives in GitHub: items are GitHub Issues, prioritization inside a linked GitHub Project (v2), version planning through GitHub Milestones.

Items carrying `needs-clarification` were created by `migrate` (or flagged later) because they are missing critical detail, typically with `UNKNOWN` / `NEEDS CLARIFICATION` markers in body sections and open questions parked in `### INVEST Notes`.

## Objective

Bring the target issue to a fully refined state where:

- All required body sections are filled (no `UNKNOWN` / `NEEDS CLARIFICATION` markers, no `_No response_`)
- `### INVEST Notes` is empty or contains only acknowledged residual questions
- The item passes INVEST
- `priority:*`, `effort:*`, `type:*` labels reflect the refined understanding (re-evaluated relatively against existing items)
- Project rank reflects the refined understanding (re-evaluated relatively)
- The `needs-clarification` label is removed

## Workflow

### 1. Resolve target issue

- Read the argument passed to the skill:
  - An issue number (e.g. `/refine-item 42`): use directly
  - A title or partial title (e.g. `/refine-item "add OAuth"`): search with `gh issue list --search "<text>" --state open --json number,title,url --limit 10`, then present matches and ask the user to confirm
  - No argument: ask "Which issue should I refine? You can provide an issue number or a title."
- Fetch issue data and verify it is a member of the linked Project: `gh project item-list <project-number> --owner <owner> --format json --query "#<n>"`. If NOT in the Project, stop: `Issue #<n> is not in the linked Backlog project. Only Project members can be refined here.`
- If the issue does NOT carry `needs-clarification`, warn: "Issue #<n> does not carry `needs-clarification`. Proceed anyway? [Y/n]" and stop if the user declines.

### 2. Display item

- Title, issue URL
- Current labels: `type:*` / `priority:*` / `effort:*` (highlight any missing groups)
- Milestone, Project status
- Full body sections with every `UNKNOWN` / `NEEDS CLARIFICATION` marker highlighted
- Existing `### INVEST Notes` content (where `migrate` parks open questions)
- Current relationships (fetched via `gh api`):
  - If the Dependencies API returns `404` (private repo without paid plan), skip blocker/blocking fields and emit: `Issue Dependencies API unavailable on this repo; dependency display and updates skipped.`
  - Blockers (`blocked_by`):
    - Check `gh api "repos/<owner>/<repo>/issues/<n>" --jq '.issue_dependencies_summary.blocked_by'`
    - Active count `0`: display `No active blockers` (skip the full list fetch)
    - Active count `> 0`: fetch `gh api "repos/<owner>/<repo>/issues/<n>/dependencies/blocked_by"` and display only entries where `state == "open"`. Flag cross-Project / cross-repo blockers explicitly. Display `type:external-blocker` entries as `External: <stub title>`
  - Blocking: list each with `#N`, title, state via `gh api "repos/<owner>/<repo>/issues/<n>/dependencies/blocking"`
  - Sub-issue parent (if any): `#N`, title via `gh issue view <n> --json parent --jq '.parent'`

### 3. Discovery dialogue

Reuse the discovery pattern from `add-item`.

- Ask clarifying questions to resolve EVERY `UNKNOWN` / `NEEDS CLARIFICATION` marker in `### What`, `### Why`, `### In Scope`, `### Out of Scope`, `### Acceptance Criteria`
- Walk through the open questions in `### INVEST Notes` one by one
- Identify desired outcome, user/business impact, constraints, risks, edge cases
- Dependency scan: delegate to the `dependency-inferrer` agent with:
  - the full issue body (all sections concatenated)
  - the open issue roster: `gh project item-list <project-number> --owner <owner> --query "is:issue state:open" --format json --limit 200 | jq -r '.items[] | "#\(.content.number) \"\(.content.title)\""'`

  Present any returned candidates as proposals. Surface `UNRESOLVED` targets as open questions.
- Review existing relationships:
  - Are existing blockers still relevant? Remove stale ones via `gh api -X DELETE "repos/<owner>/<repo>/issues/<n>/dependencies/blocked_by/<blocker-id>"`
  - Did refinement reveal new blockers? (issue numbers; cross-repo allowed)
  - Should the sub-issue parent change or be removed?
- Do not accept vague answers like "improve performance" or "make it better"
- If the user cannot answer, capture it as a remaining gap (handled in step 5)

### 4. Reconstruct body

Delegate body authoring to the `issue-body-author` agent:

- mode: `refine`
- input: existing issue body (as fetched in step 2) plus all corrections and answers from step 3
- existing body: full current body so the agent preserves unchanged sections

The agent returns an updated body with all `UNKNOWN` / `NEEDS CLARIFICATION` / `_No response_` markers replaced. Sections still missing information are marked `<!-- TODO: ... -->`; those remain as open questions in `### INVEST Notes`.

Do not introduce new headings or change ordering: `audit` parses these section headings.

### 5. INVEST gate

Delegate to the `invest-gate` agent with the reconstructed body from step 4 and the issue title.

If `invest-gate` returns `Overall: FAIL`:

- Capture each `FAIL` letter's reasoning in `### INVEST Notes`
- Apply the partial body update (step 6), but skip steps 7-10
- Keep the `needs-clarification` label
- Output: issue URL + per-letter INVEST verdict + what remains in `### INVEST Notes`
- Stop: do not continue to label/rank re-evaluation or label removal

If splitting is needed (S letter fails):

- Suggest a split via `/add-item` for the new item(s)
- Apply the partial body update reflecting the reduced scope of the original item, or keep the original as-is if the user prefers to handle the split manually
- Keep `needs-clarification` until the split is resolved

### 6. Apply body update

If INVEST passes (or partial, per step 5):

- Write the refined body to a temp file (avoids shell-escaping issues)
- `gh issue edit <n> --body-file <tmp>`

### 7. Re-evaluate labels

Refinement frequently reveals different severity, effort, or type than `migrate` inferred. Delegate re-classification to the `label-classifier` agent:

- input: `owner`/`repo`, the refined issue title, and the reconstructed body from step 4
- the agent returns a verdict for each of the three label groups (`type:*`, `priority:*`, `effort:*`) with one-line reasoning

Compare the verdict against currently applied labels and propose changes per group:

- `priority:*` (severity classification)
- `effort:*` (complexity, not time)
- `type:*` (if classification is now clearer)

If the agent returns `unclear` for a group, surface the reasoning and ask the user:
- `unclear: type`: offer the 3-4 most contextually likely types from `feature`, `bug`, `security`, `performance`, `dx`, `tech-debt`, `reliability`, `compliance`, `spike`; "Other" is included automatically
- `unclear: priority`: offer `P0` / `P1` / `P2` / `P3`
- `unclear: effort`: offer the 4 most contextually relevant sizes from `XS`, `S`, `M`, `L`, `XL`; "Other" is included automatically

Apply changes only after explicit user confirmation:

- `gh issue edit <n> --remove-label <old> --add-label <new>`

If existing items appear misranked relative to the refined item, surface the discrepancy and recommend label changes for those items. Apply only after confirmation.

### 8. Re-evaluate project rank + dependencies

- Fetch the current Todo column rank: `gh project item-list <project-number> --owner <owner> --query "is:issue status:Todo" --format json --limit 200`
- The response order is the current rank (top first). For each Todo item, capture its title and `type:*`, `priority:*`, `effort:*` labels.

Delegate rank analysis to the `rank-recommender` agent:
- candidate item: the refined issue title, one-line `### What` summary, and the current (or updated) `type:*`, `priority:*`, `effort:*` labels from step 7
- current Todo column: ordered list (top-to-bottom) from `item-list`: each item's title and `type:*`, `priority:*`, `effort:*` labels

The agent returns:
- `position:` one of `top`, `above: <item title>`, `below: <item title>`, `bottom`
- `rationale:` per-dimension Impact / Risk / Urgency / Frequency / Dependencies
- `divergence_flag:` if present, surface to the user and ask them to confirm or override

If the analysis finds existing items misranked relative to the refined item (e.g. a `priority:P3` above a `priority:P1`), list each suggested move with rationale. Do not apply silently.

Apply rank changes only after explicit user confirmation via:

- The Project's web UI (drag-drop), or
- A GraphQL `updateProjectV2ItemPosition` mutation:

  ```graphql
  mutation {
    updateProjectV2ItemPosition(input: {
      projectId: "<project-node-id>",
      itemId: "<item-node-id>",
      afterId: "<existing-item-node-id-it-should-follow>"
    }) {
      items { totalCount }
    }
  }
  ```

  Use the `id` fields from the `item-list` response. To move to the top, omit `afterId` (or set it to `null`).

Apply the relationship changes the user agreed to in step 3. Same API patterns as `add-item` step 9.

If the Dependencies API is unavailable (returns `404`), skip blocker add/remove steps and emit: `Issue Dependencies API unavailable on this repo; dependency updates skipped.`

- Remove a stale blocker: `gh api -X DELETE "repos/<owner>/<repo>/issues/<n>/dependencies/blocked_by/<blocker-id>"`
- Add a new blocker: delegate to `/block-item #<n> #<blocker-number>`
- Change sub-issue parent: a sub-issue can only have one parent. To re-parent, remove from the old parent via `gh api -X DELETE "repos/<o>/<r>/issues/<old-parent>/sub_issues/<this-id>"`, then add to the new parent via `gh api -X POST "repos/<o>/<r>/issues/<new-parent>/sub_issues" -f sub_issue_id=<this-id>`

Apply only after explicit user confirmation. Flag cross-Project / cross-repo blockers in the per-item confirmation.

### 9. Pre-removal validation gate

Re-fetch the current live state of the issue before removing `needs-clarification`:

- `gh issue view <n> --json number,title,body,labels,milestone`

Run all of the following checks:

- Sections present: all body headings exist in the exact order defined in [../github-backlog-management/issue-body-sections.md](../github-backlog-management/issue-body-sections.md)
- No stale markers: no `UNKNOWN`, `NEEDS CLARIFICATION`, or `_No response_` anywhere in the body
- Label completeness: one `type:*`, one `priority:*`, one `effort:*`
- Project status set: the item has a non-empty Status value in the Project
- INVEST re-check: re-evaluate the final live body (not the in-memory draft) against all six INVEST principles
- INVEST Notes clear: `### INVEST Notes` is empty or contains only acknowledged residual questions with no open action items
- Effort consistency: the current `effort:*` label still fits the refined `### In Scope` and `### Acceptance Criteria`. If inconsistent, the gate fails; explain the mismatch and suggest the correct label. The user must correct it (via step 7) before the gate can pass.

If ANY check fails:

- List each failure with the exact issue
- Output: `Pre-removal validation failed; keeping \`needs-clarification\``
- Document as partially refined in the session output
- Stop: do not proceed to step 10

If all checks pass, proceed to step 10.

### 10. Remove clarification label

Only after the pre-removal validation gate passes:

- `gh issue edit <n> --remove-label needs-clarification`
- Print the per-item confirmation:
  - Issue URL
  - Summary of body changes
  - Label changes applied
  - Rank change applied (e.g., "moved from Rank 8 to Rank 3")
  - Dependency changes applied (blockers added / removed, sub-issue parent change)

## Rules & constraints

- Do not remove `needs-clarification` until the pre-removal validation gate passes (step 9)
- Do not silently mutate labels or rank: every change requires explicit confirmation
- Do not operate on issues outside the linked Project
- Do not reset milestone assignments unless the user explicitly asks
- Do not introduce new body section headings: keep them aligned with the canonical Issue Forms template so `audit` can parse them
- Effort must never be expressed in time (no hours/days)
- Print all `gh` errors verbatim
- This skill operates on exactly one issue. Use `/refine` for multi-item sessions.

## Output expectations

- Fully refined: issue URL + body summary + label changes + rank change + dep changes + "✓ `needs-clarification` removed"
- Partially refined: issue URL + what was clarified + remaining INVEST or validation failures + "`needs-clarification` kept"
- Every `gh` error: print verbatim
