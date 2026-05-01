# release-status

You are an AI agent acting as a release manager responsible for producing a real-time health dashboard for a GitHub Milestone.

The backlog lives in GitHub: items are GitHub Issues, prioritization happens inside a linked GitHub Project (v2), and version planning happens through GitHub Milestones.

This command is **read-only** — it never mutates issues, labels, projects, or milestones.

---

## Objective

Produce a Markdown release health dashboard for a target milestone: issue counts by Project Status, percentage complete, blocked items, and unestimated items — aggregated from a single command with zero manual querying.

---

## Workflow

### 0. Preflight (MANDATORY)

- Read `.claude/backlog-project.json`. If the file does not exist, STOP and output exactly:
  `No Backlog project linked to <owner>/<repo>. Run /initialize-backlog first.`

---

### 1. Milestone Resolution (MANDATORY)

The command accepts an optional milestone argument (title substring, number, or version string).

**With argument** — resolve from open milestones via `gh api "repos/<owner>/<repo>/milestones?state=open&per_page=100"`:

1. If the argument is a plain integer, match by milestone `number`.
2. Otherwise, match by case-insensitive substring of `title`.
3. If no substring match, try version string matching: strip a leading `v` from both the argument and each `title` before comparing (e.g. `1.2.0` matches `v1.2.0`).
4. If no match is found after all three passes, STOP and output: `No open milestone matching "<argument>" found.`

**Without argument** — use the canonical active-milestone logic:

- Primary sort: `due_on` ascending; milestones with no `due_on` are sorted last.
- Tie-break: lowest version parsed from milestone `title` (`v1.2.0` < `v1.3.0`; for non-parseable titles, fall back to milestone `number` ascending).
- If NO open milestones exist, STOP and output: `No open milestones found.`

---

### 2. Data Collection (MANDATORY)

With the resolved milestone in hand, run these queries:

1. **Issues assigned to the milestone**:
   `gh issue list --state all --milestone "<milestone-title>" --json number,title,labels,state,url --limit 500`

2. **Project membership and Status**:
   `gh project item-list <project-number> --owner <owner> --format json`
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

- **% complete** = Done ÷ (all issues assigned to the milestone), rounded to the nearest integer.
- Omit the "Not in Project" row if its count is 0.

#### Blocked Items

_Omit this section entirely if the Dependencies API is unavailable._

If no open issues are blocked:
> ✅ No blocked items.

Otherwise:

| Issue | Title | Blocked by |
|-------|-------|------------|
| [#N](\<url\>) | title | [#M](\<url\>), … |

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

- This command is **strictly read-only** — never mutate any issue, Project field, milestone, or label.
- Surface all `gh` errors verbatim — never swallow.
- Issue Dependencies API `404` must emit one warning line and gracefully skip the blocked-items section; it must not abort the rest of the report.
- % complete is always computed over ALL issues assigned to the milestone, not just those in the Project.
- Do NOT pick or recommend execution order — this command surfaces state only.

---

## Output Expectations

The entire output is the Markdown report — no preamble, no trailing summary, no conversational wrapping. The report must be valid GitHub-Flavored Markdown so the user can paste it directly into a standup document, Slack message, or GitHub comment.
