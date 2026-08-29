# Script Dependency Inspector — quality contract

Artifact identity: `script-dependency-inspector-quality-contract`
Version: `0.2.1-alpha.1`
Release state at issue: Accepted for v0.3.1 implementation
Issue date: 2026-08-29


Status: accepted quality contract for v0.3.0 implementation; release-specific results remain separate
Applies to: product behavior and release acceptance
Decision owner: project owner

## 1. Purpose

This document selects the quality characteristics that materially affect Script Dependency Inspector and defines decision-useful scenarios for them. It does not replace `REQUIREMENTS.md` or `RELEASE-REQUIREMENTS.md`.

A quality scenario defines required assessment evidence. It is not a verification result. Release-specific results belong in delivery evidence.

## 2. Product and context

**Product:** Godot Editor add-on for bounded static GDScript structure/dependency inspection and export.

**Primary user:** Godot developer inspecting saved project source or producing JSON, Mermaid, or PlantUML architecture evidence.

**Supported environment claim:** the exact Godot versions and operating-system builds listed in `REQ-COMPAT-001` and confirmed for each release.

**Public contracts:** plugin initialization, saved-source analysis boundary, canonical snapshot schema, selected-scope semantics, editor-state compatibility, export semantics, package layout, and documented failure behavior.

**Specialist risk domains:**

- security is material at project-source parsing and filesystem-write boundaries; the add-on must not execute analyzed project classes to infer dependencies;
- accessibility is relevant to graph decoding and control use, but no formal accessibility conformance claim is established;
- safety, privacy, regulated-system, and scientific-validity assurance are not current product claims.

## 3. Selected quality characteristics

| Characteristic | Priority for this product | Why material |
|---|---|---|
| Functional suitability | high | Incorrect or invented relationships defeat the product purpose. |
| Reliability | high | Partial scans, synchronization, and export replacement must preserve understandable state. |
| Compatibility | high | The project claims operation across a specific Godot version range. |
| Interaction capability | high | The dock must make graph meaning, scope, scan mode, and export workflow usable without hidden semantics. |
| Maintainability | high | Static-analysis evidence classes, exporters, UI, and release tooling evolve independently and require explicit boundaries. |
| Performance efficiency | medium | Scans are synchronous; bounded work is required, but no universal user-project latency SLA is approved. |
| Security | medium | Project source is untrusted input and exports write files, but the add-on has no network service or credential boundary. |
| Flexibility | low/conditional | Extension frameworks are not a product goal unless two implementations or an external implementation path justify them. |
| Safety | not selected as a product claim | The editor add-on does not currently make a safety assurance claim. |

## 4. Quality scenarios

### QS-FS-01 — Deterministic supported analysis

**Actor/condition:** developer scans equivalent saved project inputs with equivalent options.
**Target property:** canonical supported evidence and ordering are deterministic.
**Acceptance:** contract-linked fixtures and schema comparisons match expected canonical output.
**Failure consequence:** misleading or unstable architecture evidence.

### QS-REL-01 — Partial-result distinction

**Condition:** an optional file or evidence class cannot be acquired or recognized, but structural invariants remain satisfiable.
**Target property:** the product reports diagnostics and preserves only supported evidence.
**Acceptance:** failure-path tests distinguish publishable partial results from fatal scan failure.
**Failure consequence:** false completeness or avoidable loss of valid evidence.

### QS-REL-02 — Export replacement recovery

**Condition:** replacement of an existing export fails after serialization has started.
**Target property:** the product reports the final state and preserves or restores the prior destination where the filesystem permits it.
**Acceptance:** failure-injection tests inspect the destination after the failed operation.
**Failure consequence:** silent loss or corruption of previously valid documentation output.

### QS-COMP-01 — Claimed Godot compatibility

**Condition:** the release is evaluated on each claimed Godot editor version.
**Target property:** plugin initialization and representative public behavior remain compatible.
**Acceptance:** isolated per-engine execution passes for every claimed version.
**Failure consequence:** published compatibility claim is unsupported.

### QS-INT-01 — Decodable graph meaning

**Condition:** developer views the graph at intended dock sizes.
**Target property:** relationship kind, direction, and scope/context role are available without color or hover as the only cue.
**Acceptance:** static UI checks plus final rendered review of representative states.
**Failure consequence:** users can misread relationship semantics.

### QS-INT-02 — Evidence-rich hover inspection

**Condition:** developer hovers a graph connection or member row.
**Target property:** the tooltip identifies the exact static relationship/member evidence without replacing visible graph semantics or implying runtime frequency.
**Acceptance:** behavioral tests verify full member declarations/count terminology, connection direction/evidence aggregation, and bounded occurrence presentation.
**Failure consequence:** hover repeats visible labels or misrepresents static evidence.

### QS-REL-03 — Actionable structural rejection

**Condition:** a candidate snapshot fails structural validation.
**Target property:** status and Log expose stable issue identity, selected root, message, and bounded structured context.
**Acceptance:** behavioral test verifies stable code/root/context survive UI rendering.
**Failure consequence:** users cannot diagnose a reproducible model-consistency defect.

### QS-PERF-01 — Bounded synchronous work

**Condition:** representative regression fixture exercises the synchronous scan path.
**Target property:** acquisition remains within explicit file/byte limits and the release-specific regression budget.
**Acceptance:** fresh measured run records fixture, hardware/environment, threshold, and result.
**Failure consequence:** editor stalls beyond the project's accepted regression envelope.

### QS-MAINT-01 — Localizable change boundaries

**Condition:** a maintainer changes one evidence class, exporter, projection policy, or presentation behavior.
**Target property:** the governing policy is identifiable and unrelated components need not change unless the contract couples them.
**Acceptance:** requirement-to-component mapping remains current; tests localize the changed contract; review records any cross-boundary edits that are necessary.
**Failure consequence:** future changes require hidden knowledge or unrelated edits.

### QS-PKG-01 — Distributed add-on usability

**Condition:** recipient installs the release add-on ZIP into a clean supported Godot project.
**Target property:** package layout, notices, plugin discovery, initialization, and representative behavior are intact.
**Acceptance:** isolated extracted-package smoke test passes.
**Failure consequence:** source-tree tests pass while the distributed product is unusable.

## 5. Evidence portfolio

Use complementary evidence only where it controls a material failure mode:

- contract-linked behavior tests;
- parser/projection boundary tests;
- structural schema validation;
- deterministic synchronization-state tests;
- filesystem failure injection for export recovery;
- static format/lint checks;
- per-engine compatibility runs;
- packaged-add-on smoke test;
- rendered UI/media review;
- second controlled build for a same-environment repeatability claim; independent rebuild evidence for any unqualified reproducibility claim;
- patch reconstruction against the exact baseline.

A green CI job is evidence that its configured checks ran successfully in that environment. It is not a substitute for the individual claims above.

## 6. Exceptions

Only the project owner can accept a missing required gate for a release. An exception record must identify:

- the gate and requirement;
- why the evidence is unavailable or rejected;
- the lost guarantee;
- affected versions/environments;
- compensating evidence, if any;
- acceptance rationale; and
- review trigger.

An unavailable required check is not a pass.

## 7. Unverified areas

Unless a later release adds direct evidence, this quality contract does not establish:

- compatibility outside the explicitly tested Godot/OS combinations;
- complete runtime dependency recovery;
- binary `.scn` analysis;
- background/cancellable scan correctness;
- formal accessibility conformance;
- unfamiliar-user comprehension;
- security certification or external security audit;
- universal latency or memory guarantees for arbitrary projects.
