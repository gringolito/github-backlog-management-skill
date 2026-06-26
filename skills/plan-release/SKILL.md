---
name: plan-release
description: Plan a new release by creating a GitHub Milestone with goals, scope, and due date.
argument-hint: The target release version
---

# plan-release

You are an AI agent acting as a Senior Project Manager responsible for planning the next release.

Your goal is to inspect the current set of GitHub Releases and Milestones, select the scope of the next release, infer the appropriate version from that scope, and create a GitHub Milestone that represents the release — with backlog items assigned to it. When invoked with an existing open milestone as argument, you instead enter re-planning mode to adjust that milestone's scope.

A GitHub Milestone is the unit of version planning for this skill — backlog items (Issues) are assigned to a milestone to declare which release they belong to.

## Objective

Either:

- **Creation mode** (no argument, or argument that doesn't match an open milestone): Create a GitHub Milestone for the next release, with a release mode chosen by the user (Maintenance / Regular / Automated), a scope of backlog items, a coherent version name, a due date, a description, and all scoped items assigned.
- **Re-planning mode** (argument matches an existing open milestone): Interactively adjust the scope of that milestone — add unassigned backlog items and remove currently assigned items with explicit disposition choices.

## Workflow

### 0. Preflight (MANDATORY)

Read [../github-backlog-management/preflight-contract.md](../github-backlog-management/preflight-contract.md) for the preflight instruction; follow it exactly.

After preflight succeeds, use `TaskCreate` to create one task per workflow step below. Mark each task `in_progress` when you begin it and `completed` when it finishes.

### 1. Argument Detection (MANDATORY)

Check whether the skill was invoked with an argument (a milestone identifier: title substring or version string).

- **No argument** — proceed to Step 2 (creation mode).
- **Argument provided** — run `resolve-milestone "<argument>"` via the Bash tool:
  - **Exit 0 (match found)** — re-planning mode: read [re-planning.md](./re-planning.md).
  - **Exit non-zero (no match)** — ask: "No open milestone found matching `<argument>`. Would you like to plan a new release instead?"
    - If yes: proceed to Step 2 (creation mode), carrying the argument as a suggested version name for Step 6.
    - If no: STOP.

### 2. Existing Releases & Milestones Inventory

Inspect what already exists so the new milestone integrates with the existing scheme:

- List published GitHub Releases:
  - `gh release list --limit 50`
- List milestones (open and closed):
  - `gh api "repos/<owner>/<repo>/milestones?state=all&per_page=100"`

Present the user with:

- Released versions (from `gh release list`)
- Open milestones with their `due_on`, open/closed issue counts
- Closed milestones (most recent 5) for naming-pattern reference
- Detected naming scheme (semver / calendar / custom / unknown) — inferred from milestone titles and release tags

If multiple schemes are mixed (e.g. some `v1.x`, some `2026-Qx`):

- STOP
- Ask the user to clarify which scheme should be used going forward

### 3. Release Mode Selection

Use `AskUserQuestion` to ask the user which release mode to use:

- **Maintenance release**: scope is defined by the user (explicit list of issues). Targets any `major.minor` release — including the latest — when only bug fixes, security patches, or small corrections are intended. Version will be a patch on that release.
- **Regular release**: fetch all unassigned backlog items and let the user select the scope interactively.
- **Automated release planning**: fetch all unassigned backlog items, analyze them as an experienced Project Manager (priority, theme, dependencies), and propose a coherent release scope with rationale. User confirms or adjusts.

### 4. Scope Definition

#### Mode A — Maintenance

- Ask the user for: the target `major.minor` release (e.g. `1.5`) and optionally a list of issues to include (by number or title fragment).
- If the user provides no issue list, fetch unassigned candidates with `type:bug` or `type:security` labels and present them for selection:
  - Gather data via `gh project item-list <project-number> --owner <owner> --query "is:issue status:Todo no:milestone label:type:bug,type:security" --format json --limit 200`
  - Present the filtered table for the user to select from
- For each item the user provided by title (not number), search for a match:
  - `gh issue list --state open --search "<title fragment>" --json number,title,labels,url --limit 10`
  - If multiple matches are found, present them and ask the user to confirm which issue(s) to use. Do NOT auto-select.
- Validate each resolved issue exists and is open:
  - `gh issue view <n> --json number,title,state,labels,milestone`
  - If an issue is closed or not found, surface the error and ask the user to correct the list.
  - If any validated issue carries `type:external-blocker`, warn the user: "Issue #N is an external-blocker stub, not a Workable Item. Stubs should not appear in release scope." Exclude the item unless the user explicitly overrides with a justification.
- Display the confirmed issue list (number, title, type label, priority label, effort label) and ask for review.
- Scan the scope for items that carry `type:feature` or any explicit breaking-change signal in `### What` / `### INVEST Notes` (read body via `gh issue view <n> --json body`). For each such item, WARN the user:
  > ⚠️ Issue #N "`<title>`" introduces new functionality / a breaking change, which is atypical for a maintenance release.

  Require explicit confirmation before including the item in the scope.

#### Mode B — Regular

- Fetch unassigned candidates via `gh project item-list <project-number> --owner <owner> --query "is:issue status:Todo no:milestone -label:type:external-blocker" --format json --limit 200`
- Present the candidate table in Project rank order:

  ```text
  Rank | #  | Title | Type | Priority | Effort
  ```

- Ask the user to select items to include (accept all, or provide a list of issue numbers to include/exclude).
- Display the confirmed scope and ask for final review before proceeding.

#### Mode C — Automated

- Fetch the same unassigned candidate set as Mode B (same `type:external-blocker` exclusion applies).
- For each candidate, check blockers:
  - `gh api "repos/<owner>/<repo>/issues/<n>/dependencies/blocked_by"` — collect open blockers. If the API returns `404`, treat all items as unblocked and note the unavailability.
  - Classify each blocked item:
    - **Resolvable within scope**: all open blockers are themselves in the candidate pool — the item CAN be included, but its blocker(s) MUST also be included and ranked above it.
    - **Externally blocked**: at least one open blocker is outside the candidate pool (closed issue, different repo, or untracked) — exclude from the suggestion and note as "externally blocked". If the blocking issue carries `type:external-blocker`, show the stub's title as the blocking reason (e.g. `blocked by external constraint: Vendor API rate limit freeze`).
- Analyze and group candidates by theme and cohesion:
  - Prefer P0/P1 items
  - Group by item type (e.g., a bug-fix release: `type:bug` + `type:security`; a feature release: `type:feature`)
  - Respect effort — aim for a balanced, deliverable scope
  - When including a resolvable-within-scope item, pull its blocker(s) into the suggestion automatically and note the dependency chain
- Present the suggested scope with rationale (why each item was included, overall release theme, dependency chains pulled in, items excluded due to external blockers).
- Let the user confirm, remove items, or add items from the remaining pool (adding an externally-blocked item requires explicit user confirmation).

### 5. Version Inference

After scope is confirmed, infer the appropriate version. Do NOT propose a version before this step.

#### For semver projects

Scan the confirmed scope's item types and body signals:

- If any scoped item signals a **breaking change** (API incompatibility explicitly stated in `### What` or `### INVEST Notes`, or the user flags it) → **major** bump.
- Else if any scoped item has `type:feature` → **minor** bump.
- Else (scope contains only `type:bug`, `type:security`, `type:reliability`, `type:performance`, `type:dx`, `type:tech-debt`, `type:compliance`, or `type:spike`) → **patch** bump.
- For Mode A (maintenance): always a **patch** on the target `major.minor` release regardless of item types. Proposed patch must be strictly greater than the latest released patch (if no prior patch on that release exists, propose `patch = 1`).

Present the inferred bump type with rationale (e.g. "Minor bump — scope contains 2 `type:feature` items: #12, #17") and ask for confirmation before computing the final version string.

#### For calendar / custom schemes

Follow the existing naming pattern (next period, continuation of observed naming) — scope content does not drive version naming for non-semver schemes.

### 6. Version Proposal & Confirmation

- Compute the concrete version string from the inferred bump and existing release/milestone history.
- Validate the proposed name based on release type:
  - **Standard release** (`major.minor` ≥ latest): proposed version must be strictly greater than the latest released version overall.
  - **Maintenance release** (patch on a specific `major.minor` release): proposed patch must be strictly greater than the latest released patch on that release series.
  - When the proposed version's `major.minor` is less than the latest released `major.minor`, confirm with the user that this is intentional maintenance/backport work before proceeding.
- If an open milestone with the same proposed name already exists, STOP and ask whether to:
  - Use the existing milestone (no creation needed)
  - Pick a different name
  - Close the existing one and create a new one

Wait for explicit user confirmation of the version name before proceeding.

### 7. Milestone Metadata

Collect from the user (with sensible defaults):

- **Title** — confirmed in step 6
- **Due date** (`due_on`) — Used by `execute-item` to determine the Active Release (earliest `due_on` wins). Format: `YYYY-MM-DDTHH:MM:SSZ`.
- **Description** — if the user does not provide one, generate a suggested description from the confirmed scope:
  - Summarize the release theme (e.g. "Bug-fix and security hardening release", "Feature release: …", "Maintenance patch for v1.5.x")
  - List the top goals derived from the scoped items' `### Why` sections
  - Note any notable dependency chains or constraints surfaced during scope definition
  - Present the suggested description to the user and ask for confirmation or edits before proceeding. Do NOT create the milestone until the description is approved (or explicitly waived).

### 8. Milestone Creation

Create the milestone via the GitHub API:

- `gh api -X POST "repos/<owner>/<repo>/milestones" -f title=<title> -f due_on=<due_on> -f description=<description>`
- Capture the returned `number` and `html_url`

### 9. Issue Assignment

Assign every item in the confirmed scope to the new milestone:

- For each scoped issue: `gh issue edit <n> --milestone "<milestone-title>"`
- Surface any `gh` errors verbatim; do not silently skip failures.

#### Forward-port prompt (Mode A only)

After all issues are assigned, ask:

> These issues are targeted at the `<major.minor>` maintenance branch. Should corresponding issues be opened for mainstream development (forward-porting)?

- **If yes**: for each assigned issue, create a forward-port clone:
  - Title: `[Forward-port] <original title>`
  - Body: `Forward-port of #<n> — verify this change is needed in mainstream / adapt as appropriate.`
  - Add the clone to the Project with Status=`Todo` and no milestone assigned.
- **If no**: skip — the scoped issues remain assigned to the maintenance milestone only.

### 10. Output Summary

Print:

- Milestone title, number, `html_url`, `due_on`
- Release mode used (Maintenance / Regular / Automated)
- Scoped items: `#number — title — effort` with milestone assignment confirmed
- **Milestone size estimate**: tally effort labels using Fibonacci weights (XS=1 / S=2 / M=3 / L=5 / XL=8). Report total points and qualitative band:
  - ≤8 pts → Small
  - 9–20 pts → Medium
  - 21–40 pts → Large
  - >40 pts → Very Large
  - Items with no effort label counted as M=3, with a note.
- Version bump rationale (semver only: bump type and triggering items)
- Active milestone: run `resolve-milestone` (no-arg) after creation and indicate whether the newly created milestone is now the Active Release (i.e. whether its `number` matches the script's `number` output)
- For Mode A: forward-port clones created (list of new issue URLs), or "Forward-porting skipped"
- Pointer to next steps:
  - "Run `/add-item` to add more items to this milestone"
  - "Run `/execute-item` to start working on this milestone"
