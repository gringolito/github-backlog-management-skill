---
name: github-backlog-management
description: Use when managing a product backlog on GitHub — creating or importing backlog items, prioritizing work, executing tasks, auditing backlog quality, or setting up a GitHub Issues + Projects v2 workflow from scratch
---

# GitHub Backlog Management

## Overview

A set of slash commands for a fully GitHub-native backlog workflow — Issues, Projects v2, Milestones, and Labels. No external tools, no database, no webhooks.

## Command Routing

| Command | When to use |
|---------|-------------|
| `/create-project` | First-time setup: provisions Project, labels, Issue Forms template. Idempotent. Run this first. |
| `/plan-release` | Create a Milestone with a due date — choose Maintenance, Regular, or Automated mode; semver version inferred from scope |
| `/add-backlog-item` | Interactively create and rank a single backlog item (enforces INVEST) |
| `/migrate-backlog` | Bulk-import an existing backlog file; skips Done items; dep inference opt-in |
| `/refine-backlog` | Orchestrate a refinement session: list `needs-clarification` candidates, let user select, loop through with `/refine-backlog-item` |
| `/refine-backlog-item` | Refine a single `needs-clarification` item — discovery dialogue, body rewrite, INVEST gate, label/rank/dep updates, label removal |
| `/validate-backlog` | Read-only audit — emits actionable `gh` commands; never mutates |
| `/execute-backlog-item` | Pick the topmost unblocked Todo item and guide it through to a PR |

## Workflow

```
create-project ─► plan-release ─► add-backlog-item / migrate-backlog
                                          │
                                          ├─► refine-backlog ─► refine-backlog-item
                                          ├─► validate-backlog (read-only)
                                          └─► execute-backlog-item
```

`create-project` is the bootstrap. Every other command preflights for a linked Project and stops with a standard error if missing.

## Key Invariants (apply to all commands)

**Label catalog**
- `type:` — `feature` `bug` `security` `performance` `dx` `tech-debt` `reliability` `compliance` `spike`
- `priority:` — `P0` `P1` `P2` `P3`
- `effort:` — `XS` `S` `M` `L` `XL`
- Operational: `needs-clarification`

**Issue body sections** (exact headings, this order):
`### What` · `### Why` · `### In Scope` · `### Out of Scope` · `### Acceptance Criteria` · `### INVEST Notes`

**Cache**: `.git/info/backlog-project.json` — 24-hour TTL, lives inside `.git/`, never tracked.

**Priority vs rank**: `priority:*` is severity classification. Project rank (topmost Todo item) is execution order. They should stay consistent but are independent concepts — `execute-backlog-item` sorts by rank only.

## Command Specs

See [commands/](commands/) for full per-command specs including exact `gh` CLI calls, workflow steps, and edge-case handling.
