# Issue forms template PR

If the issues template files are missing or the user approved replacement:

- Create a branch: `chore/backlog-issue-templates`
- Create the parent directory if needed: `mkdir -p .github/ISSUE_TEMPLATE`
- Write the canonical contents of [backlog-item.yml](./backlog-item.yml) to `.github/ISSUE_TEMPLATE/backlog-item.yml`
- Write the canonical contents of [external-blocker.yml](./external-blocker.yml) to `.github/ISSUE_TEMPLATE/external-blocker.yml`
- Commit both files using Conventional Commits, push the branch and open a PR with the following notes on the body:
  - `backlog-item.yml` is the canonical body shape for backlog items, all skills depend on its section headings
  - `external-blocker.yml` is the template for External Blocker Stub issues created by `/add-external-blocker`
- Output the PR URL
