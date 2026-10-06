---
name: release-status
description: >-
  Report how a Release is tracking: progress, blocked items and items missing an effort estimate.
  Use when the user asks about milestone progress, release readiness or blockers.
argument-hint: "Optional: the Release to report on, by title or version. Defaults to the Active Release."
---

Report how one Release is tracking, in a form the user can paste into a standup note or a comment.
The report answers three questions: how much of the Release is done and which open items are being
worked on, which open items are blocked and by what, and which open items have no effort estimate.

The Release is the one the user names, matched by title substring or version with or without a
leading `v`. Without a name it is the Active Release: the earliest open Milestone by due date, with
undated Milestones last, then the lowest version, then the lowest Milestone number breaking ties.
If no open Milestone exists or the name matches none, say so in the report and stop. The Project
and the label vocabulary are in `docs/Backlog.md`. If it is missing, tell the user to run `/setup`.

Count every issue assigned to the Milestone, open and closed. Items labeled
`type:external-blocker` are Stubs, not work: leave them out of every count and percentage, and use
them only to name a blocker. Progress is closed items over all counted items. An open item is
being worked on when its Project Status is In Progress. An open item that isn't on the Project has
no Status, so list it as not checked.

An open item is blocked when at least one of its `blocked_by` dependencies is still open. When the
blocker is a Stub, name the external constraint by the Stub's title. If the dependency API is
unavailable on the repo, say so in the report instead of listing blocked items, so the missing
section isn't read as nothing being blocked.

An open item is unestimated when it has no effort label.

Lead the report with anything that needs the user's attention, such as items that couldn't be
checked, and say where each check looked. Then give the Release title, due date if set, and total,
with the issues behind each finding.

The skill only reads: it changes no issue, Project field, Milestone or label, and doesn't rank
items or recommend an order of work.
