---
name: add-item
description: >-
  Turn a request into one well-formed, ranked backlog item. Use when the user wants to add, file
  or capture a new feature, bug, task or spike in the backlog.
---

Create one backlog item from the user's request. When you finish, an issue exists in the Project
with a clear body, one type, one priority and one effort label, a Rank in the Queue, and the
blockers, blocked items and parent the user named.

Ask questions until the request is unambiguous: the desired outcome, who benefits and why,
constraints, risks, edge cases and what is out of scope. Challenge vague requests and don't invent
requirements. Also ask whether open issues block this one, whether it blocks any, and whether it is
a sub-issue of a parent. Blockers may live in other repos or Projects.

Write a short, specific title and a body that covers what is wanted, why, what is in and out of
scope, and acceptance criteria. The criteria are a checklist of specific, verifiable conditions.
It doesn't repeat the labels, blockers, parent or Milestone, which live in labels and GitHub's
relationships. A question the user can't answer yet goes in the body as plain prose, and the item
gets `needs-clarification`.

Check the body against INVEST before creating anything. Epics are exempt from Small and Testable,
which their sub-issues carry. When an item fails, say which letter and why, propose a fix such as
narrowing, splitting or sharper criteria, and create nothing until it passes. Split an item that
mixes several problems, and make exploratory work a `type:spike`.

Apply exactly one type, one priority and one effort label from the vocabulary. Effort measures
complexity, never time. Ask when a group can't be decided from the conversation. Never use
`type:external-blocker`: it marks stubs for external constraints.

A sub-issue inherits nothing from its parent, so set its Milestone, priority, effort, type and
Rank on their own.

Execution order comes from Rank, so propose a position in the Queue by comparing the item with the
open ones, not by defaulting to the bottom. Weigh impact, risk, urgency, how often the gap bites,
and dependencies: an item goes above what it unblocks and below what it depends on. Priority and
Rank should agree, with P0 near the top and P3 near the bottom, so say so and give the reason when
the proposal diverges. If existing items look misranked next to the new one, suggest a move for
each, and apply it only if the user agrees.

When an open Milestone exists, ask whether the item belongs in it, and which one when several
are open. Adding to a Milestone changes its scope, so that is the user's call.

Create the issue once the questions are settled, recording blockers with the `blocked_by` API and
the parent with the sub-issue API. Report what was created so the user can correct it.
