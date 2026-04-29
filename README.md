# GitHub Backlog Management

> A Claude Code skill that turns GitHub Issues + Projects v2 into a disciplined, AI-assisted backlog — no extra tools, no databases, no webhooks.

---

## Why you should care

### For solo developers

You already know the problem. You have a `TODO.md`, a few sticky notes, three open browser tabs with issues you swore you'd remember, and a growing sense that you're working on the second-most-important thing right now. You don't need a PM. You need a system that gets out of your way.

This skill gives you that. Run a command, get a well-formed GitHub Issue with acceptance criteria you actually wrote, ranked in a Project you control. When you sit down to code, `/execute-backlog-item` tells you exactly what to work on next — and skips anything blocked — so you stop making that decision from scratch every morning.

No team required. No process overhead. Just you, your repo, and a backlog that doesn't lie to you.

#### Already have a `TODO.md`, `BACKLOG.md`, or some other list you've been maintaining?

Run `/migrate-backlog`, point Claude at the file, and it imports everything into GitHub Issues — skipping anything already done, inferring dependencies from your own prose, and letting you review before anything is applied. Your history, your format, no manual copying.

### For teams

Most teams treat their backlog as a graveyard. Items accumulate, priorities drift, blockers go unnoticed, and the "top of the queue" is whatever someone remembered to mention in standup.

This skill fixes that without adding yet another tool to your stack. Everything lives in GitHub — Issues, Projects v2, Milestones, Labels — exactly where your team already works. Claude acts as a senior PM embedded in your terminal: it creates well-formed issues, enforces INVEST criteria, respects dependency chains, audits quality, and picks the right next item to execute.

### What you get — solo or team

- A structured, rankable backlog that lives entirely in GitHub
- Issues that are actually useful (consistent body shape, proper labels, real acceptance criteria)
- Dependency-aware execution — blocked items are skipped automatically
- A read-only auditor that surfaces problems without making a mess
- Zero vendor lock-in — if you stop using this skill tomorrow, your GitHub data stays exactly where it is

---

## Requirements

- [Claude Code](https://claude.ai/code) (CLI or IDE extension)
- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated (`gh auth login`)
- A GitHub repository with Issues enabled
- Git `origin` remote pointing to that repository

---

## Installation

This skill is distributed as a [Claude Code skill](https://claude.ai/code). Install it with:

```bash
claude skills install gringolito/github-backlog-management-skill
```

Once installed, all commands below are available in any repository you open with Claude Code.

---

## Features

| Command | What it does |
|---|---|
| `/create-project` | One-time bootstrap: provisions the GitHub Project v2, the full label catalog, and the Issue Forms template. Idempotent — safe to re-run. |
| `/plan-release` | Creates a Milestone with a due date. Tie-breaks and active-milestone resolution are automatic. |
| `/add-backlog-item` | Interactively authors a single backlog item. Enforces INVEST, recommends rank and priority, wires up native GitHub dependencies. |
| `/migrate-backlog` | Bulk-imports an existing `BACKLOG.md`. Skips Done items. Dependency inference is opt-in — candidates are reviewed before anything is applied. |
| `/refine-backlog` | Lists all `needs-clarification` candidates, lets you select which to refine, then loops through them one by one — asking continue/stop after each. |
| `/refine-backlog-item` | Refines a single `needs-clarification` item: discovery dialogue, body rewrite, INVEST gate, label/rank/dep re-evaluation, and label removal after a final validation pass. |
| `/validate-backlog` | Read-only audit. Emits actionable `gh issue edit ...` snippets. Never mutates anything. |
| `/execute-backlog-item` | Picks the topmost unblocked Todo item, respects active milestone scope, skips blocked items, and walks you through to a PR. |

### INVEST — the quality bar every backlog item must meet

INVEST is a checklist for deciding whether a backlog item is ready to be worked on. An item passes when it is:

| Letter | Criterion | Why it matters |
| --- | --- | --- |
| **I** | Independent | Can be built and shipped without waiting on another item in the same batch. Avoids invisible coupling that breaks your execution order. |
| **N** | Negotiable | The *what* is agreed; the *how* is still open. If an item already dictates the implementation, you've skipped the design conversation. |
| **V** | Valuable | Delivers something real to a user or the system. If you can't articulate the value, the item probably isn't ready. |
| **E** | Estimable | The team can roughly size it. Items that can't be estimated are usually under-specified or secretly multiple items. |
| **S** | Small | Fits inside a single cycle of work. Large items hide risk and delay feedback. |
| **T** | Testable | Has acceptance criteria concrete enough to write a test or a manual check against. "Works correctly" doesn't count. |

This skill enforces INVEST at creation time (`/add-backlog-item`) and during refinement (`/refine-backlog-item`). Items that don't pass get the `needs-clarification` label instead of landing in the queue — because a vague item at the top of your backlog is just a polite way of not knowing what you're doing next.

### Backlog structure

Every issue created by this skill follows a consistent body shape:

```
### What
### Why
### In Scope
### Out of Scope
### Acceptance Criteria
### INVEST Notes
```

Every issue carries three label groups:

- **Type** — `type:feature` `type:bug` `type:security` `type:performance` `type:dx` `type:tech-debt` `type:reliability` `type:compliance` `type:spike`
- **Priority** — `priority:P0` through `priority:P3`
- **Effort** — `effort:XS` `effort:S` `effort:M` `effort:L` `effort:XL`

Priority is severity classification. Execution order is the manual Project rank — the two are independent concepts that should stay consistent but are never conflated.

### Workflow

```
/create-project ──► /plan-release ──► /add-backlog-item
                                      /migrate-backlog
                                            │
                                            ├──► /refine-backlog ──► /refine-backlog-item
                                            ├──► /validate-backlog  (read-only)
                                            └──► /execute-backlog-item
```

Run `/create-project` once. Every other command preflights for the linked Project and stops with a clear error if it is missing.

---

## Usage

### Starting from scratch

```
/create-project
```

This provisions the GitHub Project v2, creates all labels, and opens a PR with the Issue Forms template. Run it once per repo.

### Planning a release

```
/plan-release
```

Claude presents three release modes — **Maintenance** (patch an existing milestone), **Regular** (you select scope interactively), or **Automated** (Claude proposes scope from unassigned items). It infers a semver version from the scope and creates a Milestone with a due date.

### Adding a backlog item

```
/add-backlog-item
```

Claude asks clarifying questions, authors the issue body, recommends a rank in the Project, and links any declared blockers using GitHub's native dependency API.

### Importing an existing backlog

```
/migrate-backlog
```

Point Claude at your existing `BACKLOG.md`. Done items are skipped. Dependency hints in prose (`"depends on"`, `"blocked by"`) are surfaced for your review before anything is applied.

### Refining unclear items

```
/refine-backlog
```

Lists all `needs-clarification` items sorted by priority, lets you select which ones to work on, then calls `/refine-backlog-item` for each — asking whether to continue after every iteration.

```
/refine-backlog-item 42
```

Refines a single item directly (useful when you know exactly which issue needs attention). Guides a discovery dialogue, rewrites the body, re-evaluates labels and rank, runs a validation gate, and removes `needs-clarification` only when everything checks out.

### Auditing backlog health

```
/validate-backlog
```

A read-only pass that surfaces missing labels, malformed issue bodies, dangling blockers, and cross-Project dependency smells. Outputs copy-pasteable `gh` commands — never applies fixes itself.

### Executing next work

```
/execute-backlog-item
```

Picks the topmost unblocked Todo item (active milestone first, unmilestoned fallback), reports which items were skipped and why, and walks you through implementation to a PR.

---

## Contributing

Issues, improvement suggestions, and pull requests are all welcome.

**Found a bug or unexpected behavior?**
Open a GitHub Issue describing what command you ran, what you expected, and what actually happened. Include the relevant `gh` output if you have it.

**Have an idea for a new feature or command?**
Open an Issue with the `type:feature` label and describe the problem it solves. The best feature requests explain the workflow gap, not just the proposed solution.

**Want to contribute a fix or improvement?**

1. Fork the repository
2. Create a branch
3. Make your changes — each command spec lives in `commands/*.md`
4. Verify cross-command invariants still hold (see the consistency greps in [CLAUDE.md](CLAUDE.md))
5. Open a PR with a clear description of what changed and why

This repository uses [Conventional Commits](https://www.conventionalcommits.org/). Commit messages must follow the `<type>: <description>` format. Common types: `feat` for new behavior, `fix` for corrections, `docs` for README/comment changes, `refactor` for rewrites that don't change behavior, `chore` for maintenance. Example: `feat: add needs-refinement label to validate-backlog report`.

When editing command specs, preserve the existing style: numbered workflow sections with `(MANDATORY)` / `(STRICT)` / `(RELATIVE)` flags, opening prose in the `You are an AI agent acting as...` form, and the standard preflight block. Label catalog, preflight stop string, and issue body section headings must stay consistent across all command files.

---

## License

MIT — see [LICENSE](LICENSE).

---

## On Beer-ware and the spirit that lives on

There is a beautiful license called the Beerware License. It was written by Poul-Henning Kamp sometime in the 1990s and it says, more or less: *if you think this software is worth it, and we ever meet in person, you can buy me a beer.*

It is one of the most honest licenses ever written. It captures exactly the spirit of open source: share freely, ask for nothing, and if someone's work genuinely helped you, buy them a drink and tell them about it.

Sadly, the Beerware License is not OSI-approved. It lacks the formal language needed for corporate legal teams to wave it through, which means — in a cruel twist — the most human license ever written is the one least likely to be used by humans working inside institutions.

So this project is MIT. Lawyers can sleep soundly.

But the spirit is still here. If this skill saved you an afternoon of backlog wrangling, helped you ship something that mattered, or simply made your GitHub a little less of a mess — and if we ever happen to meet in person — you can buy me a beer.
