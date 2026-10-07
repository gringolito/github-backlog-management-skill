---
name: close-release
description: >-
  Close a Milestone and publish its release. Use when a Release is done, or the user says "close
  the release", "cut the release" or "ship the milestone".
argument-hint: "Optional: the Milestone title or version. Defaults to the open Milestone."
---

Close a Release. When you finish, no open item is left in the Milestone, the repo carries whatever
the release needs, the release and its tag are published, and the Milestone is closed.

The user may name the Milestone by title or version. Otherwise use the open Milestone, and ask
which when several are open.

Every open item in the Milestone gets the user's decision: carry it to the next open Milestone,
close it as won't fix with a comment saying it wasn't included in this release, or drop its
Milestone and leave it open in the backlog. Present all open items together and apply the choices
once the user has answered.

Prepare the repo as its own instructions describe. Read [pre-closure.md](./pre-closure.md) for
where to look and how to handle what you find.

Draft the release notes from the merged PRs, then add what the PR list misses: breaking changes,
new features, configuration or schema changes and migration steps from the closed items. Read
those items by content.

The tag and the release title are the Milestone title; follow the repository's existing pattern
if one exists. Tag the default branch, after any release-prep PR has merged. Publish the release
with those notes, then close the Milestone. Link the published release in your report so the
user can edit the notes.

If the tag or release already exists, ask how to proceed.
