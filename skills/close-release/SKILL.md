---
name: close-release
description: >-
  Close a Milestone and publish its release. Use when a Release is done, or the user says "close
  the release", "cut the release" or "ship the milestone".
argument-hint: "Optional: the Milestone title or version. Defaults to the open Milestone due soonest."
---

Close a Release. When you finish, no open item is left in the Milestone, the repo carries whatever
the release needs, the release and its tag are published with reviewed notes, and the Milestone is
closed.

The user may name the Milestone by title or version. Otherwise use the open one with the earliest
due date, and ask which when several are open and none has a due date.

Every open item in the Milestone gets the user's decision: carry it to the next open Milestone,
close it as won't fix with a comment saying it wasn't included in this release, or drop its
Milestone and leave it open in the backlog. Present all open items together and apply the choices
once the user has answered. If the user carries items forward and no other Milestone is open, say
so and ask for another choice.

Prepare the repo as its own instructions describe. Read [pre-closure.md](./pre-closure.md) for
where to look and how to handle what you find.

Draft the release notes from the merged PRs, then add what the PR list misses: breaking changes,
new features, configuration or schema changes and migration steps from the closed items. Read
those items by content, whatever shape their bodies have. Show the draft and apply the user's
edits until they approve it.

Publishing the release and its tag is visible to everyone at once and can't be quietly taken back,
so confirm once before it, naming the tag, the commit it points at and the notes. The tag and the
release title are the Milestone title. Tag the default branch, after any release-prep PR has
merged. Once published, close the Milestone. A closed Milestone can be reopened, so that needs no
confirmation.

If the tag or release already exists, or a call fails, report it and ask how to proceed.
