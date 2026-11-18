#!/usr/bin/env python3
"""Create platform application icons from the user-provided tennis-ball image.

The source is a size-optimized copy of the uploaded image, not generated
replacement art. Preserve its square composition and original blue/white motif.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
from io import BytesIO
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "tennis-ball-original.webp.b64"
OUT = ROOT / "build"
ICON_PNG = OUT / "icon.png"
ICON_ICO = OUT / "icon.ico"

EXPECTED_SOURCE_SHA256 = "a1a7ce2cf1cb1ce66845e40523092f0b20106e5be18e765baa94ba9d35e07e58"
WINDOWS_SIZES = ((16, 16), (24, 24), (32, 32), (48, 48),
                 (64, 64), (128, 128), (256, 256))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()

    raw = base64.b64decode(SOURCE.read_text(encoding="ascii").strip(), validate=True)
    digest = hashlib.sha256(raw).hexdigest()
    if digest != EXPECTED_SOURCE_SHA256:
        raise SystemExit(f"Provided source artwork checksum mismatch: {digest}")

    with Image.open(BytesIO(raw)) as src:
        if src.size != (160, 160):
            raise SystemExit(f"Unexpected source artwork size: {src.size}")
        icon = src.convert("RGBA").resize((256, 256), Image.Resampling.LANCZOS)

    if args.verify:
        with Image.open(ICON_PNG) as png:
            if png.size != (256, 256) or png.format != "PNG":
                raise SystemExit("Linux / window icon is missing or invalid")
        with Image.open(ICON_ICO) as ico:
            if ico.format != "ICO":
                raise SystemExit("Windows icon is missing or invalid")
            sizes = set(ico.info.get("sizes", ()))
            if not {(16, 16), (32, 32), (48, 48), (256, 256)}.issubset(sizes):
                raise SystemExit(f"Windows icon missing sizes: {sizes}")
        print("Tennis-ball Windows and Linux icon assets verified")
        return

    OUT.mkdir(exist_ok=True)
    icon.save(ICON_PNG, format="PNG", optimize=True)
    icon.save(ICON_ICO, format="ICO", sizes=WINDOWS_SIZES)
    print(f"Created {ICON_PNG} and {ICON_ICO} from provided artwork")


if __name__ == "__main__":
    main()
