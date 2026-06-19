---
name: initialize
description: "Bootstrap the GitHub-native backlog system: create the Project, labels, and Issue Forms template PR."
---

# initialize

You are an AI agent acting as a Senior Project Manager responsible for bootstrapping the GitHub-native backlog system for this repository.

Your goal is to provision the GitHub primitives the other backlog skills depend on: a GitHub Project (v2) linked to this repo, the standard label catalog, and the Issue Forms template that defines the canonical backlog-item shape.

This skill is **idempotent**: re-running it on a repo where the project already exists must not duplicate or destroy anything.

---

## Objective

Make the repository ready to host backlog items as GitHub Issues, prioritized inside a linked GitHub Project (v2), so that:

- All other skills can all read project metadata from `.claude/backlog-project.json`
- Issues created by any skill share the same body shape (driven by the Issue Forms template)
- Labels are uniform across `type:*`, `priority:*`, and `effort:*`

---

## Workflow

### 0. Preflight (MANDATORY)

**Re-run / idempotent case** — if `.claude/backlog-project.json` already exists run `backlog-preflight` via the Bash tool. If it exits non-zero, STOP and surface the error verbatim. If it exits zero, continue to step 5.

**Fresh bootstrap** — if `.claude/backlog-project.json` does not yet exist, verify the local environment can talk to GitHub:

- Parse `<owner>/<repo>` from the origin URL (support both `git@github.com:owner/repo.git` and `https://github.com/owner/repo.git` forms)
- Confirm Issues are enabled: `gh repo view <owner>/<repo> --json hasIssuesEnabled --jq '.hasIssuesEnabled'`. If `false`, STOP and instruct the user to enable Issues in repository settings.
- Confirm Projects are enabled: `gh repo view <owner>/<repo> --json hasProjectsEnabled --jq '.hasProjectsEnabled'`. If `false`, STOP and instruct the user to enable Projects in repository settings.
- Confirm the GitHub Issue Dependencies API is reachable on this repo (used by `add-item`, `execute-item`, `audit`, `refine-item`, `migrate`):

If any required preflight step fails:

- STOP
- Report the missing prerequisite explicitly
- Do NOT continue to provisioning

---

After preflight succeeds, use `TaskCreate` to create one task per workflow step below. Mark each task `in_progress` when you begin it and `completed` when it finishes.

### 1. Project Detection (IDEMPOTENT)

Before creating anything:

- Query existing projects:
  - `gh project list --owner <owner> --format json`
- Filter for a Project (v2) titled `<owner>/<repo> Backlog` that is linked to this repo
- If a matching Project exists:
  - Record its number and URL
  - SKIP step 2
  - Continue with label and template provisioning (which are also idempotent)

---

### 2. Project Creation

If no matching Project exists:

- Use AskUserQuestion to ask which visibility the Project should have:
  - **Private (Recommended)** — only members with explicit access can see the project
  - **Public** — visible to anyone
- Create a new Project (v2):
  - `gh project create --owner <owner> --title "<owner>/<repo> Backlog"`
- If the user chose **public**, set the visibility:
  - `gh project edit <project-number> --owner <owner> --visibility PUBLIC`
- Link it to the repository
  - `gh project link <project-number> --owner <owner> --repo <repo>`
- Set a canonical short description on the project:
  - Use the GraphQL mutation `updateProjectV2` with `shortDescription: "Backlog for <owner>/<repo>"`:

    ```sh
    gh api graphql -f query='mutation { updateProjectV2(input: { projectId: "<project-id>", shortDescription: "Backlog for <owner>/<repo>" }) { projectV2 { id } } }'
    ```

- Verify the Project's built-in `Status` field exists with options:
  - `Todo`
  - `In Progress`
  - `Done`
- If the user has customized the Status field options, STOP and use AskUserQuestion with options: "Add missing options" / "Rename existing options" / "Cancel" — DO NOT silently overwrite

---

### 3. Label Provisioning (IDEMPOTENT)

Create the standard label catalog. Use `gh label create --force` so existing labels are updated rather than duplicated.

#### Type labels (one of these must be on every backlog item)

- `type:feature` — `"New capability or user-visible behaviour not yet present"`
- `type:bug` — `"Incorrect behaviour deviating from a documented or expected contract"`
- `type:security` — `"Vulnerability, auth gap, data-exposure risk, or compliance hardening"`
- `type:performance` — `"Latency, throughput, memory, or resource-efficiency improvement"`
- `type:dx` — `"Contributor-facing improvement: CI, tooling, contributing docs"`
- `type:tech-debt` — `"Internal restructuring; no user-visible behaviour change"`
- `type:reliability` — `"Uptime, error recovery, observability, or graceful-degradation improvement"`
- `type:compliance` — `"Regulatory, legal, or contractual obligation"`
- `type:spike` — `"Time-boxed investigation to reduce uncertainty; deliverable is knowledge"`
- `type:external-blocker` — `"External constraint blocking a backlog item (Stub)"`

#### Priority labels (one of these must be on every backlog item)

- `priority:P0` — `"Critical: system broken, data loss, or no viable workaround"`
- `priority:P1` — `"High: major user or business impact"`
- `priority:P2` — `"Medium: planned work; not blocking anything critical"`
- `priority:P3` — `"Low: nice-to-have; easily deferred without consequence"`

#### Effort labels (one of these must be on every backlog item)

- `effort:XS` — `"Trivial: config tweak, one-liner, or doc edit"`
- `effort:S` — `"Small: focused change in one file or component"`
- `effort:M` — `"Medium: multiple files or components; some design thought"`
- `effort:L` — `"Large: cross-cutting; multiple subsystems or substantial design"`
- `effort:XL` — `"Extra large: major undertaking; probably needs a split plan"`

Effort label descriptions MUST NOT include time estimates (e.g. "2 hours", "1 day"). Use only relative size terms (e.g. "Extra small", "Small", "Medium", "Large", "Extra large").

#### Operational labels

- `needs-clarification` — `"Item needs more information before it can be worked"`

Apply distinct color groupings (e.g. priority shades from red→grey, effort shades light→dark, type using semantic colors).

---

### 4. Issue Forms Template (CANONICAL BODY SHAPE — VIA PR)

The Issue Forms template at `.github/ISSUE_TEMPLATE/backlog-item.yml` is the **single source of truth for the backlog-item issue body shape** — every skill MUST construct issue bodies whose section headings match this template exactly.

This file MUST be added to the repository through a Pull Request, not committed directly to the default branch. The PR is the gate for review and adoption of the canonical body shape.

#### 4a. Detect existing template

If `.github/ISSUE_TEMPLATE/backlog-item.yml` already exists on the default branch:

- Read its current contents
- Compare against the canonical version below
- If they match, SKIP step 4b
- If they differ, STOP and use AskUserQuestion with options: "Open PR to replace" / "Keep existing" — do NOT silently overwrite user customizations

When step 4b is reached: read [issue-forms-template.md](./issue-forms-template.md) for the template PR creation and canonical content (steps 4b–4d).

### 5. Persist Project Metadata

Persist project metadata to `.claude/backlog-project.json` so other skills can read it without any live GitHub queries.

Resolve the metadata via:

- `gh project field-list <project-number> --owner <owner> --format json` — for the Status field's node ID and the option IDs for `Todo` / `In Progress` / `Done`
- `gh project view <project-number> --owner <owner> --format json` — for the project's node ID

Create the `.claude/` directory if needed: `mkdir -p .claude`

Write the file:

```json
{
  "owner": "<owner>",
  "repo": "<repo>",
  "project_number": <int>,
  "project_id": "<project-node-id>",
  "project_title": "<project-title>",
  "project_url": "<html-url>",
  "status_field_id": "<status-field-node-id>",
  "status_options": {
    "Todo": "<option-id>",
    "In Progress": "<option-id>",
    "Done": "<option-id>"
  }
}
```

Schema notes:

- This file is the single source of truth for project metadata — all other skills read it directly with no fallback
- Re-running `initialize` on a fully-provisioned repo MUST refresh this file

---

### 6. Output Summary

Print a structured summary so the user can verify provisioning:

- Project URL (`https://github.com/users/<owner>/projects/<n>` or `https://github.com/orgs/<owner>/projects/<n>`)
- Project number (used by other skills)
- Repository (`<owner>/<repo>`)
- Visibility (`private` or `public`) — from the user's choice in Step 2 on fresh runs; derived from the `public` boolean in the `gh project view` JSON response (already fetched in Step 5) on idempotent re-runs
- Labels created or updated (count, with full list)
- Issue Forms template PR URL (or "already present, no PR needed")
- Status field options confirmed
- Metadata file path: `.claude/backlog-project.json`

---

## Rules & Constraints

- Re-running this skill on a fully-provisioned repo MUST be a no-op except for printing the summary
- NEVER delete pre-existing labels, projects, or templates the user may have customized
- NEVER skip the `gh auth status` and `git remote get-url origin` preflight checks
- Stop and ask before opening a PR that would replace a pre-existing `.github/ISSUE_TEMPLATE/backlog-item.yml`
- NEVER commit `.github/ISSUE_TEMPLATE/backlog-item.yml` directly to the default branch — always go through a PR
- All `gh` errors must be surfaced verbatim to the user — do not swallow them

---

## Output Expectations

- Clear summary of provisioned resources with URLs
- Any skipped steps (because resources already existed) explicitly listed
- Next-step pointer: "Run `/plan-release` to create your first milestone, then `/add-item` or `/migrate`."
