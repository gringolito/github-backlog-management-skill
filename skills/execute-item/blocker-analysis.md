# Per-Blocker Analysis

Rendered when all candidates are blocked (`candidate` null, `skipped_blocked` non-empty). All facts come from the script output — no extra API calls needed.

- Report: `All actionable items are blocked. Resolve a blocker or re-rank.`
- Render:

  | Blocked item | Blocker | Blocker state | Suggested action |
  | --- | --- | --- | --- |
  | #N title | #M title | open / closed | see rules below |

- **Suggested action rules** (apply first match; use `cross_repo`, `assignees`, `labels` from `skipped_blocked[].open_blockers`):
  - Blocker `closed` + dependency still active → `Stale — clear with: gh api -X DELETE repos/<owner>/<repo>/issues/<n>/dependencies/blocked_by/<m>`
  - Blocker `open`, `cross_repo: true` → `External — coordinate with owning team`
  - Blocker `open`, `assignees` non-empty → `In Progress — monitor`
  - Blocker `open`, `assignees` empty → `Unassigned — assign or re-plan`
  - Blockers with `"type:external-blocker"` in labels: show as `External: <stub title>`.
- Close with: `N of M blockers may be resolvable without new work` (stale + in-progress count as resolvable).
- DO NOT pick a blocked item even with user confirmation. Re-run `/execute-item` after resolving a blocker.
