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

Read the spike issue and its comments, and its parent if it has one. Clear up anything unclear
before investigating.

Prototypes are allowed but only to answer the question, and are thrown away. Findings that say
"abandon" or "not feasible" are valid outcomes.

Write the findings to `docs/spikes/<nnnn>-<slug>.md`, where `<nnnn>` is the next unused four-digit
index in that folder. The document restates the question, says what was investigated and which
sources and prototypes were used, reports what was learned including dead ends, gives the
recommendation, and lists the proposed follow-on items. Keep the findings clean, tight, concise,
technical and direct.

Open the pull request with only the findings document and the spike's milestone, if it has one.
Keep monitoring it for reviews and feedback and apply them. Make sure the pull request body
includes a footer `Closes #<spike>`.

Once the user approves the pull request, create the follow-on items through `add-item`. When the
spike has a parent, they become that parent's sub-issues. Each one refers back to the spike. Write
their issue numbers into the findings document and push. Never merge the pull request without the
user's explicit consent.
