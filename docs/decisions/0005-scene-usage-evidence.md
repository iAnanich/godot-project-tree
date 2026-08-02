# ADR 0005: Exact text-scene usage evidence

Status: accepted for v0.2.0

## Decision

Add a separate bounded scanner for `.tscn` files. Record only external Script resources that are assigned directly to scene nodes. Store scene path, node path, script path, source line, source column, and evidence kind in snapshot schema v2.

## Rationale

Scene files have a different grammar, size profile, and failure boundary from GDScript. A separate stage localizes failures and prevents scene heuristics from changing script-dependency meaning. Exact text records are useful for navigation and architecture review without claiming a complete resource graph.

## Exclusions

Binary `.scn` files, dynamically assigned scripts, inherited/instantiated-scene transitive effects, arbitrary resource references, and runtime modifications are not inferred.
