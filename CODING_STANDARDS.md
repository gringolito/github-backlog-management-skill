# Coding standards

Review changes to skill files under `skills/` against these rules.

## Skill files

- The frontmatter `description` says what the skill does and when to use it, not how it works, and
  agrees with the body.
- The body opens with the goal and a done state someone could verify.
- Each paragraph holds one concern, and each rule appears once.
- No sentence tells the agent what it already knows or already has in context, such as how to find
  the repo, which command does a job, what a common term means, that it should read the issue it
  was given, or that an API exists.
- No sentence describes an older version of the skill, a removed script, a transition state or a
  compatibility layer.
- The skill does only its own job. Work another skill covers is handed to that skill by name, not
  restated.
- The skill stops for the user only where ADR 0005 allows it, and describes each stop where it
  happens rather than listing stops up front.
- A report is asked for only when the user acts on it. "This skill is read-only", "say what you
  couldn't check" and closing next-step lines are flagged unless they change what the user does.
- No numbered procedures, command blocks, output templates nothing reads, emphasis words such as
  MUST or NEVER, persona openers, or harness tool names.
- Long references, such as templates, live in their own file next to the skill and are linked with
  one sentence saying when to read them.
- Lines stay under 100 characters.

## Plugin rules

- Skills don't say where the backlog configuration lives or tell the user to run `/setup`. The
  repo's agent instructions already load `docs/Backlog.md`.
- Skills don't set the Project's Status field. GitHub sets it as items are added, worked and
  closed.
- There is no Active Release. A repo usually has one open Milestone; when several are open and the
  user hasn't named one, the skill asks which.
- Adding an item to a Milestone changes the release's scope, so a skill does it only with the
  user's consent.

## Docs for people

The README and other docs written for people keep their author's voice. The skill-file rules above
don't apply to them.
