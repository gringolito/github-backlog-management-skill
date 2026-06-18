# Issue Manifest Schema

The manifest is a JSON file passed to `create-item --input <file>`.

`title` and `body_file` are required; all other fields are optional and should be omitted when not applicable.

```json
{
  "title": "<issue title>",
  "body_file": "/tmp/add-item-body.md",
  "labels": ["type:<x>", "priority:<y>", "effort:<z>"],
  "rank": {"position": "top"} | {"position": "bottom"} | {"after_issue": N},
  "rank_adjustments": [{"issue": N, "position": "top"} | {"issue": N, "after_issue": M}],
  "blocked_by": [{"owner": "...", "repo": "...", "number": N}],
  "blocking":   [{"owner": "...", "repo": "...", "number": N}],
  "parent": <integer issue number>,
  "milestone": "<milestone title>"
}
```

## Field Notes

- `rank` / `rank_adjustments` — use `after_issue: N` with the issue number of the item to position after
- `blocked_by` / `blocking` — cross-repo references are allowed; include `owner` and `repo` for cross-repo items; same-repo items need only `number`
