# Compatibility

Version: 0.2.2

The compatibility target remains the supplied Linux x86_64 editor builds of Godot 4.3, 4.4.1, 4.5.2, 4.6.3, and 4.7. Each supplied version passed the same isolated static, editor-import, public-test, automation, export-matrix, showcase-generation, visual-showcase, and performance sequence.

The implementation uses the established Godot 4 dock API. Optional APIs—including graph arrangement, current-script lookup, scene opening, and editor signals—are capability-checked. The v0.2.2 UI and export-only implementation uses APIs available throughout the existing target range: `FileDialog`, `OptionButton`, dictionaries/arrays, `GraphEdit`, `DirAccess`, and project-local editor state.

See the [v0.2.2 compatibility matrix](validation/v0.2.2-compatibility-matrix.md) for executed engine identifiers, gate results, observations, and qualifications.

No claim is made for Godot 4.0–4.2, future versions, C# projects, non-Linux editors, or exported games without execution evidence. The add-on is editor-only.
