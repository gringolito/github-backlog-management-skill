# PR–Project traceability via `Closes #N`, not `--project` flag

`execute-item` does not pass `--project` to `gh pr create`. Project traceability is handled entirely by the `Closes #N` reference in the PR body, which creates a linked-PR relationship on the Issue's existing Project card.

`gh pr create --project <title>` adds the PR as a separate, independent card in the Project board. In Projects v2 this means two items in the Queue for the same unit of work: the Issue card (Status = In Progress) and a new PR card (Status = Todo by default). The PR card pollutes both the board and the Queue — `/execute-item`'s candidate selection does not filter by `type:*`, so the PR card can surface as a candidate.

## Considered Options

**`gh pr create --project <title>`** — rejected because it adds a duplicate PR card to the Project board, polluting the Queue and making PR items eligible for candidate selection in `/execute-item`.

**`gh project item-add`** — rejected for the same reason: it adds the PR as a separate Project item rather than associating it with the existing Issue card.
