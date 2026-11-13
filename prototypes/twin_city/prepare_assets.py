#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, os
from pathlib import Path
from huggingface_hub import hf_hub_download

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
APPROVED = ROOT / "assets/wuxia_imperial_pack/imperial_approved_assets.json"
CACHE = HERE / "asset_cache"
DATASET = "ZzwahwahzZ/clash-of-legends-terrain-assets"
PREFIX = "assets/wuxia_imperial_pack/"
MODELS = {
"Ceremonial Hall (Imperial China Palace and Garden)",
"Water Pavilion (Imperial China Palace and Garden)",
"Lotus pond pavilion (Imperial China Palace and Garden)",
"Gate Tower (Imperial China Palace and Garden)",
"Palace Wall Straight (Imperial China Palace and Garden)",
"Palace Wall Corner (Imperial China Palace and Garden)",
"Palace Wall Moon Gate (Imperial China Palace and Garden)",
"Arched Stone Bridge (Imperial China Palace and Garden)",
"Terrace Platform Module (Imperial China Palace and Garden)",
"Terrace Step Flight (Imperial China Palace and Garden)",
"Dragon Roof Finial (Imperial China Palace and Garden)",
"Standing Garden Lantern (Imperial China Palace and Garden)",
"Hanging Silk Lantern (Imperial China Palace and Garden)",
"Guardian Lion Pair (Imperial China Palace and Garden)",
"Imperial Throne Chair (Imperial China Palace and Garden)",
"Pond Water Module (Imperial China Palace and Garden)",
"Lotus Cluster (Imperial China Palace and Garden)",
"Plum Tree In Blossom (Imperial China Palace and Garden)",
"Bamboo Clump (Imperial China Palace and Garden)",
"Pine Tree (Wipe Day Survival Island)",
}
TEXTURES = {
"textures/PavingStones036/PavingStones036_1K-JPG_Color.jpg",
"textures/PavingStones036/PavingStones036_1K-JPG_NormalGL.jpg",
"textures/PavingStones036/PavingStones036_1K-JPG_Roughness.jpg",
"textures/Marble012/Marble012_1K-JPG_Color.jpg",
"textures/Marble012/Marble012_1K-JPG_NormalGL.jpg",
"textures/Marble012/Marble012_1K-JPG_Roughness.jpg",
"textures/RoofingTiles013A/RoofingTiles013A_1K-JPG_Color.jpg",
"textures/RoofingTiles013A/RoofingTiles013A_1K-JPG_NormalGL.jpg",
"textures/RoofingTiles013A/RoofingTiles013A_1K-JPG_Roughness.jpg",
"textures/Wood096/Wood096_1K-JPG_Color.jpg",
"textures/Wood096/Wood096_1K-JPG_NormalGL.jpg",
"textures/Wood096/Wood096_1K-JPG_Roughness.jpg",
}

def main():
    token = os.environ.get("HF_TOKEN", "").strip()
    if not token:
        raise SystemExit("HF_TOKEN secret is required.")
    approved = json.loads(APPROVED.read_text(encoding="utf-8"))
    selected, seen = [], set()
    for category in approved["categories"].values():
        for item in category.get("assets", []):
            file_path = str(item.get("file", ""))
            if item.get("style_group") == "imperial_chinese" and file_path.endswith(".glb"):
                selected.append(item); seen.add(item["name"])
            elif item.get("style_group") == "environmental" and item.get("name") in MODELS:
                selected.append(item); seen.add(item["name"])
            elif item.get("style_group") == "pbr_materials" and file_path in TEXTURES:
                selected.append(item); seen.add(file_path)
    missing = sorted(MODELS - seen) + sorted(TEXTURES - seen)
    if missing:
        raise SystemExit("Approved manifest missing required assets: " + repr(missing))
    restored = []
    for item in selected:
        filename = PREFIX + str(item["file"])
        local = Path(hf_hub_download(repo_id=DATASET, repo_type="dataset", filename=filename, token=token, local_dir=str(CACHE)))
        digest = hashlib.sha256(local.read_bytes()).hexdigest()
        if digest != item["sha256"] or local.stat().st_size != int(item["bytes"]):
            raise SystemExit("Approved asset integrity mismatch: " + filename)
        restored.append({"name": item["name"], "style_group": item["style_group"], "file": item["file"], "sha256": digest, "bytes": local.stat().st_size})
        print("TWIN_CITY_APPROVED_ASSET_READY: " + filename)
    manifest = CACHE / PREFIX / "imperial_approved_assets.json"
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_bytes(APPROVED.read_bytes())
    report = {"dataset": DATASET, "approved_manifest_sha256": hashlib.sha256(APPROVED.read_bytes()).hexdigest(),
              "restored_files": len(restored), "restored_glb_models": sum(x["file"].endswith(".glb") for x in restored),
              "restored_pbr_textures": sum(not x["file"].endswith(".glb") for x in restored), "files": restored}
    out = HERE / "reports"; out.mkdir(parents=True, exist_ok=True)
    (out / "twin_city_asset_restore.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("TWIN_CITY_ASSET_RESTORATION_PASS: " + json.dumps({k: report[k] for k in ("restored_files", "restored_glb_models", "restored_pbr_textures")}))

if __name__ == "__main__":
    main()
