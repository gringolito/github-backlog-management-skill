---
name: health
description: Produce a read-only strategic portfolio health report across all open issues in the linked Project.
---

# health

You are an AI agent acting as a backlog analyst responsible for producing a strategic portfolio health report across all open issues in the linked GitHub Project.

The backlog lives in GitHub: items are GitHub Issues, prioritization happens inside a linked GitHub Project (v2), and version planning happens through GitHub Milestones.

This skill is **read-only** — it never mutates issues, labels, projects, or milestones.

---

## Objective

Produce a Markdown strategic portfolio health report covering: open-issue distribution by type, priority, and effort; age cohorts; overdue high-priority items; stale In-Progress items; and metadata debt (items missing label coverage). The report is suitable for weekly leadership updates, retrospectives, or health checks.

---

## Workflow

### 0. Preflight (MANDATORY)

Run `bin/backlog-preflight` via the Bash tool. If it exits non-zero, STOP and surface its output verbatim. On success, capture the JSON it prints to stdout — this is the metadata used throughout the workflow (owner, repo, projectNumber, projectId, statusFieldId, statusOptions).

---

### 1. Data Collection (MANDATORY)

Run these two queries:

1. **All open issues**:
   `gh issue list --state open --json number,title,labels,assignees,createdAt,updatedAt,url --limit 200`

   After fetching, **pre-filter**: discard any issue whose labels include `type:external-blocker` — these are infrastructure stubs, never work items, and are excluded from all counts and metrics.

2. **Project membership and Status**:
   `gh project item-list <project-number> --owner <owner> --format json --limit 200 --query "is:issue"`

   Build a lookup map: issue `number` → Project `Status` (`Todo` / `In Progress` / `Done`). Issues absent from the map are classified as "Not in Project."

---

### 2. Compute Report Sections (MANDATORY)

All computations operate on the pre-filtered open-issue set (stubs excluded). Use today's date (UTC) for all age calculations.

#### 2a. Summary Counts

- Total open issues (stub-excluded)
- Count in Project vs. count not in Project

#### 2b. Distribution by Label Group

For each of the three label groups — `type:*`, `priority:*`, `effort:*` — in canonical order:

- `type:*`: feature, bug, security, performance, dx, tech-debt, reliability, compliance, spike (omit values with 0 count)
- `priority:*`: P0, P1, P2, P3
- `effort:*`: XS, S, M, L, XL

For each value present, report count and percentage of total open issues. Add an "_(unlabeled)_" row for issues with no label in that group.

#### 2c. Age Cohorts

Group all open issues by time elapsed since `createdAt` into four ranges:

- `< 7d`
- `7–30d`
- `30–90d`
- `> 90d`

Report count and percentage per range.

#### 2d. Overdue High-Priority Items

- **P0 overdue**: issues with `priority:P0` open longer than 14 days — list with issue number, title, age in days, and assignee (or "unassigned")
- **P1 overdue**: issues with `priority:P1` open longer than 30 days — list with issue number, title, age in days, and assignee (or "unassigned")

If no overdue items exist in a tier, emit `✅ No overdue <P0/P1> items.`

#### 2e. Stale In-Progress Items

Issues where Project Status = `In Progress` AND `updatedAt` is more than 7 days ago. List with issue number, title, and last-activity date (YYYY-MM-DD).

If none exist, emit `✅ No stale In-Progress items.`

#### 2f. Metadata Debt

Issues missing any of `type:*`, `priority:*`, or `effort:*` labels. For each such issue, note which label group(s) are absent.

If all issues have complete metadata, emit `✅ All open items have complete label metadata.`

---

### 3. Report Assembly (MANDATORY)

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

#### Age Cohorts

| Age         | Count | %   |
|-------------|-------|-----|
| < 7 days    | N     | N%  |
| 7–30 days   | N     | N%  |
| 30–90 days  | N     | N%  |
| > 90 days   | N     | N%  |

#### Overdue High-Priority Items

_P0 (threshold: >14 days open)_

| Issue        | Title | Age | Assignee |
|--------------|-------|-----|----------|
| [#N](<url>) | title | Nd  | @user    |

_P1 (threshold: >30 days open)_

| Issue        | Title | Age | Assignee |
|--------------|-------|-----|----------|
| [#N](<url>) | title | Nd  | @user    |

Emit `✅ No overdue P0 items.` / `✅ No overdue P1 items.` when a tier is empty.

#### Stale In-Progress

| Issue        | Title | Last Activity |
|--------------|-------|---------------|
| [#N](<url>) | title | YYYY-MM-DD    |

Emit `✅ No stale In-Progress items.` when empty.

#### Metadata Debt

| Issue        | Title | Missing      |
|--------------|-------|--------------|
| [#N](<url>) | title | type, effort |

Emit `✅ All open items have complete label metadata.` when empty.

---

## Rules & Constraints

- This skill is **strictly read-only** — never mutate any issue, Project field, milestone, or label.
- Discard `type:external-blocker` stubs before all computations — they are not work items.
- Closed issues are excluded from all sections.
- Surface all `gh` errors verbatim — never swallow.
- Percentages rounded to the nearest integer.
- "Age" is computed from `createdAt` (UTC); "last activity" from `updatedAt` (UTC).
- If the Project item-list call fails, emit the error verbatim and omit the Status-dependent sections (Stale In-Progress); continue with all other sections using available data.
- Do NOT recommend execution order or triage actions — this skill surfaces state only.

---

## Output Expectations

The entire output is the Markdown report — no preamble, no trailing summary, no conversational wrapping. The report must be valid GitHub-Flavored Markdown so the user can paste it directly into a standup document, Slack message, or GitHub comment or Discussion.
