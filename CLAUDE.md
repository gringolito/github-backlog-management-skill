# Rules

## Release management

Version bumps are controlled by `plugin.json:version`/`marketplace.json:plugins:version` and happen at release closure, not per PR. Do not bump versions in feature PRs.

## Commit requirements

All commits to this repository MUST be both signed (`-S`) and signed-off (`-s`). Use: `git commit -S -s -m "..."`

## Agent skills

### Issue tracker

Issues live in GitHub Issues, managed via the `github-backlog-management-skill`. See `docs/agents/issue-tracker.md`.

### Triage labels

This repo uses the `github-backlog-management-skill`'s own label classification. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context repo: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
