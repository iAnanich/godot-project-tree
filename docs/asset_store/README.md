# Godot Asset Library media

`current/` contains the exact thumbnail and featured `.webp` files intended for the current Godot Asset Library listing. `media_manifest.json` records their role, source capture, release, dimensions, and scenario.

All featured images are derived from real Godot-rendered screenshots. The thumbnail is an informational composition that embeds the real default-overview screenshot; it does not replace the add-on graph with a synthetic or AI-generated diagram.

## Constraints

- 16:9 is mandatory.
- 1920×1080 is the repository target.
- 1280×720 is the minimum accepted size.
- Each upload file must be at most 600 KB.
- Final upload files use WebP.

Validate the committed set:

```bash
python tools/validate_asset_store_media.py
```

Regenerate final WebP files from already-approved real captures:

```bash
python tools/build_asset_store_media.py
```

Capture the complete set on Linux with Godot 4.7 and Xvfb:

```bash
python tools/capture_asset_store_media.py \
  --godot /path/to/Godot_v4.7-stable_linux.x86_64
```

The current v0.4.0 set also includes dedicated member-evidence and connection-evidence hover captures.

The capture command uses the small `examples/media_showcase` fixture for focused images, the broader existing showcase for the complex view, and a temporary editor-only helper plugin for the source-navigation image. The helper is not enabled in the development project or distributed add-on.
