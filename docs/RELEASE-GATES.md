# Script Dependency Inspector — release gates

Artifact identity: `script-dependency-inspector-release-gates`
Version: `0.2.1-alpha.1`
Release state at issue: Accepted for v0.3.1 implementation
Issue date: 2026-08-29


Status: accepted release-gate contract for v0.3.1; release-specific results are retained outside this substantive contract
Exception authority: project owner

## 1. Purpose

Each gate controls one release claim. A gate result must record the environment, method, observed result, and limitation. A skipped, unavailable, timed-out, or failed required gate does not count as a pass.

| Gate ID | Claim controlled | Required check or review | Environment | Acceptance condition | Retained evidence |
|---|---|---|---|---|---|
| RG-01 | source contract is internally consistent | static requirements/design/schema/version/license/handoff consistency check | target source tree | no unresolved contradiction that changes runtime or release behavior | machine log plus material manual findings |
| RG-02 | GDScript source meets configured mechanical checks | `gdformat --check` and `gdlint` using pinned project configuration | declared development environment / CI | commands exit successfully with no hidden skip | command log and tool versions |
| RG-03 | contract-linked behavior is verified | public regression suites and targeted defect tests | isolated target project | all required tests pass; defect regressions demonstrate sensitivity | test log and verification mapping |
| RG-04 | synchronization/export lifecycle is verified | deterministic lifecycle and export-matrix tests | isolated target project | required scenarios pass, including partial-format failure and self-event suppression | test log |
| RG-05 | claimed Godot compatibility is supported | plugin initialization plus representative behavior on each claimed engine | one isolated project per claimed engine | every claimed version passes | per-engine logs |
| RG-06 | distributed add-on package is usable | build add-on ZIP, extract into clean project, initialize plugin, run representative behavior | clean supported Godot environment | package contents and smoke behavior pass | package inventory and smoke-test log |
| RG-07 | project source archive is complete and safe | build, extract, inventory, traversal/cache/secret checks, manifest verification | clean temporary workspace | archive matches source contract and exclusions | archive inventory and manifest check |
| RG-08 | immediate-predecessor patch is applicable | apply binary-capable patch to exact baseline and compare target tree | detached/clean baseline worktree | reconstructed tree matches target within declared metadata exclusions | patch log, baseline/target hashes |
| RG-09 | documentation matches released behavior | check version/schema/compatibility/store/AI/use-case/requirements/design consistency | final target tree and release docs | no material contradiction | documentation consistency report |
| RG-10 | Asset Library media is upload-valid when media is release-owned or changed | final-file format/dimension/size validation plus rendered review | final upload files | all contract checks pass and representative images are legible | media validator output and review record |
| RG-11 | same-environment repeatability claim is supported | second controlled build of each artifact claimed repeatable | declared source state, build instructions, and environment | byte-identical result for claimed artifact | artifact hashes and build environment record |
| RG-12 | final delivery integrity is recorded | calculate SHA-256 after all artifacts are final and verify the list | final delivery directory | all listed hashes verify | checksum file and verification log |

## 2. Gate exceptions

A release exception must name the gate, missing evidence, lost guarantee, affected scope, rationale, owner approval, and review trigger.

A release with a required unresolved gate must be described as `conditionally accepted` or `blocked`, not `verified`, according to `RELEASE-REQUIREMENTS.md`.

## 3. Gate ordering

Use a diagnostic-cost order where practical:

1. RG-01 and RG-02;
2. targeted tests in RG-03/04;
3. RG-05 and RG-06;
4. RG-07 and RG-08;
5. RG-09 and RG-10;
6. RG-11 when a same-environment repeatability claim is intended;
7. RG-12 after artifacts are final.

The order is a workflow decision, not a claim that later gates are more important.

A same-operator or same-machine second build can support repeatability/determinism only. An unqualified reproducibility claim additionally requires recreation by a separate operator or independently controlled build service from the declared source, environment, and instructions.
