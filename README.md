# GitHub Backlog Management

> A Claude Code plugin that turns GitHub Issues and Projects v2 into a disciplined, AI-assisted backlog. No extra tools, no databases, no webhooks.

## Motivation

Backlogs rot. Items accumulate without acceptance criteria, blockers go unrecorded, priorities drift from execution order, and eventually the backlog stops reflecting reality, so people stop trusting it.

This skill keeps a GitHub backlog honest. Every item is INVEST-validated before it lands in the queue. Blockers are tracked with GitHub's native dependency API, not buried in comments. `/pick-item` picks the topmost unblocked work automatically, so "what do I do next?" has a deterministic answer.

Claude enforces structure; it doesn't set your priorities. It flags vague items, surfaces dependency candidates for you to confirm, and picks the next item, but you decide what to do with it.

## Breaking changes

- `.claude/backlog-project.json` is gone. `/setup` writes the Project and label vocabulary to `docs/Backlog.md` and links it from `CLAUDE.md` or `AGENTS.md`.
- Permission modes and the plugin's user configuration are gone. Allow `gh` and `git` in your own Claude Code settings if you want fewer prompts.
- The SessionStart hook and preflight check are gone.
- Issue Forms templates are gone.
- There is no Active Release. A repo usually has one open Milestone; when several are open, skills ask which one.
- Removed or merged skills:

| Removed | Use instead |
|---|---|
| `initialize` | `/setup` |
| `github-backlog-management` | none; Claude picks skills from their descriptions |
| `execute-item` | `/pick-item`, then implement as usual |
| `setup-permissions` | none |
| `add-external-blocker`, `resolve-external-blocker`, `block-item` | `/external-blocker` |

## Requirements

- [Claude Code](https://claude.ai/code)
- [GitHub CLI](https://cli.github.com/) (`gh`), authenticated
- A GitHub repository with Issues enabled and an `origin` remote pointing to it

## Installation

```text
/plugin marketplace add gringolito/github-backlog-management-skill
/plugin install github-backlog-management@gringolito
```

Restart Claude Code if it was already running. If installation fails with an SSH error, see [Troubleshooting](#troubleshooting).

Your `gh` token needs the `repo`, `project` and `read:user` scopes, plus `read:org` for organization repos. Add missing ones with `gh auth refresh --scopes repo,project,read:user,read:org`. With a personal access token, create a new one with these scopes.

## Skills

Run `/setup` once per repo. The other skills read `docs/Backlog.md` for the Project and labels.

| Skill | What it does |
|---|---|
| `/setup` | Links a GitHub Project, creates the label vocabulary, and documents both in `docs/Backlog.md`. Safe to re-run. |
| `/add-item` | Turns a request into one well-formed, ranked backlog item. |
| `/migrate` | Imports an existing `TODO.md`, `BACKLOG.md` or other list into GitHub Issues. |
| `/refine` | Runs a refinement session over items that need clarification or labels. |
| `/refine-item` | Brings one item up to standard and clears `needs-clarification`. |
| `/pick-item` | Chooses the next unblocked item by rank, checks it is ready and assigns it to you. |
| `/spike` | Investigates a spike and delivers a findings pull request with follow-on items. |
| `/external-blocker` | Records, links and resolves constraints outside the team's control that block items. |
| `/plan-release` | Creates a Milestone with a version, due date and scope, or re-plans one. |
| `/release-status` | Reports how a Release is tracking: progress, blocked items, items needing clarification. |
| `/close-release` | Closes a Milestone and publishes its release. |
| `/health` | Reports the overall shape of the backlog: distribution, age, overdue priorities, stale work. |
| `/audit` | Finds conflicting labels, malformed items, broken dependencies and milestone inconsistencies, with a fix for each. |

## Conventions

Every Workable Item carries one `type:*`, one `priority:*` and one `effort:*` label. Priority is severity; execution order is the manual rank in the Project. Items that fail [INVEST](https://en.wikipedia.org/wiki/INVEST_(mnemonic)) get `needs-clarification` until refined. Blockers use GitHub's native dependencies (`blocked_by`). Edit `docs/Backlog.md` to change the label vocabulary.

## Troubleshooting

### Plugin install fails with SSH authentication error

Symptom: `git@github.com: Permission denied (publickey).` or `Host key verification failed.` during install.

Claude Code clones marketplace plugins over SSH, even for public repos ([anthropics/claude-code#26588](https://github.com/anthropics/claude-code/issues/26588)). Either rewrite SSH URLs to HTTPS:

```bash
git config --global url."https://github.com/".insteadOf git@github.com:
```

or configure SSH for GitHub: trust its host key with `ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts`, and add your key to your GitHub account and `ssh-agent`.

## Contributing

Open an Issue for a bug (which skill, what you expected, what happened) or a feature idea (the workflow gap it closes). For a pull request, fork, branch, and change the skill in `skills/<name>/`. Commits follow [Conventional Commits](https://www.conventionalcommits.org/).

## License

MIT. See [LICENSE](LICENSE).

### On Beer-ware and the spirit that lives on

Poul-Henning Kamp wrote the Beerware License in the 1990s: *if you think this software is worth it, and we ever meet in person, you can buy me a beer.* It is one of the most honest licenses ever written. Sadly, it isn't OSI-approved, and corporate legal teams can't wave it through, so this project is MIT. Lawyers can sleep soundly.

But the spirit is still here. If this skill saved you an afternoon of backlog wrangling, or simply made your GitHub a little less of a mess, and we ever happen to meet, you can buy me a beer.
