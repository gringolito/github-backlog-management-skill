---
name: refine-item
description: >-
  Bring one backlog item up to standard: fill its gaps with the user, rewrite its body, and fix its
  labels, Rank and relationships. Use when the user wants to refine a specific issue, or when
  `refine` hands one over.
---

Refine one backlog item until it passes INVEST, then remove `needs-clarification`. The item is an
issue in the linked Project; the Project defines the backlog, so an issue outside it isn't refined.
If the user didn't give an issue number, find the item from their description and ask only if more
than one issue matches.

Fill the gaps with the user. Ask about the outcome, who it matters to, constraints, risks, edge
cases and anything the body leaves unclear, and push back on vague answers such as "make it
faster". Don't invent details. Keep what the body already says that is still right, and rewrite
only what the conversation changed. What the user can't answer becomes an open question in the
body.

The body covers what is wanted, why, what is in and out of scope, and acceptance criteria as a
checklist of specific, verifiable conditions. It needs no fixed headings and no placeholder
markers: open questions are plain prose in the body.

Judge the rewritten body against INVEST, with a short reason for each failure. Epics are exempt
from Small and Testable, which their sub-issues carry. When the item fails, write the open
questions into the body and keep `needs-clarification`, and leave labels, Rank and relationships
alone until it passes. When it fails Small, suggest splitting it, narrow the original's scope to
match, and leave creating the new items to `add-item`.

When the item passes, review what surrounds the body. The refined understanding can change the
type, priority and effort, so check each against the vocabulary and against the item's scope and
acceptance criteria. Effort measures complexity, not time. Where the right label is unclear, ask
the user.

Weigh where the item belongs in the Queue against the items already there, and look for any whose
Rank or priority now looks wrong next to it. Check that each existing blocker is still relevant,
whether refinement revealed new ones, and whether the parent should change or go. Blockers may
live in other repos or Projects, and the confirmation says so when they do. Dependencies are
recorded through the `blocked_by` API and parents through the sub-issue API. A sub-issue has one
parent, so re-parenting removes the old link. The Milestone stays as it is unless the user asks
to change it.

Make one confirmation right before writing to GitHub. It covers the new body and every label,
Rank and relationship change, on this item and on others, so the user can accept or adjust it
as a whole.

Once the changes are written, check the item as it now stands on GitHub. Remove
`needs-clarification` only if the body still passes INVEST with no open questions, the item has
one label per group and its effort fits the scope. If a check fails, keep the label and say what
remains.
