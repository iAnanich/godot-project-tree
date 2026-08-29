# Script Dependency Inspector — repository and release requirements

Artifact identity: `script-dependency-inspector-release-requirements`  
Version: `0.2.0-alpha.1`  
Release state at issue: Accepted for v0.3.0 implementation  
Issue date: 2026-08-27


Status: proposed successor baseline for owner review  
Scope: repository knowledge, packaging, release automation, patching, quality gates, AI disclosure, and Godot Asset Library media

## 1. Purpose and separation from product behavior

This document defines how Script Dependency Inspector is maintained and delivered. It is not the runtime product-behavior contract.

`REQUIREMENTS.md` governs add-on behavior. `DESIGN.md` governs the selected product architecture. This document governs repository contents and release outputs.

## 2. Normative terms

The terms **must**, **must not**, **should**, **may**, and **can** use the meanings defined in `REQUIREMENTS.md`.

## 3. Repository knowledge boundary

### REL-REPO-001 — Keep durable project knowledge in the repository

The repository must retain durable knowledge required to understand, change, verify, and release the product, including as applicable:

- current product requirements;
- current design and architecture;
- current user use cases and their text alternatives;
- public snapshot schema and compatibility notes;
- accepted architecture decision records;
- security/trust-boundary documentation;
- performance contract and regression-fixture description;
- setup, contribution, and release instructions;
- current Asset Library copy and media;
- AI usage notice;
- tests and test fixtures.

### REL-REPO-002 — Do not retain ordinary internal review reports as active repository knowledge

Routine review reports, temporary review notes, and one-off generated critique artifacts must not be kept in the normal repository tree solely as historical evidence.

A review finding that creates a durable product decision must be converted into the appropriate requirement, design section, ADR, issue, or decision record. Release verification evidence may be attached to the release or retained in a designated evidence store without becoming active design authority.

### REL-REPO-003 — Avoid unrelated-project material

The repository must not contain documentation about the owner's unrelated projects unless the material is required by an explicit dependency or comparison decision for Script Dependency Inspector.

A narrow attribution to an external related tool is permitted when it records a specific late-considered feature source or licensing/provenance obligation.

### REL-REPO-004 — Project Mapper attribution boundary

Project Mapper must be referenced only as a **late consideration** where a feature was reviewed or adapted after the Script Dependency Inspector baseline design already existed.

The repository must not imply that Project Mapper was the origin of the product concept, canonical snapshot architecture, export architecture, or static-evidence model.

If a future feature is materially adapted from Project Mapper, the relevant ADR or notice must identify that feature and the nature of the adaptation.

## 4. AI-assisted development disclosure

### REL-AI-001 — Explicit AI usage notice

The repository must contain an `AI_USAGE_NOTICE.md` or equivalent current notice.

The notice must state:

- which development activities used generative AI;
- what the owner directed or approved;
- what supervision was applied;
- what verification and quality-control measures were used;
- which verification activities were independent of the generating model where applicable;
- what material review, security, accessibility, or comprehension work was not performed.

The notice must not claim that AI self-review is independent verification.

### REL-AI-002 — Marketplace summary

The Godot Asset Library description must include a concise summary that AI assistance was used and that owner direction plus project verification controls were applied. The summary must link or point to the full repository notice when the marketplace format permits it.

## 5. Development quality gates

### REL-DEV-001 — Pinned GDScript tooling

The repository must define reproducible development dependencies for `gdformat` and `gdlint`, including a pinned or otherwise explicitly controlled `gdtoolkit` version.

### REL-DEV-002 — Pre-commit execution

The repository must provide a pre-commit configuration that runs GDScript formatting and lint checks before a normal commit after the developer installs the hooks.

Formatting changes must remain visible for developer review and staging. The hook must not silently commit formatter changes.

### REL-DEV-003 — CI parity

GitHub CI should run the same material formatting/lint configuration used by local pre-commit hooks so local and remote gates do not intentionally disagree.

When a tool cannot run in an offline or constrained environment, release documentation must record the check as unavailable rather than claiming it passed.

## 6. Packaging requirements

### REL-PKG-001 — Redistributable add-on archive

Every release must provide a simple ZIP archive that installs as:

```text
addons/script_dependency_inspector/...
```

The archive must contain only files required by the redistributable add-on and its required notices/licenses.

### REL-PKG-002 — Complete project archive

Every release must provide a complete project/source archive that is sufficient to inspect, test, and reproduce the released project without requiring an earlier release archive.

### REL-PKG-003 — Deterministic packaging

Given the same accepted source tree and packaging-tool version, the release builder should produce byte-identical archives or document the metadata that prevents byte identity.

Release validation must distinguish "archive contents match" from "byte-identical deterministic archive".

### REL-PKG-004 — Generated-cache exclusion

Release archives must exclude generated or local state that is not part of the source contract, including as applicable:

- `.git/`;
- `.godot/`;
- Godot import sidecars and cache-only metadata such as `.import` and `.uid` where they are not source artifacts;
- Python cache/bytecode;
- local validation output;
- `dist/` build products nested inside the source archive.

### REL-PKG-005 — Verify the packaged add-on as delivered

Release verification must exercise the redistributable add-on ZIP after extraction into a clean Godot project or an equivalent isolated install surface.

The check must verify at least package structure, required notices/licenses, plugin discovery/initialization, and one representative public behavior. Source-tree execution alone does not satisfy this requirement.

## 7. Patch requirements

### REL-PATCH-001 — Per-release upgrade patch

Every release after a known exact baseline must provide a complete Git binary-capable patch from the immediately preceding released source tree.

### REL-PATCH-002 — Easy application

Patch notes must state the required base release and provide commands equivalent to:

```sh
git apply --check --binary --whitespace=nowarn <patch>
git apply --binary --whitespace=nowarn <patch>
```

### REL-PATCH-003 — Reconstruction verification

Before delivery, the complete patch must be applied to a clean copy or detached worktree of the exact baseline. The reconstructed Git tree must be compared with the target tree.

A patch must not be described as complete or applicable unless this reconstruction check succeeds or a limitation is explicitly reported.

### REL-PATCH-004 — Review-oriented text diff

A text-oriented patch or diff may be provided for review convenience. It must not be described as the reconstruction artifact when it omits binary or generated-but-source-controlled files.

## 8. GitHub release automation

### REL-GH-001 — Tag-triggered release workflow

The repository should provide a GitHub Actions workflow that builds release artifacts from a version tag and verifies that the tag/version agrees with the add-on's declared version.

### REL-GH-002 — Release artifacts

The tag workflow should attach, at minimum:

- redistributable add-on ZIP;
- complete project/source ZIP;
- immediate-predecessor binary-capable patch when the baseline tag exists;
- checksum list;
- current Asset Library media package when media is release-owned.

### REL-GH-003 — Least required repository permission

The release workflow must use only the repository permission required to create or update the release and attach artifacts. It must not require persistent personal credentials when the repository-scoped GitHub token is sufficient.

### REL-GH-004 — Free-tier assumption is not a product guarantee

Documentation may explain current GitHub-hosted runner availability or free-tier behavior, but billing limits are external and time-varying. The repository must not encode a permanent "free" guarantee as a project requirement.

## 9. Godot Asset Library media requirements

### REL-MEDIA-001 — Repository-owned current upload set

The repository must contain the latest thumbnail and featured media intended for the Godot Asset Library under a stable current-media directory.

The repository should also retain the source captures and a manifest that maps each published media file to its real capture source and use case.

### REL-MEDIA-002 — Real runtime/editor evidence

Featured media that represents the add-on graph, dock, source navigation, or export workflow must be derived from actual Godot runtime/editor screenshots of the released product.

AI-generated diagrams, fabricated graph layouts, or generated UI imitations must not replace screenshots that claim to show actual product behavior.

### REL-MEDIA-003 — Informational thumbnail

The Asset Library thumbnail may use editorial layout, titles, or callouts, but any embedded product UI must come from a real screenshot of the released product.

### REL-MEDIA-004 — Media format contract

Current Asset Library featured media must satisfy the accepted marketplace constraints:

- aspect ratio: exactly 16:9;
- recommended resolution: 1920 × 1080 pixels;
- minimum resolution: 1280 × 720 pixels;
- maximum file size: 600 KB per upload file;
- preferred format: WebP.

The thumbnail must also use a 16:9 aspect ratio.

### REL-MEDIA-005 — Focused showcase selection

The media set must use purpose-specific, focused scenarios rather than one cluttered full-project graph for every image.

At minimum, the maintained capture plan should cover:

- default dock with a small readable structure;
- each principal dock tab or menu for repository documentation;
- the same small structure with maximum supported information visible;
- a zoomed-out complex graph;
- selected node/member navigation with the Script Editor cursor at the corresponding source;
- export workflow or export-only graph-hidden operation;
- selected-scope/context behavior;
- search/focus behavior when it materially helps explain the product.

### REL-MEDIA-006 — Media validation

The repository must provide a script or deterministic check that verifies current upload media for required filenames/roles, aspect ratio, minimum resolution, preferred/accepted format, and maximum file size.

The check must validate the delivered files, not only the source-capture metadata.

### REL-MEDIA-007 — Godot import isolation

Repository documentation media that Godot does not need at runtime must be isolated from Godot resource importing, for example with `.gdignore` at the appropriate documentation boundary.

## 10. Marketplace-copy requirements

### REL-STORE-001 — Export capability must be prominent

The Asset Library description must state prominently that the add-on exports JSON, Mermaid, and PlantUML.

It must explain that these files can be used in third-party tools for larger canvases, alternative layout engines, themes, publication/presentation workflows, automation, or custom rendering.

### REL-STORE-002 — Built-in graph versus external renderers

Marketplace copy must present the built-in GraphEdit as an inspection surface. It may explain that external renderers can present the exported relationships differently or more suitably for documentation.

The copy must not imply that third-party renderers add semantic evidence that was not present in the export.

### REL-STORE-003 — Static-analysis boundary

Marketplace copy must preserve the source-analysis limitations. It must not describe the add-on as a complete runtime dependency or call-graph analyzer.

### REL-STORE-004 — Compatibility claims

Marketplace compatibility claims must match direct release evidence. Unsupported environments must not be implied by a broad "Godot 4" statement when only a narrower range has been tested.

## 11. Verification and evidence requirements

### REL-VERIFY-001 — Separate requirements from results

Requirements and design documents must not use a prior release's passed checks as current evidence for a later release.

Fresh release validation must record version, environment, method, observed result, and limitations.

### REL-VERIFY-002 — Per-version Godot compatibility

Each claimed Godot version must receive direct plugin initialization and relevant behavioral evidence in an isolated project copy or equivalent clean environment.

A single passing engine version must not be generalized to the full compatibility claim.

### REL-VERIFY-003 — Documentation consistency

Release validation must check that version identifiers, schema references, compatibility statements, Asset Library copy, AI notice, requirements, design, and use cases do not contradict the released source behavior on material points.

### REL-VERIFY-004 — Rendered media review

Current Asset Library media must be reviewed as rendered upload files at their final dimensions. Automated dimension/file-size checks do not establish legibility or representativeness.

### REL-VERIFY-005 — Checksums

Final release artifacts must have SHA-256 checksums calculated only after the artifacts are final.

Matching unsigned checksums establish integrity comparison, not producer authenticity.

### REL-VERIFY-006 — Regression-test sensitivity

A regression test added for a corrected defect must demonstrate that it detects the targeted incorrect behavior. Prefer an observed pre-fix failure on the exact baseline.

When direct pre-fix execution is unavailable or unsafe, the release evidence must record another credible sensitivity demonstration and its limitation.

### REL-VERIFY-007 — Required gates fail closed

A release must not be described as verified when a required gate failed, timed out, was skipped, or was unavailable.

The project owner may accept a release exception only when the exception record identifies the missing evidence, lost guarantee, scope, rationale, and review trigger.

### REL-VERIFY-008 — AI-generated test assertion review

Tests generated or materially rewritten with AI assistance must receive assertion review against the requirement or defect they claim to verify. A passing generated test is not independent evidence that its oracle is correct.

### REL-VERIFY-009 — Reproducibility claim requires a second controlled build

The project may describe a specified release archive as reproducible only after a second controlled build recreates that artifact byte for byte under the declared source state, build instructions, and environment assumptions.

A single successful build may establish build completion. It does not establish reproducibility.

## 12. Release completion states

A release may be described as:

- **verified for the stated release contract** when all required release checks have direct evidence;
- **conditionally accepted** when explicitly documented limitations remain but the owner accepts release use within them;
- **blocked** when a missing baseline, missing authority decision, failed compatibility gate, or unavailable required check prevents the release claim.

Producing archives or a patch does not by itself establish release completion.

## 13. Open release decisions

No new release-process decision is required by this documentation revision. The requirements above consolidate owner-approved directions already stated in the Project.
