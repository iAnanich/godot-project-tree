# Canonical snapshot schema

The canonical JSON-compatible snapshot is the stable boundary between scanning/building, editor presentation, and exporters. The current version is `schema_version: 1`.

A machine-readable schema is provided at [`docs/schema/snapshot-v1.schema.json`](schema/snapshot-v1.schema.json). Runtime exports are additionally checked by `core/snapshot_validator.gd` before serialization.

The runtime validator and JSON Schema define the same required fields and scalar types. Validation is strict at semantic boundaries: `schema_version` must be an integer, IDs/endpoints must be strings, required node member collections and edge `member_links` must be present, and warning/error entries must be strings. Values are not coerced during validation. Unknown additive fields remain permitted.

## Root object

| Field | Required | Meaning |
|---|---:|---|
| `schema_version` | yes | Integer serialization version. Version 1 readers must reject other values. |
| `metadata` | yes | Scan root, engine version, resolved options, and style snapshot. |
| `nodes` | yes | Canonically sorted class/script nodes. |
| `edges` | yes | Canonically sorted class-level dependency relations. |
| `warnings` | yes | Reader-facing nonfatal messages retained for compatibility. |
| `errors` | yes | Reader-facing graph errors retained for compatibility. |
| `diagnostics` | no | Structured `{severity, code, message, context}` records. New producers include it. |

Unknown root and nested fields are permitted. Consumers should ignore unknown fields unless they explicitly require them.

## Node identity

`id` is the relationship key and must be unique.

- User and add-on scripts: their normalized `res://` path.
- Native classes: `native://ClassName`.
- Unresolved/external classes: a deterministic external identifier.

`name` is presentation text. `path` is the complete script path when applicable. A declared `class_name` is kept separately and is not concatenated with `path`.

`kind` is one of `user`, `addon`, `native`, or `external`.

## Edge direction and kinds

Canonical edges point from the script that depends or derives to the class it uses or extends.

- `extends`: inheritance.
- `uses`: literal `.gd` load/preload or direct class-qualified member use.
- `type_uses`: a reference established only through a type annotation.

The GraphEdit renderer may reverse connection direction for layout, but it must not mutate the snapshot or exported semantics.

## Member provenance

An edge may contain `member_links`. Each link contains optional `source_member` and `target_member` references plus a required evidence code. Member references use:

```json
{"kind": "method", "name": "calculate_damage"}
```

Member provenance is evidence about a class-level relation; it does not create a second graph edge. Empty endpoint objects mean the source analyzer could establish only one side or only the containing class.

JSON is the lossless representation. PlantUML can express exact `Class::member` endpoints. Mermaid class diagrams retain member specificity in relationship labels because their class relationship grammar does not provide member endpoints.

## Evolution policy

- Additive optional fields may be introduced without changing version 1.
- New required fields, changed identity rules, changed edge direction, or changed field meaning require a new schema version.
- Writers produce canonical ordering; readers must not infer semantic meaning from incidental object-key order.
- Schema migration must be explicit. The current implementation does not silently coerce unsupported versions.
