---
name: refine
description: >-
  Run a refinement session over backlog items that need clarification or are missing a type,
  priority or effort label. Use when the user wants to clean up the backlog or refine several items
  in one sitting. To refine a single item, use `refine-item`.
---

Run a refinement session. When it ends, the items the user picked have each been through
`refine-item`.

The Project and the label vocabulary come from the repo's `docs/Backlog.md`, linked from its
`CLAUDE.md` or `AGENTS.md`. If that configuration is missing, point the user to `/setup` and stop.

Candidates are open issues in the linked Project that carry `needs-clarification` or lack a type,
priority or effort label. Issues outside the Project are ignored, because the Project defines the
backlog. If there are no candidates, say so and finish.

Show the candidates grouped by why they qualify, most urgent priority first and unprioritized last,
with ties broken by Rank, then issue number. An item that qualifies for both reasons goes in the
`needs-clarification` group. Include each item's number, title, priority and Milestone, and let the
user pick which to refine: a few, a range, all, or all but some. This is the only question before
the work starts.

Hand each picked item to `refine-item` in turn, in the order shown. Don't prompt between items. The
user can stop at any time, and rerunning the session rebuilds the candidates, so refined items drop
out on their own.
