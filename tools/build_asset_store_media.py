#!/usr/bin/env python3
"""Build final Asset Library WebP files from approved real runtime captures."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from build_release import release_version

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
except ModuleNotFoundError as error:
    if error.name != "PIL":
        raise
    raise SystemExit(
        "Pillow is unavailable for this Python interpreter: "
        f"{sys.executable}\n"
        "Install development requirements with that same interpreter: "
        f"{sys.executable} -m pip install -r requirements-dev.txt"
    ) from error

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / f"docs/asset_store/source-captures/v{release_version()}/raw"
CURRENT = ROOT / "docs/asset_store/current"
MAPPING = {
    "featured-01-default-overview.webp": "overview.png",
    "featured-02-maximum-information.webp": "max_info.png",
    "featured-03-complex-project.webp": "complex.png",
    "featured-04-editor-navigation.webp": "editor-navigation.png",
    "featured-05-export-workflow.webp": "export_only.png",
    "featured-06-scoped-context.webp": "scope.png",
    "featured-07-search-and-focus.webp": "search.png",
    "featured-08-member-evidence-tooltip.webp": "member_tooltip.png",
    "featured-09-connection-evidence-tooltip.webp": "connection_tooltip.png",
    "featured-10-stale-snapshot-recovery.webp": "stale_snapshot.png",
}


def font(paths: list[str], size: int):
    for value in paths:
        path = Path(value)
        if path.exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def build_thumbnail() -> Image.Image:
    width, height = 1920, 1080
    background = Image.new("RGB", (width, height), (12, 18, 28))
    pixels = background.load()
    for y in range(height):
        for x in range(width):
            t = x / width
            pixels[x, y] = (int(12 + 8 * t), int(18 + 14 * t), int(28 + 18 * t))
    shot = Image.open(RAW / "overview.png").convert("RGB").crop((0, 0, 1920, 1040))
    shot.thumbnail((1120, 760), Image.Resampling.LANCZOS)
    card = Image.new("RGB", (shot.width + 28, shot.height + 28), (34, 43, 58))
    card.paste(shot, (14, 14))
    background.paste(card.filter(ImageFilter.GaussianBlur(0.15)), (735, 160))
    draw = ImageDraw.Draw(background)
    bold = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf",
    ]
    regular = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
    ]
    icon_candidates = [
        ROOT / "docs/asset_store/icon-source.png",
        ROOT / "docs/images/icon.png",
    ]
    for icon_path in icon_candidates:
        if icon_path.exists():
            icon = Image.open(icon_path).convert("RGBA")
            icon.thumbnail((150, 150), Image.Resampling.LANCZOS)
            background.paste(icon, (80, 80), icon)
            break
    draw.text((80, 255), "SCRIPT", font=font(bold, 34), fill=(89, 210, 255))
    draw.multiline_text(
        (80, 310),
        "DEPENDENCY\nINSPECTOR",
        font=font(bold, 78),
        fill=(245, 248, 252),
        spacing=4,
    )
    draw.multiline_text(
        (80, 520),
        "Understand GDScript inheritance,\ndependencies, scenes, and source evidence.",
        font=font(regular, 32),
        fill=(188, 199, 215),
        spacing=12,
    )
    chip_font = font(bold, 25)
    y = 720
    for text in ["IN-EDITOR GRAPH", "SOURCE NAVIGATION", "JSON · MERMAID · PLANTUML"]:
        box = draw.textbbox((0, 0), text, font=chip_font)
        w = box[2] - box[0]
        draw.rounded_rectangle(
            (80, y, 80 + w + 34, y + 50),
            radius=14,
            fill=(28, 54, 75),
            outline=(63, 145, 196),
            width=2,
        )
        draw.text((97, y + 10), text, font=chip_font, fill=(220, 239, 252))
        y += 68
    draw.text(
        (80, 1000),
        "Godot 4 editor add-on",
        font=font(regular, 32),
        fill=(135, 151, 170),
    )
    return background


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--quality", type=int, default=88)
    args = parser.parse_args()
    CURRENT.mkdir(parents=True, exist_ok=True)
    for output, source in MAPPING.items():
        image = Image.open(RAW / source).convert("RGB")
        if image.size != (1920, 1080):
            raise RuntimeError(f"{source} must be 1920x1080")
        image.save(CURRENT / output, "WEBP", quality=args.quality, method=6)
    build_thumbnail().save(
        CURRENT / "thumbnail.webp", "WEBP", quality=args.quality, method=6
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
