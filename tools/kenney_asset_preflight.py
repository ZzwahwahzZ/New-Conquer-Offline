#!/usr/bin/env python3
"""Preflight the exact Kenney GLB models used by the six-city architecture.

This is a structural gate before Godot imports the project: it validates GLB v2
chunks, embedded buffers, mesh primitives, accessors, bufferView bounds and finite
node transforms. Godot smoke tests then verify the imported scenes and renderable
MeshInstance3D nodes.
"""
from __future__ import annotations

import json
import math
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = {
    "nature-kit": [
        "bridge_wood.glb",
        "bridge_stone.glb",
        "cactus_short.glb",
        "cactus_tall.glb",
        "tree_palm.glb",
        "tree_default.glb",
        "tree_oak.glb",
        "tree_pineDefaultA.glb",
        "tree_pineDefaultB.glb",
        "tree_default_dark.glb",
        "tree_oak_dark.glb",
        "tree_oak_fall.glb",
        "plant_bush.glb",
        "plant_bushLarge.glb",
        "plant_flatTall.glb",
        "grass.glb",
        "grass_large.glb",
        "flower_redA.glb",
        "rock_largeA.glb",
        "rock_smallA.glb",
        "rock_smallB.glb",
        "stone_largeB.glb",
        "stone_largeD.glb",
        "mushroom_redGroup.glb",
        "log_large.glb",
        "stump_round.glb",
    ],
    "castle-kit": [
        "gate.glb",
        "tower-square.glb",
        "wall.glb",
    ],
    "fantasy-town-kit": [
        "stall-red.glb",
        "stall-green.glb",
        "fountain-square.glb",
        "windmill.glb",
        "watermill.glb",
    ],
}
COMPONENTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}
COMPONENT_BYTES = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}


def fail(path: Path, reason: str) -> None:
    raise RuntimeError(f"KENNEY_PREFLIGHT_FAIL: {path.relative_to(ROOT)}: {reason}")


def finite_tree(value: object, path: Path, label: str) -> None:
    if isinstance(value, float) and not math.isfinite(value):
        fail(path, f"non-finite {label}")
    if isinstance(value, list):
        for item in value:
            finite_tree(item, path, label)


def validate(path: Path) -> dict:
    data = path.read_bytes()
    if len(data) < 20 or data[:4] != b"glTF":
        fail(path, "missing GLB magic or truncated header")
    version, declared = struct.unpack_from("<II", data, 4)
    if version != 2 or declared != len(data):
        fail(path, f"invalid GLB version/length ({version}, {declared}, {len(data)})")

    offset = 12
    json_chunk = None
    bin_chunk = None
    chunk_index = 0
    while offset < len(data):
        if offset + 8 > len(data):
            fail(path, "truncated chunk header")
        length, kind = struct.unpack_from("<II", data, offset)
        offset += 8
        end = offset + length
        if end > len(data):
            fail(path, "chunk exceeds declared GLB length")
        payload = data[offset:end]
        if chunk_index == 0 and kind != 0x4E4F534A:
            fail(path, "first chunk is not JSON")
        if kind == 0x4E4F534A:
            if json_chunk is not None:
                fail(path, "duplicate JSON chunk")
            json_chunk = payload
        elif kind == 0x004E4942:
            if bin_chunk is not None:
                fail(path, "duplicate BIN chunk")
            bin_chunk = payload
        offset = end
        chunk_index += 1
    if offset != len(data) or json_chunk is None:
        fail(path, "missing JSON chunk or invalid chunk alignment")

    try:
        document = json.loads(json_chunk.rstrip(b" \\t\\r\\n\\0").decode("utf-8"))
    except Exception as exc:
        fail(path, f"invalid JSON chunk: {exc}")
    if document.get("asset", {}).get("version") != "2.0":
        fail(path, "asset.version is not glTF 2.0")

    meshes = document.get("meshes", [])
    if not meshes:
        fail(path, "no meshes")
    primitive_count = 0
    for mesh_index, mesh in enumerate(meshes):
        primitives = mesh.get("primitives", [])
        if not primitives:
            fail(path, f"mesh {mesh_index} has no primitives")
        for primitive in primitives:
            primitive_count += 1
            attrs = primitive.get("attributes", {})
            if "POSITION" not in attrs:
                fail(path, f"mesh {mesh_index} primitive has no POSITION accessor")
            for accessor_index in list(attrs.values()) + ([primitive["indices"]] if "indices" in primitive else []):
                if not isinstance(accessor_index, int) or accessor_index < 0 or accessor_index >= len(document.get("accessors", [])):
                    fail(path, f"mesh {mesh_index} references invalid accessor {accessor_index}")

    buffer_views = document.get("bufferViews", [])
    buffers = document.get("buffers", [])
    if buffers:
        if len(buffers) != 1 or bin_chunk is None:
            fail(path, "expected one embedded GLB buffer")
        declared_buffer = int(buffers[0].get("byteLength", -1))
        if declared_buffer < 0 or declared_buffer > len(bin_chunk) or declared_buffer > len(bin_chunk) + 3:
            fail(path, f"embedded buffer length mismatch ({declared_buffer}, {len(bin_chunk)})")
    for index, view in enumerate(buffer_views):
        buffer_index = int(view.get("buffer", 0))
        if buffer_index >= len(buffers):
            fail(path, f"bufferView {index} references missing buffer")
        start = int(view.get("byteOffset", 0))
        length = int(view.get("byteLength", -1))
        if start < 0 or length <= 0 or start + length > int(buffers[buffer_index]["byteLength"]):
            fail(path, f"bufferView {index} is out of bounds")

    accessors = document.get("accessors", [])
    for index, accessor in enumerate(accessors):
        view_index = accessor.get("bufferView")
        if view_index is None:
            continue
        if not isinstance(view_index, int) or view_index < 0 or view_index >= len(buffer_views):
            fail(path, f"accessor {index} references missing bufferView")
        component = COMPONENT_BYTES.get(accessor.get("componentType"))
        component_count = COMPONENTS.get(accessor.get("type"))
        count = accessor.get("count")
        if component is None or component_count is None or not isinstance(count, int) or count <= 0:
            fail(path, f"accessor {index} has invalid component/type/count")
        view = buffer_views[view_index]
        stride = int(view.get("byteStride", component * component_count))
        accessor_offset = int(accessor.get("byteOffset", 0))
        required = accessor_offset + (count - 1) * stride + component * component_count
        if accessor_offset < 0 or required > int(view["byteLength"]):
            fail(path, f"accessor {index} exceeds bufferView bounds")
        for bound_name in ("min", "max"):
            if bound_name in accessor:
                finite_tree(accessor[bound_name], path, f"accessor {index} {bound_name}")

    for node_index, node in enumerate(document.get("nodes", [])):
        for key in ("translation", "rotation", "scale", "matrix"):
            if key in node:
                finite_tree(node[key], path, f"node {node_index} {key}")
    if not document.get("nodes"):
        fail(path, "no scene nodes")

    return {
        "file": path.relative_to(ROOT).as_posix(),
        "bytes": len(data),
        "meshes": len(meshes),
        "primitives": primitive_count,
        "nodes": len(document["nodes"]),
        "materials": len(document.get("materials", [])),
        "textures": len(document.get("textures", [])),
    }


def main() -> int:
    report = []
    for pack, names in ASSETS.items():
        for name in names:
            path = ROOT / "assets" / "environment" / "kenney" / pack / "Models" / "GLB format" / name
            if not path.is_file():
                alternate = ROOT / "assets" / "environment" / "kenney" / pack / "Models" / "GLTF format" / name
                if alternate.is_file():
                    path = alternate
                else:
                    raise RuntimeError(f"KENNEY_PREFLIGHT_FAIL: required model missing: {pack}/{name}")
            result = validate(path)
            report.append(result)
            print("KENNEY_PREFLIGHT_MODEL_PASS: " + json.dumps(result, sort_keys=True), flush=True)
    output = ROOT / "reports" / "kenney-asset-preflight.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({"version": 1, "models": report}, indent=2), encoding="utf-8")
    print(f"KENNEY_ASSET_PREFLIGHT_PASS: models={len(report)} meshes={sum(x['meshes'] for x in report)} primitives={sum(x['primitives'] for x in report)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
