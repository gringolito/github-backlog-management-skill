# Audit Rubric

Full criteria applied by the `backlog-auditor` agent. See `agents/backlog-auditor.md` for the complete implementation.

## Label rules (work items)

Each work item must have **exactly one** label from each group:

| Group | Canonical values |
|-------|-----------------|
| `type:*` | `feature` `bug` `security` `performance` `dx` `tech-debt` `reliability` `compliance` `spike` |
| `priority:*` | `P0` `P1` `P2` `P3` |
| `effort:*` | `XS` `S` `M` `L` `XL` |

`type:external-blocker` is reserved for stubs — never assigned to work items.

## Issue body shape

Required sections in exact order (case-sensitive):

1. `### What` — required, non-empty
2. `### Why` — required, non-empty
3. `### In Scope` — required, non-empty
4. `### Out of Scope` — optional
5. `### Acceptance Criteria` — required, non-empty; must be a checklist (`- [ ]` format)
6. `### INVEST Notes` — optional

## Stub rules (`type:external-blocker`)

- `priority:*` and `effort:*` labels: not required
- Body sections: not required
- `### Reason` field: required, non-boilerplate
- Project Status: required
- Must be blocking at least one open issue (orphaned stub = quality smell)

## Report structure

| Section | Contents |
|---------|----------|
| **A. Critical** | Missing labels, missing body sections, dangling blockers, dep cycles, blocked P0 items |
| **B. Quality** | INVEST violations, vague ACs, scope problems, stale blockers, orphaned stubs |
| **C. Consistency** | Status/state drift, stale milestone items, cross-Project blockers, blocked Todo items |
| **D. External** | Open cross-repo blockers consolidated by external repo |
| **E. Recommendations** | Ready-to-run `gh issue edit` snippets for each finding |
