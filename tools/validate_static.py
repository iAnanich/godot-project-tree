#!/usr/bin/env python3
"""Static integrity checks for the Script Dependency Inspector development project."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT / "addons" / "script_dependency_inspector"
CURRENT_RELEASE = "0.5.1"

EXPECTED = [
    ROOT / "project.godot",
    ROOT / ".gitignore",
    ROOT / ".pre-commit-config.yaml",
    ROOT / ".gdlintrc",
    ROOT / "gdformatrc",
    ROOT / "requirements-dev.txt",
    ROOT / ".github" / "workflows" / "quality.yml",
    ROOT / ".github" / "workflows" / "release.yml",
    ROOT / "README.md",
    ROOT / "CONTRIBUTING.md",
    ROOT / "CHANGELOG.md",
    ROOT / "LICENSE",
    ROOT / "NOTICE",
    ROOT / "AI_USAGE_NOTICE.md",
    ROOT / "docs" / "ARCHITECTURE.md",
    ROOT / "docs" / "DESIGN.md",
    ROOT / "docs" / "REQUIREMENTS.md",
    ROOT / "docs" / "RELEASE-REQUIREMENTS.md",
    ROOT / "docs" / "QUALITY-CONTRACT.md",
    ROOT / "docs" / "RELEASE-GATES.md",
    ROOT / "docs" / "TRACEABILITY.md",
    ROOT / "docs" / "ASSET_STORE_DESCRIPTION.md",
    ROOT / "docs" / "SCHEMA.md",
    ROOT / "docs" / "SECURITY.md",
    ROOT / "docs" / "PERFORMANCE.md",
    ROOT / "docs" / "USE_CASES.md",
    ROOT / "docs" / "ROADMAP.md",
    ROOT / "docs" / "RELEASING.md",
    ROOT / "docs" / "COMPREHENSION_TEST.md",
    ROOT / "docs" / "HANDOFF.md",
    ROOT / "docs" / "diagrams" / "use-cases-overview.dot",
    ROOT / "docs" / "diagrams" / "use-cases-overview.svg",
    ROOT / "docs" / "diagrams" / "use-cases-analysis.dot",
    ROOT / "docs" / "diagrams" / "use-cases-analysis.svg",
    ROOT / "docs" / "diagrams" / "use-cases-synchronization.dot",
    ROOT / "docs" / "diagrams" / "use-cases-synchronization.svg",
    ROOT / "docs" / "schema" / "snapshot-v1.schema.json",
    ROOT / "docs" / "schema" / "snapshot-v2.schema.json",
    ROOT / "docs" / "decisions" / "0001-canonical-dictionary-snapshot.md",
    ROOT / "docs" / "decisions" / "0002-source-analysis-boundary.md",
    ROOT / "docs" / "decisions" / "0003-automation-state-and-export-paths.md",
    ROOT / "docs" / "decisions" / "0004-editor-synchronized-navigation.md",
    ROOT / "docs" / "decisions" / "0005-scene-usage-evidence.md",
    ROOT / "docs" / "decisions" / "0006-scoped-projection-and-focus.md",
    ROOT / "docs" / "decisions" / "0007-optional-graph-and-control-hierarchy.md",
    ROOT / "docs" / "decisions" / "0008-scope-paths-and-release-artifacts.md",
    ROOT / "docs" / "decisions" / "0009-source-only-project-analysis.md",
    PLUGIN / "plugin.cfg",
    PLUGIN / "icon.svg",
    PLUGIN / "LICENSE",
    PLUGIN / "NOTICE",
    PLUGIN / "AI_USAGE_NOTICE.md",
    PLUGIN / "plugin.gd",
    PLUGIN / "default_settings.tres",
    PLUGIN / "core" / "snapshot_validator.gd",
    PLUGIN / "core" / "scene_usage_scanner.gd",
    PLUGIN / "core" / "editor_state_store.gd",
    PLUGIN / "core" / "snapshot_scope.gd",
    PLUGIN / "core" / "graph_query.gd",
    PLUGIN / "ui" / "dependency_dock.tscn",
    PLUGIN / "ui" / "dependency_graph_edit.gd",
    PLUGIN / "ui" / "dependency_graph_node.tscn",
    ROOT / "tests" / "README.md",
    ROOT / "tests" / "test_runner.gd",
    ROOT / "tests" / "automation_runner.gd",
    ROOT / "tests" / "visual_showcase_runner.gd",
    ROOT / "tests" / "performance_runner.gd",
    ROOT / "tests" / "export_matrix_runner.gd",
    ROOT / "tests" / "generate_showcase_exports.gd",
    ROOT / "tests" / "contracts" / "exporter_contract.gd",
    ROOT / "tests" / "suites" / "quality_contract_suite.gd",
    ROOT / "tests" / "security_fixtures" / "static_initializer_side_effect.gd",
    ROOT
    / "tests"
    / "contract_fixtures"
    / "services"
    / "failing_commit_export_service.gd",
    ROOT / "tools" / "dev.py",
    ROOT / "tools" / "run_validation.py",
    ROOT / "tools" / "run_gdscript_quality.py",
    ROOT / "tools" / "verify_packaged_addon.py",
    ROOT / "tools" / "verify_release_artifacts.py",
    ROOT / "tools" / "build_release.py",
    ROOT / "tools" / "build_handoff.py",
    ROOT / "tools" / "package_addon.py",
    ROOT / "tools" / "build_patch.py",
    ROOT / "tools" / "capture_asset_store_media.py",
    ROOT / "tools" / "build_asset_store_media.py",
    ROOT / "tools" / "validate_asset_store_media.py",
    ROOT / "tools" / "media_capture" / "plugin.cfg",
    ROOT / "tools" / "media_capture" / "plugin.gd",
    ROOT / "docs" / "asset_store" / "README.md",
    ROOT / "docs" / "asset_store" / ".gdignore",
    ROOT / "docs" / "asset_store" / "media_manifest.json",
    ROOT / "docs" / "asset_store" / "current" / "thumbnail.webp",
    ROOT
    / "docs"
    / "asset_store"
    / "current"
    / "featured-08-member-evidence-tooltip.webp",
    ROOT
    / "docs"
    / "asset_store"
    / "current"
    / "featured-09-connection-evidence-tooltip.webp",
    ROOT / "docs" / "asset_store" / "source-captures" / f"v{CURRENT_RELEASE}" / "notes.md",
    ROOT / "docs" / "INTERFACE_GALLERY.md",
    ROOT / "examples" / "showcase" / "README.md",
    ROOT / "examples" / "showcase" / "services" / "targeting_service.gd",
    ROOT / "examples" / "showcase" / "scenes" / "battle_demo.tscn",
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
    "res://presentation_scene.tscn",
    "res://legacy.mmd",
    "res://object_script.gd",
    "res://ref_counted_script.gd",
    "res://node_script.gd",
    "res://node_2d_script.gd",
    "res://node_3d_script.gd",
    "res://control_script.gd",
    "res://performance_fixture.gd",
    "res://synthetic",
    "res://../outside",
    "res://.godot",
    "res://.godot/",
    "res://script_dependency_exports",
    "res://feature",
    "res://feature/child.gd",
    "res://shared/base.gd",
    "res://shared/service.gd",
    "res://unrelated/other.gd",
    "res://scene.tscn",
    "res://other.tscn",
}

ALLOWED_SYNTHETIC_RES_PREFIXES = (
    "res://synthetic/",
    "res://script_dependency_exports/",
    "res://generated/",
    "res://.godot/script_dependency_inspector/",
)

failures: list[str] = []
notes: list[str] = []
checks = 0


def check(condition: bool, message: str) -> None:
    global checks
    checks += 1
    if not condition:
        failures.append(message)


check(
    not (ROOT / "script_dependency_exports").exists(),
    "Default automatic exports must not be committed to the source tree.",
)


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
            if value in ALLOWED_SYNTHETIC_RES_PATHS or value.startswith(
                ALLOWED_SYNTHETIC_RES_PREFIXES
            ):
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
                node_keys.append(
                    (
                        (parent_match.group(1) if parent_match else ""),
                        name_match.group(1),
                    )
                )
        check(
            len(node_keys) == len(set(node_keys)),
            f"Duplicate node declarations in {scene.relative_to(ROOT)}",
        )


def validate_graph_ports() -> None:
    script = PLUGIN / "ui" / "dependency_graph_node.gd"
    scene = PLUGIN / "ui" / "dependency_graph_node.tscn"
    slot_indices = [
        int(value) for value in re.findall(r"set_slot\((\d+)", script.read_text())
    ]
    direct_rows = len(
        re.findall(
            r'^\[node name="[^"]+"[^\]]* parent="\."', scene.read_text(), re.MULTILINE
        )
    )
    check(
        bool(slot_indices),
        "Graph node script must configure at least one GraphNode slot.",
    )
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
        path = (
            res_to_path(script_value)
            if script_value.startswith("res://")
            else PLUGIN / script_value
        )
        check(
            path is not None and path.is_file(),
            "plugin.cfg points to a missing script.",
        )

    plugin_script = (PLUGIN / "plugin.gd").read_text(encoding="utf-8")
    check(
        "extends EditorPlugin" in plugin_script,
        "Plugin entry point must extend EditorPlugin.",
    )
    check("add_control_to_dock(" in plugin_script, "Plugin does not register its dock.")
    check(
        "remove_control_from_docks(" in plugin_script,
        "Plugin does not remove its dock.",
    )
    check(
        '@icon("res://addons/script_dependency_inspector/icon.svg")' in plugin_script,
        "Plugin entry point does not declare the bundled editor icon.",
    )

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
    concat_pattern = re.compile(r'^([A-Za-z_]\w*)\s*\+\s*"([^"\\]*(?:\\.[^"\\]*)*)"$')
    for script in sorted(PLUGIN.rglob("*.gd")):
        definitions = dict(
            definition_pattern.findall(script.read_text(encoding="utf-8"))
        )
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
                    suffix = bytes(concat_match.group(2), "utf-8").decode(
                        "unicode_escape"
                    )
                    resolved[name] = resolved[concat_match.group(1)] + suffix
                    made_progress = True
        for name, value in sorted(resolved.items()):
            if not name.endswith("_PATH") or name in {"EDITOR_STATE_PATH"}:
                continue
            path_constants += 1
            target = res_to_path(value)
            check(
                target is not None and target.is_file(),
                f"Required resource path constant is unresolved in {script.relative_to(ROOT)}: {value}",
            )
    check(
        path_constants >= 10,
        "Expected required resource path constants were not discovered.",
    )


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
    check(f'version="{CURRENT_RELEASE}"' in plugin_cfg, f"plugin.cfg version is not {CURRENT_RELEASE}.")

    release_builder = (ROOT / "tools" / "build_release.py").read_text(encoding="utf-8")
    check(
        '".git"' in release_builder and "EXCLUDED_DIRECTORY_NAMES" in release_builder,
        "Release builder must exclude VCS metadata from archives and manifests.",
    )
    check(
        'path.suffix == ".import"' in release_builder
        and 'path.suffix in {".uid", ".import"}' not in release_builder,
        "Release builder must exclude generated Godot import sidecars from archives and manifests.",
    )
    check(
        "write_media_archive" in release_builder
        and "script-dependency-inspector-asset-store-media-v" in release_builder,
        "Release builder must package the exact current Asset Library upload media.",
    )
    quality_workflow = (ROOT / ".github" / "workflows" / "quality.yml").read_text(encoding="utf-8")
    release_workflow = (ROOT / ".github" / "workflows" / "release.yml").read_text(encoding="utf-8")
    capture_media = (ROOT / "tools" / "capture_asset_store_media.py").read_text(encoding="utf-8")
    gdformat_config = (ROOT / "gdformatrc").read_text(encoding="utf-8")
    gdlint_config = (ROOT / ".gdlintrc").read_text(encoding="utf-8")
    check(
        "cache-dependency-path: requirements-dev.txt" in quality_workflow
        and "cache-dependency-path: requirements-dev.txt" in release_workflow,
        "GitHub setup-python pip caching must use requirements-dev.txt explicitly.",
    )
    check("sys.executable" in capture_media, "Media capture must reuse the invoking Python interpreter.")
    check("line_length: 100" in gdformat_config and "max-line-length: 100" in gdlint_config, "Formatter/linter line length contract mismatch.")
    check("max-file-lines: 2500" in gdlint_config, "gdlint project file-line ceiling is missing.")

    showcase_json = ROOT / "examples" / "showcase" / "representations" / "showcase.json"
    if showcase_json.is_file():
        import json

        try:
            snapshot = json.loads(showcase_json.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            check(False, f"Showcase JSON is invalid: {error}")
        else:
            check(
                snapshot.get("schema_version") == 2,
                "Showcase JSON schema version is invalid.",
            )
            check(
                len(snapshot.get("nodes", [])) == 25,
                "Showcase JSON should contain 25 nodes.",
            )
            check(
                len(snapshot.get("edges", [])) == 36,
                "Showcase JSON should contain 36 edges.",
            )
            type_edges = [
                edge
                for edge in snapshot.get("edges", [])
                if edge.get("kind") == "type_uses"
            ]
            check(
                len(type_edges) == 8,
                "Showcase JSON should contain eight type-use edges.",
            )
            check(
                any(
                    edge.get("source")
                    == "res://examples/showcase/services/targeting_service.gd"
                    and edge.get("target")
                    == "res://examples/showcase/actors/base_actor.gd"
                    for edge in type_edges
                ),
                "Showcase JSON is missing the annotation-only targeting-service dependency.",
            )
            check(
                any(
                    edge.get("source") == "res://examples/showcase/actors/base_actor.gd"
                    and edge.get("target")
                    == "res://examples/showcase/services/damage_service.gd"
                    and any(
                        link.get("source_member", {}).get("name") == "attack_power"
                        and link.get("target_member", {}).get("name")
                        == "calculate_damage"
                        for link in edge.get("member_links", [])
                    )
                    for edge in snapshot.get("edges", [])
                ),
                "Showcase JSON is missing the member-to-member damage-service dependency.",
            )
            check(
                not snapshot.get("errors", []), "Showcase JSON contains graph errors."
            )
            check(
                len(snapshot.get("scene_usages", [])) == 1,
                "Showcase JSON should contain one exact scene usage.",
            )
            check(
                any(
                    node.get("autoload", {}).get("name") == "BattleCoordinator"
                    for node in snapshot.get("nodes", [])
                ),
                "Showcase JSON is missing the development-project autoload classification.",
            )


def validate_v014_feature_contracts() -> None:
    settings = (PLUGIN / "core" / "settings.gd").read_text(encoding="utf-8")
    dock_scene = (PLUGIN / "ui" / "dependency_dock.tscn").read_text(encoding="utf-8")
    dock_script = (PLUGIN / "ui" / "dependency_dock.gd").read_text(encoding="utf-8")
    node_script = (PLUGIN / "ui" / "dependency_graph_node.gd").read_text(
        encoding="utf-8"
    )
    analyzer = (PLUGIN / "core" / "gdscript_analyzer.gd").read_text(encoding="utf-8")
    builder = (PLUGIN / "core" / "graph_builder.gd").read_text(encoding="utf-8")

    for flag in [
        "show_method_signatures",
        "show_signal_signatures",
        "show_property_types",
        "include_type_dependencies",
    ]:
        check(
            flag in settings and flag in dock_script,
            f"Missing presentation option: {flag}",
        )
    for color in ["property_color", "signal_color", "method_color", "metadata_color"]:
        check(
            color in settings and color in node_script,
            f"Missing member color contract: {color}",
        )
    for node_name in [
        "Content",
        "Appearance",
        "Colors",
        "Log",
        "MethodSignatures",
        "PropertyTypes",
        "NativeNodeWidth",
        "MaxMemberHeight",
        "TypeDependencyColor",
    ]:
        check(
            f'name="{node_name}"' in dock_scene,
            f"Dock scene is missing control: {node_name}",
        )
    check(
        'parent="MainSplit/ControlsTabs' in dock_scene,
        "Controls must remain above GraphEdit in the vertical split.",
    )
    check(
        'kind == "native"' in node_script
        and "member_scroll.visible = false" in node_script,
        "Native-node compaction contract is missing.",
    )
    check(
        "_depth_for" in dock_script and "_layout_sort_key" in dock_script,
        "Deterministic depth layout contract is missing.",
    )
    check(
        '"type_references"' in analyzer
        and "_collect_source_scope_type_reference_details" in analyzer,
        "Type-annotation source analysis is missing.",
    )
    check('"type_uses"' in builder, "Graph builder does not emit type-use edges.")
    for flag in ["include_member_access_dependencies", "show_member_dependency_edges"]:
        check(
            flag in settings and flag in dock_script,
            f"Missing member dependency option: {flag}",
        )
    for node_name in ["IncludeMemberAccessDependencies", "ShowMemberDependencyEdges"]:
        check(
            f'name="{node_name}"' in dock_scene,
            f"Dock scene is missing member dependency control: {node_name}",
        )
    check(
        '"member_links"' in builder and "member_accesses" in analyzer,
        "Canonical member dependency provenance is missing.",
    )
    check(
        "port_for_member" in node_script and "_member_ports" in node_script,
        "GraphNode member-edge anchor contract is missing.",
    )
    for family in [
        "object_family_color",
        "ref_counted_family_color",
        "node_family_color",
        "node_2d_family_color",
        "node_3d_family_color",
        "control_family_color",
    ]:
        check(
            family in settings and family in node_script,
            f"Missing inheritance-family color: {family}",
        )
    check(
        '"inheritance_family"' in builder and "_classify_native_family" in builder,
        "Inheritance-family classification contract is missing.",
    )
    check(
        "get_parent_class" in builder,
        "Native intermediary bases must be discovered through ClassDB.",
    )
    check(
        'tooltip_text = ""' in node_script
        and 'path_button.tooltip_text = "Copy script path:\\n%s" % path' in node_script
        and "DisplayServer.clipboard_set(path)" in node_script,
        "GraphNode-wide tooltip masking or keyboard-accessible path tooltip contract is missing.",
    )
    check(
        "graph_node_max_width" in settings and "layout_size()" in node_script,
        "Adaptive GraphNode sizing contract is missing.",
    )
    check(
        '_id_to_graph_name[edge["target"]]' in dock_script,
        "Rendered GraphEdit connections must point dependency/base to dependent for arrangement.",
    )


def validate_v020_feature_contracts() -> None:
    settings = (PLUGIN / "core" / "settings.gd").read_text(encoding="utf-8")
    scanner = (PLUGIN / "core" / "project_scanner.gd").read_text(encoding="utf-8")
    scene_scanner = (PLUGIN / "core" / "scene_usage_scanner.gd").read_text(
        encoding="utf-8"
    )
    builder = (PLUGIN / "core" / "graph_builder.gd").read_text(encoding="utf-8")
    validator = (PLUGIN / "core" / "snapshot_validator.gd").read_text(encoding="utf-8")
    dock = (PLUGIN / "ui" / "dependency_dock.gd").read_text(encoding="utf-8")
    dock_scene = (PLUGIN / "ui" / "dependency_dock.tscn").read_text(encoding="utf-8")
    node = (PLUGIN / "ui" / "dependency_graph_node.gd").read_text(encoding="utf-8")
    state_store = (PLUGIN / "core" / "editor_state_store.gd").read_text(
        encoding="utf-8"
    )
    for token in [
        "sync_on_editor_changes",
        "editor_change_debounce_seconds",
        "follow_active_script",
    ]:
        check(
            token in settings and token in dock and token in state_store,
            f"Missing editor synchronization contract: {token}",
        )
    check(
        "auto_rescan_enabled: bool = false" in settings,
        "Timed rescan must remain disabled by default.",
    )
    for node_name in [
        "SearchInput",
        "PreviousMatch",
        "NextMatch",
        "SyncOnEditorChanges",
        "EditorSyncDebounce",
        "FollowActiveScript",
    ]:
        check(
            f'name="{node_name}"' in dock_scene,
            f"Dock scene is missing v0.2.0 control: {node_name}",
        )
    check(
        "source_requested" in node and "scene_requested" in node,
        "Graph node navigation signals are missing.",
    )
    check(
        "_apply_search" in dock and "_focus_node_id" in dock,
        "Search/focus implementation is missing.",
    )
    check(
        "_on_editor_filesystem_changed" in dock and "_editor_change_pending" in dock,
        "Editor refresh lifecycle is missing.",
    )
    check(
        "_autoload_index" in scanner and '"autoload"' in builder,
        "Autoload classification is missing.",
    )
    check(
        "tscn_node_script_attachment" in scene_scanner and '"scene_usages"' in builder,
        "Scene usage evidence is missing.",
    )
    check(
        '"source_location": source_location' in builder,
        "Relationship occurrence locations are missing from canonical member links.",
    )
    check(
        "relationship_occurrences" in dock and '"References"' in node,
        "Exact relationship occurrence navigation is missing.",
    )
    check('"Inner classes"' in node, "Inner-class declaration navigation is missing.")
    check(
        "SUPPORTED_SCHEMA_VERSION: int = 2" in validator,
        "Snapshot validator does not enforce schema v2.",
    )
    check(
        "STATE_SCHEMA_VERSION: int = 4" in state_store
        and "loaded_schema not in [1, 2, 3, STATE_SCHEMA_VERSION]" in state_store,
        "Editor state v1/v2/v3 migration and schema-v4 contract is missing.",
    )


def validate_v021_feature_contracts() -> None:
    scope = (PLUGIN / "core" / "snapshot_scope.gd").read_text(encoding="utf-8")
    query = (PLUGIN / "core" / "graph_query.gd").read_text(encoding="utf-8")
    validator = (PLUGIN / "core" / "snapshot_validator.gd").read_text(encoding="utf-8")
    dock = (PLUGIN / "ui" / "dependency_dock.gd").read_text(encoding="utf-8")
    dock_scene = (PLUGIN / "ui" / "dependency_dock.tscn").read_text(encoding="utf-8")
    node = (PLUGIN / "ui" / "dependency_graph_node.gd").read_text(encoding="utf-8")
    mermaid = (PLUGIN / "export" / "mermaid_exporter.gd").read_text(encoding="utf-8")
    plantuml = (PLUGIN / "export" / "plantuml_exporter.gd").read_text(encoding="utf-8")
    for token in [
        "scope_role",
        "required_ancestor",
        "required_dependency",
        "scope_summary",
    ]:
        check(token in scope, f"Scoped projection contract is missing: {token}")
    for token in ["descendant_counts", "relationship_focus_ids", "neighborhood_ids"]:
        check(token in query, f"Graph presentation query is missing: {token}")
    check(
        'str(edge.get("kind", "")) == "extends"' in query,
        "Neighborhood queries must keep descendant inclusion controlled by the explicit option.",
    )
    for node_name in [
        "ScopeOption",
        "ChooseScope",
        "IncludeDescendants",
        "IsolateNeighborhood",
        "ClearFocus",
        "FocusStatus",
    ]:
        check(
            f'name="{node_name}"' in dock_scene,
            f"Dock scene is missing v0.2.1 control: {node_name}",
        )
    for token in [
        "_set_scan_root",
        "_update_relationship_focus",
        "_clear_relationship_focus",
        "_populate_scope_options",
    ]:
        check(token in dock, f"Dock is missing v0.2.1 orchestration: {token}")
    check(
        "Context" in node and "scope_reason" in node,
        "Graph nodes must communicate retained context in text.",
    )
    check("(context)" in mermaid, "Mermaid must label retained context nodes.")
    check("<<context>>" in plantuml, "PlantUML must label retained context nodes.")
    for code in ["invalid_scope_role", "missing_scope_role", "scope_summary_mismatch"]:
        check(
            code in validator,
            f"Snapshot validator is missing v0.2.1 scope code: {code}",
        )
    use_cases = (ROOT / "docs" / "USE_CASES.md").read_text(encoding="utf-8")
    for use_case in ["UC-01", "UC-02", "UC-04", "UC-05", "UC-11"]:
        check(use_case in use_cases, f"Use-case catalogue is missing {use_case}.")
    check(
        "authoritative alternative representation" in use_cases,
        "Use-case diagrams need an authoritative text alternative.",
    )


def validate_v022_feature_contracts() -> None:
    settings = (PLUGIN / "core" / "settings.gd").read_text(encoding="utf-8")
    state_store = (PLUGIN / "core" / "editor_state_store.gd").read_text(
        encoding="utf-8"
    )
    dock = (PLUGIN / "ui" / "dependency_dock.gd").read_text(encoding="utf-8")
    dock_scene = (PLUGIN / "ui" / "dependency_dock.tscn").read_text(encoding="utf-8")
    for node_name in [
        "ScanModeIndicator",
        "ShowGraph",
        "FormatOption",
        "ContentSourcesHeader",
        "ContentMembersHeader",
        "ContentRelationsHeader",
        "ContentExportHeader",
        "AppearanceSizingHeader",
        "AppearanceDensityHeader",
        "AppearanceLayoutHeader",
        "ColorsNodesHeader",
        "ColorsMembersHeader",
        "ColorsRelationsHeader",
        "ColorsFamiliesHeader",
        "AutomationEditorHeader",
        "AutomationTimedHeader",
        "AutomationExportHeader",
    ]:
        check(
            f'name="{node_name}"' in dock_scene,
            f"Dock scene is missing v0.2.2 control: {node_name}",
        )
    check(
        "custom_minimum_size = Vector2(80, 0)" in dock_scene
        and "fit_to_longest_item = false" in dock_scene,
        "Manual export format selector must remain compact.",
    )
    check(
        'name="ToolbarSeparator"' in dock_scene
        and 'name="ToolbarActionGap"' in dock_scene,
        "Scan and Export action groups need explicit separation.",
    )
    for token in [
        "_update_scan_mode_indicator",
        "_apply_graph_view_visibility",
        "_clear_rendered_graph",
        "_setup_fold_sections",
        "_apply_fold_section",
    ]:
        check(token in dock, f"Dock is missing v0.2.2 orchestration: {token}")
    check(
        "graph_view_enabled: bool = true" in settings
        and '"control_section_expanded"' in settings,
        "Default graph visibility and fold-state settings are missing.",
    )
    check(
        "STATE_SCHEMA_VERSION: int = 4" in state_store
        and '"graph_view_enabled"' in state_store
        and '"control_section_expanded"' in state_store,
        "Editor-state schema v4 graph/fold contract is missing.",
    )
    use_cases = (ROOT / "docs" / "USE_CASES.md").read_text(encoding="utf-8")
    check(
        "UC-12" in use_cases
        and "UC-13" in use_cases
        and "export-only" in use_cases.lower(),
        "Use-case layer is missing export-only/control-configuration workflows.",
    )
    ai_notice = (ROOT / "AI_USAGE_NOTICE.md").read_text(encoding="utf-8")
    for heading in [
        "How AI was used",
        "Human direction and supervision",
        "Quality-control measures",
        "Provenance and licensing boundary",
    ]:
        check(heading in ai_notice, f"AI notice is missing section: {heading}")
    store = (ROOT / "docs" / "ASSET_STORE_DESCRIPTION.md").read_text(encoding="utf-8")
    for phrase in [
        "third-party",
        "larger canvas",
        "AI-assisted development disclosure",
    ]:
        check(
            phrase.lower() in store.lower(),
            f"Store description is missing v0.2.2 disclosure/export message: {phrase}",
        )


def validate_v023_feature_contracts() -> None:
    scanner = (PLUGIN / "core" / "project_scanner.gd").read_text(encoding="utf-8")
    dock = (PLUGIN / "ui" / "dependency_dock.gd").read_text(encoding="utf-8")
    dock_scene = (PLUGIN / "ui" / "dependency_dock.tscn").read_text(encoding="utf-8")
    quality_suite = (ROOT / "tests" / "suites" / "quality_contract_suite.gd").read_text(
        encoding="utf-8"
    )
    release_builder = (ROOT / "tools" / "build_release.py").read_text(encoding="utf-8")
    package_addon = (ROOT / "tools" / "package_addon.py").read_text(encoding="utf-8")
    patch_builder = (ROOT / "tools" / "build_patch.py").read_text(encoding="utf-8")
    release_workflow = (ROOT / ".github" / "workflows" / "release.yml").read_text(
        encoding="utf-8"
    )
    precommit = (ROOT / ".pre-commit-config.yaml").read_text(encoding="utf-8")

    check(
        "ProjectSettings.localize_path" in scanner
        and "_normalize_scan_root" in scanner,
        "Absolute project-local scan roots are not normalized through one scanner boundary.",
    )
    check(
        "FileDialog.ACCESS_RESOURCES" in dock and "access = 0" in dock_scene,
        "The folder chooser must request project-resource access.",
    )
    check(
        "project_absolute_root" in quality_suite
        and "absolute path" in quality_suite.lower(),
        "The native-dialog absolute-path regression test is missing.",
    )
    check(
        '"dist"' in release_builder,
        "Release-source enumeration must exclude generated dist artifacts.",
    )
    for token in ["write_addon_archive", "script-dependency-inspector-addon-v"]:
        check(token in package_addon, f"Add-on packaging script is missing: {token}")
    for token in [
        "--binary",
        "--full-index",
        "worktree",
        "--check",
        "--index",
        "write-tree",
        "infer_base_ref",
        "git",
        "describe",
    ]:
        check(token in patch_builder, f"Verified patch generation is missing: {token}")
    for token in [
        "gh release create",
        "tools/build_patch.py",
        "tools/build_release.py",
    ]:
        check(token in release_workflow, f"GitHub release workflow is missing: {token}")
    requirements_dev = (ROOT / "requirements-dev.txt").read_text(encoding="utf-8")
    check(
        "gdformat" in precommit
        and "gdlint" in precommit
        and "gdtoolkit==4.5.0" in requirements_dev,
        "Pinned pre-commit gdformat/gdlint hooks are missing.",
    )
    for removed in [
        ROOT / "docs" / "QUALITY_REVIEW.md",
        ROOT / "docs" / "GUIDANCE_APPLIED.md",
        ROOT / "docs" / "RELATED_PROJECTS.md",
        ROOT / "docs" / "diagrams" / "REVIEW.md",
        ROOT / "docs" / "reviews",
    ]:
        check(
            not removed.exists(),
            f"Repository-internal review/provenance artifact remains: {removed.relative_to(ROOT)}",
        )


def validate_v030_feature_contracts(*, allow_root_manifest: bool = False) -> None:
    scanner = (PLUGIN / "core" / "project_scanner.gd").read_text(encoding="utf-8")
    builder = (PLUGIN / "core" / "graph_builder.gd").read_text(encoding="utf-8")
    dock = (PLUGIN / "ui" / "dependency_dock.gd").read_text(encoding="utf-8")
    settings = (PLUGIN / "core" / "settings.gd").read_text(encoding="utf-8")
    release_builder = (ROOT / "tools" / "build_release.py").read_text(encoding="utf-8")
    release_workflow = (ROOT / ".github" / "workflows" / "release.yml").read_text(
        encoding="utf-8"
    )
    quality_workflow = (ROOT / ".github" / "workflows" / "quality.yml").read_text(
        encoding="utf-8"
    )
    quality_suite = (ROOT / "tests" / "suites" / "quality_contract_suite.gd").read_text(
        encoding="utf-8"
    )
    requirements = (ROOT / "docs" / "REQUIREMENTS.md").read_text(encoding="utf-8")

    check(
        "_reflect_script" not in scanner,
        "Project scanner must not retain analyzed-project Script reflection.",
    )
    check(
        'resolved_options["use_runtime_reflection"]' not in scanner,
        "Legacy runtime-reflection setting must not reactivate project-script loading.",
    )
    check(
        "use_runtime_reflection" not in settings.split("func to_scan_options", 1)[-1],
        "Settings must not emit the deprecated runtime-reflection option to the scanner.",
    )
    check(
        "func initialization_errors()" in scanner
        and "func initialization_errors()" in builder,
        "Scanner and graph builder must expose transitive initialization failures.",
    )
    validation_pos = dock.find("_validate_snapshot_candidate(candidate_snapshot)")
    validated_return_pos = dock.find('return {"ok": true, "snapshot": candidate_snapshot}')
    candidate_build_pos = dock.find("_build_scan_candidate()")
    accept_pos = dock.find('_snapshot = scan_attempt.get("snapshot", {})')
    check(
        validation_pos >= 0
        and validated_return_pos > validation_pos
        and candidate_build_pos >= 0
        and accept_pos > candidate_build_pos,
        "Dock must validate a candidate snapshot before accepting it as current.",
    )
    check(
        "STATIC_EXECUTION_MARKER" in quality_suite
        and "use_runtime_reflection" in quality_suite,
        "Source-only regression must prove the legacy option cannot execute a scanned static initializer.",
    )
    check(
        "FAILING_COMMIT_SERVICE_PATH" in quality_suite
        and "commit_failed_restored" in quality_suite,
        "Export replacement recovery failure-injection regression is missing.",
    )
    check(
        "load analyzed project GDScript resources" in requirements,
        "Requirements do not state the source-only project-script loading prohibition.",
    )
    check(
        '(ROOT / "MANIFEST.sha256").write_bytes' not in release_builder,
        "Release builder must not mutate the repository root MANIFEST.sha256.",
    )
    check(
        allow_root_manifest or not (ROOT / "MANIFEST.sha256").exists(),
        "Generated root MANIFEST.sha256 must not remain in the repository source tree.",
    )
    check(
        "--draft" in release_workflow,
        "GitHub tag workflow must create a draft release candidate, not imply runtime verification.",
    )
    check(
        "dist-first" in release_workflow
        and "dist-second" in release_workflow
        and "cmp " in release_workflow,
        "GitHub release workflow must perform a controlled second archive build before reproducibility claims.",
    )
    dev_tool = (ROOT / "tools" / "dev.py").read_text(encoding="utf-8")
    check(
        "tools/dev.py quality --check --skip-godot" in release_workflow
        and "tools/dev.py quality --check --skip-godot" in quality_workflow
        and "run_gdscript_quality.py" in dev_tool,
        "GitHub quality/release workflows must run the fail-closed GDScript quality gate.",
    )
    for removed in [
        ROOT / "docs" / "validation",
        ROOT / "docs" / "images",
        ROOT / "docs" / "CONTRACT.md",
        ROOT / "docs" / "RESEARCH.md",
    ]:
        check(
            not removed.exists(),
            f"Superseded or release-specific repository artifact remains: {removed.relative_to(ROOT)}",
        )


def validate_v031_feature_contracts() -> None:
    root_license = (ROOT / "LICENSE").read_text(encoding="utf-8")
    plugin_license = (PLUGIN / "LICENSE").read_text(encoding="utf-8")
    plugin_config = (PLUGIN / "plugin.cfg").read_text(encoding="utf-8")
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    asset_store = (ROOT / "docs" / "ASSET_STORE_DESCRIPTION.md").read_text(
        encoding="utf-8"
    )
    requirements = (ROOT / "docs" / "REQUIREMENTS.md").read_text(encoding="utf-8")
    use_cases = (ROOT / "docs" / "USE_CASES.md").read_text(encoding="utf-8")
    traceability = (ROOT / "docs" / "TRACEABILITY.md").read_text(encoding="utf-8")
    design = (ROOT / "docs" / "DESIGN.md").read_text(encoding="utf-8")
    dock = (PLUGIN / "ui" / "dependency_dock.gd").read_text(encoding="utf-8")
    graph_edit = (PLUGIN / "ui" / "dependency_graph_edit.gd").read_text(
        encoding="utf-8"
    )
    graph_node = (PLUGIN / "ui" / "dependency_graph_node.gd").read_text(
        encoding="utf-8"
    )
    graph_builder = (PLUGIN / "core" / "graph_builder.gd").read_text(encoding="utf-8")
    tests = (ROOT / "tests" / "test_runner.gd").read_text(encoding="utf-8")
    automation = (ROOT / "tests" / "automation_runner.gd").read_text(encoding="utf-8")
    handoff = (ROOT / "tools" / "build_handoff.py").read_text(encoding="utf-8")
    handoff_doc = (ROOT / "docs" / "HANDOFF.md").read_text(encoding="utf-8")
    release_builder = (ROOT / "tools" / "build_release.py").read_text(encoding="utf-8")
    release_verifier = (ROOT / "tools" / "verify_release_artifacts.py").read_text(
        encoding="utf-8"
    )
    validation_runner = (ROOT / "tools" / "run_validation.py").read_text(
        encoding="utf-8"
    )
    ignore = (ROOT / ".gitignore").read_text(encoding="utf-8")

    check(f'version="{CURRENT_RELEASE}"' in plugin_config, f"Plugin version must be {CURRENT_RELEASE}.")
    check(
        "MIT License" in root_license, "Repository LICENSE must use MIT License text."
    )
    check(
        root_license == plugin_license,
        "Root and packaged add-on LICENSE files must match.",
    )
    check(
        "Licensed under the MIT License" in asset_store,
        "Asset Library description must state MIT licensing.",
    )
    check(
        "## License" in readme and "MIT" in readme,
        "README must expose the current MIT license.",
    )

    for req in ("REQ-VALID-005", "REQ-UI-005", "REQ-UI-006", "REQ-DIAG-003", "REQ-VALID-006"):
        check(req in requirements, f"Missing v0.4.0 requirement: {req}")
        check(req in traceability, f"Missing v0.4.0 traceability mapping: {req}")
    for use_case in ("UC-14", "UC-15", "UC-16", "UC-17"):
        check(use_case in use_cases, f"Missing v0.4.0 use case: {use_case}")
    check(
        "Filtered member provenance" in design,
        "Design must document filtered member provenance.",
    )
    check(
        "Validator failure diagnostics" in design,
        "Design must document validator failure diagnostics.",
    )

    check(
        "get_closest_connection_at_point" in graph_edit,
        "GraphEdit tooltip layer must resolve hovered connections.",
    )
    check(
        "Exact evidence occurrences represented" in graph_edit,
        "Connection tooltip must report represented exact evidence.",
    )
    check(
        "Rendered direction: dependency → dependent (layout only)" in graph_edit,
        "Connection tooltip must distinguish layout direction from canonical direction.",
    )
    check(
        "clear_connection_evidence" in dock and "register_connection_evidence" in dock,
        "Dock must own the rendered-connection evidence lifecycle.",
    )
    check(
        "Counts are static source evidence, not runtime call counts." in graph_node,
        "Member tooltip must qualify static evidence counts.",
    )
    check(
        "_member_full_declaration" in graph_node and "Declaration:" in graph_node,
        "Member tooltip must retain full declaration/signature provenance.",
    )

    check(
        graph_builder.count("_existing_member_reference(") >= 4,
        "GraphBuilder must filter both source and target member provenance through endpoint membership.",
    )
    check(
        "_test_hidden_member_scope_validation" in tests,
        "Hidden-member selected-root regression test is missing.",
    )
    check(
        "_test_connection_tooltip_evidence" in tests,
        "Connection-tooltip behavioral test is missing.",
    )
    check(
        "_test_validator_log_rendering" in tests,
        "Validator diagnostic rendering test is missing.",
    )
    check(
        "get_closest_connection_at_point" in tests,
        "Compatibility tests must exercise the GraphEdit connection lookup API.",
    )
    for token in [
        "SNAPSHOT_STATE_STALE",
        "_last_successful_scan_at",
        "_ensure_snapshot_validator_available",
        "_stale_snapshot_status_text",
        "_snapshot_state != SNAPSHOT_STATE_CURRENT",
        "prepare_for_shutdown",
        "not auto_rescan_timer.is_inside_tree()",
    ]:
        check(token in dock, f"Missing stale-snapshot/validator lifecycle implementation token: {token}")
    for token in [
        "forced_validation_failure",
        "stale-must-not-export.json",
        "validator_unavailable",
        "STALE SNAPSHOT",
    ]:
        check(token in automation, f"Missing lifecycle regression coverage token: {token}")
    check("REQ-VALID-006" in requirements and "RESOLVED-OPEN-001" in requirements, "OPEN-001 must be resolved into the accepted stale-snapshot requirement.")

    check(
        "source/{PROJECT_ARCHIVE_ROOT}/{record['path']}" in handoff,
        "Handoff checksums must use actual source archive member paths.",
    )
    check(
        "def verify_handoff_archive" in handoff
        and "verify_handoff_archive(artifact)" in handoff,
        "Handoff archive must self-verify after construction.",
    )
    check(
        'ROOT.parent / "script-dependency-inspector-handoff-artifacts"' in handoff,
        "Handoff default output must be outside the repository.",
    )
    check(
        "verifies every `sha256sums.txt` entry" in handoff_doc.lower(),
        "Handoff documentation must describe archive verification.",
    )

    check(
        'path.suffix == ".import"' in release_builder
        and '".uid"'
        not in release_builder.split("def is_release_file", 1)[1].split(
            "def release_files", 1
        )[0],
        "Release packaging must exclude generated .import files without dropping .uid source sidecars.",
    )
    check(
        '".uid"'
        not in release_verifier.split("FORBIDDEN_SUFFIXES", 1)[1].split(
            "def sha256", 1
        )[0],
        "Release verification must not reject .uid source sidecars by suffix.",
    )
    copy_body = validation_runner.split("def copy_project", 1)[1].split(
        "def suspicious_output", 1
    )[0]
    check(
        '.endswith(".uid")' not in copy_body,
        "Isolated validation must preserve tracked .uid source sidecars.",
    )
    for token in (".idea/", "__pycache__/", "*.py[cod]", "*.import"):
        check(token in ignore, f"Repository ignore contract is missing {token}.")
    check(
        "*.uid" not in ignore,
        "Godot .uid source sidecars must not be globally ignored.",
    )
    for generated in (
        ROOT / ".idea",
        ROOT / "tools" / "__pycache__",
        ROOT / "docs" / "images",
    ):
        check(
            not generated.exists(),
            f"Generated/local repository state remains: {generated.relative_to(ROOT)}",
        )
    check(
        not any(ROOT.rglob("*.import")),
        "Generated Godot .import sidecars must not remain in source.",
    )


def validate_schema_contract() -> None:
    schema_path = ROOT / "docs" / "schema" / "snapshot-v2.schema.json"
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
                "Showcase JSON violates snapshot-v2 schema: "
                + "; ".join(error.message for error in errors[:5]),
            )
    check(
        "diagnostics" in snapshot, "Showcase JSON should expose structured diagnostics."
    )


def _hex_rgb(value: str) -> tuple[float, float, float]:
    return tuple(int(value[index : index + 2], 16) / 255.0 for index in (0, 2, 4))  # type: ignore[return-value]


def _linear_component(value: float) -> float:
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def _luminance(value: str) -> float:
    red, green, blue = (_linear_component(component) for component in _hex_rgb(value))
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue


def _contrast(first: str, second: str) -> float:
    first_luminance, second_luminance = _luminance(first), _luminance(second)
    lighter, darker = (
        max(first_luminance, second_luminance),
        min(first_luminance, second_luminance),
    )
    return (lighter + 0.05) / (darker + 0.05)


def _simulate_cvd(
    value: str, matrix: tuple[tuple[float, float, float], ...]
) -> tuple[float, float, float]:
    channels = _hex_rgb(value)
    return tuple(
        max(
            0.0,
            min(
                1.0, sum(matrix[row][column] * channels[column] for column in range(3))
            ),
        )
        for row in range(3)
    )  # type: ignore[return-value]


def validate_default_color_contract() -> None:
    settings = (PLUGIN / "core" / "settings.gd").read_text(encoding="utf-8")
    values = dict(
        re.findall(
            r"@export var (\w+_color): Color = Color\(\"([0-9a-fA-F]{6})\"\)", settings
        )
    )
    required = {
        "user_script_color": "005a8d",
        "addon_script_color": "8f4f79",
        "native_class_color": "59616d",
        "external_class_color": "9a6500",
        "inheritance_edge_color": "e5e7eb",
        "dependency_edge_color": "e69f00",
        "type_dependency_edge_color": "56b4e9",
    }
    for key, expected in required.items():
        check(
            values.get(key, "").lower() == expected,
            f"Unexpected default palette value for {key}.",
        )
    for key in (
        "user_script_color",
        "addon_script_color",
        "native_class_color",
        "external_class_color",
    ):
        if key in values:
            check(
                _contrast(values[key], "ffffff") >= 4.5,
                f"Default node fill does not preserve readable white text contrast: {key}",
            )
    # Color is not the sole encoding: edge kinds also use labels, toggles, and line semantics.
    # This simulation guards only against the three default edge colors collapsing together.
    matrices = (
        (
            (0.152286, 1.052583, -0.204868),
            (0.114503, 0.786281, 0.099216),
            (-0.003882, -0.048116, 1.051998),
        ),
        (
            (0.367322, 0.860646, -0.227968),
            (0.280085, 0.672501, 0.047413),
            (-0.011820, 0.042940, 0.968881),
        ),
    )
    edge_keys = (
        "inheritance_edge_color",
        "dependency_edge_color",
        "type_dependency_edge_color",
    )
    for matrix in matrices:
        simulated = {
            key: _simulate_cvd(values[key], matrix)
            for key in edge_keys
            if key in values
        }
        for index, first in enumerate(edge_keys):
            for second in edge_keys[index + 1 :]:
                if first not in simulated or second not in simulated:
                    continue
                distance = (
                    sum(
                        (simulated[first][channel] - simulated[second][channel]) ** 2
                        for channel in range(3)
                    )
                    ** 0.5
                )
                check(
                    distance >= 0.30,
                    f"Default edge colors collapse under CVD simulation: {first}, {second}",
                )


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
                check(
                    False,
                    f"Documentation link escapes project root in {document.relative_to(ROOT)}: {target}",
                )
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
        "docs/COMPREHENSION_TEST.md",
        "docs/ROADMAP.md",
        "docs/RELEASING.md",
        "docs/USE_CASES.md",
        "AI_USAGE_NOTICE.md",
        "CONTRIBUTING.md",
        "CHANGELOG.md",
    ]:
        check(
            required_reference in readme,
            f"README does not link to {required_reference}.",
        )
    check(CURRENT_RELEASE in readme, f"README release identifier is not {CURRENT_RELEASE}.")


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
        check(
            code in service,
            f"Export service is missing structured failure code: {code}",
        )
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
        "invalid_scene_usage",
        "duplicate_scene_usage",
        "invalid_node_scene_usage",
        "node_scene_usage_script_mismatch",
        "duplicate_node_scene_usage",
        "orphan_node_scene_usage",
        "missing_node_scene_usage",
        "invalid_source_location",
        "invalid_scope_role",
        "missing_scope_role",
        "missing_scope_index_root",
        "in_scope_node_outside_root",
        "scope_summary_mismatch",
    ]:
        check(code in validator, f"Snapshot validator is missing issue code: {code}")
    check(
        "follow_symbolic_links" in scanner and "invalid_scan_root" in scanner,
        "Scanner trust-boundary controls are missing.",
    )
    for node_name in ["LegendPanel", "LegendView", "Summary", "SummaryView"]:
        check(
            f'name="{node_name}"' in dock_scene,
            f"Dock scene is missing accessible decoding control: {node_name}",
        )
    check(
        "_update_legend" in dock_script and "_update_summary" in dock_script,
        "Dock does not maintain legend and non-visual summary output.",
    )
    check(
        (ROOT / "tests" / "contracts" / "exporter_contract.gd").is_file(),
        "Reusable exporter contract suite is missing.",
    )


def validate_public_method_documentation() -> None:
    """Require local API documentation for every non-private add-on method."""
    for script in sorted(PLUGIN.rglob("*.gd")):
        lines = script.read_text(encoding="utf-8").splitlines()
        for index, line in enumerate(lines):
            if not line.startswith("func ") or line.startswith("func _"):
                continue
            method_name = line.removeprefix("func ").split("(", 1)[0]
            preceding = lines[max(0, index - 4) : index]
            check(
                any(candidate.lstrip().startswith("##") for candidate in preceding),
                f"Public method lacks a GDScript documentation comment: "
                f"{script.relative_to(ROOT)}::{method_name}",
            )


def validate_exporter_contracts() -> None:
    mermaid = (PLUGIN / "export" / "mermaid_exporter.gd").read_text(encoding="utf-8")
    plantuml = (PLUGIN / "export" / "plantuml_exporter.gd").read_text(encoding="utf-8")
    check(
        'cssClass "%s" %s' in mermaid, "Mermaid styles are not attached with cssClass."
    )
    check("{signal}" not in plantuml, "PlantUML uses an unsupported {signal} modifier.")
    check(
        'return "%s::%s"' in plantuml and "show_member_dependency_edges" in plantuml,
        "PlantUML member endpoint export is missing.",
    )
    check(
        "_member_relation_label" in mermaid
        and "show_member_dependency_edges" in mermaid,
        "Mermaid member-specific relation labeling is missing.",
    )
    check(
        "@startuml" in plantuml and "@enduml" in plantuml,
        "PlantUML markers are missing.",
    )
    exporter_base = (PLUGIN / "export" / "exporter.gd").read_text(encoding="utf-8")
    service = (PLUGIN / "export" / "export_service.gd").read_text(encoding="utf-8")
    check(
        "_arguments_without_defaults" in exporter_base,
        "Text exporters have no shared default-expression sanitizer.",
    )
    check(
        "_mermaid_arguments" in mermaid
        and "_arguments_without_defaults(value)" in mermaid,
        "Mermaid signature sanitization contract is missing.",
    )
    check(
        "path.get_extension()" in service and "path.left(" in service,
        "Export extension replacement contract is missing.",
    )


def validate_asset_store_media_contract() -> None:
    environment = dict(__import__("os").environ)
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    result = subprocess.run(
        [sys.executable, "tools/validate_asset_store_media.py"],
        cwd=ROOT,
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    check(
        result.returncode == 0,
        f"Asset-store media validation failed:\n{result.stdout.strip()}",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--allow-root-manifest",
        action="store_true",
        help="Allow MANIFEST.sha256 only when validating an extracted release archive.",
    )
    arguments = parser.parse_args()

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
    validate_v020_feature_contracts()
    validate_v021_feature_contracts()
    validate_v022_feature_contracts()
    validate_v023_feature_contracts()
    validate_v030_feature_contracts(allow_root_manifest=arguments.allow_root_manifest)
    validate_v031_feature_contracts()
    validate_schema_contract()
    validate_default_color_contract()
    validate_documentation_contract()
    validate_quality_contracts()
    validate_public_method_documentation()
    validate_exporter_contracts()
    validate_asset_store_media_contract()

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
