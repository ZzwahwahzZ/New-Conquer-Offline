#!/usr/bin/env python3
"""Inspect the four legacy unclassified GLBs and emit a node/AABB classification report."""
from __future__ import annotations
import json
import os
import shutil
from pathlib import Path
import trimesh
from huggingface_hub import HfApi

ROOT = Path(__file__).resolve().parents[1]
ENV_DIR = ROOT / "assets" / "environment"
MODEL_DIR = ENV_DIR / "models"
REPORT = ENV_DIR / "glb_classification_report.json"

def classify(filename: str, labels: list[str]) -> str:
    text = (filename + " " + " ".join(labels)).lower()
    if any(word in text for word in ("temple", "pagoda", "gate", "bridge", "building", "house", "palace", "arch", "city")):
        return "architecture"
    if any(word in text for word in ("volcano", "lava", "alpine", "arctic", "mountain", "snow", "ice", "biome", "dune", "desert")):
        return "terrain"
    if "island" in text or "archipelago" in text:
        return "islands"
    if any(word in text for word in ("rock", "boulder", "basalt", "cliff", "karst", "stone")):
        return "rocks"
    if any(word in text for word in ("tree", "pine", "palm", "sakura", "willow", "forest", "foliage")):
        return "vegetation"
    return "unclassified"

def main() -> None:
    records = []
    paths = sorted(path for path in ENV_DIR.rglob("*.glb") if MODEL_DIR / "classified" not in path.parents)
    for path in paths:
        scene = trimesh.load(path, force="scene", process=False)
        if not isinstance(scene, trimesh.Scene):
            scene = trimesh.Scene(scene)
        labels = []
        nodes = []
        for node_name in scene.graph.nodes_geometry:
            transform, geometry_name = scene.graph.get(node_name)
            geometry = scene.geometry[geometry_name]
            labels.extend([str(node_name), str(geometry_name)])
            bounds = geometry.bounds
            nodes.append({
                "node": str(node_name),
                "mesh": str(geometry_name),
                "vertices": int(len(geometry.vertices)),
                "faces": int(len(geometry.faces)),
                "local_aabb_min": [float(x) for x in bounds[0]],
                "local_aabb_max": [float(x) for x in bounds[1]],
                "world_transform": [[float(v) for v in row] for row in transform],
            })
        bounds = scene.bounds
        category = classify(path.name, labels)
        records.append({
            "file": path.name,
            "bytes": path.stat().st_size,
            "sha256": __import__("hashlib").sha256(path.read_bytes()).hexdigest(),
            "category": category,
            "scene_aabb_min": [float(x) for x in bounds[0]] if bounds is not None else None,
            "scene_aabb_max": [float(x) for x in bounds[1]] if bounds is not None else None,
            "node_count": len(nodes),
            "nodes": nodes,
        })
        print(f"GLB_AUDIT: {path.name} category={category} nodes={len(nodes)} aabb={bounds.tolist() if bounds is not None else None}")
    report = {
        "source": "settlement-terrain-source/models/unclassified",
        "inspected_files": len(records),
        "classification_policy": "Only node/mesh-name evidence is used; ambiguous files remain unclassified.",
        "models": records,
    }
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    token = os.environ.get("HF_TOKEN", "").strip()
    if token:
        HfApi(token=token).upload_file(
            path_or_fileobj=str(REPORT),
            path_in_repo="settlement-terrain-source/reports/glb_classification_report.json",
            repo_id="ZzwahwahzZ/clash-of-legends-terrain-assets",
            repo_type="dataset",
            commit_message="Publish GLB node and AABB classification report",
        )
    print(f"GLB_AUDIT_REPORT: {REPORT}")
    print(f"GLB_AUDITED_COUNT: {len(records)}")

if __name__ == "__main__":
    main()
