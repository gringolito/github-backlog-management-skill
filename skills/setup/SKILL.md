---
name: setup
description: >-
  Link a GitHub Project and create the label vocabulary for this repo's backlog, and document both
  in docs/Backlog.md. Run once per repo, and again to change either.
disable-model-invocation: true
---

Make this repo ready for the backlog skills. When you finish, a GitHub Project is linked to the
repo, the label vocabulary exists, and `docs/Backlog.md` names the Project and the labels. The
repo's `CLAUDE.md` or `AGENTS.md` links to that file, so the other skills load it only when they
need it.

Explore first. If Issues or Projects are disabled on the repo, tell the user which setting to turn
on and stop. Otherwise find the Projects linked to the repo, its labels, which of `CLAUDE.md` and
`AGENTS.md` exist, and whether `docs/Backlog.md` and a Backlog section already do. An existing
`docs/Backlog.md` is the source of truth on a re-run, so keep its choices.

Reuse a Project already linked to the repo, preferring one titled `<owner>/<repo> Backlog`. If none
exists, create one with that title and the short description `Backlog for <owner>/<repo>`, private
unless the user asks otherwise, and link it. Leave the Status field as GitHub created it.

The default label vocabulary is in [Backlog.md](./Backlog.md), which is also the template for the
repo's file. The user can keep the defaults or map any of them to labels the repo already uses.
Create only the labels that are missing, with a consistent color per group, and leave existing
labels, Projects and their settings alone.

Write the repo's `docs/Backlog.md` from the template, filled in with the Project and the labels in
use. Then add a `## Backlog` section to `CLAUDE.md` if it exists, otherwise `AGENTS.md`, that links
to it. If neither exists, ask the user which to create. Re-running updates the file and that
section in place, and changes nothing that is already right.

When you finish, report what you created, reused and changed.
