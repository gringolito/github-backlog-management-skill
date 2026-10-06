---
name: health
description: Produce a read-only strategic portfolio health report across all open issues in the linked Project.
---

# health

You are an AI agent acting as a backlog analyst responsible for producing a strategic portfolio health report across all open issues in the linked GitHub Project.

Produce a Markdown strategic portfolio health report across all open issues in the linked GitHub Project, covering: open-issue distribution by type, priority, and effort; age cohorts; overdue high-priority items; stale in-progress items; and metadata debt. Read-only: never mutates issues, labels, projects, or milestones.

## Workflow

### 1. Data collection

Run these two queries:

1. Fetch all open issues:
   `gh issue list --state open --json number,title,labels,assignees,createdAt,updatedAt,url --limit 200`

   Pre-filter: discard any issue whose labels include `type:external-blocker`. These are Stubs, not Workable Items, and are excluded from all counts and metrics.

2. Fetch project membership and status:
   `gh project item-list <project-number> --owner <owner> --format json --limit 200 --query "is:issue"`

   Build a lookup map: issue `number` → project `Status` (`Todo` / `In Progress` / `Done`). Issues absent from the map are classified as "Not in Project."

### 2. Compute report sections

All computations operate on the pre-filtered open-issue set (stubs excluded). Use today's date (UTC) for all age calculations.

#### 2a. Summary counts

- Total open issues (stub-excluded)
- Count in project vs. count not in project

#### 2b. Distribution by label group

For each of the three label groups (`type:*`, `priority:*`, `effort:*`) in canonical order:

- `type:*`: use the discovered label list from `gh label list --repo <owner>/<repo> --json name --limit 100 | jq '[.[] | select(.name | startswith("type:")) | .name]'` as the value set; omit values with 0 count
- `priority:*`: P0, P1, P2, P3
- `effort:*`: XS, S, M, L, XL

For each value present, report count and percentage of total open issues. Add an "_(unlabeled)_" row for issues with no label in that group.

#### 2c. Age cohorts

Group all open issues by time elapsed since `createdAt` into four ranges:

- `< 7d`
- `7–30d`
- `30–90d`
- `> 90d`

Report count and percentage per range.

#### 2d. Overdue high-priority items

- P0: issues with `priority:P0` open longer than 14 days. List with issue number, title, age in days, and assignee (or "unassigned").
- P1: issues with `priority:P1` open longer than 30 days. List with issue number, title, age in days, and assignee (or "unassigned").

If no overdue items exist in a tier, emit `✅ No overdue <P0/P1> items.`

#### 2e. Stale in-progress items

Issues where project status = `In Progress` AND `updatedAt` is more than 7 days ago. List with issue number, title, and last-activity date (YYYY-MM-DD).

If none exist, emit `✅ No stale In-Progress items.`

#### 2f. Metadata debt

Issues missing any of `type:*`, `priority:*`, or `effort:*` labels. For each such issue, note which label group(s) are absent.

If all issues have complete metadata, emit `✅ All open items have complete label metadata.`

### 3. Report assembly

Produce a Markdown report with the following sections in this exact order.

#### Header

```text
## Backlog Health Report
Generated: <YYYY-MM-DD>
```

#### Summary

```text
**Open issues:** N (M in Project, K not in Project)
```

Stubs excluded from all counts.

#### Distribution

Three tables, one per label group:

_By Type_

| Label         | Count | %   |
|---------------|-------|-----|
| type:feature  | N     | N%  |
| …             | …     | …   |
| _(unlabeled)_ | N     | N%  |

_By Priority_

| Label       | Count | %   |
|-------------|-------|-----|
| priority:P0 | N     | N%  |
| …           | …     | …   |
| _(unlabeled)_ | N   | N%  |

_By Effort_

| Label       | Count | %   |
|-------------|-------|-----|
| effort:XS   | N     | N%  |
| …           | …     | …   |
| _(unlabeled)_ | N   | N%  |

Omit the `_(unlabeled)_` row for a group when its count is 0.

#### Age cohorts

| Age         | Count | %   |
|-------------|-------|-----|
| < 7 days    | N     | N%  |
| 7–30 days   | N     | N%  |
| 30–90 days  | N     | N%  |
| > 90 days   | N     | N%  |

#### Overdue high-priority items

_P0 (threshold: >14 days open)_

| Issue        | Title | Age | Assignee |
|--------------|-------|-----|----------|
| [#N](<url>) | title | Nd  | @user    |

_P1 (threshold: >30 days open)_

| Issue        | Title | Age | Assignee |
|--------------|-------|-----|----------|
| [#N](<url>) | title | Nd  | @user    |

Emit `✅ No overdue P0 items.` / `✅ No overdue P1 items.` when a tier is empty.

#### Stale in-progress

| Issue        | Title | Last Activity |
|--------------|-------|---------------|
| [#N](<url>) | title | YYYY-MM-DD    |

Emit `✅ No stale In-Progress items.` when empty.

#### Metadata debt

| Issue        | Title | Missing      |
|--------------|-------|--------------|
| [#N](<url>) | title | type, effort |

Emit `✅ All open items have complete label metadata.` when empty.

## Rules and constraints

- Never mutate any issue, project field, milestone, or label.
- Discard `type:external-blocker` Stubs before all computations; they are not Workable Items.
- Closed issues are excluded from all sections.
- Surface all `gh` errors verbatim; never swallow.
- Percentages rounded to the nearest integer.
- "Age" is computed from `createdAt` (UTC); "last activity" from `updatedAt` (UTC).
- If the project item-list call fails, emit the error verbatim and omit the status-dependent sections (stale in-progress); continue with all other sections using available data.
- Do not recommend execution order or triage actions. This skill surfaces state only.

## Output expectations

The entire output is the Markdown report: no preamble, no trailing summary, no conversational wrapping. The report must be valid GitHub-Flavored Markdown.
