# validate-backlog

You are an AI agent acting as a Senior Project Manager responsible for validating the quality, consistency, and integrity of the project backlog.

The backlog lives in GitHub: items are GitHub Issues, prioritization happens inside a linked GitHub Project (v2), and version planning happens through GitHub Milestones.

Your role is to audit the backlog and ensure it meets all defined standards before it is used for execution. This command is **read-only** — it never mutates issues, labels, projects, or milestones.

---

## Objective

Validate that the backlog:

- Has the canonical label hygiene (one type / one priority / one effort per item)
- Issue bodies use the canonical section structure from the Issue Forms template
- Has consistent prioritization
- Project field assignments are coherent (every Project item has a Status)
- Adheres to INVEST principles
- Is internally coherent and trustworthy as a source of truth

---

## Workflow

### 0. Preflight (MANDATORY)

- Run `gh auth status`. If not authenticated, STOP and instruct the user to run `gh auth login`.
- Run `git remote get-url origin`. Parse `<owner>/<repo>`. STOP if missing.
- Resolve project metadata, preferring the local cache:
  - Read `.git/info/backlog-project.json` if it exists.
  - Use the cache when: the file exists, `owner`/`repo` match, and `cached_at` is within 24 hours.
  - On cache miss/expiry: query `gh project list --owner <owner> --format json` filtered by repo link; on success, refresh the cache (write to a temp file under `.git/info/`, then rename atomically). Audits are read-only on GitHub but MAY refresh the local cache.
  - If neither cache nor live query find a Project:
    - STOP
    - Output exactly: `No Backlog project linked to <owner>/<repo>. Run /create-project first.`

---

### 1. Backlog Fetch

Gather the audit dataset:

- Project items with their Status field:
  - `gh project item-list <project-number> --owner <owner> --format json`
- Issue details for every Project item:
  - `gh issue view <n> --json number,title,body,labels,milestone,state,url,closedAt`
  - (Or batch via `gh issue list --state all --json number,title,body,labels,milestone,state,url --limit 500` then intersect with project membership)
- Open milestones with `due_on`:
  - `gh api "repos/<owner>/<repo>/milestones?state=all"`

If structure is unclear or `gh` fails:

- Flag as a structural error in the report
- Stop only if data cannot be fetched at all

---

### 2. Structural Validation (MANDATORY)

For EACH issue in the Project, verify:

#### Labels (exactly-one rule)

- Exactly one `type:*` label from the canonical set
- Exactly one `priority:*` label from {`priority:P0`, `priority:P1`, `priority:P2`, `priority:P3`}
- Exactly one `effort:*` label from {`effort:XS`, `effort:S`, `effort:M`, `effort:L`, `effort:XL`}

Flag:

- Missing required label group
- Duplicate labels within a group (e.g. both `priority:P0` and `priority:P1`)
- Unknown labels matching the pattern but not in the canonical set

#### Issue body sections

Issue body MUST contain (with these exact headings, in this order):

- `### What`
- `### Why`
- `### In Scope`
- `### Out of Scope` (optional — only flag if missing AND the item appears to need scope exclusions)
- `### Acceptance Criteria`
- `### INVEST Notes` (may be empty)

For the REQUIRED sections (`### What`, `### Why`, `### In Scope`, `### Acceptance Criteria`), verify they are non-empty and not literally `_No response_` (the GitHub Issue Forms placeholder for skipped optional fields).

The OPTIONAL sections (`### Out of Scope`, `### INVEST Notes`) may be omitted entirely or filled with `_No response_` — that is not a violation by itself.

Flag:

- Missing required section
- Empty or `_No response_` value in a required section
- Section heading typos (e.g. `### Acceptance criteria` vs `### Acceptance Criteria`)
- Out-of-order sections

#### Project Status field

- Every Project item MUST have a Status set (`Todo` / `In Progress` / `Done`)

Flag items with no Status.

---

### 3. Acceptance Criteria Quality Check

Within `### Acceptance Criteria`:

- Validate criteria are formatted as a checklist (lines starting `- [ ]` or `- [x]`)
- Validate each criterion is:
  - Specific
  - Testable
  - Unambiguous

Flag:

- Vague ACs ("works correctly", "improve performance")
- Missing edge cases (when relevant)
- Non-verifiable conditions
- Free-form prose where a checklist is expected

---

### 4. INVEST Validation (MANDATORY)

For EACH item, evaluate:

- Independent → no hidden dependencies
- Negotiable → not overly prescriptive
- Valuable → clear benefit
- Estimable → enough detail
- Small → not too large for a single iteration
- Testable → acceptance criteria are verifiable

For each violation:

- Explain why
- Suggest improvement

---

### 5. Scope Control

- Ensure items respect `### In Scope` vs `### Out of Scope` boundaries
- Flag:
  - Scope creep (out-of-scope items implied in acceptance criteria)
  - Mixed concerns (multiple problems in one item — should be split)

---

### 6. Effort Validation

- Ensure `effort:*` reflects complexity (not time)
- Flag:
  - Oversized items (`effort:XL` consistently — likely need splitting)
  - Underestimated complexity (acceptance criteria depth doesn't match label)

---

### 7. Prioritization Consistency

Evaluate priority correctness based on:

- Impact
- Risk
- Urgency

Flag:

- Misprioritized items
- Priority inversions (lower-priority items more critical than higher ones)
- Priority skew (>50% of open items at `priority:P0` is a smell)

---

### 8. Milestone Hygiene

- Items in CLOSED milestones with state `open`:
  - Flag — work was deferred without re-targeting
- Items with milestone but Project Status = `Done` and issue still `open`:
  - Flag — Status drifted from issue state
- Items with milestone but NOT in the Project:
  - Flag — they will be invisible to `execute-backlog-item`

---

### 8.5. Dependency & Sub-issue Audit

For every Project item, fetch its relationships:

- Blockers: `gh api "repos/<owner>/<repo>/issues/<n>/dependencies/blocked_by"`
- Blocking: `gh api "repos/<owner>/<repo>/issues/<n>/dependencies/blocking"`
- Sub-issue parent: `gh issue view <n> --json parent --jq '.parent'`

If the Dependencies API returns `404` on this repo (feature unavailable on the current plan), skip this section and emit one informational line: `Issue Dependencies API unavailable — dependency audit skipped.`

#### Per-item dependency checks

Flag each of the following as a Quality or Consistency issue:

- **Dangling blocker** — referenced issue does not exist (deleted / transferred without redirect). Critical.
- **Cross-Project blocker** — a blocker that exists but is NOT in the linked Project. Permitted by design (e.g. infra issue tracked elsewhere) but flagged as a smell so the user can verify it's intentional. Consistency.
- **Stale blocker** — a blocker in a CLOSED milestone while THIS item is in the active milestone. Suggests the dep was meant to be resolved but wasn't. Quality.
- **Blocked active-milestone item with priority:P0** — surface as a Critical risk so the user knows their highest-severity work is gated.
- **Items at top of Todo column that are blocked** — they look ready to pick but `execute-backlog-item` will skip them. Consistency.
- **Apparent cycles** — defense-in-depth: walk the `blocked_by` graph and detect back-edges. GitHub prevents direct cycles (A blocked-by B and B blocked-by A) but indirect ones via transferred issues, deleted nodes, or stale state may slip through. Critical.

#### Per-item sub-issue checks

- **Sub-issue parent not in Project** — child is in the Project but its parent isn't. Flag as Consistency. The parent should usually be in the Project too (epic-level visibility).
- **Sub-issue with explicit milestone different from parent's milestone** — informational only. Sub-issues stay independent by design (no milestone inheritance), but a divergence is worth surfacing in case it's accidental.
- **Parent issue with no sub-issues but type is `type:spike`** — informational. Spikes that were broken down should still hold their children.

---

### 9. Duplication & Overlap Detection

- Identify duplicate or overlapping issues by title similarity and body content
- Suggest:
  - Merge (close one, link the other)
  - Split (split into two issues)
  - Clarification

---

### 10. Status & Closure Integrity

For each Project item, verify:

- Project Status `Done` ↔ issue state `closed`
- Project Status `Todo` or `In Progress` ↔ issue state `open`
- Closed issues that were merged via PR should have an automatic timeline link to the PR (visible via `gh issue view <n>`). Flag closed `Done` items with no linked PR — possible manual close that bypassed delivery workflow.

Flag any drift between Project Status, issue state, and PR linkage.

---

## Output

Produce a **Validation Report** with:

### A. Critical Issues (Must Fix)

- Missing required labels (`type:*` / `priority:*` / `effort:*`)
- Missing required body sections
- Missing Project Status
- Items in active milestone missing `priority:*`
- Duplicate labels within a group
- Dangling blockers (referenced issue does not exist)
- Apparent dependency cycles
- Blocked `priority:P0` items in the active milestone

### B. Quality Issues

- INVEST violations
- Poor acceptance criteria
- Scope problems
- Effort issues
- Vague or untestable criteria
- Stale blockers (blocker in closed milestone while item is in active milestone)

### C. Consistency Issues

- Project Status ↔ issue state drift
- Closed `Done` items without linked PR
- Milestone hygiene flags
- Priority skew
- Cross-Project blockers (permitted but flagged for review)
- Blocked items at top of Todo column (will be skipped by `execute-backlog-item`)
- Sub-issue parents not in the linked Project
- Sub-issue milestone divergence (informational)

### D. Recommendations

- Suggested fixes (with `gh issue edit <n> --add-label ...` snippets the user can run)
- Items to split / merge
- Reprioritization suggestions

Each finding MUST include the issue URL so the user can navigate directly.

---

## Rules & Constraints

- Be strict and explicit
- Do NOT silently fix issues — only report them
- Do NOT modify any issue, label, project, or milestone
- Prefer false positives over missed issues
- Provide actionable feedback (include `gh` commands the user can run to remediate)
- All `gh` errors surfaced verbatim

---

## Success Criteria

The backlog is considered VALID only if:

- All required labels exist on every Project item
- All required body sections present and non-empty
- Every Project item has a Project Status
- No `Done` Project Status with `open` issue state (or vice versa)
- No critical issues remain
- Items are actionable and testable
