---
name: setup
description: >-
  Set up this repo for the backlog skills: link a GitHub Project, create the label vocabulary, and
  write both into the repo's CLAUDE.md or AGENTS.md. Run once per repo, and again to change the
  configuration.
disable-model-invocation: true
---

Make this repo ready for the backlog skills. When you finish, a GitHub Project is linked to the
repo, the label vocabulary exists on the repo, and the repo's `CLAUDE.md` or `AGENTS.md` has a
Backlog section naming the Project and the labels. The other skills read both facts from that
section instead of discovering them, so the user can change them, labels included, by editing it.

Start by exploring. Work out the owner and repo from the git remote, and check that Issues and
Projects are enabled on the repo. If either is off, tell the user which setting to turn on and stop.
Then see what's already there: Projects linked to the repo, the repo's labels, whether `CLAUDE.md`
or `AGENTS.md` exists, and whether it already has a Backlog section. An existing section is the
source of truth on a re-run: keep its Project and label choices rather than proposing new ones.

Present what's in place and what's missing, then confirm once before writing anything. Cover
everything in that one confirmation: the Project to reuse or create, the label vocabulary, and the
file that gets the section. If the user's answer amends the plan, apply it as amended without asking
again.

Reuse a Project already linked to the repo, preferring one titled `<owner>/<repo> Backlog`. When
none exists, create one with that title and the short description `Backlog for <owner>/<repo>`,
private unless the user asks otherwise, and link it to the repo. Leave the Status field as GitHub
created it.

The default vocabulary is below. Every description fits GitHub's 100-character limit, and label
creation fails on longer ones. Effort descriptions stay relative and never mention time.

- `type:feature`: New capability or user-visible behaviour not yet present
- `type:bug`: Incorrect behaviour deviating from a documented or expected contract
- `type:security`: Vulnerability, auth gap, data-exposure risk, or compliance hardening
- `type:performance`: Latency, throughput, memory, or resource-efficiency improvement
- `type:dx`: Contributor-facing improvement: CI, tooling, contributing docs
- `type:tech-debt`: Internal restructuring; no user-visible behaviour change
- `type:reliability`: Uptime, error recovery, observability, or graceful-degradation improvement
- `type:compliance`: Regulatory, legal, or contractual obligation
- `type:spike`: Time-boxed investigation to reduce uncertainty; deliverable is knowledge
- `type:epic`: Large body of work, split into sub-issues
- `type:external-blocker`: External constraint blocking a backlog item (Stub)
- `priority:P0`: Critical: system broken, data loss, or no viable workaround
- `priority:P1`: High: major user or business impact
- `priority:P2`: Medium: planned work; not blocking anything critical
- `priority:P3`: Low: nice-to-have; easily deferred without consequence
- `effort:XS`: Trivial: config tweak, one-liner, or doc edit
- `effort:S`: Small: focused change in one file or component
- `effort:M`: Medium: multiple files or components; some design thought
- `effort:L`: Large: cross-cutting; multiple subsystems or substantial design
- `effort:XL`: Extra large: major undertaking; probably needs a split plan
- `needs-clarification`: Item needs more information before it can be worked

The user can keep the defaults or map any of them to labels the repo already uses, for example
`bug` for `type:bug`. When the repo has labels that look like equivalents, suggest mapping them
instead of creating duplicates. Create only the labels the vocabulary needs and the repo lacks, with
a consistent color per group. Leave existing labels, Projects and their settings as they are.

Write the Backlog section into `CLAUDE.md` if it exists, otherwise `AGENTS.md`. When neither exists,
ask which to create as part of the confirmation. Under the heading `## Backlog`, name the Project
with its owner, number and URL, and list the labels in use for each group with their meanings,
marking the ones mapped to existing repo labels. Keep it short, since the file is loaded into every
session. On a re-run, rewrite that section where it stands and leave the rest of the file alone, so
the file never ends up with two Backlog sections.

Some helper scripts (`create-item`, `resolve-milestone`, `select-item`) still read
`.claude/backlog-project.json`, so write it with these fields: `owner`, `repo`, `project_number`,
`project_id`, `project_title`, `project_url`, `status_field_id`, and `status_options`, which maps
`Todo`, `In Progress` and `Done` to their option IDs on the Project's Status field. Create the
`.claude` directory if needed.

Running setup on a repo that's already configured changes nothing that's in place, apart from
refreshing the metadata file.

Finish with a short report. Lead with anything the user still has to do, such as enabling a repo
setting. Then say what you created, linked or wrote, and what was already in place. Point to
`/plan-release` as the next step.
