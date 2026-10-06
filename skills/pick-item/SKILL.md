---
name: pick-item
description: >-
  Choose the next backlog item to work on, assign it to you and agree a plan. Use when the user
  wants to start the next item or resume one already assigned to them.
---

Choose the next item to work on, assign it to the user, and agree an implementation plan with them. The skill is done when the item is assigned and the user has approved the plan. It stops to ask in four cases: whether to resume an item already assigned to the user or pick a new one, what to do with a parent whose sub-issues are all closed, an epic that needs decomposing, and the plan.

The Project and the label vocabulary are in the repo's `docs/Backlog.md`, linked from its `CLAUDE.md` or `AGENTS.md`. If that configuration is missing, point the user to `/setup`.

Items come from the Project. Look in the Active Release first, then at items without a milestone. The top of the Queue wins.

Items already assigned to the user come first: list them with their PR status and ask whether to resume one. Resuming skips selection and goes straight to the plan, which starts from the existing branch and PR.

An item is skipped when it is blocked, a Stub (`type:external-blocker`), or labelled `needs-clarification`. The skill doesn't judge whether an item is well formed; that label is the signal that it isn't, and the user can run `/refine-item` on it. Blocked means it has an open `blocked_by` dependency in GitHub's issue dependencies; a closed blocker no longer counts. A blocked item is never picked, even if the user asks, because its blocker would stop the work midway. If the dependency API is unavailable, carry on without block checks and warn the user. When every candidate is blocked, say so and list each blocker with its state, who holds it, and whether it looks stale, in progress, unassigned or external.

A parent is never worked directly. When the top item has open sub-issues, go into them and pick the topmost one that qualifies. When all of its sub-issues are closed, run a scope completeness review: map each acceptance criterion of the parent to the closed sub-issue that covers it, and show the user the coverage. Ask whether to close the parent as complete, posting the coverage as a comment, or to create sub-issues with `/add-item` for the uncovered criteria. An epic with no sub-issues is not workable; ask the user to decompose it.

Read the item's body by content, not by headings, since items exist in more than one shape. Read its comments and, when it has a parent, the parent's what and why. If the item's priority label looks out of line with its Queue position, mention it in the plan.

Assign the item to the user. GitHub moves its Status on its own. A `type:spike` item is handed to `/spike` once the plan is approved, and its plan describes the investigation and the findings rather than a code change.

Propose a concise implementation plan that covers every acceptance criterion, stays inside the scope, and fits the parent's context. Research online when the approach needs it. Wait for the user's approval before handing the item over, and don't make assumptions the user could settle with a question.

When the item is too large for one iteration, propose a split instead: each sub-issue with a title, what, why, acceptance criteria and labels, and how together they cover the parent's criteria. On approval, create the sub-issues with `/add-item` under the parent, unassign the parent, and pick the first sub-issue. Where siblings depend on each other, record that as `blocked_by` directly and include it in the proposal, so one approval covers all of it.

Issues are closed by the PR's `Closes #N`, never by hand. The exceptions are a parent closed after the scope completeness review, and a spike closed by its own PR.
