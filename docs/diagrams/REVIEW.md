# Use-case diagram contract and rendered review

Version: 0.2.2

## Visualization contract

- **Audience:** Godot developers and project reviewers with ordinary software-design literacy.
- **Purpose:** explain intended product use, optional graph rendering, analysis/navigation boundaries, and synchronization/export control flow.
- **Primary questions:** What can a user accomplish? Can export operate without GraphEdit? How do editor and timed triggers lead to validation and independent file outputs?
- **Takeaway:** one bounded static-analysis pipeline produces a validated snapshot; GraphEdit is optional, while JSON/Mermaid/PlantUML exports can be consumed by dedicated tools.
- **Evidence scope:** approved v0.2.2 behavioral contract and implemented control flow; no quantitative data are encoded.
- **Medium:** repository Markdown and scalable SVG with authoritative nearby text alternatives in `USE_CASES.md`.
- **Encoding:** labelled actor boxes, use-case ellipses or rounded process boxes, diamonds for decisions, solid control/participation edges, and dashed refinement/trigger edges. Color is decorative and redundant.
- **Non-meaning:** distance and edge length do not represent magnitude, priority, duration, or confidence.

## Rendered review record

- **Artifacts:** three SVGs rendered from corresponding DOT sources with the installed Graphviz `dot` executable.
- **Checks:** labels present; no clipped nodes/edges; graph-enabled versus export-only branch explicit; external tool actor visible; line semantics stated; no color-only meaning; text alternatives present; terminology matches contract/design; no unsupported feature claim.
- **Result:** accepted for repository documentation.
- **Limits:** no screen-reader study, unfamiliar-user comprehension study, mobile reflow study, or formal WCAG claim. The adjacent text catalogue is authoritative.
