# initialize-backlog

You are an AI agent acting as a Senior Project Manager responsible for bootstrapping the GitHub-native backlog system for this repository.

Your goal is to provision the GitHub primitives the other backlog commands depend on: a GitHub Project (v2) linked to this repo, the standard label catalog, and the Issue Forms template that defines the canonical backlog-item shape.

This command is **idempotent**: re-running it on a repo where the project already exists must not duplicate or destroy anything.

---

## Objective

Make the repository ready to host backlog items as GitHub Issues, prioritized inside a linked GitHub Project (v2), so that:

- All other commands can all read project metadata from `.claude/backlog-project.json`
- Issues created by any command share the same body shape (driven by the Issue Forms template)
- Labels are uniform across `type:*`, `priority:*`, and `effort:*`

---

## Workflow

### 1. Preflight (MANDATORY)

Verify the local environment can talk to GitHub:

- Parse `<owner>/<repo>` from the origin URL (support both `git@github.com:owner/repo.git` and `https://github.com/owner/repo.git` forms)
- Confirm Issues are enabled: `gh repo view <owner>/<repo> --json hasIssuesEnabled --jq '.hasIssuesEnabled'`. If `false`, STOP and instruct the user to enable Issues in repository settings.
- Confirm Projects are enabled: `gh repo view <owner>/<repo> --json hasProjectsEnabled --jq '.hasProjectsEnabled'`. If `false`, STOP and instruct the user to enable Projects in repository settings.
- Confirm the GitHub Issue Dependencies API is reachable on this repo (used by `add-backlog-item`, `execute-backlog-item`, `validate-backlog`, `refine-backlog-item`, `migrate-backlog`):

If any required preflight step fails:

- STOP
- Report the missing prerequisite explicitly
- Do NOT continue to provisioning

---

### 2. Project Detection (IDEMPOTENT)

Before creating anything:

- Query existing projects:
  - `gh project list --owner <owner> --format json`
- Filter for a Project (v2) titled `<owner>/<repo> Backlog` that is linked to this repo
- If a matching Project exists:
  - Record its number and URL
  - SKIP step 3
  - Continue with label and template provisioning (which are also idempotent)

---

### 3. Project Creation

If no matching Project exists:

- Create a new Project (v2):
  - `gh project create --owner <owner> --title "<owner>/<repo> Backlog"`
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
- If the user has customized the Status field options, STOP and ask the user to confirm whether to add the missing options or rename existing ones — DO NOT silently overwrite

---

### 4. Label Provisioning (IDEMPOTENT)

Create the standard label catalog. Use `gh label create --force` so existing labels are updated rather than duplicated.

#### Type labels (one of these must be on every backlog item)

- `type:feature`
- `type:bug`
- `type:security`
- `type:performance`
- `type:dx`
- `type:tech-debt`
- `type:reliability`
- `type:compliance`
- `type:spike`
- `type:external-blocker`

#### Priority labels (one of these must be on every backlog item)

- `priority:P0`
- `priority:P1`
- `priority:P2`
- `priority:P3`

#### Effort labels (one of these must be on every backlog item)

- `effort:XS`
- `effort:S`
- `effort:M`
- `effort:L`
- `effort:XL`

Effort label descriptions MUST NOT include time estimates (e.g. "2 hours", "1 day"). Use only relative size terms (e.g. "Extra small", "Small", "Medium", "Large", "Extra large").

#### Operational labels

- `needs-clarification` — applied by `migrate-backlog` to items missing critical info

Apply distinct color groupings (e.g. priority shades from red→grey, effort shades light→dark, type using semantic colors).

---

### 5. Issue Forms Template (CANONICAL BODY SHAPE — VIA PR)

The Issue Forms template at `.github/ISSUE_TEMPLATE/backlog-item.yml` is the **single source of truth for the backlog-item issue body shape** — every command MUST construct issue bodies whose section headings match this template exactly.

This file MUST be added to the repository through a Pull Request, not committed directly to the default branch. The PR is the gate for review and adoption of the canonical body shape.

#### 5a. Detect existing template

If `.github/ISSUE_TEMPLATE/backlog-item.yml` already exists on the default branch:

- Read its current contents
- Compare against the canonical version below
- If they match, SKIP step 5b
- If they differ, STOP and ask the user whether to open a PR replacing it (do NOT silently overwrite user customizations)

#### 5b. Open the template PR

If the file is missing or the user approved replacement:

- Create a branch: `chore/backlog-item-issue-template`
  - `git checkout -b chore/backlog-item-issue-template`
- Create the parent directory if needed: `mkdir -p .github/ISSUE_TEMPLATE`
- Write the canonical contents of §5c below to `.github/ISSUE_TEMPLATE/backlog-item.yml`
- Write the canonical contents of §5d below to `.github/ISSUE_TEMPLATE/external-blocker.yml`
- Commit both files using Conventional Commits:
  - `git add .github/ISSUE_TEMPLATE/backlog-item.yml .github/ISSUE_TEMPLATE/external-blocker.yml`
  - `git commit -m "chore: add backlog-item and external-blocker issue forms templates"`
- Push the branch: `git push -u origin chore/backlog-item-issue-template`
- Open a PR via `gh pr create --title "chore: add backlog-item and external-blocker issue forms templates" --body "<body>"` where the body explains:
  - `backlog-item.yml` is the canonical body shape for backlog items — all commands depend on its section headings
  - `external-blocker.yml` is the template for infrastructure stub issues created by `/add-external-blocker`
  - `validate-backlog` parses `backlog-item.yml` sections — changing them will break parsing
- Print the PR URL

The remaining provisioning steps (project, labels) are NOT gated by this PR — they are direct API calls. The template only takes effect on the default branch after the PR is merged. Until then, `add-backlog-item` and `migrate-backlog` will still emit issue bodies in the canonical shape (the template is for human use in the GitHub UI).

#### 5c. Canonical contents

```yaml
name: Backlog Item
description: Add a new item to the project backlog
labels: []
body:
  - type: textarea
    id: what
    attributes:
      label: What
      description: Clear and specific description of the work.
      placeholder: A concise description of what is being delivered.
    validations:
      required: true
  - type: textarea
    id: why
    attributes:
      label: Why
      description: Business value, user impact, or technical justification.
      placeholder: Why this item matters and what outcome it produces.
    validations:
      required: true
  - type: textarea
    id: in-scope
    attributes:
      label: In Scope
      description: What is explicitly included in this item.
      placeholder: |
        - Item A
        - Item B
    validations:
      required: true
  - type: textarea
    id: out-of-scope
    attributes:
      label: Out of Scope
      description: What is explicitly excluded (when relevant).
      placeholder: |
        - Item X (handled separately)
    validations:
      required: false
  - type: textarea
    id: acceptance-criteria
    attributes:
      label: Acceptance Criteria
      description: Concrete, testable, unambiguous conditions. Use a checklist.
      placeholder: |
        - [ ] Criterion 1
        - [ ] Criterion 2
    validations:
      required: true
  - type: textarea
    id: invest-notes
    attributes:
      label: INVEST Notes
      description: Open questions, "NEEDS CLARIFICATION" markers, INVEST violations to be resolved.
      placeholder: Leave blank if the item is fully specified.
    validations:
      required: false
```

The rendered issue body produced by GitHub for this template uses `### What`, `### Why`, `### In Scope`, `### Out of Scope`, `### Acceptance Criteria`, `### INVEST Notes` headings. All other commands MUST emit bodies that use these exact headings (case + ordering preserved).

#### 5d. Canonical contents — external-blocker.yml

```yaml
name: External Blocker
description: Record an external constraint (API limitation, vendor issue, regulatory hold, etc.) blocking a backlog item
title: "External blocker: "
labels: ["type:external-blocker"]
body:
  - type: textarea
    id: reason
    attributes:
      label: Reason
      description: What external constraint is causing the block?
      placeholder: e.g. "Vendor API does not support X; waiting for SDK v3 release"
    validations:
      required: true
  - type: input
    id: external-reference
    attributes:
      label: External Reference / URL
      description: Link to vendor issue, RFC, ticket, or documentation (optional).
      placeholder: https://...
    validations:
      required: false
  - type: textarea
    id: resolution-path
    attributes:
      label: Expected Resolution Path
      description: How is this expected to be resolved? (optional)
      placeholder: e.g. "Monitor vendor release notes; re-evaluate in next sprint"
    validations:
      required: false
```

This template pre-applies the `type:external-blocker` label. There is no "Blocked Item" field — a single stub can block multiple items, and GitHub tracks blocking relationships natively via the Issue Dependencies API.

---

### 6. Persist Project Metadata

Persist project metadata to `.claude/backlog-project.json` so other commands can read it without any live GitHub queries.

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

- This file is the single source of truth for project metadata — all other commands read it directly with no fallback
- Re-running `initialize-backlog` on a fully-provisioned repo MUST refresh this file

---

### 7. Output Summary

Print a structured summary so the user can verify provisioning:

- Project URL (`https://github.com/users/<owner>/projects/<n>` or `https://github.com/orgs/<owner>/projects/<n>`)
- Project number (used by other commands)
- Repository (`<owner>/<repo>`)
- Labels created or updated (count, with full list)
- Issue Forms template PR URL (or "already present, no PR needed")
- Status field options confirmed
- Metadata file path: `.claude/backlog-project.json`

---

## Rules & Constraints

- Re-running this command on a fully-provisioned repo MUST be a no-op except for printing the summary
- NEVER delete pre-existing labels, projects, or templates the user may have customized
- NEVER skip the `gh auth status` and `git remote get-url origin` preflight checks
- Stop and ask before opening a PR that would replace a pre-existing `.github/ISSUE_TEMPLATE/backlog-item.yml`
- NEVER commit `.github/ISSUE_TEMPLATE/backlog-item.yml` directly to the default branch — always go through a PR
- All `gh` errors must be surfaced verbatim to the user — do not swallow them

---

## Output Expectations

- Clear summary of provisioned resources with URLs
- Any skipped steps (because resources already existed) explicitly listed
- Next-step pointer: "Run `/plan-release` to create your first milestone, then `/add-backlog-item` or `/migrate-backlog`."
