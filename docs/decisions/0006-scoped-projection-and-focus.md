# ADR 0006 — scoped projection and presentation focus

Status: accepted  
Version: 0.2.1

## Context

Users need to inspect one project area without losing the outside inheritance and dependency context required to understand it. They also need local graph focus without rebuilding or changing exported relationship meaning.

Project Mapper was reviewed late in development and includes selected-folder scanning with retained outside ancestors. That interaction was a late consideration; Script Dependency Inspector already had a deterministic canonical snapshot, explicit dependency kinds, validation, and export architecture.

## Decision

1. Always build one bounded full-project index for a scan.
2. Project the resulting snapshot onto the selected folder.
3. Keep in-folder scripts, complete visible inheritance chains, direct `uses`/`type_uses` targets, and ancestry required to explain those targets.
4. Label retained outside nodes as `context` with a reason; omit unrelated outside scripts.
5. Keep snapshot schema v2 and add scope fields additively.
6. Compute ancestor/descendant focus and neighborhood isolation through a pure query service over the scoped snapshot.
7. Treat focus/isolation as presentation state only.

## Alternatives rejected

- **Scan only the selected folder:** loses resolvable outside context and makes results depend on local duplication or unresolved placeholders.
- **Retain every outside dependency transitively:** can expand back toward the entire project and defeats the user's scope choice.
- **Mutate canonical edges for focus:** corrupts exports and mixes data semantics with interaction state.

## Consequences

- Selected scope does not reduce full-index acquisition cost or full-index diagnostics.
- Direct outside dependencies are visible, but dependencies of those context nodes are not recursively retained unless independently required; their inheritance ancestry is retained.
- Scope role is represented in text and diagram labels, not only by opacity.
- Project Mapper is cited for the late selected-folder/context interaction consideration; no code was copied.
