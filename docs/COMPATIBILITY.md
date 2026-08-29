# Compatibility

Version: 0.2.4

The compatibility target remains the supplied Linux x86_64 editor builds of Godot 4.3, 4.4.1, 4.5.2, 4.6.3, and 4.7. Each supplied version passed the same isolated static, editor-import, public-test, automation, export-matrix, showcase-generation, visual-showcase, and performance sequence.

The implementation uses the established Godot 4 dock API. Optional APIs—including graph arrangement, current-script lookup, scene opening, and editor signals—are capability-checked. The v0.2.4 media workflow does not change the add-on runtime API surface. Repository-owned PNG/WebP documentation is isolated with `docs/asset_store/.gdignore`, so supported editors do not import marketplace media as project resources.

See the [v0.2.4 compatibility matrix](validation/v0.2.4-compatibility-matrix.md) for executed engine identifiers, gate results, observations, and qualifications.

No claim is made for Godot 4.0–4.2, future versions, C# projects, non-Linux editors, or exported games without execution evidence. The add-on is editor-only.
