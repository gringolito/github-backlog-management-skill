---
name: migrate
description: >-
  Import an existing backlog, such as a TODO.md or BACKLOG.md file or another source the user
  provides, into GitHub Issues in the Project. Use when the user has work items outside GitHub and
  wants them in the backlog.
argument-hint: "Optional: the backlog to import, such as a file path."
---

Import the backlog given as the argument, or the one the user names. When you finish, every item
in the source that isn't done and that the user kept is an issue in the Project, linked by the
dependencies the user accepted, and the user has a report of what was created and what needs
their attention.

Don't edit the source: once imported, GitHub is the source of truth. Skip done items, which are
history and would only clutter the Project. Import every other item, whatever its status.

Split the source into items even when it's poorly structured. Import items that look like
duplicates, or that should be split, as written, and flag them in the report, since merging or
splitting changes what the user wrote.

Read blocking and parent relationships from the source's prose, and match each to another imported
item or to an existing issue in the repo. A reference you can't match, including one to a skipped
done item, goes in the report instead of a guess. Inferred dependencies produce false positives,
and a false blocker keeps an item out of the Queue, so record one only after the user accepts it.

Before adding anything, show the items you'll import, the done items you skipped so the user can
revive any, and the dependencies with their evidence. If the dependencies form a cycle, mark it,
since the items can't be added in order until the user rejects one link. The user adjusts the
list, and you revise until they approve it.

Then add each approved item with the `add-item` skill, passing its source text as the request and
its accepted relationships as the ones the user named. Keep the item's intent and wording. Don't
invent what the source doesn't say: each gap becomes an open question in the body. Add blockers
and parents first, so the issues they point to exist when the links are recorded.

A constraint outside the repo that the source mentions goes in the report, not in a stub.

If adding an item fails, don't add the rest, since later items may point to it. Don't roll back or
recreate issues already created: the user may already have linked to them, and recreating would
duplicate them.

End with a migration report. Lead with what you need from the user: the items marked
`needs-clarification`, every flag and suggestion noted above, and any failure with what was
created and what wasn't attempted. Then list the issues created, each linked to its source title,
and the Milestone they were assigned to, if any. Mark what you couldn't check and where you looked.
