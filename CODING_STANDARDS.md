# Coding standards

Skill files under `skills/` follow the
[writing-skills](https://github.com/gringolito/skills/tree/main/skills/writing-skills) skill.
Read it before writing or reviewing a change to a skill.

Lines in skill files stay under 100 characters.

These rules are specific to this plugin:

- Skills don't say where the backlog configuration lives or tell the user to run `/setup`. The
  repo's agent instructions already load `docs/Backlog.md`.
- Skills don't set the Project's Status field. GitHub sets it as items are added, worked and
  closed.
- There is no Active Release. A repo usually has one open Milestone; when several are open and the
  user hasn't named one, the skill asks which.
- Adding an item to a Milestone changes the release's scope, so a skill does it only with the
  user's consent.
