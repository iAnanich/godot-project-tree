# ADR 0007 — Optional graph rendering and hierarchical controls

Status: accepted for v0.2.2
Date: 2026-07-29

## Context

The dock treated GraphEdit as mandatory, used a format selector that expanded disproportionately, did not expose active scan triggers near **Scan**, and presented long flat option lists. Some users need only synchronized file exports for external diagram tools.

## Decision

- Keep scanning, validation, diagnostics, and export independent of graph rendering.
- Add a default-on persisted **Graph** toggle. Hiding it releases rendered nodes but preserves the current snapshot; showing it rerenders without scanning.
- Put a derived scan-mode indicator beside **Scan**.
- Separate Scan and Export task groups and constrain the format selector to compact width.
- Group control tabs into persisted foldable semantic sections.

## Consequences

The dock supports both interactive and export-only workflows and uses space according to task priority. Graph-only actions are unavailable while hidden. Editor-state schema advances to version 4. UI tests must verify retention/rerender behavior and all fold headers require tooltips. Export semantics and snapshot schema remain unchanged.
