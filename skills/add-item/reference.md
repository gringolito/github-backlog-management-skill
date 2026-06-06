# INVEST Rubric

Every backlog item must pass all six criteria before entering the queue.

| Letter | Criterion | What to check |
|--------|-----------|---------------|
| **I** | Independent | Buildable without waiting on another in-flight item |
| **N** | Negotiable | The *what* is agreed; the *how* is open |
| **V** | Valuable | Delivers something real to a user or the system |
| **E** | Estimable | Team can roughly size it |
| **S** | Small | Fits inside a single cycle of work |
| **T** | Testable | Has acceptance criteria concrete enough to verify |

## Common INVEST violations

| Violation | Indicator | Fix |
|-----------|-----------|-----|
| Not Independent | "depends on #N being done first" | Split, or declare blocker and defer |
| Not Negotiable | Implementation specified down to function names | Rewrite to focus on the outcome |
| Not Valuable | "clean up code", "refactor internals" | Tie to a concrete user or system benefit |
| Not Estimable | No acceptance criteria, unbounded scope | Define Done more concretely |
| Not Small | `effort:XL` with many acceptance criteria | Split into smaller items |
| Not Testable | "improve performance", "make it better" | Add measurable acceptance criteria |

## Effort scale

Effort measures **complexity**, never time.

| Label | Meaning |
|-------|---------|
| `effort:XS` | Trivially small change, few lines |
| `effort:S` | Small, self-contained change |
| `effort:M` | Moderate, some design decisions |
| `effort:L` | Large, significant design or integration work |
| `effort:XL` | Very large — consider splitting before accepting |
