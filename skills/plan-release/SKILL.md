---
name: plan-release
description: >-
  Create a Release Milestone with a version, due date and scope, or re-plan an existing one. Use
  when the user wants to start a release, scope a version, or add or remove items from a Milestone.
argument-hint: "Optional: the version to plan, or the open Milestone to re-plan."
---

Plan a release. When you finish, an open Milestone exists with a version title, a due date, a
description, and every item in its scope assigned to it.

If the argument names an open Milestone, or the version you propose matches one, this is a re-plan
of that Milestone: read [re-planning.md](./re-planning.md) and follow it instead. Otherwise create
a new one, using the argument as the suggested version.

Take the scope, version and due date from the user where they gave them. Ask only about what you
have to pick yourself, and when you do, offer the options for the user to choose between, such as
two coherent scopes, or a patch versus a minor version. Ask about the due date when you can't
infer it from a calendar versioning model.

Candidates are the open backlog items with no Milestone, in Project rank order. Leave out
`type:external-blocker` stubs and `type:idea` ideas, since they aren't workable. Propose a coherent
scope rather than the top of the list: favor P0 and P1 items, keep a theme, and size it so the
release is deliverable. If the user names the issues, use those, after checking that each exists,
is open and is neither a stub nor an idea. For a bug-fix or security release with no list, the
unscoped bug and security items are the candidates.

Check each candidate's `blocked_by` dependencies. An item whose blockers are all candidates can go
in only together with them, with the blockers ranked above it. An item with an open blocker outside
the pool, including an external-blocker stub, stays out and is named in the proposal with the
blocking reason. The user can override that.

The description gives the release theme, the goals taken from the scoped items' reasons, and any
dependency chains or constraints that shaped the scope. The user can supply their own. Set the due
date from the size of the scope and the cadence of earlier Milestones.

Infer the version from the repo's release history and the scope, and say which items drove it. A
breaking change anywhere in the scope, stated in an item's body or flagged by the user, calls for a
major bump under semver, a `type:feature` item for a minor bump, and anything else for a patch.

A release the user aims at an existing `major.minor` line, including the latest, is a maintenance
release. Its version is the next patch on that line, whatever the scope's types, and a feature or
breaking change in its scope is flagged, since it doesn't belong in a patch. Say in the proposal
when the line isn't the latest, so the backport is visible. Any other version must be higher than
the latest released one and not match a closed release.

For maintenance releases, ask whether to open a `[Forward-port]` issue for each scoped item, so the
fix also reaches mainstream development. These are added to the Project with no Milestone, and
the body links the original.

Create the Milestone, assign every scoped item, and open the forward-ports the user accepted.
