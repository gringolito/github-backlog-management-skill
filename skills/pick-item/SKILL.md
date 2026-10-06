---
name: pick-item
description: >-
  Choose the next backlog item to work on, check that it is ready and assign it to you. Use when
  the user wants to start the next item.
---

Select the next item to work on, verify it can be worked, and assign it to the user. The skill is
done when that item is assigned.

Items are ranked within projects or milestones. Look into the user's named milestone first, or
else the open milestone, and ask which one when several are open. Then look at items without a
milestone. The top of the queue wins.

Skip an item that is blocked, or labelled `needs-clarification` or `type:external-blocker`. Use
GitHub's blocked-by API to resolve blockers, where a closed blocker no longer counts. When every
candidate is blocked, list each blocker with its state.

When the top item has open sub-issues, pick the topmost one that qualifies instead. An epic with
no sub-issues is not workable; ask the user to decompose it.

Read the item's comments and, when it has a parent, also read the parent's context.

Check whether the item has enough information to be worked on. If context or relevant information
is missing, comment on the item saying what is missing, add the `needs-clarification` label, and
move on to the next item.

Self-assign the issue.
