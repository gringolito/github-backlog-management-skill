---
name: audit
description: >-
  Check the backlog for missing or conflicting labels, malformed items, broken dependencies and
  milestone inconsistencies, and get a fix for each finding. Read-only. Use before planning or
  releasing, or when the backlog feels untrustworthy.
---

Check whether the open items in the repo's backlog are well-formed and consistent, and give the
user a fix for every problem found. The audit changes nothing: no issue, label, Project or
Milestone.

Read the Project and the label vocabulary from `docs/Backlog.md`, which the repo's `CLAUDE.md` or
`AGENTS.md` links to. If the file is missing, tell the user to run `/setup` and stop. The audit
asks nothing else, because it changes nothing.

Audit every open issue in the Project.

An item carries exactly one type, one priority and one effort label, all from the vocabulary. Flag
missing groups, duplicates within a group, and labels outside the vocabulary. Flag any type label
whose description is blank, since the description tells people when to apply it.

Check that priority and effort fit the item. Flag inversions, a backlog where more than half the
items are P0, and acceptance criteria much deeper or shallower than the effort label suggests. An
XL item probably needs splitting.

The body states what is wanted, why, what is in and out of scope, and acceptance criteria. Check
that content, whatever the headings. Treat a what, why, scope or acceptance-criteria part that
holds only a placeholder as missing. Acceptance criteria should be a checklist of specific,
verifiable conditions. Flag vague ones such as "works correctly", and criteria that reach beyond
the stated scope.

Judge each item against INVEST and give a short reason for every failure. Epics are exempt from
Small and Testable, which their sub-issues carry. An epic with no sub-issues hasn't been
decomposed, so suggest adding `needs-clarification`.

Flag items that mix several problems or overlap another item; the fix is to split or merge them.

External blocker stubs, the items typed `type:external-blocker`, follow their own rules. They
carry no priority, effort or full body, but they need a stated reason that explains the specific
constraint. Flag a reason that is missing, empty or generic, such as "TBD" or "external
dependency". Flag an open stub that blocks nothing.

Read each item's `blocked_by` relationships. A blocker that can no longer be resolved is dangling.
A cycle is a defect even though GitHub rejects direct ones, because transfers and deletions can
leave indirect ones.

A closed blocker is satisfied and needs no report. A blocker outside the Project is allowed, but
surface it so the user can confirm it's intended. Collect open blockers in other repos together,
each with the item it holds up.

Call out blocked P0 items and blocked items near the top of the Queue, since they look ready and
aren't. When the blocker is an external blocker stub, name it alongside the blocked item.

Flag a child in the Project whose parent isn't in it, because the parent carries the epic-level
view. A child's milestone may differ from its parent's, since sub-issues don't inherit, but
mention it in case it's accidental.

Flag open issues assigned to a closed Milestone, with a fix that clears the assignment rather than
choosing a new one. Flag issues with a Milestone that aren't in the Project, since the Queue never
offers them.

For a large backlog, split the items across general-purpose subagents. Give each the vocabulary,
these rules and its batch, and ask for findings that quote their evidence: the label, the body
passage or the dependency record. Check each finding's evidence against the issue before
accepting it, and drop what doesn't hold. Findings that compare items, such as duplicates,
priority skew and cycles, belong to you.

Link every finding's issue and pair it with a fix the user can run as written, such as a label
edit, a milestone change or a dependency removal. When the fix needs a decision, such as which of
two duplicates survives, say so and recommend one. Order findings by how much they hurt: what
breaks picking and planning first, then quality problems, then consistency smells.

Lead the report with what you need from the user, if anything. Then mark what you couldn't check
and why, for example when the dependency data was unavailable on this plan, and say where you
looked.
