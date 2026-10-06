---
name: health
description: >-
  Report on the overall shape of the backlog: distribution, age, overdue priorities, stalled work and
  missing labels. Use when the user asks how healthy the backlog is or wants a portfolio overview.
---

Produce a read-only report on the shape of the whole backlog. It describes the state without
recommending what to triage or work on next, and it asks the user nothing. The report is the finished
result.

The Project and the label vocabulary are in `docs/Backlog.md`, linked from the repo's `CLAUDE.md` or
`AGENTS.md`. If the file is missing, tell the user to run `/setup` and stop.

Cover every open issue except Stubs, which are constraints and not work. Measure ages in UTC days from
creation, and last activity from the last update.

The report answers these questions:

- How many open issues are there, and how many of them are in the Project?
- How are they distributed by type, priority and effort? Show count and percentage per value, rounded
  to whole numbers, with items missing a label in a group counted as unlabeled.
- How old are they? Group by time open: under 7 days, 7 to 30, 30 to 90, and over 90.
- Which P0 items have been open over 14 days, and which P1 items over 30? Give each one's age and
  assignee.
- Which items being worked on, meaning In Progress in the Project, have had no activity for more than
  7 days? Give the date of the last activity.
- Which items are missing a type, priority or effort label, and which of the three?

Where a question has no hits, say so in a line instead of leaving it out. Link each issue the report
names.

Lead the report with anything the user needs to act on. Mark each question it couldn't answer, for
example when the Project's Status is unavailable and stalled work can't be found, and say where it
looked.
