# Dependency-Inference Heuristics

Used by the `dependency-inferrer` agent during `/migrate` to surface candidate relationships from source prose. All candidates are presented to the user for review — none are applied automatically.

## Pattern library

| Relationship type | Trigger phrases |
|-------------------|-----------------|
| `blocked_by` | "depends on", "depends upon", "blocked by", "after X is done", "after X", "before X can start", "requires X first", "requires", "prerequisite", "needs X first" |
| `blocking` | "blocks", "blocking", "must be done before X", "before X" |
| `sub_issue` | "sub-task of", "part of", "child of", "parent: X" |

## Confidence levels

| Level | Meaning |
|-------|---------|
| `HIGH` | Exact phrase match; target identified by issue number or exact title |
| `MEDIUM` | Pattern match but target resolved by fuzzy/partial title match |
| `LOW` | Phrase suggests dependency but target is unclear or ambiguous |

## Edge cases

- **UNRESOLVED target**: hint references a title not in the issue roster → surface as "manual resolution needed", do NOT guess
- **Done-item target**: hint points at a skipped Done item → skip the candidate and note it in the Migration Report
- **False-positive rate is high**: a false `blocked_by` gates `execute-item` on phantom work — always require explicit user confirmation before applying
- **Dependencies API unavailable** (private repo, 404): skip inference entirely and emit one warning line in the Migration Report
