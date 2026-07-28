# ADR 0001: Use a versioned dictionary snapshot as the canonical boundary

- Status: Accepted
- Date: 2026-07-28

## Context

The scanner, editor renderer, and several exporters need one representation that is deterministic, JSON-compatible, inspectable in tests, and usable across Godot 4 minor versions. Custom model classes would create script-loading and serialization coupling at every boundary.

## Decision

Use a versioned dictionary/array snapshot with stable node IDs, canonical ordering, explicit edge kinds, and optional additive fields. Validate it before public serialization. JSON is the lossless export.

## Consequences

- Positive: simple serialization, reproducible fixtures, no object-lifecycle coupling, and straightforward third-party consumption.
- Negative: weaker compile-time typing and more runtime validation code.
- Constraint: required-field or semantic changes require a schema-version decision; unknown additive fields remain readable by version-1 consumers.

## Reversal condition

Reconsider only if dictionary validation and migration cost materially exceeds the compatibility benefit, with a demonstrated migration path for existing JSON consumers.
