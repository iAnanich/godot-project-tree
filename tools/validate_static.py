#!/usr/bin/env python3
"""Static integrity checks for the Script Dependency Inspector development project."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT / "addons" / "script_dependency_inspector"

EXPECTED = [
    ROOT / "project.godot",
    ROOT / "README.md",
    ROOT / "CONTRIBUTING.md",
    ROOT / "CHANGELOG.md",
    ROOT / "docs" / "ARCHITECTURE.md",
    ROOT / "docs" / "SCHEMA.md",
    ROOT / "docs" / "SECURITY.md",
    ROOT / "docs" / "PERFORMANCE.md",
    ROOT / "docs" / "QUALITY_REVIEW.md",
    ROOT / "docs" / "images" / "v0.1.6-default-dock.png",
    ROOT / "docs" / "images" / "v0.1.6-summary.png",
    ROOT / "docs" / "images" / "v0.1.6-advanced.png",
    ROOT / "docs" / "schema" / "snapshot-v1.schema.json",
    ROOT / "docs" / "decisions" / "0001-canonical-dictionary-snapshot.md",
    ROOT / "docs" / "decisions" / "0002-source-analysis-boundary.md",
    PLUGIN / "plugin.cfg",
    PLUGIN / "plugin.gd",
    PLUGIN / "default_settings.tres",
    PLUGIN / "core" / "snapshot_validator.gd",
    PLUGIN / "ui" / "dependency_dock.tscn",
    PLUGIN / "ui" / "dependency_graph_node.tscn",
    ROOT / "tests" / "README.md",
    ROOT / "tests" / "test_runner.gd",
    ROOT / "tests" / "performance_runner.gd",
    ROOT / "tests" / "generate_showcase_exports.gd",
    ROOT / "tests" / "contracts" / "exporter_contract.gd",
    ROOT / "tests" / "suites" / "quality_contract_suite.gd",
    ROOT / "tools" / "run_validation.py",
    ROOT / "tools" / "build_release.py",
    ROOT / "examples" / "showcase" / "README.md",
    ROOT / "examples" / "showcase" / "services" / "targeting_service.gd",
    ROOT / "examples" / "showcase" / "representations" / "showcase.json",
    ROOT / "examples" / "showcase" / "representations" / "showcase.mmd",
    ROOT / "examples" / "showcase" / "representations" / "showcase.puml",
]

ALLOWED_SYNTHETIC_RES_PATHS = {
    "res://nested.gd",
    "res://not_a_dependency.gd",
    "res://inside_doc.gd",
    "res://multiline.gd",
    "res://does_not_exist",
    "res://example.gd",
    "res://a.gd",
    "res://b.gd",
    "res://grandchild.gd",
    "res://presentation_example.gd",
    "res://object_script.gd",
    "res://ref_counted_script.gd",
    "res://node_script.gd",
    "res://node_2d_script.gd",
    "res://node_3d_script.gd",
    "res://control_script.gd",
    "res://performance_fixture.gd",
    "res://synthetic",
    "res://../outside",
    "res://.godot/",
}

ALLOWED_SYNTHETIC_RES_PREFIXES = (
    "res://synthetic/",
)

failures: list[str] = []
notes: list[str] = []
checks = 0


def check(condition: bool, message: str) -> None:
    global checks
    checks += 1
    if not condition:
        failures.append(message)


def res_to_path(value: str) -> Path | None:
    if not value.startswith("res://"):
        return None
    return ROOT / value.removeprefix("res://")


def validate_expected_files() -> None:
    for path in EXPECTED:
        check(path.is_file(), f"Missing required file: {path.relative_to(ROOT)}")


def validate_resource_references() -> None:
    resource_pattern = re.compile(r"res://[A-Za-z0-9_./-]+")
    suffixes = {".gd", ".tscn", ".tres", ".cfg", ".godot"}
    for source in sorted(ROOT.rglob("*")):
        if not source.is_file() or source.suffix not in suffixes:
            continue
        if ".godot" in source.relative_to(ROOT).parts:
            continue
        text = source.read_text(encoding="utf-8")
        for value in sorted(set(resource_pattern.findall(text))):
            value = value.rstrip(".,;:)]}'\"")
            if value in ALLOWED_SYNTHETIC_RES_PATHS or value.startswith(ALLOWED_SYNTHETIC_RES_PREFIXES):
                continue
            target = res_to_path(value)
            if target is None:
                continue
            check(
                target.exists(),
                f"Broken resource reference in {source.relative_to(ROOT)}: {value}",
            )


def parse_unique_nodes(scene: Path) -> set[str]:
    text = scene.read_text(encoding="utf-8")
    nodes: set[str] = set()
    current_name: str | None = None
    for line in text.splitlines():
        match = re.match(r'\[node name="([^"]+)"', line)
        if match:
            current_name = match.group(1)
            continue
        if current_name and line.strip() == "unique_name_in_owner = true":
            nodes.add(current_name)
    return nodes


def validate_unique_name_contract(script: Path, scene: Path) -> None:
    references = set(re.findall(r"%([A-Z]\w*)", script.read_text(encoding="utf-8")))
    unique_nodes = parse_unique_nodes(scene)
    missing = sorted(references - unique_nodes)
    check(
        not missing,
        f"{script.relative_to(ROOT)} references missing unique scene nodes: {missing}",
    )


def validate_scene_ids_and_paths() -> None:
    for scene in sorted(list(ROOT.rglob("*.tscn")) + list(ROOT.rglob("*.tres"))):
        text = scene.read_text(encoding="utf-8")
        ids = re.findall(r'\[ext_resource[^\]]* id="([^"]+)"\]', text)
        check(
            len(ids) == len(set(ids)),
            f"Duplicate ext_resource IDs in {scene.relative_to(ROOT)}",
        )
        node_keys: list[tuple[str, str]] = []
        for line in text.splitlines():
            if not line.startswith("[node "):
                continue
            name_match = re.search(r'name="([^"]+)"', line)
            parent_match = re.search(r'parent="([^"]*)"', line)
            if name_match:
                node_keys.append(((parent_match.group(1) if parent_match else ""), name_match.group(1)))
        check(
            len(node_keys) == len(set(node_keys)),
            f"Duplicate node declarations in {scene.relative_to(ROOT)}",
        )


def validate_graph_ports() -> None:
    script = PLUGIN / "ui" / "dependency_graph_node.gd"
    scene = PLUGIN / "ui" / "dependency_graph_node.tscn"
    slot_indices = [int(value) for value in re.findall(r"set_slot\((\d+)", script.read_text())]
    direct_rows = len(
        re.findall(r'^\[node name="[^"]+"[^\]]* parent="\."', scene.read_text(), re.MULTILINE)
    )
    check(bool(slot_indices), "Graph node script must configure at least one GraphNode slot.")
    if slot_indices:
        check(
            direct_rows > max(slot_indices),
            "GraphNode scene does not have enough direct child rows for configured slot indices.",
        )


def validate_plugin_contract() -> None:
    plugin_cfg = (PLUGIN / "plugin.cfg").read_text(encoding="utf-8")
    script_match = re.search(r'^script="([^"]+)"', plugin_cfg, re.MULTILINE)
    check(script_match is not None, "plugin.cfg has no script entry.")
    if script_match:
        script_value = script_match.group(1)
        path = res_to_path(script_value) if script_value.startswith("res://") else PLUGIN / script_value
        check(path is not None and path.is_file(), "plugin.cfg points to a missing script.")

    plugin_script = (PLUGIN / "plugin.gd").read_text(encoding="utf-8")
    check("extends EditorPlugin" in plugin_script, "Plugin entry point must extend EditorPlugin.")
    check("add_control_to_dock(" in plugin_script, "Plugin does not register its dock.")
    check("remove_control_from_docks(" in plugin_script, "Plugin does not remove its dock.")

    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    check(
        "res://addons/script_dependency_inspector/plugin.cfg" in project,
        "Development project does not enable the plugin.",
    )


def validate_compatibility_guardrails() -> None:
    plugin_text = "\n".join(
        path.read_text(encoding="utf-8") for path in sorted(PLUGIN.rglob("*.gd"))
    )
    forbidden = {
        "show_menu =": "GraphEdit.show_menu is not part of the Godot 4.0 baseline.",
        "add_dock(": "Newer dock API must not replace the Godot 4.0 dock API directly.",
        "/mnt/data/": "Build-environment paths must not be embedded in the plugin.",
    }
    for token, message in forbidden.items():
        check(token not in plugin_text, message)

    compat = (PLUGIN / "core" / "compat.gd").read_text(encoding="utf-8")
    check(
        'has_method("arrange_nodes")' in compat,
        "Optional graph arrangement must remain capability-checked.",
    )
    check(
        'call_optional(script, &"get_global_name")' in compat,
        "Script.get_global_name must remain behind the compatibility shim.",
    )


def validate_runtime_dependency_policy() -> None:
    """Prevent parse-time preload chains in production plugin scripts."""
    for script in sorted(PLUGIN.rglob("*.gd")):
        text = script.read_text(encoding="utf-8")
        preload_assignment = re.search(
            r"^(?:const|var)\s+[A-Za-z_]\w*(?:\s*:[^=]+)?\s*(?::=|=)\s*preload\s*\(",
            text,
            re.MULTILINE,
        )
        check(
            preload_assignment is None,
            f"Production script uses a parse-time preload assignment: {script.relative_to(ROOT)}",
        )

    dock_scene = (PLUGIN / "ui" / "dependency_dock.tscn").read_text(encoding="utf-8")
    check(
        "default_settings.tres" not in dock_scene,
        "Dock scene must not parse-load default settings before dependency diagnostics can run.",
    )

    path_constants = 0
    definition_pattern = re.compile(
        r"^const\s+([A-Za-z_]\w*)(?:\s*:\s*String)?\s*=\s*(.+)$",
        re.MULTILINE,
    )
    literal_pattern = re.compile(r'^"([^"\\]*(?:\\.[^"\\]*)*)"$')
    concat_pattern = re.compile(
        r'^([A-Za-z_]\w*)\s*\+\s*"([^"\\]*(?:\\.[^"\\]*)*)"$'
    )
    for script in sorted(PLUGIN.rglob("*.gd")):
        definitions = dict(definition_pattern.findall(script.read_text(encoding="utf-8")))
        resolved: dict[str, str] = {}
        made_progress = True
        while made_progress:
            made_progress = False
            for name, expression in definitions.items():
                if name in resolved:
                    continue
                expression = expression.strip()
                literal_match = literal_pattern.fullmatch(expression)
                if literal_match:
                    resolved[name] = bytes(literal_match.group(1), "utf-8").decode(
                        "unicode_escape"
                    )
                    made_progress = True
                    continue
                concat_match = concat_pattern.fullmatch(expression)
                if concat_match and concat_match.group(1) in resolved:
                    suffix = bytes(concat_match.group(2), "utf-8").decode("unicode_escape")
                    resolved[name] = resolved[concat_match.group(1)] + suffix
                    made_progress = True
        for name, value in sorted(resolved.items()):
            if not name.endswith("_PATH"):
                continue
            path_constants += 1
            target = res_to_path(value)
            check(
                target is not None and target.is_file(),
                f"Required resource path constant is unresolved in {script.relative_to(ROOT)}: {value}",
            )
    check(path_constants >= 10, "Expected required resource path constants were not discovered.")



def validate_release_regressions() -> None:
    settings_resource = (PLUGIN / "default_settings.tres").read_text(encoding="utf-8")
    check(
        settings_resource.startswith('[gd_resource type="Resource"'),
        "default_settings.tres must declare its Resource type in the gd_resource header.",
    )

    for script in sorted(PLUGIN.rglob("*.gd")):
        text = script.read_text(encoding="utf-8")
        risky_inference = re.search(
            r"^\s*var\s+[A-Za-z_]\w*\s*:=",
            text,
            re.MULTILINE,
        )
        check(
            risky_inference is None,
            f"Production script reintroduced untyped := inference: {script.relative_to(ROOT)}",
        )

    plugin_cfg = (PLUGIN / "plugin.cfg").read_text(encoding="utf-8")
    check('version="0.1.6"' in plugin_cfg, "plugin.cfg version is not 0.1.6.")

    showcase_json = ROOT / "examples" / "showcase" / "representations" / "showcase.json"
    if showcase_json.is_file():
        import json

        try:
            snapshot = json.loads(showcase_json.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            check(False, f"Showcase JSON is invalid: {error}")
        else:
            check(snapshot.get("schema_version") == 1, "Showcase JSON schema version is invalid.")
            check(len(snapshot.get("nodes", [])) == 25, "Showcase JSON should contain 25 nodes.")
            check(len(snapshot.get("edges", [])) == 36, "Showcase JSON should contain 36 edges.")
            type_edges = [edge for edge in snapshot.get("edges", []) if edge.get("kind") == "type_uses"]
            check(len(type_edges) == 8, "Showcase JSON should contain eight type-use edges.")
            check(
                any(
                    edge.get("source") == "res://examples/showcase/services/targeting_service.gd"
                    and edge.get("target") == "res://examples/showcase/actors/base_actor.gd"
                    for edge in type_edges
                ),
                "Showcase JSON is missing the annotation-only targeting-service dependency.",
            )
            check(
                any(
                    edge.get("source") == "res://examples/showcase/actors/base_actor.gd"
                    and edge.get("target") == "res://examples/showcase/services/damage_service.gd"
                    and any(
                        link.get("source_member", {}).get("name") == "attack_power"
                        and link.get("target_member", {}).get("name") == "calculate_damage"
                        for link in edge.get("member_links", [])
                    )
                    for edge in snapshot.get("edges", [])
                ),
                "Showcase JSON is missing the member-to-member damage-service dependency.",
            )
            check(not snapshot.get("errors", []), "Showcase JSON contains graph errors.")

def validate_v014_feature_contracts() -> None:
    settings = (PLUGIN / "core" / "settings.gd").read_text(encoding="utf-8")
    dock_scene = (PLUGIN / "ui" / "dependency_dock.tscn").read_text(encoding="utf-8")
    dock_script = (PLUGIN / "ui" / "dependency_dock.gd").read_text(encoding="utf-8")
    node_script = (PLUGIN / "ui" / "dependency_graph_node.gd").read_text(encoding="utf-8")
    analyzer = (PLUGIN / "core" / "gdscript_analyzer.gd").read_text(encoding="utf-8")
    builder = (PLUGIN / "core" / "graph_builder.gd").read_text(encoding="utf-8")

    for flag in [
        "show_method_signatures",
        "show_signal_signatures",
        "show_property_types",
        "include_type_dependencies",
    ]:
        check(flag in settings and flag in dock_script, f"Missing presentation option: {flag}")
    for color in ["property_color", "signal_color", "method_color", "metadata_color"]:
        check(color in settings and color in node_script, f"Missing member color contract: {color}")
    for node_name in [
        "Content", "Appearance", "Colors", "Log", "MethodSignatures", "PropertyTypes",
        "NativeNodeWidth", "MaxMemberHeight", "TypeDependencyColor",
    ]:
        check(f'name="{node_name}"' in dock_scene, f"Dock scene is missing control: {node_name}")
    check('parent="MainSplit/ControlsTabs' in dock_scene, "Controls must remain above GraphEdit in the vertical split.")
    check('kind == "native"' in node_script and 'member_scroll.visible = false' in node_script,
          "Native-node compaction contract is missing.")
    check("_depth_for" in dock_script and "_layout_sort_key" in dock_script,
          "Deterministic depth layout contract is missing.")
    check('"type_references"' in analyzer and "_collect_source_scope_type_reference_details" in analyzer,
          "Type-annotation source analysis is missing.")
    check('"type_uses"' in builder, "Graph builder does not emit type-use edges.")
    for flag in ["include_member_access_dependencies", "show_member_dependency_edges"]:
        check(flag in settings and flag in dock_script, f"Missing member dependency option: {flag}")
    for node_name in ["IncludeMemberAccessDependencies", "ShowMemberDependencyEdges"]:
        check(f'name="{node_name}"' in dock_scene, f"Dock scene is missing member dependency control: {node_name}")
    check('"member_links"' in builder and 'member_accesses' in analyzer,
          "Canonical member dependency provenance is missing.")
    check('port_for_member' in node_script and '_member_ports' in node_script,
          "GraphNode member-edge anchor contract is missing.")
    for family in [
        "object_family_color", "ref_counted_family_color", "node_family_color",
        "node_2d_family_color", "node_3d_family_color", "control_family_color",
    ]:
        check(family in settings and family in node_script, f"Missing inheritance-family color: {family}")
    check('"inheritance_family"' in builder and "_classify_native_family" in builder,
          "Inheritance-family classification contract is missing.")
    check('get_parent_class' in builder, "Native intermediary bases must be discovered through ClassDB.")
    check(
        'tooltip_text = ""' in node_script
        and 'path_button.tooltip_text = "Script path:\\n%s\\n\\nPress to copy." % path' in node_script
        and 'DisplayServer.clipboard_set(path)' in node_script,
        "GraphNode-wide tooltip masking or keyboard-accessible path tooltip contract is missing.",
    )
    check('graph_node_max_width' in settings and 'layout_size()' in node_script,
          "Adaptive GraphNode sizing contract is missing.")
    check('_id_to_graph_name[edge["target"]]' in dock_script,
          "Rendered GraphEdit connections must point dependency/base to dependent for arrangement.")


def validate_schema_contract() -> None:
    schema_path = ROOT / "docs" / "schema" / "snapshot-v1.schema.json"
    showcase_path = ROOT / "examples" / "showcase" / "representations" / "showcase.json"
    try:
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        check(False, f"Snapshot JSON Schema is unreadable or invalid JSON: {error}")
        return
    try:
        snapshot = json.loads(showcase_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        check(False, f"Showcase JSON is unreadable or invalid: {error}")
        return
    try:
        import jsonschema
    except ImportError:
        notes.append("Skipped optional JSON Schema validation: jsonschema")
    else:
        try:
            jsonschema.Draft202012Validator.check_schema(schema)
        except jsonschema.SchemaError as error:
            check(False, f"Snapshot JSON Schema is invalid: {error.message}")
        else:
            errors = sorted(
                jsonschema.Draft202012Validator(schema).iter_errors(snapshot),
                key=lambda error: list(error.absolute_path),
            )
            check(
                not errors,
                "Showcase JSON violates snapshot-v1 schema: "
                + "; ".join(error.message for error in errors[:5]),
            )
    check("diagnostics" in snapshot, "Showcase JSON should expose structured diagnostics.")


def validate_documentation_contract() -> None:
    markdown_files = sorted(ROOT.rglob("*.md"))
    local_link_pattern = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
    for document in markdown_files:
        text = document.read_text(encoding="utf-8")
        for raw_target in local_link_pattern.findall(text):
            target = raw_target.split("#", 1)[0].strip()
            if not target or "://" in target or target.startswith("mailto:"):
                continue
            resolved = (document.parent / target).resolve()
            try:
                resolved.relative_to(ROOT.resolve())
            except ValueError:
                check(False, f"Documentation link escapes project root in {document.relative_to(ROOT)}: {target}")
                continue
            check(
                resolved.exists(),
                f"Broken documentation link in {document.relative_to(ROOT)}: {target}",
            )
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    for required_reference in [
        "docs/ARCHITECTURE.md",
        "docs/SCHEMA.md",
        "docs/SECURITY.md",
        "CONTRIBUTING.md",
        "CHANGELOG.md",
    ]:
        check(required_reference in readme, f"README does not link to {required_reference}.")
    check("0.1.6" in readme, "README release identifier is not 0.1.6.")


def validate_quality_contracts() -> None:
    service = (PLUGIN / "export" / "export_service.gd").read_text(encoding="utf-8")
    validator = (PLUGIN / "core" / "snapshot_validator.gd").read_text(encoding="utf-8")
    dock_scene = (PLUGIN / "ui" / "dependency_dock.tscn").read_text(encoding="utf-8")
    dock_script = (PLUGIN / "ui" / "dependency_dock.gd").read_text(encoding="utf-8")
    scanner = (PLUGIN / "core" / "project_scanner.gd").read_text(encoding="utf-8")
    for code in [
        "invalid_snapshot",
        "empty_export_output",
        "duplicate_exporter",
        "commit_and_restore_failed",
    ]:
        check(code in service, f"Export service is missing structured failure code: {code}")
    for code in [
        "invalid_schema_version_type",
        "missing_node_field",
        "invalid_node_field",
        "missing_edge_field",
        "invalid_edge_field",
        "invalid_snapshot_message",
        "duplicate_node_id",
        "dangling_edge_target",
        "unknown_member_reference",
        "invalid_diagnostic_severity",
    ]:
        check(code in validator, f"Snapshot validator is missing issue code: {code}")
    check("follow_symbolic_links" in scanner and "invalid_scan_root" in scanner,
          "Scanner trust-boundary controls are missing.")
    for node_name in ["LegendPanel", "LegendView", "Summary", "SummaryView"]:
        check(f'name="{node_name}"' in dock_scene, f"Dock scene is missing accessible decoding control: {node_name}")
    check("_update_legend" in dock_script and "_update_summary" in dock_script,
          "Dock does not maintain legend and non-visual summary output.")
    check((ROOT / "tests" / "contracts" / "exporter_contract.gd").is_file(),
          "Reusable exporter contract suite is missing.")



def validate_public_method_documentation() -> None:
    """Require local API documentation for every non-private add-on method."""
    for script in sorted(PLUGIN.rglob("*.gd")):
        lines = script.read_text(encoding="utf-8").splitlines()
        for index, line in enumerate(lines):
            if not line.startswith("func ") or line.startswith("func _"):
                continue
            method_name = line.removeprefix("func ").split("(", 1)[0]
            preceding = lines[max(0, index - 4):index]
            check(
                any(candidate.lstrip().startswith("##") for candidate in preceding),
                f"Public method lacks a GDScript documentation comment: "
                f"{script.relative_to(ROOT)}::{method_name}",
            )

def validate_exporter_contracts() -> None:
    mermaid = (PLUGIN / "export" / "mermaid_exporter.gd").read_text(encoding="utf-8")
    plantuml = (PLUGIN / "export" / "plantuml_exporter.gd").read_text(encoding="utf-8")
    check('cssClass "%s" %s' in mermaid, "Mermaid styles are not attached with cssClass.")
    check("{signal}" not in plantuml, "PlantUML uses an unsupported {signal} modifier.")
    check('return "%s::%s"' in plantuml and 'show_member_dependency_edges' in plantuml,
          "PlantUML member endpoint export is missing.")
    check('_member_relation_label' in mermaid and 'show_member_dependency_edges' in mermaid,
          "Mermaid member-specific relation labeling is missing.")
    check("@startuml" in plantuml and "@enduml" in plantuml, "PlantUML markers are missing.")


def run_command(command: list[str], description: str) -> None:
    executable = shutil.which(command[0])
    if executable is None:
        notes.append(f"Skipped optional validation command: {command[0]}")
        return
    result = subprocess.run(
        [executable, *command[1:]],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    check(result.returncode == 0, f"{description} failed:\n{result.stdout.strip()}")


def validate_gdscript_tooling() -> None:
    scripts = [str(path) for path in sorted(ROOT.rglob("*.gd"))]
    run_command(["gdlint", *scripts], "gdlint")
    run_command(["gdformat", "--check", *scripts], "gdformat --check")


def main() -> int:
    validate_expected_files()
    validate_resource_references()
    validate_unique_name_contract(
        PLUGIN / "ui" / "dependency_dock.gd", PLUGIN / "ui" / "dependency_dock.tscn"
    )
    validate_unique_name_contract(
        PLUGIN / "ui" / "dependency_graph_node.gd",
        PLUGIN / "ui" / "dependency_graph_node.tscn",
    )
    validate_scene_ids_and_paths()
    validate_graph_ports()
    validate_plugin_contract()
    validate_compatibility_guardrails()
    validate_runtime_dependency_policy()
    validate_release_regressions()
    validate_v014_feature_contracts()
    validate_schema_contract()
    validate_documentation_contract()
    validate_quality_contracts()
    validate_public_method_documentation()
    validate_exporter_contracts()
    validate_gdscript_tooling()

    if failures:
        print(f"Static validation failed: {len(failures)} issue(s), {checks} checks.")
        for failure in failures:
            print(f"- {failure}")
        for note in notes:
            print(f"NOTE: {note}")
        return 1
    print(f"Static validation passed: {checks} checks.")
    for note in notes:
        print(f"NOTE: {note}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
