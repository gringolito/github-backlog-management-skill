# Scope Completeness Review

1. Extract `### In Scope` and `### Acceptance Criteria` from `candidate.body` in the context.

2. Fetch each closed sub-issue body:
   - Use the sub-issue list from the API call above for their numbers.
   - For each: `gh issue view <m> --json number,title,body`

3. Perform coverage analysis:
   - For each criterion in `### Acceptance Criteria`, determine which closed sub-issue (if any) addressed it, based on sub-issue titles and bodies.
   - Format as a checklist:

     ```text
     **Coverage analysis — #N: <parent title>**

     Acceptance Criteria:
     - [x] AC1: <text> → covered by #M (<sub-issue title>)
     - [x] AC2: <text> → covered by #P (<sub-issue title>)
     - [ ] AC3: <text> → not addressed by any closed sub-issue
     ```

4. Present the coverage checklist to the user. Then use AskUserQuestion with two options:
   - **"Close parent — scope complete"**
   - **"Create sub-issues for uncovered gaps"**

5. **If "Close parent — scope complete":**
   - Post a comment with the full coverage checklist: `gh issue comment <n> --body "..."`
   - Close the issue: `gh issue close <n>`

6. **If "Create sub-issues for gaps":**
   - For each uncovered criterion (marked `[ ]` in the checklist), invoke `/add-item` with the parent issue number so the new items become sub-issues.
   - Suggest re-running `/pick-item` to pick a new Workable Item.
