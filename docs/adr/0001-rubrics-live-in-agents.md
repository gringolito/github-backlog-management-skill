> Status: superseded by [ADR 0004](0004-no-rubric-files-skills-carry-their-own-rules.md).

# Rubric content lives in the executing agent, not in per-skill reference files

Each quality rubric (INVEST, audit checks, dependency-inference patterns) lives in exactly one place: the stateless agent that executes it (`invest-gate`, `backlog-auditor`, `dependency-inferrer`). Skills delegate to the agent and never carry a second copy; the umbrella router and docs may reference the rubric but must not reproduce it. The label catalog is the sole exception; it is short, enumerable, and kept consistent across files by the grep guards in CLAUDE.md.

## Considered options

Per-skill `reference.md` files followed the documented Claude Code plugin progressive-disclosure pattern and were the original plan in issue #41. They were rejected once the agents existed. The agent is the only runtime consumer of the rubric, so a sibling `reference.md` had no reader and became a pure drift hazard with nothing to keep it in sync.
