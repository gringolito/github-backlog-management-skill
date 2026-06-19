# Pre-closure checklist

Scan for project-specific release requirements and verify release readiness.

## Scan project documentation for release instructions

Read the following files if they exist (in this priority order):

- `RELEASING.md`
- `CONTRIBUTING.md`
- `README.md`
- `CLAUDE.md` (repo root and `.claude/CLAUDE.md`)
- `AGENTS.md` (repo root and `.claude/AGENTS.md`)

Extract any instructions tagged with keywords: "release", "close release", "publish", "version bump", "before releasing", "pre-release", "checklist", or similar in meaning. Present each instruction found as a numbered checklist item.

## Version consistency check

Search the repository for files that commonly embed version literals. The table below is a starting-point reference, do not treat it as an exhaustive list. Also scan for any other project-specific files (custom manifests, config files, documentation) that appear to declare a version string.

| File pattern | Version field |
| --- | --- |
| `package.json` | `.version` |
| `pyproject.toml` | `[project] version` or `[tool.poetry] version` |
| `Cargo.toml` | `[package] version` |
| `*.gemspec` | `spec.version` |
| `plugin.json` | `.version` |
| `marketplace.json` | `.version` |
| `setup.py` | `version=` |
| `setup.cfg` | `version =` |
| `Chart.yaml` | `version:` / `appVersion:` |
| `build.gradle` / `build.gradle.kts` | `version =` |
| `pom.xml` | `<version>` (top-level project only) |

For each found file, extract the version string and compare it against the milestone title (strip a leading `v` from both before comparing). Flag any mismatch as:

> ⚠️ Version mismatch: `<file>` declares `<found-version>` but milestone is `<milestone-title>`.

## Action classification and execution

Collect all items from the previous steps into a unified checklist. Classify each as one of:

- **File update change**: The action requires only committing updated files in the repository (e.g. bumping a version literal, updating a changelog file). For these:

1. Make all required file changes.
2. Commit using Conventional Commits format: `chore(release): prepare <milestone-title>` (no issue reference in the commit body).
3. Push to a branch `chore/release-prep-<milestone-title>` and open a PR:

   ```sh
   gh pr create \
     --title "chore(release): prepare <milestone-title>" \
     --milestone "<milestone-title>" \
     --body "Release prep for <milestone-title>. Milestone: <milestone-url>."
   ```

   Capture the resulting PR URL from stdout.
4. Use **AskUserQuestion** to inform the user and wait for confirmation before proceeding:

   > Release prep PR opened: `<PR URL>`
   > Please merge this PR, then confirm here to continue closing the milestone.

   Do NOT end this workflow until the user confirms the PR has merged.

- **Manual action**: The action does not require file edits alone (e.g. publishing to a registry, triggering a CI pipeline, running a smoke test suite, coordinating with another team). For these:

Use **AskUserQuestion** to surface a numbered checklist to the user with clear descriptions and wait for confirmation before proceeding:

   > Please complete the following manual steps before closing the milestone:
   > 1. [ ] `<action 1>`
   > 2. [ ] `<action 2>`
   > ...
   > Confirm here when all steps are finished.

Do NOT end this workflow until the user confirms all steps are complete.

- **No required actions**: When no version mismatches and no release instructions are found:

Output: `✅ Pre-closure checklist: no project-specific requirements found.`
