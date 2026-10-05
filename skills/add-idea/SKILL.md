---
name: add-idea
description: Capture a rough idea in the backlog without defining or sizing it. Use when the user wants to jot something down to refine later.
---

# add-idea

Create a `type:idea` issue at the bottom of the backlog. An Idea is a Non-Workable Item: it has no priority, no effort, no acceptance criteria, and it skips INVEST. The point is speed. The user has a thought and no time to define it, so take what they give you and file it.

Ideas become Workable Items later through `/refine-item` (or `/refine`, which lists them in their own pool).

## Workflow

### 0. Preflight

Read [../github-backlog-management/preflight-contract.md](../github-backlog-management/preflight-contract.md) and follow it exactly.

### 1. Input

Take the idea text from the skill argument or the conversation. If there is none, ask once: "What's the idea?" and wait.

Do NOT run discovery. Do NOT ask about impact, scope, acceptance criteria, priority, effort, blockers, or milestones. If the user volunteers extra context (links, constraints, open questions), keep it for `### Notes`.

If the user clearly wants to define the item properly right now, stop and point them to `/add-item`.

### 2. Draft

- Title: a short, specific summary of the idea in the user's terms. No `Idea:` prefix; the label already says it.
- Body: match the idea Issue Forms template exactly:

  ```
  ### Idea

  <the idea, in the user's words; fix typos, don't turn it into requirements>

  ### Notes

  <extra context the user gave, or _No response_>
  ```

Show the title and body. Create it unless the user objects; don't make them approve a one-liner.

### 3. Create

Write the body to a temp file (e.g. `/tmp/add-idea-body.md`) and the manifest to `/tmp/add-idea-manifest.json`:

```json
{
  "title": "<title>",
  "body_file": "/tmp/add-idea-body.md",
  "labels": ["type:idea"]
}
```

Run `create-item --input /tmp/add-idea-manifest.json`.

Leave out `rank`, `rank_adjustments`, `milestone`, `parent`, `blocked_by`, and `blocking`. Without `rank`, GitHub appends the new Project item at the end of the Todo column, below every Workable Item, which is where Ideas belong.

Branch on the exit code:

- Exit 0: success.
- Exit 2: the issue was created but a post-creation step warned. Report it as created and surface the warnings. Do NOT retry.
- Any other non-zero exit: nothing was created. Surface stderr verbatim.

## Rules

- Labels: `type:idea` only. NEVER add `priority:*`, `effort:*`, `needs-clarification`, a milestone, or an assignee.
- NEVER run `invest-gate`, `label-classifier`, `rank-recommender`, or `issue-body-author` on an Idea.
- NEVER rank an Idea above a Workable Item.
- One idea per issue. If the user lists several, create one issue each.
- Surface all `gh` errors verbatim.

## Output

- Issue URL and number
- Title
- Any warnings from `create-item`, verbatim
- Reminder: `Refine it when you're ready: /refine-item #<n>`
