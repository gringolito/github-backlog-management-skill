---
name: release-status
description: >-
  Report how a Release is tracking: progress, blocked items and items that need clarification.
  Use when the user asks about milestone progress, release readiness or blockers.
argument-hint: "Optional: the Release to report on, by title or version."
---

Report how one Release is tracking, in a form the user can paste into a standup note or a comment.
The report answers four questions: how far along the Release is, how many items are in progress,
which open items are blocked and by what, and which items need clarification.

The Release is the open Milestone. If several are open, ask which one. If the user names a Release,
match it by title substring or by version, with or without a leading `v`.

An item is in progress when its Project Status says so. Use the `blocked_by` GitHub API for
blockers. An item needs clarification when it carries the `needs-clarification` label.

The skill only reads: it changes no issue, Project field, Milestone or label.
