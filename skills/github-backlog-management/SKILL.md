---
name: github-backlog-management
description: Manage backlog, issues, and milestones with INVEST quality enforcement. Use for requests about backlog, issue, milestone, prioritize, INVEST, refine, audit, or clarify.
---

# GitHub Backlog Management

A set of slash commands for a fully GitHub-native backlog workflow — Issues, Projects v2, Milestones, and Labels. No external tools, no database, no webhooks.

## Command Routing

| Command | When to use |
|---------|-------------|
| `/initialize-backlog` | First-time setup: provisions Project, labels, Issue Forms template. Idempotent. Run this first. |
| `/plan-release` | Create a Milestone with a due date — choose Maintenance, Regular, or Automated mode; semver version inferred from scope |
| `/add-backlog-item` | Interactively create and rank a single backlog item (enforces INVEST) |
| `/migrate-backlog` | Bulk-import an existing backlog file; skips Done items; dep inference opt-in |
| `/refine-backlog` | Orchestrate a refinement session: list `needs-clarification` candidates, let user select, loop through with `/refine-backlog-item` |
| `/refine-backlog-item` | Refine a single `needs-clarification` item — discovery dialogue, body rewrite, INVEST gate, label/rank/dep updates, label removal |
| `/release-status` | Read-only milestone health dashboard — issue counts by Status, blocked items, unestimated items |
| `/validate-backlog` | Read-only audit — emits actionable `gh` commands; never mutates |
| `/execute-backlog-item` | Pick the topmost unblocked Todo item and guide it through to a PR |

## Workflow

```
initialize-backlog ─► plan-release ─► add-backlog-item / migrate-backlog
                                              │
                                              ├─► refine-backlog ─► refine-backlog-item
                                              ├─► release-status (read-only)
                                              ├─► validate-backlog (read-only)
                                              └─► execute-backlog-item
```

`initialize-backlog` is the bootstrap. Every other command preflights for a linked Project and stops with a standard error if missing.

## INVEST Quality Bar

Every item must pass before entering the queue:

| Letter | Criterion | What to check |
|--------|-----------|---------------|
| **I** | Independent | Buildable without waiting on another in-flight item |
| **N** | Negotiable | The *what* is agreed; the *how* is open |
| **V** | Valuable | Delivers something real to a user or the system |
| **E** | Estimable | Team can roughly size it |
| **S** | Small | Fits inside a single cycle of work |
| **T** | Testable | Has acceptance criteria concrete enough to verify |

## Key Invariants (apply to all commands)

**Label catalog**
- `type:` — `feature` `bug` `security` `performance` `dx` `tech-debt` `reliability` `compliance` `spike` `external-blocker`
- `priority:` — `P0` `P1` `P2` `P3`
- `effort:` — `XS` `S` `M` `L` `XL`
- Operational: `needs-clarification`

**Issue body sections** (exact headings, this order):
`### What` · `### Why` · `### In Scope` · `### Out of Scope` · `### Acceptance Criteria` · `### INVEST Notes`

**Metadata file**: `.claude/backlog-project.json` — written by `initialize-backlog`, read directly by all other commands.

**Standard preflight stop string**: `No Backlog project linked to <owner>/<repo>. Run /initialize-backlog first.`

**Priority vs rank**: `priority:*` is severity classification. Project rank (topmost Todo item) is execution order. They should stay consistent but are independent concepts — `execute-backlog-item` sorts by rank only.

## Command Specs

See [commands/](commands/) for full per-command specs including exact `gh` CLI calls, workflow steps, and edge-case handling.
