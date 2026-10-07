---
name: refine
description: >-
  Run a refinement session over backlog items that need clarification, are missing a type,
  priority or effort label, or are parked ideas. Use when the user wants to clean up the backlog
  or refine several items in one sitting. To refine a single item, use `refine-item`.
---

Run a refinement session. When it ends, the items the user picked have each been through
`refine-item`.

Candidates are open issues in the linked Project that carry `needs-clarification`, lack a type,
priority or effort label, or are ideas labeled `type:idea`. Ideas and external-blocker stubs carry
only their type by design, so a missing priority or effort doesn't make them candidates. Issues
outside the Project are ignored, because the Project defines the backlog. If there are no
candidates, say so and finish.

Show the candidates grouped by why they qualify, most urgent priority first and unprioritized last,
with ties broken by Rank, then issue number. An item that needs clarification and also lacks a
label goes in the `needs-clarification` group. Ideas form a group of their own, shown last in Rank
order. Include each item's number, title, priority and Milestone, and let the user pick which to
refine: a few, a range, all, or all but some. This is the only question before the work starts.

Hand each picked item to `refine-item` in turn, in the order shown. Don't prompt between items. The
user can stop at any time, and rerunning the session rebuilds the candidates, so refined items drop
out on their own.
