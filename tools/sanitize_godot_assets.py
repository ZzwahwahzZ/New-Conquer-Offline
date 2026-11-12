#!/usr/bin/env python3
"""Sanitize temporary Godot import inputs; originals are quarantined, not destroyed."""
from pathlib import Path
from PIL import Image, ImageOps, UnidentifiedImageError
import argparse
import json
import shutil
import struct
import sys

IMAGE_EXTS = {".png", ".jpg", ".jpeg"}
GLB_LIMIT_NODES = 250

def glb_node_count(path: Path) -> int:
    """Read the GLB JSON chunk without importing meshes or allocating GPU resources."""
    with path.open("rb") as stream:
        header = stream.read(12)
        if len(header) != 12:
            raise ValueError("truncated GLB header")
        magic, version, total_length = struct.unpack("<4sII", header)
        if magic != b"glTF" or version != 2 or total_length != path.stat().st_size:
            raise ValueError("invalid GLB v2 header or declared length")
        while stream.tell() < total_length:
            chunk_header = stream.read(8)
            if len(chunk_header) != 8:
                raise ValueError("truncated GLB chunk header")
            chunk_length, chunk_type = struct.unpack("<II", chunk_header)
            if chunk_length > total_length - stream.tell():
                raise ValueError("GLB chunk exceeds declared file length")
            chunk = stream.read(chunk_length)
            if chunk_type == 0x4E4F534A:
                document = json.loads(chunk.decode("utf-8").rstrip(" \t\r\n\0"))
                nodes = document.get("nodes", [])
                if not isinstance(nodes, list):
                    raise ValueError("GLB nodes field is not an array")
                return len(nodes)
    raise ValueError("GLB JSON chunk is missing")

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
    parser.add_argument("--max-glb-mb", type=float, default=50)
    parser.add_argument("--max-glb-nodes", type=int, default=GLB_LIMIT_NODES)
    parser.add_argument("--max-image-dimension", type=int, default=1024)
    args = parser.parse_args()
    root = args.root.resolve()
    quarantine_root = args.quarantine.resolve()
    max_glb_bytes = int(args.max_glb_mb * 1024 * 1024)
    stats = {"glb_quarantined": 0, "glb_nodes_quarantined": 0, "glb_checked": 0,
             "images_resized": 0, "images_quarantined": 0}

    files = sorted(p for p in root.rglob("*") if p.is_file()
                   and ".git" not in p.parts and ".godot" not in p.parts
                   and "build" not in p.parts and quarantine_root not in p.parents)
    for path in files:
        suffix = path.suffix.lower()
        if suffix == ".glb":
            size = path.stat().st_size
            if size == 0 or size > max_glb_bytes:
                quarantine(path, root, quarantine_root,
                           "empty GLB" if size == 0 else f"GLB exceeds {args.max_glb_mb:g} MB")
                stats["glb_quarantined"] += 1
                continue
            try:
                nodes = glb_node_count(path)
                stats["glb_checked"] += 1
                if nodes > args.max_glb_nodes:
                    quarantine(path, root, quarantine_root,
                               f"GLB has {nodes} nodes (limit {args.max_glb_nodes})")
                    stats["glb_nodes_quarantined"] += 1
            except (OSError, ValueError, UnicodeDecodeError, json.JSONDecodeError, struct.error) as error:
                quarantine(path, root, quarantine_root, f"invalid GLB structure: {error}")
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
