---
name: external-blocker
description: >-
  Record, link and resolve constraints outside the team's control that block backlog items. Use
  when the user reports an external dependency, vendor issue or hold on an item, or says one is
  cleared.
---

Manage the `type:external-blocker` issue for an external constraint. When you finish, the
constraint has one such issue in the Project, linked as a blocker of every item it blocks, or
it is closed with its resolution and the user knows which items it freed.

The issue carries only `type:external-blocker`: no priority, effort, Milestone or assignee. Give
it a short title naming the constraint, and a body with the reason and, when the user knows
them, the external reference and the expected resolution path.

One constraint gets one issue. Look for an open one before creating, and reuse it when the user
names another item it blocks. The blocked item can live in any repo or Project. Ask when the
direction of a dependency is ambiguous.

Resolve only issues labeled `type:external-blocker`; anything else is a real item and isn't
closed here. Ask for the resolution if the user hasn't given it.

Link each blocked item with the `blocked_by` API, and ask first when the item is closed or is
itself a `type:external-blocker`. To resolve, comment the resolution and close the issue.

Tell the user which of those items are now unblocked and which still have other open blockers,
naming them. A closed one stays closed: if the constraint returns, create a new one.
