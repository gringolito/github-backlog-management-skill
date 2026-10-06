---
name: plan-release
description: >-
  Create a Release Milestone with a version, due date and scope, or re-plan an existing one. Use
  when the user wants to start a release, scope a version, or add or remove items from a Milestone.
argument-hint: "Optional: the version to plan, or the open Milestone to re-plan."
---

Plan a release. When you finish, an open Milestone exists with a version title, a due date, a
description, and every item in its scope assigned to it, all approved by the user beforehand.

Read the Project and label vocabulary from the repo's `docs/Backlog.md`, linked from its
`CLAUDE.md` or `AGENTS.md`. If the configuration is missing, tell the user to run `/setup` and stop.

If the argument names an open Milestone, or the version you propose matches one, this is a re-plan
of that Milestone: read [re-planning.md](./re-planning.md) and follow it instead. Otherwise create
a new one, using the argument as the suggested version.

Start from what exists: the published Releases, and the open and closed Milestones. Work out the
versioning scheme from their titles and tags. If the history mixes schemes and the right one going
forward isn't clear, ask the user which to use. That is the only question before the proposal.

Propose the whole plan at once: the scope, the version, the due date and the description. The user
adjusts it, and you revise until they approve it.

Candidates are the open backlog items with no Milestone, in Project rank order. Leave out
`type:external-blocker` stubs, since they describe constraints and aren't workable, and keep them
out even when the user names them unless the user insists. Propose a coherent scope rather than the
top of the list: favor P0 and P1 items, keep a theme, and size it so the release is deliverable. If
the user names the issues, use those. For a bug-fix or security release with no list, the unscoped
bug and security items are the candidates.

Check each candidate's `blocked_by` dependencies. An item whose blockers are all candidates can go
in only together with them, with the blockers ranked above it. An item with an open blocker outside
the pool, including an external-blocker stub, stays out and is named in the proposal with the
blocking reason. The user can override that. If the dependency API is unavailable, treat items as
unblocked and say so.

Infer the version from the scope. For semver projects, a breaking change anywhere in the scope
means a major bump, a `type:feature` item means a minor bump, and anything else is a patch. A
breaking change is one an item's body states or the user flags. Read bodies by content, not by
heading, since older items follow a different template. For calendar or custom schemes, continue
the observed pattern, since scope doesn't drive the name there.

The version must be higher than the latest released one, except for maintenance releases: a patch
on an existing `major.minor` line, including the latest. A maintenance version is higher than that
line's latest released patch. When the line isn't the latest, say in the proposal that it's a
backport. Flag any feature or breaking change in a maintenance scope, since it doesn't belong in a
patch.

For maintenance releases, offer to open a `[Forward-port]` issue for each scoped item, so the fix
also reaches mainstream development. These are added to the Project with no Milestone, and the body
links the original. Include the offer in the proposal.

Explain the version choice in a line, naming the items that drove it.

The due date is how `pick-item` chooses the Active Release, the open Milestone with the earliest
due date. Propose one that fits the size of the scope and the cadence of earlier Milestones, and
tell the user if it would make this the Active Release.

The description gives the release theme, the goals taken from the scoped items' reasons, and any
dependency chains or constraints that shaped the scope. The user can supply their own.

Show the size of the scope as points and a band. Weights are XS=1, S=2, M=3, L=5 and XL=8, and an
item with no effort label counts as M, noted as such. Up to 8 points is Small, 9 to 20 Medium, 21
to 40 Large, and above that Very Large.

Once the user approves, create the Milestone, assign every scoped item, and open any forward-ports.
This single approval covers all of it. Then report the Milestone link, its due date, the scope with
effort, the size, the reason for the version, and anything that failed.
