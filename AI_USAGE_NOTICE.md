# AI-assisted development notice

Script Dependency Inspector was developed with extensive assistance from generative AI systems, principally OpenAI ChatGPT. The v0.2.3 release-tooling work, v0.2.4 media workflow, and v0.3.0 requirements/design/quality implementation work used OpenAI models; earlier revisions may have used different model versions.

## How AI was used

AI assistance contributed to:

- requirements synthesis, design alternatives, and risk identification;
- code and refactoring drafts;
- automated-test and fixture drafts;
- documentation, release notes, use-case diagrams, and marketplace copy;
- static review suggestions, compatibility planning, and release packaging support;
- visual-asset and screenshot-state planning.

AI output was treated as proposed work, not as evidence that behavior was correct.

## Human direction and supervision

The project owner defined the product goals, accepted or rejected proposed features, set priorities, supplied target Godot versions and quality guidance, and reviewed delivered artifacts and UI states. Changes were constrained by explicit behavioral contracts, design decisions, compatibility boundaries, and release acceptance criteria. Final acceptance and distribution remain the responsibility of the project maintainer.

This notice does not claim that every line received an independent manual audit or that automated tests constitute independent human verification.

## Quality-control measures

AI-assisted changes are subjected to the same repository controls as other changes:

- requirement-to-design-to-test traceability and recorded review findings;
- diff and interface review against documented invariants and failure behavior;
- Godot parser/editor import checks;
- public, negative, boundary, synchronization, export-matrix, visual, and performance tests;
- execution against the supplied Linux builds of Godot 4.3, 4.4.1, 4.5.2, 4.6.3, and 4.7 for claimed releases;
- deterministic release construction, controlled second-build comparison where reproducibility is claimed, SHA-256 manifests, ZIP integrity checks, packaged-add-on smoke verification, and patch reconstruction;
- rendered screenshot and diagram inspection for clipping, state visibility, and documentation consistency;
- provenance, licensing, security-boundary, and unsupported-claim review.

Failures or unavailable tools are reported rather than converted into pass claims. Residual limits—including the absence of independent unfamiliar-user, accessibility, and human security-audit evidence—remain explicit.

## Provenance and licensing boundary

The project does **not** represent or warrant that datasets used to train any AI system were lawfully obtained, licensed, consented to, or otherwise authorized by every underlying rightsholder. Distribution under the MIT License does not approve, ratify, or grant rights to third-party material that may have been used to train an AI system.

The MIT License applies only to the copyrightable contents distributed with this project. Third-party names, trademarks, engine code, documentation, and other materials remain governed by their respective rights and licenses.

Contributors must submit only material they have the right to contribute. AI-generated or AI-assisted contributions must be reviewed for correctness, provenance risks, incompatible copying, security issues, and license conflicts before acceptance.
