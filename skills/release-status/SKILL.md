---
name: release-status
description: >-
  Report how a Release is tracking: progress, blocked items and items missing an effort estimate.
  Use when the user asks about milestone progress, release readiness or blockers. Read-only.
argument-hint: "Optional: the Release to report on, by title or version. Defaults to the Active Release."
---

Report how one Release is tracking, as a read-only view the user can paste into a standup note or
a comment. The report answers three questions: how much of the Release is done and which open
items are being worked on, which open items are blocked and by what, and which items have no effort
estimate.

The Release is the one the user names, matched by title substring or version with or without a
leading `v`. Without a name it is the Active Release: the earliest open Milestone by due date, with
the lowest version breaking ties. If no open Milestone exists or the name matches none, say so in
the report and stop. The Project and the label vocabulary are in `docs/Backlog.md`. If it is
missing, tell the user to run `/setup`.

Count every issue assigned to the Milestone, open and closed. Items carrying the external-blocker
label are Stubs, not work: leave them out of every count and percentage, and use them only to name
a blocker. Progress is closed items over all counted items. An open item is being worked on when
its Project Status is In Progress.

An item is blocked when at least one of its `blocked_by` dependencies is still open. When the
blocker is a Stub, name the external constraint by the Stub's title. If the dependency API is
unavailable on the repo, leave blocked items out and say so in the report, so a missing section
isn't read as nothing being blocked.

An item is unestimated when it has no effort label. Only open items matter here.

Lead the report with anything that needs the user's attention, such as the dependency API being
unavailable or items that couldn't be checked, and say where each check looked. Then give the
Release title, due date if set, and total, followed by the progress, blocked and unestimated
findings. Listing the issues by status is welcome when the Release is small enough to read.

The report is the whole output, with no preamble. It describes state only, and never ranks items,
recommends an order of work, or changes an issue, Project field, Milestone or label.
