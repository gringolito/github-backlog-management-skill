---
name: health
description: >-
  Report on the overall shape of the backlog: distribution, age, overdue priorities, stalled work and
  missing labels. Use when the user asks how healthy the backlog is or wants a portfolio overview.
---

Produce a read-only report on the shape of the whole backlog. It changes nothing, and it describes
the state without recommending what to triage or work on next.

The Project and the label vocabulary are in `docs/Backlog.md`, linked from the repo's `CLAUDE.md` or
`AGENTS.md`. If the file is missing, tell the user to run `/setup` and stop.

Cover every open issue except Stubs (`type:external-blocker`), which are constraints and not work.
Closed issues are out. Measure ages in UTC days from creation, and last activity from the last update.

The report answers these questions:

- How many open issues are there, and how many of them are in the Project?
- How are they distributed by type, priority and effort? Show count and percentage per value, rounded
  to whole numbers, and count items with no label in a group as unlabeled.
- How old are they? Group by time open: under 7 days, 7 to 30, 30 to 90, and over 90.
- Which P0 items have been open over 14 days, and which P1 items over 30? Give each one's age and
  assignee.
- Which items being worked on, meaning In Progress in the Project, have had no activity for more than
  7 days?
- Which items are missing a type, priority or effort label, and which of the three?

Where a question has no hits, say so in a line instead of leaving it out. Link each issue the report
names.

Lead the report with what the user needs to act on, if anything: a missing configuration, a question
the skill couldn't answer. Mark every section it couldn't compute, for example when Project status is
unavailable and the stalled-work question can't be answered, and say where it looked.
