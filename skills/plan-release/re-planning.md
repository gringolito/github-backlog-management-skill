# Re-planning a Milestone

Adjust the scope of an open Milestone. Start from its current state: title, due date, and its items
grouped by whether they are done, in progress or still to do.

Done items stay in the Milestone. Items in progress or still to do can be removed.

Candidates to add are the same as for a new release: open items with no Milestone, in Project rank
order, leaving out external-blocker stubs, with the same blocker checks.

The user says which items to add and which to remove, or asks for a proposal. Apply the additions
and removals they asked for directly. When they ask for a proposal, offer the choices and apply the
one they pick.

Every removed item needs a disposition. Unless the user says otherwise, return it to the backlog
with its Milestone cleared. Ask only when that default doesn't clearly fit the item.
The alternatives are to carry it to another open Milestone, which needs a target, or to close it as
won't fix with a comment saying so. If no other open Milestone exists, carrying forward isn't
possible.

If the Milestone is a maintenance release, ask whether to open forward-ports for added items, as
for a new release. Keep the Milestone's version and due date unless the change calls for new ones;
when it does, ask about them as for a new release.
