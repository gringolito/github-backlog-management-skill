# Re-planning a Milestone

Adjust the scope of an open Milestone. Start from its current state: title, due date, and its items
grouped by whether they are done, in progress or still to do. Show the size of the scope as in
`SKILL.md`.

Items that are done or in progress stay in the Milestone, and the user can't remove them here.
Only items still to do can be removed.

Candidates to add are the same as for a new release: open items with no Milestone, in Project rank
order, leaving out external-blocker stubs, with the same blocker checks.

The user says which items to add and which to remove, or asks for a proposal. Every removed item
needs a disposition. Unless the user says otherwise, return it to the backlog with its Milestone
cleared. The alternatives are to carry it to another open Milestone, which needs a target, or to
close it as won't fix with a comment saying so. If no other open Milestone exists, carrying forward
isn't possible.

Show the resulting size of the scope with the changes. One approval covers all additions, removals
and dispositions. Once it's given, apply them and report what was added, what was removed and where
each removed item went, the resulting size, and anything that failed.
