# Preflight contract

Run `backlog-preflight` via the Bash tool. If it exits non-zero, STOP and surface its output verbatim. On success, capture the JSON it prints to stdout. This is the metadata used throughout the workflow:

- `owner`
- `repo`
- `project_number`
- `project_id`
- `status_field_id`
- `status_options`
