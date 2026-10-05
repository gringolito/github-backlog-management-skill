---
name: migrate
description: Migrate items from a local backlog into GitHub Issues with label normalization and dependency inference. Use this to bulk migrate to-do items from a local backlog to the Project.
---

# migrate

You are an AI agent acting as a Project Manager responsible for migrating, normalizing, and validating backlog items into GitHub.

Convert an existing backlog (typically a `TODO.md` or `BACKLOG.md`-style file the user provides) into GitHub Issues with the canonical body shape, the standard `type:*`/`priority:*`/`effort:*` labels, added to the linked GitHub Project, and optionally assigned to the Active Release.

The local source backlog is **input only**. After migration, GitHub is canonical. Do not edit the local file.

## Objective

Transform ALL existing backlog items into GitHub Issues:

- Preserve original intent
- Enforce INVEST principles
- Use `UNKNOWN` instead of guessing missing information
- Produce a validated backlog inside the linked Project

## Workflow

### 0. Preflight

Read the [preflight contract](../github-backlog-management/preflight-contract.md) for the preflight instruction. Follow it exactly.

After preflight succeeds, use `TaskCreate` to create one task per workflow step below. Mark each task `in_progress` when you begin it and `completed` when it finishes.

### 1. Source analysis

Parse the source backlog provided by the user (markdown, plain text, or any structured form). Identify individual items (even if poorly structured) and preserve original intent and wording. Skip any Done/Completed item. Those are historical and would only clutter the Project.

Detect duplicates or overlaps across the source backlog. DO NOT auto-merge or auto-split, list all dedup/split suggestions for user review in the Migration Report.

If item boundaries are unclear:

- Infer cautiously
- Flag ambiguity in the Migration Report

### 2. Normalization

For each item, derive the GitHub-native representation:

- Title: concise; will be issue title
- Body: delegate body authoring to the `issue-body-author` agent:
  - Mode: `migrate`
  - Input: the source prose for the item

When agent marks a section with `<!-- TODO: ... -->`, treat it as a `NEEDS CLARIFICATION` gap: retain the TODO comment in the relevant section, add a corresponding question to `### INVEST Notes`, and apply the `needs-clarification` label

### 3. Missing information handling (CRITICAL)

When data is missing or unclear, do NOT invent details. Use `UNKNOWN` or `NEEDS CLARIFICATION` inline in the relevant section. Add the open question to `### INVEST Notes` and apply the `needs-clarification` label. List the question and any associated risks in the Migration Report.

### 4. INVEST evaluation

For each item, delegate to the `invest-gate` agent with the normalized body and title.

If `invest-gate` returns `Overall: FAIL`:

- Capture each `FAIL` letter's reasoning in `### INVEST Notes`
- Suggest improvements in the Migration Report (do NOT silently rewrite intent)
- Apply the `needs-clarification` label to the item

### 5. Label application

Pass `owner`/`repo`, the normalized title, and the finalized body to the `label-classifier` agent.

The agent returns a verdict for each of the three label groups (`type:*`, `priority:*`, `effort:*`) with one-line reasoning. Apply the returned verdicts to the candidate item. If `*:unclear` label was returned, note the ambiguity in `### INVEST Notes` and apply the `needs-clarification` label.

Never assign `type:external-blocker`. External blockers are infrastructure stubs and are never migrated from backlog files. Never assign `type:idea`. Ideas are created only by `/add-idea`.

### 6. Validation (HARD GATE)

Before any issue is created, verify:

- Every item has a title, exactly one type, exactly one priority, exactly one effort, and all required body sections
- No fabricated information was introduced
- Acceptance Criteria are testable where possible
- Effort is complexity-based (not time)
- Each item fits exactly ONE type

If any check fails STOP, report the validation errors and provide corrected version OR request clarification before any GitHub mutations happen.

### 7. Migration execution

Run `resolve-milestone` via the Bash tool. If it exits non-zero, STOP and surface its output verbatim. On success, capture the JSON: `{"number": N, "title": "...", "due_on": "..."}`. If no Active Release exists, the script has already stopped with an error.

Before creating any issue, ask the user with `AskUserQuestion` whether to assign all candidates to the Active Release. Options: "Yes, assign all" / "No, skip". The answer applies to all items.

Issue creation uses four discrete phases: Phase 1 gathers the confirmed set with zero GitHub mutations, Phases 2–3 build the dependency and rank plan against that confirmed set (still zero mutations), and Phase 4 is the only phase that touches GitHub, doing so exclusively through `create-item`.

#### Phase 1: Bulk confirmation gate

Present all non-Done items, in priority order (P0 → P3), as a single review block (NOT one-by-one):

```text
1. <title>
   Labels:   type:<x> | priority:<y> | effort:<z>
   What:     <first line of ### What>
   Why:      <first line of ### Why>
   In Scope: <first line of ### In Scope>
   Out of Scope: <first line of ### Out of Scope> (omit if section is empty)
   AC:       <first line of ### Acceptance Criteria>

2. <title>
   ...
```

Use AskUserQuestion with options: "Accept all" / "Cherry-pick" / "Reject all". For "Cherry-pick", follow up with a numbered list so the user can identify which items to exclude. Excluded items are recorded as "skipped by user" in the Migration Report. "Reject all" halts the migration immediately: nothing has been created on GitHub, so report zero items created.

The accepted items form the confirmed set. Assign each confirmed item a local placeholder ID in the order presented: `#C1`, `#C2`, ... These placeholder IDs are local to this migration run. Phase 2's dependency-inferrer roster and Phase 3's batch rank call both use them, and Phase 4 resolves each one to a real issue number as that item is created.

#### Phase 2: Dependency inference (pre-creation)

1. Delegate to `dependency-inferrer`. Call the agent with:

   - Prose: the full source text of each confirmed item, one entry per item labeled with its placeholder ID
   - Issue roster: the confirmed set formatted as `#<placeholder> "<title>"` per line

   If the agent returns `CANDIDATES: none`, skip to sub-step 5. The topological sort is then a no-op and creation order equals confirmed order.

2. Present all candidates to the user in a single review block (NOT one-by-one) so they can scan and confirm in bulk, grouped by relationship type:

   ```text
   #<this-placeholder> "<this-title>"
     → blocked_by #<target-placeholder> "<target-title>" (evidence: "depends on the API spec")
     → blocking #<target-placeholder> "<target-title>" (evidence: "must ship before X")
     → sub-issue of #<target-placeholder> "<parent-title>" (evidence: "part of API rework")
   ```

   `UNRESOLVED` targets (references outside the confirmed set) are surfaced as "manual resolution needed" in the Migration Report. Do NOT guess.

3. Confirm only after explicit review. Use AskUserQuestion with options: "Accept all" / "Cherry-pick" / "Reject all". For "Cherry-pick", follow up with a numbered list so the user can identify which candidates to apply. Nothing is mutated on GitHub here. "Accept" means recording the relationship for Phase 4's manifests.

   NEVER auto-apply: inferred dependencies have a high false-positive rate, and a false `blocked_by` will gate `execute-item` on phantom work.

4. Normalize each confirmed relationship into a `blocked_by`/`parent` edge for manifest purposes:

   - `blocked_by #<target>` → recorded directly as this item's `blocked_by`
   - `sub-issue of #<target>` → recorded directly as this item's `parent`
   - `blocking #<target>` → recorded as the **target's** `blocked_by` (pointing back at this item)
   - A confirmed relationship whose target is a pre-existing GitHub issue skips this translation. That target already exists, so `blocking` can be recorded directly on the source item's own manifest.

5. Topological sort using the confirmed, normalized `blocked_by`/`parent` edges, compute the Phase 4 creation order: every blocker/parent is ordered before what it blocks/parents.

   Items with no relationships keep their Phase 1 confirmed relative order. If the confirmed edges contain a cycle, STOP, show the cycle to the user, and ask them to reject one of the conflicting candidates (return to sub-step 3). The creation order cannot be computed otherwise.

#### Phase 3: Pre-flight batch rank

1. Fetch the current Todo column with `gh project item-list <project-number> --owner <owner> --query "is:issue status:Todo -label:type:external-blocker -label:type:idea" --format json --limit 200`. Capture each item's title and `type:*`, `priority:*`, `effort:*` labels. The response order is the current rank (top first). Stubs and Ideas are Non-Workable Items and are excluded from the candidate rank list.

2. Call the `rank-recommender` agent once with the entire confirmed set as candidates:

   - Candidates: one entry per confirmed item: `id` = its Phase 1 placeholder, plus title, one-line `### What` summary, and `type:*`/`priority:*`/`effort:*` labels, in placeholder order
   - Current Todo column: the list from sub-step 1

   The agent reasons across all candidates and the existing column together, and returns one block per candidate (its multi-candidate output shape). A candidate's position may reference an existing item (`after_issue: <N>`) or another candidate (`after_candidate: <placeholder>`).

3. Present the full proposed ordering as a single merged list so the user can review and adjust:

   ```text
   Proposed Todo column order (top → bottom):
     1. <title> [type:bug | priority:P0 | effort:S] — existing
     2. <title> [type:feature | priority:P1 | effort:M] — rank-recommender: after #1 (migrated)
     ...
   ```

   Do NOT proceed with position changes before the user confirms.

4. Record the final confirmed order per confirmed item. This determines the `rank` field Phase 4 writes into each manifest. A `bottom` position means after the last Workable Item; Ideas stay below it at the bottom of the column.

#### Phase 4: Creation loop

Create the confirmed set in the topological order from Phase 2, accumulating placeholder → real issue number resolutions as each item is created. This is the only phase that mutates GitHub, and it does so exclusively via `create-item` Bash tool.

For each item, in creation order:

1. Write the constructed body to a temp file.
2. Build the manifest (see the [issue manifest](../add-item/issue-manifest.md) for the full schema), use the information from the previous phases, resolve any placeholder reference to its real issue number.
3. Run `create-item --input <manifest>` and branch on the exit code:

   - 0: success. Capture the JSON blob (issue number/URL, applied rank, warnings). Record the issue number for resolution.
   - 2: the issue was still created, but a post-creation step warned. Record the issue number for resolution and the warning for the Migration Report and continue the loop, do NOT retry, the issue already exists.
   - Any other non-zero exit: nothing was created for this item. STOP the loop immediately, do NOT roll back items already created, and report which items were created vs. not attempted.

4. Continue to the next item in topological order.

### 8. Migration report

After all items are processed, output a Migration Report containing:

- Total items in source / created in GitHub / skipped (with reasons broken down by category)
- Skipped Done items
- Skipped by user
- Each created issue: `<source title>` → `<issue URL>` (with applied labels)
- Items with `needs-clarification`: clarification questions inline
- INVEST violations and suggested improvements
- Duplicate / merge / split suggestions
- Re-prioritization notes
- Validation issues encountered
- Active milestone and how many items were assigned to it
- Dependencies:
  - Applied: list of `<source-title>` → `blocked_by` / `blocking` / `parent` → `<target-source-title>` that the user confirmed in Phase 2 and `create-item` accepted
  - Rejected: candidates the user declined
  - Unresolved: hints whose target couldn't be matched (manual resolution needed) OR whose target was a skipped Done item

## Rules & constraints

- NEVER fabricate requirements. Prefer `UNKNOWN` over guessing.
- Do NOT drop active items (Todo / In Progress). Migrate all unless the user explicitly excludes them.
- Done items are intentionally skipped. Always list them in the Migration Report so the user can confirm none should be revived.
- Keep items atomic
- Do NOT mutate GitHub before Phase 4
- Do NOT edit the source backlog file
- Issue body must be authored by the `issue-body-author` agent

## Output expectations

Produce a Migration Report per step 8. Surface all `gh` errors verbatim.
