# `rank-recommender` gets a backward-compatible batch contract

`rank-recommender` accepts one or more candidates. A single candidate returns the original single `position:` block, byte-for-byte — `add-item` step 7a and `refine-item` step 8 need no changes. More than one candidate returns one block per candidate, in input order, separated by `---`, reasoned holistically against each other and the existing Todo column; a candidate's `position` may reference another candidate in the batch via `after_candidate: <id>` in addition to the existing `after_issue: <N>` and `top`/`bottom` options.

This keeps the ranking rubric in the one place it already lived (consistent with ADR-0001): `migrate`'s Phase 3 batch rank pre-flight needs to rank several not-yet-created items against each other and against the live Todo column in a single holistic pass, which the single-candidate contract couldn't express. Extending the agent's own contract avoids duplicating the rubric into `migrate` or forcing N sequential single-candidate calls that reason about the Todo column in isolation from each other.

## Considered Options

**N sequential single-candidate calls, one per item** (`migrate`'s prior per-item post-creation rank loop) — rejected: each call only reasons against the live Todo column, not against the other items being migrated in the same run, so two candidates with a real relative-priority relationship could each be recommended relative to existing items without ever being compared to each other.

**A second, `migrate`-only ranking agent** — rejected: it would fork the rubric into two agents that must be kept in sync, the exact drift hazard ADR-0001 already ruled out for reference files.
