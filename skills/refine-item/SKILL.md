---
name: refine-item
description: >-
  Bring one backlog item up to standard and clear its `needs-clarification` label, or turn a parked
  idea into a defined item. Use when the user wants to refine a specific issue or idea, or when
  `refine` hands one over.
---

Refine one backlog item until it passes: the body passes INVEST with no open questions, the item
has one type, one priority and one effort label, and the effort fits its scope. Then remove
`needs-clarification`. The item is an issue in the linked Project; the Project defines the backlog,
so an issue outside it isn't refined. If the user didn't give an issue number, find the item from
their description and ask only if more than one issue matches.

Fill the gaps with the user. Ask about the outcome, who it matters to, constraints, risks, edge
cases and anything the body leaves unclear, and push back on vague answers such as "make it
faster". Don't invent details. Keep what the body already says that is still right, and rewrite
only what the conversation changed.

The body covers what is wanted, why, what is in and out of scope, and acceptance criteria as a
checklist of specific, verifiable conditions. What the user can't answer is written into the body
as an open question in plain prose. Keep the body clean, tight, concise, technical and direct.

An idea, labeled `type:idea`, was parked without being defined, so refining it defines it from
scratch. Ask all the questions above, and write the whole body from the user's original words and
the answers. When it passes, replace `type:idea` with a type from the vocabulary and add a priority
and an effort. It sat at the bottom of the Queue, so it needs a real position among the defined
items. If the conversation shows the idea isn't worth doing, offer to close it as not planned.

Judge the rewritten body against INVEST, with a short reason for each failure. Epics are exempt
from Small and Testable, which their sub-issues carry. When a defined item fails, keep
`needs-clarification` and leave labels, Rank and relationships alone until it passes. When it fails
Small, suggest splitting it, narrow the original's scope to match, and leave creating the new
items to `add-item`.

An idea that fails is the user's call: keep it an idea, still carrying only `type:idea`, with what
was learned written into its body, or make it a defined item now with a type, priority, effort and
Rank, flagged `needs-clarification`.

When the item passes, review what surrounds the body. The refined understanding can change the
type, priority and effort, so check each against the vocabulary and against the item's scope and
acceptance criteria. Where the right label is unclear, ask the user.

Weigh where the item belongs in the Queue against the items already there, and look for any whose
Rank or priority now looks wrong next to it.

Check that each existing blocker is still relevant, whether refinement revealed new ones, and
whether the parent should change or go. Blockers may live in other repos or Projects; flag those
when you propose them. Dependencies are recorded through the `blocked_by` API and parents through
the sub-issue API.

The Milestone stays as it is unless the user asks to change it.

Remove `needs-clarification` once the changes are written and the item as it now stands on GitHub
still passes. If a defined item doesn't, keep the label. Report what the item still needs from the
user first, then what changed.
