---
name: audit
description: >-
  Check the backlog for missing or conflicting labels, malformed items, broken dependencies and
  milestone inconsistencies, and get a fix for each finding. Read-only. Use before planning or
  releasing, or when the backlog feels untrustworthy.
---

Check whether the open items in the repo's backlog are well-formed and consistent, and give the
user a fix for every problem found. When you finish, the user has one report they can act on
without re-deriving anything. The audit changes nothing: no issue, label, Project or Milestone.

Read the Project and the label vocabulary from `docs/Backlog.md`, which the repo's `CLAUDE.md` or
`AGENTS.md` links to. If the file is missing, point the user to `/setup` and stop. The audit asks
the user nothing else, since it has no writes to confirm.

Audit every open issue in the Project. Judge each item against the following.

Labels. An item carries exactly one type, one priority and one effort label, all from the
vocabulary. Flag missing groups, duplicates within a group, and labels outside the vocabulary.
Flag any type label whose description is blank, since the description is what tells people when to
apply it. Priority should follow impact, risk and urgency, and effort should follow complexity
rather than time. Flag inversions, a backlog where more than half the items are P0, and items
whose acceptance criteria are much deeper or shallower than their effort label suggests. An XL
item probably needs splitting.

Body. The body states what is wanted, why, what is in and out of scope, and acceptance criteria.
Check that content, not headings, so items in the old six-section shape pass, and treat a section
that holds only a placeholder such as `_No response_` as missing. Acceptance criteria should be a
checklist of specific, verifiable conditions. Flag vague ones such as "works correctly", and
criteria that reach beyond the stated scope. Flag items that mix several problems.

INVEST. Judge each item against it and give a short reason for every failure. Epics are exempt
from Small and Testable, which their sub-issues carry. An epic with no sub-issues hasn't been
decomposed, so suggest adding `needs-clarification`. Also flag items that duplicate or overlap
another; the fix is to merge or split them.

External blocker stubs, the items typed `type:external-blocker`, follow their own rules. They
carry no priority, effort or full body, but they need a type label and a stated reason that
explains the specific constraint. Flag a reason that is missing, empty or generic, such as "TBD"
or "external dependency". Flag an open stub that blocks nothing, since it gates no work.

Dependencies. Read each item's `blocked_by` relationships. A blocker that can no longer be
resolved is dangling. A cycle in the graph is a defect even though GitHub rejects direct ones,
because transfers and deletions can leave indirect ones. A closed blocker no longer gates its
item, so it is worth reporting only when it was closed as not planned, because the work it stood
for never happened. A blocker outside the Project is allowed, but surface it so the user can
confirm it's intended. Collect open blockers in other repos in one place with the item each one
holds up. Call out blocked P0 items and blocked items near the top of the Queue, since they look
ready and aren't. For a blocker that is an external blocker stub, name the stub alongside the
blocked item.

Sub-issues and milestones. A child in the Project whose parent isn't in it should be flagged,
because the parent normally carries the epic-level view. A child's milestone may differ from its
parent's, as sub-issues don't inherit, but mention it in case it's accidental. Flag open issues
assigned to a closed Milestone, with a fix that clears the assignment rather than choosing a new
one. Flag issues with a Milestone that aren't in the Project, since the Queue never offers them.

For a large backlog, split the items across general-purpose subagents. Give each the vocabulary,
these rules and its batch, and ask for findings that quote their evidence: the label, the body
passage or the dependency record. Check each finding's evidence against the issue before
accepting it, and drop what doesn't hold. Findings that compare items, such as duplicates,
priority skew and cycles, belong to you.

Report findings in the order of how much they hurt: first what breaks picking and planning, such
as missing labels, dangling blockers and cycles, then quality problems, then consistency smells.
Leave out any category with nothing in it. Link every finding's issue and pair it with a fix the
user can run as written, such as a label edit, a milestone change or a dependency removal. Where
the fix needs a decision, such as which of two duplicates survives, say so and recommend one.

Lead the report with what you need from the user, if anything. Then mark what you couldn't check
and why, for example when the dependency data was unavailable on this plan, and say where you
looked: the Project, the issues, the milestones and the dependency data. A clean result says what
was covered.
