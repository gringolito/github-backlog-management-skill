---
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

Display the resolved milestone title, number, `due_on`, and open/closed issue counts. Use **AskUserQuestion** to ask for explicit confirmation before proceeding — **closing a milestone is irreversible**.

---

### 2. Open Issue Resolution (STRICT)

Fetch all open issues assigned to the milestone:

`gh issue list --state open --milestone "<milestone-title>" --json number,title,labels,url --limit 500`

If there are no open issues, skip to Step 3.

For each open issue, use **AskUserQuestion** to present it (number, title, labels, URL) and ask the user to choose exactly one of three options:

**A — Carry forward**: reassign the issue to the next open milestone.
  - Resolve "next" using the same canonical tie-break logic as milestone resolution, but exclude the current milestone. If no other open milestone exists, STOP and output: `No next milestone exists to carry #<n> forward. Create one with /plan-release first.`
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

Before composing release notes, scan for project-specific release requirements and verify release readiness. Any new PRs merged as a result of this step will be included in the release notes generated in Step 4.

#### 3.1 Scan project documentation for release instructions

Read the following files if they exist (in this priority order):

- `RELEASING.md`
- `CONTRIBUTING.md`
- `README.md`
- `CLAUDE.md` (repo root and `.claude/CLAUDE.md`)
- `AGENTS.md` (repo root and `.claude/AGENTS.md`)

Extract any instructions tagged with keywords: "release", "close release", "publish", "version bump", "before releasing", "pre-release", "checklist". Present each instruction found as a numbered checklist item.

#### 3.2 Version consistency check

Search the repository for files that commonly embed version literals. The table below is a starting-point reference — do not treat it as an exhaustive list. Also scan for any other project-specific files (custom manifests, config files, documentation) that appear to declare a version string.

| File pattern | Version field |
| --- | --- |
| `package.json` | `.version` |
| `pyproject.toml` | `[project] version` or `[tool.poetry] version` |
| `Cargo.toml` | `[package] version` |
| `*.gemspec` | `spec.version` |
| `plugin.json` | `.version` |
| `marketplace.json` | `.version` |
| `setup.py` | `version=` |
| `setup.cfg` | `version =` |
| `Chart.yaml` | `version:` / `appVersion:` |
| `build.gradle` / `build.gradle.kts` | `version =` |
| `pom.xml` | `<version>` (top-level project only) |

For each found file, extract the version string and compare it against the milestone title (strip a leading `v` from both before comparing). Flag any mismatch as:

> ⚠️ Version mismatch: `<file>` declares `<found-version>` but milestone is `<milestone-title>`.

#### 3.3 Action classification and execution

Collect all items from 3.1 and 3.2 into a unified checklist. Classify each as one of:

**File-only change** — the action requires only committing updated files in the repository (e.g. bumping a version literal, updating a changelog file). For these:

1. Make all required file changes.
2. Commit using Conventional Commits format: `chore(release): prepare <milestone-title>` (no issue reference in the commit body).
3. Push to a branch `chore/release-prep-<milestone-title>` and open a PR:
   `gh pr create --title "chore(release): prepare <milestone-title>" --body "Release prep for <milestone-title>. Milestone: <milestone-url>."`
4. Use **AskUserQuestion** to inform the user and wait for confirmation before proceeding:

   > Release prep PR opened: `<PR URL>`
   > Please merge this PR, then confirm here to continue closing the milestone.

   Do NOT proceed to Step 4 until the user confirms the PR has merged.

**Manual action** — the action cannot be performed by file edits alone (e.g. publishing to a registry, triggering a CI pipeline, running a smoke test suite, coordinating with another team). For these:

1. Use **AskUserQuestion** to surface a numbered checklist to the user with clear descriptions and wait for confirmation before proceeding:

   > Please complete the following manual steps before closing the milestone:
   > 1. [ ] `<action 1>`
   > 2. [ ] `<action 2>`
   > ...
   > Confirm here when all steps are finished.

   Do NOT proceed to Step 4 until the user confirms all steps are complete.

**No required actions** — if no version mismatches and no release instructions are found:

- Output: `✅ Pre-closure checklist: no project-specific requirements found.`
- Proceed immediately to Step 4.

---

### 4. Release Notes Composition (MANDATORY)

#### 4.1 Auto-generated base draft

Call GitHub's native release notes API to produce a base draft from merged PRs (including any release-prep PR merged in Step 3):

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

Capture the resulting Release URL from the command output. If the tag `<milestone-title>` already exists as a release, use **AskUserQuestion** to ask the user whether to delete the existing draft or choose a different tag.

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
- GitHub Release draft URL
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
