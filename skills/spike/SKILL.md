---
name: spike
description: >-
  Investigate a spike issue and deliver a findings pull request with follow-on items.
  Use once a spike is selected or when the user wants to conduct a spike.
---

Run a spike from its question to a pull request that closes it. The deliverable is knowledge: a
findings document that answers the spike's question and recommends a path, and backlog items for
the work the recommendation implies. The done state is the pull request merged and the follow-on
items created.

Read the spike and its comments, and its parent if it has one. Clear up anything unclear before
investigating, and run autonomously from there.

Prototypes are allowed but only to answer the question, and are thrown away. Findings that say
"abandon" or "not feasible" are valid outcomes. Keep all communication clean, tight, concise,
technical and direct.

Write the findings to `docs/spikes/<nnnn>-<slug>.md`, where `<nnnn>` is the next unused four-digit
index in that folder. The document restates the question, says what was investigated and which
sources and prototypes were used, reports what was learned including dead ends, gives the
recommendation, and lists the proposed follow-on items.

Open the pull request without waiting for feedback. It contains only the findings document, since
code belongs in the follow-on items, and its body includes `Closes #<spike>`. The review is the
user's sign-off, so keep monitoring the pull request for reviews and feedback and apply them.

Once the user approves the pull request, create the follow-on items through `add-item`. When the
spike has a parent, they become that parent's sub-issues. Each one refers back to the spike. Write
their issue numbers into the findings document and push.
