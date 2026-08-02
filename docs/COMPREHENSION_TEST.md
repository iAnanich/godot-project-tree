# Graph comprehension test

## Purpose

This protocol tests whether a Godot developer unfamiliar with Script Dependency Inspector can correctly interpret the initial dock view and complete its core tasks without implementation knowledge. It is a human evaluation instrument, not an automated test.

## Current status

The interface has undergone an internal expert walkthrough against the tasks below. No independent participant study has yet been executed, so the project does **not** claim externally validated comprehension. The protocol and results template are included so release candidates can collect reproducible evidence instead of relying on informal impressions.

Screen-reader and exhaustive keyboard testing are outside the current acceptance scope by owner decision. Background/cancellable scanning is a deferred product feature, not a release blocker for this evaluation.

## Participants

Recruit at least three developers who:

- have used Godot 4 and can read basic GDScript;
- have not contributed to this add-on;
- have not read the add-on implementation or test suite;
- represent at least one small-project and one larger-project workflow.

## Test material

Use the bundled showcase project and the default dock configuration. Do not explain the legend, colors, tooltips, or controls before the first task. Record the Godot version, display scale, theme, viewport size, and add-on commit/release.

## Tasks and expected answers

1. **Identify a class.** Find one script with `class_name` and state the displayed name. Expected: custom class name, not a combined path/title.
2. **Identify an unnamed script.** Find the unnamed Node2D example. Expected: `ambient_marker`, derived from the filename.
3. **Find the source path.** Obtain the full `res://` path for either script. Expected: use the focused path action or member tooltip; do not infer the path from the title.
4. **Read inheritance.** State the direct base of `ShowcasePlayer`. Expected: the graph's inheritance relation, not a usage relation.
5. **Distinguish relation kinds.** Explain one inheritance edge, one literal/direct-use edge, and one type-annotation edge. Expected: correct legend/category interpretation and no claim that a type annotation executes or loads the target.
6. **Read inheritance families.** Identify one RefCounted-family and one Control-family node. Expected: family border/accent or summary/legend is used correctly; color name itself is not required.
7. **Change detail level.** Show full method signatures and property types, then return to compact names. Expected: use the content controls without rescanning.
8. **Export exact data.** Export JSON and identify where the full path and member provenance are stored. Expected: JSON selected as the lossless representation; Mermaid/PlantUML described as textual diagrams with format-specific limits.
9. **Explain arrow direction.** Explain why GraphEdit may render dependency → dependent while canonical export records dependent → dependency. Expected: recognizes layout direction versus data-model direction.

## Acceptance criteria

A release passes the independent comprehension gate when:

- every participant completes tasks 1–8;
- at least 90% of all scored tasks are correct without moderator instruction;
- no participant confuses inheritance with usage after consulting the visible legend;
- no participant believes a type-annotation edge proves runtime instantiation or execution;
- the median time for each task is at most 90 seconds;
- task 9 is answered correctly by at least two participants after using the Summary tab;
- every observed failure is recorded with the screen state and the participant's interpretation.

A moderator may answer environment questions but must not name controls, explain color meanings, or point to the correct node before scoring.

## Results template

Copy the following table for each participant:

| Field | Value |
|---|---|
| Participant ID | |
| Godot experience | |
| Godot version | |
| Theme / UI scale / viewport | |
| Release or commit | |

| Task | Correct | Time (s) | Assistance | Observation / misconception |
|---|---:|---:|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |
| 6 | | | | |
| 7 | | | | |
| 8 | | | | |
| 9 | | | | |

## Review outcome

Summarize findings as defects, design decisions, or accepted limitations. A screenshot proving that the dock rendered is not comprehension evidence; retain participant results and the exact tested build with the release record.
