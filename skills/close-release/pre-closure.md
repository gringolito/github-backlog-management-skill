# Pre-closure

Find what the repo needs before this Release can be tagged, and do what can be done in files.

Read the repo's release instructions wherever they live: `RELEASING.md`, `CONTRIBUTING.md`,
`README.md`, `CLAUDE.md` and `AGENTS.md`. Look for anything about releasing, publishing, version
bumps or pre-release checks.

Search for every file that declares the project's version, including custom manifests and docs,
not only the usual package files. Compare each against the Milestone title, ignoring a leading
`v`, and treat a mismatch as work to do.

File-only work, such as bumping versions or updating a changelog, goes on a branch named by the
repo's conventions, with a `chore(release): prepare <milestone-title>` commit and a PR in the
Milestone. Wait for the user to confirm it has merged before tagging.

Anything that isn't a file change, such as publishing to a registry, running a pipeline or
coordinating with another team, is listed for the user, and you wait for their confirmation that
it's done.

If the repo has no requirements and no version mismatches, say so and move on.
