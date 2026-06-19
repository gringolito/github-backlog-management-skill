---
name: release-status
description: Display a real-time health dashboard for the active or specified GitHub Milestone.
---

# release-status

You are an AI agent acting as a release manager responsible for producing a real-time health dashboard for a GitHub Milestone.

The backlog lives in GitHub: items are GitHub Issues, prioritization happens inside a linked GitHub Project (v2), and version planning happens through GitHub Milestones.

This skill is **read-only** — it never mutates issues, labels, projects, or milestones.

---

## Objective

Produce a Markdown release health dashboard for a target milestone: issue counts by Project Status, percentage complete, blocked items, and unestimated items — aggregated with zero manual querying with zero manual querying.

---

## Workflow

### 0. Preflight (MANDATORY)

Run `backlog-preflight` via the Bash tool. If it exits non-zero, STOP and surface its output verbatim. On success, capture the JSON it prints to stdout — this is the metadata used throughout the workflow (owner, repo, projectNumber, projectId, statusFieldId, statusOptions).

---

After preflight succeeds, use `TaskCreate` to create one task per workflow step below. Mark each task `in_progress` when you begin it and `completed` when it finishes.

### 1. Milestone Resolution (MANDATORY)

The skill accepts an optional milestone argument (title substring or version string).

Run `resolve-milestone "<argument>"` if an argument was provided, or `resolve-milestone` (no argument) for the Active Release. If it exits non-zero, STOP and surface its output verbatim.

---

### 2. Data Collection (MANDATORY)

With the resolved milestone in hand, run these queries:

1. **Issues assigned to the milestone**:
   `gh issue list --state all --milestone "<milestone-title>" --json number,title,labels,state,url --limit 500`

   After fetching, **partition the results**: set aside any issue whose labels include `type:external-blocker` — these are Stubs and are **excluded from all Milestone counts and metrics**. They are retained only to enrich the blocked-items table with stub titles as blocker context (step 3).

2. **Project membership and Status**:
   `gh project item-list <project-number> --owner <owner> --query "is:issue milestone:<milestone-title>" --format json --limit 200`
   Build a lookup map: issue `number` → Project `Status` (`Todo` / `In Progress` / `Done`). Issues absent from the map are classified as "Not in Project."

3. **Blocker check** (open issues only):
   For each open issue, call: `gh api "repos/<owner>/<repo>/issues/<n>/dependencies/blocked_by"`
   - If the API returns `404` on the first call, emit exactly once: `Issue Dependencies API unavailable on this repo — blocked items section omitted.` Skip the blocked-items section for the entire report.
   - An issue is **blocked** if the response contains at least one blocker with `state == "open"`.

4. **Unestimated check**:
   For each issue, scan its labels for any `effort:*` label. Issues with none are unestimated.

---

### 3. Report Assembly (MANDATORY)

Produce a Markdown report with the following sections in this exact order.

#### Header

```
## Release Status: <milestone-title>
Due: <due_on as YYYY-MM-DD> | Total: <N> issues
```

Omit the `Due:` line if the milestone has no `due_on`.

#### Progress

| Status | Count | % of Total |
|--------|-------|------------|
| ✅ Done | N | N% |
| 🔄 In Progress | N | N% |
| 📋 Todo | N | N% |
| ⚠️ Not in Project | N | — |

- **% complete** = Done ÷ (all non-stub issues assigned to the milestone), rounded to the nearest integer. `type:external-blocker` stubs are excluded from this denominator.
- Omit the "Not in Project" row if its count is 0.

#### Blocked Items

_Omit this section entirely if the Dependencies API is unavailable._

If no open issues are blocked:
> ✅ No blocked items.

Otherwise:

| Issue | Title | Blocked by |
|-------|-------|------------|
| [#N](\<url\>) | title | [#M](\<url\>), … |

For blockers that carry `type:external-blocker`, replace the issue link with the stub's title in the "Blocked by" column (e.g. `External: Vendor API rate limit freeze`) to surface the external constraint clearly.

#### Unestimated Items

If all open issues carry an `effort:*` label:
> ✅ All open items are estimated.

Otherwise, a bulleted list of open issues missing `effort:*`:

- `#N` — title (`<Status>`)

#### All Issues

Issues grouped by Status:

**✅ Done (N)**
- [x] [#N](\<url\>) — title

**🔄 In Progress (N)**
- [ ] [#N](\<url\>) — title

**📋 Todo (N)**
- [ ] [#N](\<url\>) — title

**⚠️ Not in Project (N)** _(omit section if 0)_
- [ ] [#N](\<url\>) — title

---

## Rules & Constraints

- This skill is **strictly read-only** — never mutate any issue, Project field, milestone, or label.
- Surface all `gh` errors verbatim — never swallow.
- Issue Dependencies API `404` must emit one warning line and gracefully skip the blocked-items section; it must not abort the rest of the report.
- % complete is always computed over ALL issues assigned to the milestone, not just those in the Project.
- Do NOT pick or recommend execution order — this skill surfaces state only.

---

## Output Expectations

The entire output is the Markdown report — no preamble, no trailing summary, no conversational wrapping. The report must be valid GitHub-Flavored Markdown so the user can paste it directly into a standup document, Slack message, or GitHub comment.
