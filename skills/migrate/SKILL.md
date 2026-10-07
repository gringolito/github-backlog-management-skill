---
name: migrate
description: >-
  Import an existing backlog, such as a TODO.md or BACKLOG.md file or another source the user
  provides, into GitHub Issues in the Project. Use when the user has work items outside GitHub and
  wants them in the backlog.
argument-hint: "Optional: the backlog to import, such as a file path."
---

Import an existing backlog, such as a TODO.md or BACKLOG.md file, or another source the user
provides. When you finish, every item in the source that isn't done and that you could resolve is
an issue in the Project.

Don't edit the source: once imported, GitHub is the source of truth. Skip done items, which are
history and would only clutter the Project. Import every other item, whatever its status.

Split the source into items even when it's poorly structured. Import items that look like
duplicates, or that should be split, as written, and flag them in the report, since merging or
splitting changes what the user wrote.

Read blocking and parent relationships from the source's prose, and match each to another imported
item or to an existing issue in the repo. A reference you can't match, including one to a skipped
done item, goes in the report instead of a guess.

Import the items and dependencies you're confident in without asking for approval. Leave what you
can't resolve yourself to the report, so the user decides what to do next. If the dependencies
form a cycle, create the items without the conflicting link and report it.

Use the `add-item` skill to create the issues. It runs without asking the user, since the source
is the request. Don't invent what the source doesn't say: each gap becomes an open question in the
body. An item that fails INVEST is still created, with the failure written as an open question in
the body and `needs-clarification` added. Add blockers and parents first, so the issues they point
to exist when the links are recorded.

End with a migration report. Lead with what the user needs to decide: the items and dependencies
you left out, the items marked `needs-clarification`, and the flags noted above. Then list the
issues created, each linked to its source title, and the done items you skipped, so the user can
revive any. Mark what you couldn't check and where you looked.
