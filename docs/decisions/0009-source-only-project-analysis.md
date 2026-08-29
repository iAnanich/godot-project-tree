# ADR 0009 — Do not load analyzed project scripts for dependency discovery

Status: accepted for v0.3.0  
Date: 2026-08-27  
Supersedes: the optional reflection-enrichment clause in ADR 0002 only

## Context

ADR 0002 permitted optional Godot `Script` reflection to enrich class/base resolution while keeping dependency evidence source-based. A controlled Godot 4.7 probe against the v0.2.4 implementation showed that `ResourceLoader.load()` of an analyzed GDScript can execute a static variable initializer. A representative showcase comparison also produced the same canonical snapshot with reflection disabled while avoiding reflection-related script-load noise.

Dependency inspection is intended to analyze saved project source without executing analyzed project code. Loading each analyzed script as a `Script` resource therefore crosses the intended trust boundary even when no project class instance is created.

## Decision

1. Dependency discovery must derive supported evidence from saved source text, project metadata, the global-class registry, and `ClassDB`.
2. `ProjectScanner` must not load analyzed project GDScript resources for dependency discovery or class/base enrichment.
3. The legacy `use_runtime_reflection` setting remains a compatibility no-op in v0.3.0. A later incompatible cleanup may remove it explicitly.
4. Required add-on implementation scripts may still be loaded through checked plugin-internal dependency boundaries. This decision applies to analyzed project scripts, not to the add-on loading its own implementation.
5. Missing edges continue to mean that the supported static analysis did not establish the relationship. They do not prove runtime independence.

## Alternatives considered

### Keep reflection behind an opt-in setting

Rejected. An opt-in still permits analysis-triggered project execution and creates two materially different trust boundaries for one product operation.

### Instantiate project classes only when reflection is requested

Rejected. This would widen the execution boundary further and conflicts with the product requirements.

### Remove all Godot metadata resolution

Rejected. Project global-class metadata and `ClassDB` can resolve supported names without loading the analyzed project script resource.

## Consequences

- Analysis has a clearer non-execution boundary for project scripts.
- Some class/base enrichment that depended only on runtime `Script` reflection can remain unresolved rather than being guessed.
- Existing serialized editor settings that contain `use_runtime_reflection` remain readable, but the value has no effect.
- Regression evidence must demonstrate that scanning a project script with a static initializer does not trigger that initializer.

## Review trigger

Reconsider only if Godot provides a documented metadata API that can inspect project scripts without loading or executing analyzed project code, or if the project owner explicitly changes the analysis trust boundary.
