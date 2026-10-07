---
name: migrate
description: >-
  Import an existing backlog file, such as a TODO.md or BACKLOG.md, into GitHub Issues in the
  Project. Use when the user has a list of work items outside GitHub and wants them in the backlog.
argument-hint: "Optional: the path to the backlog file to import."
---

Import the backlog file given as the argument, or the one the user names. When you finish, every
item in the file that isn't done and that the user kept is an issue in the Project with a body,
labels, dependencies and a Rank, all approved by the user beforehand, and the user has a report of
what was created and what needs their attention.

Don't edit the file: once imported, GitHub is the source of truth. Skip done items, which are
history and would only clutter the Project. Import every other item, whatever its status.

Split the file into items even when it's poorly structured, and keep each item's intent and
wording. Write each issue's title and body from its source text.

The body covers what, why, scope in and out, and acceptance criteria, without fixed headings.

Give each item one type, one priority and one effort label from the vocabulary. Effort measures
complexity, not time.

Judge each item against INVEST. Epics are exempt from Small and Testable, which their sub-issues
carry.

Don't invent what the source doesn't say, such as a reason, a scope boundary or an acceptance
criterion. Write each gap, each label you can't decide and each INVEST failure as an open question
in plain prose in the body, and add `needs-clarification`. Don't rewrite an item to make it pass
INVEST; suggest the improvement in the report.

Import items that look like duplicates, or that should be split, as written, and flag them in the
report, since merging or splitting changes what the user wrote.

Read blocking and parent relationships from the source's prose, and match each to another imported
item or to an existing issue in the repo. A reference you can't match, including one to a skipped
done item, goes in the report instead of a guess. Inferred dependencies produce false positives,
and a false blocker keeps an item out of the Queue, so record one only after the user accepts it.

Propose a Rank for every item, relative to the items already queued and to each other. A blocker
ranks above what it blocks.

If there's an open Milestone, propose assigning the items to it. When several are open and the
user hasn't named one, list them in the proposal and let the user choose.

For a large file, split the items across subagents. Give each the label vocabulary, these rules
and its items, and ask for the labels, open questions and dependencies with the source passage each
came from. Check each result against the source before using it, and drop what the passage doesn't
support. Duplicates, dependencies across batches and Rank belong to you.

Before writing anything to GitHub, present the whole import at once. For each item show the title,
labels, one line on what it covers, its open questions and its Rank. Then show the dependencies
with their evidence, the Milestone, and the done items you skipped, so the user can revive any. If
the dependencies form a cycle, mark it, since the issues can't be created in order until the user
rejects one link. The user adjusts the proposal, by dropping items, changing labels, rejecting
dependencies or reordering, and you revise until they approve it. That one approval covers
everything.

Create the approved items in an order that puts blockers and parents first, so the issues they
point to exist when the links are recorded. Add each issue to the Project at its Rank and to the
approved Milestone, if any, then record the accepted dependencies with GitHub's `blocked_by` API
and the parent links as sub-issues. Don't create external-blocker Stubs. A constraint outside the
repo that the source mentions goes in the report.

If creating an issue fails, don't attempt the rest, since the approved order assumes each earlier
issue exists. If a later step for a created issue fails, note it and continue. Don't roll back or
recreate created issues: the user may already have linked to them, and recreating would duplicate
them.

End with a migration report. Lead with what you need from the user: the items marked
`needs-clarification`, every flag and suggestion noted above, and any failure with what was
created and what wasn't attempted. Then list the issues created, each linked to its source title,
and the Milestone they were assigned to, if any. Mark what you couldn't check and where you looked.
