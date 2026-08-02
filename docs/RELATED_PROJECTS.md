# Related projects and late considerations

## Project Mapper

[Project Mapper](https://github.com/Eefschmeef2310/Project-Mapper), by Eefschmeef2310, was discovered and reviewed late in development, after Script Dependency Inspector's core concept, canonical snapshot, dependency categories, exporters, validation boundary, automation system, and v0.1.8 implementation already existed. It is therefore recorded as a **late consideration**, not as the original inspiration.

No Project Mapper source code was copied. The review informed feature selection and interaction design only.

| Script Dependency Inspector feature | Relationship to Project Mapper | Material difference |
|---|---|---|
| Source-line navigation | Adapted as a late consideration in v0.2.0 | Uses canonical one-based declaration/occurrence locations and explicit fallback. |
| Graph search and focus | Adapted as a late consideration in v0.2.0 | Searches names, paths, members, autoloads, scenes, and scene-node paths. |
| Active-script graph synchronization | Adapted as a late consideration in v0.2.0 | Independent, persisted, default-on option. |
| Autoload classification | Adapted as a late consideration in v0.2.0 | Stored in snapshot v2 and exposed without color-only meaning. |
| Scene usage presentation | Adapted as a late consideration in v0.2.0 | Exact direct text-`.tscn` evidence with scene/node/line data; binary and dynamic cases are omitted. |
| Selected-folder inspection with retained outside context | Adapted as a late consideration in v0.2.1 | Implemented as deterministic projection over a validated full-project snapshot; retains ancestor chains and direct dependency targets, labels context in graph/JSON/diagrams, and validates scope counts. |
| Inheritance-path emphasis and descendant counts | Adapted as a late consideration in v0.2.1 | Implemented as pure presentation queries that do not alter canonical data or exports. |

Project Mapper's selected-folder scanning and optional main-screen placement were added after public feedback in commit [`3ed1451`](https://github.com/Eefschmeef2310/Project-Mapper/commit/3ed1451fb54e86e78e21414909edd2f99e93b8fc), corresponding to [issue 2](https://github.com/Eefschmeef2310/Project-Mapper/issues/2). The selected-folder/context interaction is now implemented and attributed above. Main-screen placement remains deferred and is not an immediate priority.

Project Mapper remains MIT-licensed under its repository. This document records provenance of product considerations; it does not import that project's code or license into this Apache-2.0 project.
