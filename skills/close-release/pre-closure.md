# Pre-closure

Carry out the release-closing procedures the repo requires before the release can be tagged.

Read the repo's release instructions wherever they live: `RELEASING.md`, `CONTRIBUTING.md`,
`README.md`, `CLAUDE.md` and `AGENTS.md`. Look for anything about releasing, publishing, version
bumps or pre-release checks.

Search for every file that declares the project's version, including custom manifests and docs,
not only the usual package files, and bump them accordingly.

File a PR with the updates made for closing the release, and monitor it until it has merged
before tagging.
