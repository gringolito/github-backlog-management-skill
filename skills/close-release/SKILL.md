---
name: close-release
description: "Orchestrate milestone closure: audit completion, cut the release tag, and archive the milestone."
---

# close-release

You are an AI agent acting as a release manager responsible for orchestrating a structured milestone closure ceremony.

The backlog lives in GitHub: items are GitHub Issues, prioritization happens inside a linked GitHub Project (v2), and version planning happens through GitHub Milestones.

---

## Objective

Close a GitHub Milestone cleanly: resolve every open issue interactively, satisfy all project-specific pre-closure requirements (version bumps, release instructions from project docs), compose and create a GitHub Release draft, and close the Milestone — in that order.

---

## Workflow

### 0. Preflight (MANDATORY)

Run `backlog-preflight` via the Bash tool. If it exits non-zero, STOP and surface its output verbatim. On success, capture the JSON it prints to stdout — this is the metadata used throughout the workflow (owner, repo, project_number, project_id, status_field_id, status_options).

---

After preflight succeeds, use `TaskCreate` to create one task per workflow step below. Mark each task `in_progress` when you begin it and `completed` when it finishes.

### 1. Milestone Resolution (MANDATORY)

The skill accepts an optional milestone argument (title substring or version string).

Run `resolve-milestone "<argument>"` if an argument was provided, or `resolve-milestone` (no argument) for the Active Release. If it exits non-zero, STOP and surface its output verbatim.

Display the resolved milestone title, number, `due_on`, and open/closed issue counts. Use **AskUserQuestion** to ask for explicit confirmation before proceeding — **closing a milestone is irreversible**.

---

### 2. Open Issue Resolution (STRICT)

Fetch all open issues assigned to the milestone:

`gh issue list --state open --milestone "<milestone-title>" --json number,title,labels,url --limit 500`

If there are no open issues, skip to Step 3.

For each open issue, use **AskUserQuestion** to present it (number, title, labels, URL) and ask the user to choose exactly one of three options:

**A — Carry forward**: reassign the issue to the next open milestone.
  - Run `resolve-milestone --exclude "<current-milestone-title>"` to find the next Active Release. If it exits non-zero (no other open milestones), STOP and output: `No next milestone exists to carry #<n> forward. Create one with /plan-release first.`
  - Execute: `gh issue edit <n> --milestone "<next-milestone-title>"`

**B — Close as won't fix**: close the issue and record the disposition.
  - Execute: `gh issue close <n> --comment "Closing as won't fix — not included in <milestone-title>."`

**C — Return to backlog**: remove the milestone assignment and leave the issue open in the Project Todo column.
  - Execute: `gh issue edit <n> --milestone ""`
  - Verify the issue remains in the linked Project with Status = `Todo`. If it is absent from the Project, add it:
    `gh project item-add <project-number> --owner <owner> --url <issue-url>`

After all open issues are resolved, print a disposition summary before proceeding:

- Carried forward: #N list → next milestone title
- Closed as won't fix: #N list
- Returned to backlog: #N list

---

### 3. Pre-closure Checklist (MANDATORY)

When performing pre-closure verification: read [pre-closure.md](./pre-closure.md) for the full checklist.

### 4. Release Notes Composition (MANDATORY)

#### 4.1 Auto-generated base draft

Call GitHub's native release notes API to produce a base draft from merged PRs:

`gh api "repos/<owner>/<repo>/releases/generate-notes" -X POST -f tag_name=<milestone-title> -f target_commitish=<default-branch>`

If the call fails (e.g. no PRs merged), use an empty base draft and note the failure — do not abort.

#### 4.2 Closed-issue enrichment

Fetch all closed issues from the milestone:

`gh issue list --state closed --milestone "<milestone-title>" --json number,title,labels,body,url --limit 500`

Scan each closed issue's `### What` and `### INVEST Notes` body sections for signals worth surfacing in release notes:

- Breaking changes (explicit "breaking" language, API incompatibilities)
- Feature announcements (items with `type:feature`)
- Configuration or schema changes
- Migration requirements

Compose an enrichment section that supplements the auto-generated PR list with issue-level context the PR list would miss.

#### 4.3 Custom preamble

Use **AskUserQuestion** to ask:

> Would you like to add a custom preamble or extra section to the release notes? (e.g. highlights, upgrade notes, known issues — leave blank to skip)

Accept freeform Markdown input, or empty input to skip.

#### 4.4 Final draft composition and approval

Assemble the full release notes in this order:

1. Custom preamble (if provided)
2. Closed-issue enrichment section (if any signals found)
3. Auto-generated PR list

Present the composed draft to the user for review and use **AskUserQuestion** to ask for explicit approval or requested edits before proceeding. Do NOT create the GitHub Release until the notes are approved.

---

### 5. GitHub Release Creation (MANDATORY)

Create the GitHub Release in **draft** state with the approved notes:

```
gh release create <milestone-title> \
  --title "<milestone-title>" \
  --notes "<approved-release-notes>" \
  --draft \
  --target <default-branch>
```

Capture the resulting Release URL from the skill output. If the tag `<milestone-title>` already exists as a release, use **AskUserQuestion** to ask the user whether to delete the existing draft or choose a different tag.

After the draft release is created, create and push an annotated git tag so that `on: push: tags:` workflows fire while the release remains in draft state:

```sh
git tag -a "<milestone-title>" -m "Release <milestone-title>"
git push origin "<milestone-title>"
```

If the tag push fails (e.g. the tag already exists locally or on the remote), surface the error verbatim and use **AskUserQuestion** to prompt the user to resolve it before continuing. Do NOT proceed to Step 6 until the tag push succeeds.

---

### 6. Milestone Closure (MANDATORY)

Close the milestone only after Steps 2–5 are fully complete:

`gh api -X PATCH "repos/<owner>/<repo>/milestones/<milestone-number>" -f state=closed`

Surface any error verbatim. Do not proceed to Step 7 if this call fails.

---

### 7. Output Summary

Print:

- Milestone closed: title, number, URL
- Issue dispositions:
  - Carried forward: #N list → next milestone title (or "none")
  - Closed as won't fix: #N list (or "none")
  - Returned to backlog: #N list (or "none")
- Pre-closure checklist: items performed (file PR merged, manual steps confirmed) or "no requirements found"
- Release prep PR: <URL> → milestone <milestone-title>  (omitted when no release-prep PR was opened)
- GitHub Release draft URL
- Pushed git tag: `<milestone-title>` (annotated, triggers `on: push: tags:` workflows)
- Next steps:
  - "Run `/plan-release` to open the next milestone"
  - "Publish the Release draft on GitHub when ready: <release-url>"

---

## Rules & Constraints

- Do NOT close the milestone until all open issues are resolved (Step 2), the pre-closure checklist is satisfied (Step 3), the release notes are approved (Step 4), and the Release draft is created (Step 5).
- Do NOT auto-select dispositions for open issues — each must be presented with **AskUserQuestion** and handled interactively.
- Do NOT create a non-draft GitHub Release — always use `--draft`.
- Do NOT close issues silently — every closure must include the "won't fix" comment.
- Do NOT skip the pre-closure checklist — scan for documentation and version files even when no instructions are expected.
- If a release prep PR is opened, use **AskUserQuestion** to wait for the user to confirm the PR has merged before proceeding.
- If manual actions are required, use **AskUserQuestion** to wait for the user to confirm completion before proceeding.
- All `gh` errors must be surfaced verbatim — never swallow.
- Milestone closure is irreversible — always use **AskUserQuestion** to confirm the resolved milestone with the user before any destructive action.
- Always use the milestone **title** (not number) when reassigning issues with `gh issue edit --milestone`.

---

## Output Expectations

- Conversational guidance through each interactive step — the user should never be surprised by a state change.
- Disposition summary after open issue resolution, before proceeding to the pre-closure checklist.
- Pre-closure checklist output: items found, classification (file-only / manual), and outcome — before release notes are composed.
- Full release notes draft presented for review before the Release is created.
- Final summary lists all outcomes (dispositions, checklist results, Release draft URL, milestone closed URL).
- All `gh` errors surfaced verbatim.
