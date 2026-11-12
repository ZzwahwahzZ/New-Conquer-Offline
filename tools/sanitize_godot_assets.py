#!/usr/bin/env python3
"""Sanitize temporary Godot import inputs; originals are quarantined, not destroyed."""
from pathlib import Path
from PIL import Image, ImageOps, UnidentifiedImageError
import argparse
import shutil
import sys

IMAGE_EXTS = {".png", ".jpg", ".jpeg"}

def quarantine(path: Path, root: Path, quarantine_root: Path, reason: str) -> None:
    relative = path.relative_to(root)
    destination = quarantine_root / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        destination = destination.with_name(destination.stem + ".quarantined" + destination.suffix)
    shutil.move(str(path), str(destination))
    print(f"QUARANTINED [{reason}]: {relative} -> {destination}", flush=True)

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--quarantine", type=Path, default=Path("/tmp/godot-asset-quarantine"))
    parser.add_argument("--max-glb-mb", type=float, default=15)
    parser.add_argument("--max-image-dimension", type=int, default=1024)
    args = parser.parse_args()
    root = args.root.resolve()
    quarantine_root = args.quarantine.resolve()
    max_glb_bytes = int(args.max_glb_mb * 1024 * 1024)
    stats = {"glb_quarantined": 0, "images_resized": 0, "images_quarantined": 0}

    files = sorted(p for p in root.rglob("*") if p.is_file()
                   and ".git" not in p.parts and ".godot" not in p.parts
                   and "build" not in p.parts and quarantine_root not in p.parents)
    for path in files:
        suffix = path.suffix.lower()
        if suffix == ".glb":
            if path.stat().st_size == 0 or path.stat().st_size > max_glb_bytes:
                quarantine(path, root, quarantine_root,
                           "empty GLB" if path.stat().st_size == 0 else f"GLB exceeds {args.max_glb_mb:g} MB")
                stats["glb_quarantined"] += 1
        elif suffix in IMAGE_EXTS:
            try:
                with Image.open(path) as image:
                    image.verify()
                with Image.open(path) as image:
                    image = ImageOps.exif_transpose(image)
                    if max(image.size) > args.max_image_dimension:
                        image.thumbnail((args.max_image_dimension, args.max_image_dimension), Image.Resampling.LANCZOS)
                        if suffix in {".jpg", ".jpeg"}:
                            if image.mode not in ("RGB", "L"):
                                image = image.convert("RGB")
                        elif image.mode not in ("RGB", "RGBA", "L", "LA", "P"):
                            image = image.convert("RGBA")
                        temporary = path.with_name(path.name + ".sanitizing")
                        image.save(temporary, format="JPEG" if suffix in {".jpg", ".jpeg"} else "PNG",
                                   quality=90, optimize=True)
                        with Image.open(temporary) as check:
                            check.verify()
                        temporary.replace(path)
                        stats["images_resized"] += 1
                        print(f"RESIZED: {path.relative_to(root)} -> {image.size}", flush=True)
            except (UnidentifiedImageError, OSError, ValueError, SyntaxError) as error:
                quarantine(path, root, quarantine_root, f"corrupt image: {error}")
                stats["images_quarantined"] += 1

    print("ASSET_SANITIZER_SUMMARY " + " ".join(f"{k}={v}" for k, v in stats.items()), flush=True)
    return 0

if __name__ == "__main__":
    sys.exit(main())
