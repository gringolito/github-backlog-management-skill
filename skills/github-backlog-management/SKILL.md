---
name: github-backlog-management
description: Manage backlog, issues, and milestones with INVEST quality enforcement. Use for requests about backlog, issue, milestone, prioritize, INVEST, refine, audit, or clarify.
---

# GitHub Backlog Management

A set of skills for a fully GitHub-native backlog workflow — Issues, Projects v2, Milestones, and Labels. No external tools, no database, no webhooks.

## Skill Routing

| Skill | When to use |
|---------|-------------|
| `/initialize` | First-time setup: provisions Project, labels, Issue Forms template. Idempotent. Run this first. |
| `/plan-release` | Create a Milestone with a due date — choose Maintenance, Regular, or Automated mode; semver version inferred from scope |
| `/add-item` | Interactively create and rank a single backlog item (enforces INVEST) |
| `/migrate` | Bulk-import an existing backlog file; skips Done items; dep inference opt-in |
| `/refine` | Orchestrate a refinement session: list `needs-clarification` candidates, let user select, loop through with `/refine-item` |
| `/refine-item` | Refine a single `needs-clarification` item — discovery dialogue, body rewrite, INVEST gate, label/rank/dep updates, label removal |
| `/release-status` | Read-only milestone health dashboard — issue counts by Status, blocked items, unestimated items |
| `/health` | Read-only strategic portfolio health report — distribution by type/priority/effort, age cohorts, overdue P0/P1 items, stale In-Progress, metadata debt |
| `/audit` | Read-only audit — emits actionable `gh` commands; never mutates |
| `/execute-item` | Pick the topmost unblocked Todo item and guide it through to a PR |

## Workflow

```
initialize ─► plan-release ─► add-item / migrate
                                      │
                                      ├─► refine ─► refine-item
                                      ├─► release-status (read-only)
                                      ├─► health (read-only)
                                      ├─► audit (read-only)
                                      └─► execute-item
```

`initialize` is the bootstrap. Every other skill preflights for a linked Project and stops with a standard error if missing.

## INVEST Quality Bar

Every Workable Item passes INVEST (Independent, Negotiable, Valuable, Estimable, Small, Testable) before entering the queue — enforced by the `invest-gate` agent.

## Key Invariants (apply to all skills)

**Label catalog**
- `type:` — `feature` `bug` `security` `performance` `dx` `tech-debt` `reliability` `compliance` `spike` `external-blocker`
- `priority:` — `P0` `P1` `P2` `P3`
- `effort:` — `XS` `S` `M` `L` `XL`
- Operational: `needs-clarification`

**Issue body sections** (exact headings, this order):
`### What` · `### Why` · `### In Scope` · `### Out of Scope` · `### Acceptance Criteria` · `### INVEST Notes`

**Metadata file**: `.claude/backlog-project.json` — written by `initialize`, read directly by all other skills.

**Standard preflight stop string**: `No Backlog project linked to <owner>/<repo>. Run /initialize first.`

**Priority vs rank**: `priority:*` is severity classification. Project rank (topmost Todo item) is execution order. They should stay consistent but are independent concepts — `execute-item` sorts by rank only.

## Skill Specs

See [skills/](skills/) for full per-skill specs including exact `gh` CLI calls, workflow steps, and edge-case handling.
