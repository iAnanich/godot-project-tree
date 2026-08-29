# ADR 0002: Keep dependency discovery conservative and source-based

- Status: Accepted; reflection-enrichment clause superseded by ADR 0009
- Date: 2026-07-28
- Partial supersession: ADR 0009 (2026-08-27)

## Context

A complete GDScript call graph would require compiler-grade parsing plus runtime and dispatch information that is unavailable or unsafe to infer in an editor inspection tool. Guessing creates authoritative-looking false relationships.

## Decision

Recognize explicit source evidence only: inheritance declarations, literal `.gd` loads, declared types, and direct class-qualified member access. Do not infer ordinary instance calls, aliases, dependency-injection targets, virtual dispatch, evaluated expressions, or dynamic resource paths.

Historical note: this ADR originally permitted optional Godot `Script` reflection for class/base enrichment. ADR 0009 supersedes that clause. v0.3.0 must not load analyzed project GDScript resources for dependency discovery.

## Consequences

- Positive: deterministic output, explainable evidence, and low false-positive pressure.
- Negative: incomplete runtime dependency coverage and a large hand-written analyzer that must be characterized carefully.
- User contract: absence of an edge means “not established by supported static evidence,” not “no runtime dependency exists.”

## Reversal condition

Add a stronger parser or language-server integration only behind a capability boundary with equivalent fixtures, failure diagnostics, compatibility evidence, and a documented confidence model.
