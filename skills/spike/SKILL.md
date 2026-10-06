---
name: spike
description: >-
  Investigate a type:spike backlog item and deliver a findings pull request with follow-on items.
  Use once a spike is selected, from pick-item's hand-off or directly.
---

Run a spike from its question to a pull request that closes it. The deliverable is knowledge: a
findings document that answers the spike's question and recommends a path, and backlog items for
the work the recommendation implies. The done state is that pull request open, with the user's
sign-off on the findings and every approved follow-on item created.

The skill stops to ask the user in two places: when the question or scope is unclear, and once for
sign-off on the findings. Read the spike and its comments, and its parent if it has one. Clear up
anything unclear before investigating.

Investigate on a branch, using whatever answers the question: docs, source, experiments.
Prototypes are allowed but only to answer the question, and are thrown away. Findings that say
"abandon" or "not feasible" are valid outcomes.

Write the findings to `docs/spikes/<nnnn>-<slug>.md`, where `<nnnn>` is the next unused four-digit
index in that folder. The document restates the question, says what was investigated and which
sources and prototypes were used, reports what was learned including dead ends, gives the
recommendation, and lists the follow-on work.

Once the document is drafted, present a concise summary of the findings and recommendation, with
the follow-on items you propose. This is the sign-off. Don't create any item before it, and apply
any amendments or discarded items without asking again.

Create the approved follow-ons through `add-item`, one per independently deliverable piece of work,
never a bundle of unrelated tasks. When the spike has a parent, the follow-ons become that parent's
sub-issues, otherwise they're standalone items. Each one refers back to the spike so the origin is
traceable. Then fill in the document's follow-on work with the new issue numbers.

The pull request contains only the findings document, since code belongs in the follow-on items.
Its body includes `Closes #<spike>` and lists the follow-ons created, so reviewers can check that
surfaced work reached the backlog, and it carries the spike's milestone if there is one.
