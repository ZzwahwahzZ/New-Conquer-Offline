#!/usr/bin/env python3
"""Fetch pinned CC0 rigged GLB actors and validate them before Godot import.

Source: Ariescar/gobkit-free-assets, commit 4e73c68fa6e8ca9d948fcc0ce7215c830a022c3b.
License: CC0-1.0 (LICENSE copied into assets/rigged_characters).
The game ships these files inside exports; runtime never contacts the network.
"""
from __future__ import annotations
import hashlib, io, json, pathlib, struct, urllib.request
import numpy as np
import trimesh

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "rigged_characters"
BASE = "https://raw.githubusercontent.com/Ariescar/gobkit-free-assets/4e73c68fa6e8ca9d948fcc0ce7215c830a022c3b/"
LICENSE_URL = BASE + "LICENSE"

API_URL = "https://gobkit.com/api/free"
EXTENDED_PACK_SELECTION = {
    "gobkit-human003-pack": ["Archer","Footman","HeavyWarrior","King","KnightCaptain","PeasantMilitia","Priestess","Scout"],
    "gobkit-human006-pack": ["OrcIronGuard","OrcLegionArcher","OrcLegionCommander","OrcLegionary","OrcShieldBearer","OrcWarDrummer","OrcWarShaman","OrcWarbandChampion"],
    "gobkit-human010-pack": ["BloodironGrunt","BloodironJuggernaut","BloodironKnight","BloodironSmith","OrcChainBrute","OrcPyromancer"],
    "gobkit-human011-pack": ["CleaverButcher","NightWitch","PumpkinScarecrow","SheetGhost","StitchedBrute","TombMummy","VampireCountess","WerewolfCaptain"],
    "gobkit-human013-pack": ["CourtJester","CrownedPrincess","LadyKnight","PalaceHalberdier","Prince","RoyalHerald"],
    "gobkit-human016-pack": ["AxeThrower","Berserker","BoarHelmSpearman","ClanSmith","WolfQueen"],
    "gobkit-human017-pack": ["FarmHand","FarmOwner","MarketVendor","Shepherd"],
    "gobkit-human014-pack": ["GongOverlord","IronFanFighter","ShadowKunoichi","TasselSpearMaster"],
    "gobkit-dino-pack": ["Carnotaurus","Pterodactylus","Spinosaurus","Trex"],
    "gobkit-insect002-pack": ["AtlasBeetle","Manticora","SacredScarab"],
    "gobkit-animal007-pack": ["Dingo","Scorpion"],
    "gobkit-animal006-pack": ["Fox","Lion"],
}
ASSETS = {
    "humanoid_01": ("minion/minion-a01.glb", "f7700d62b6252f14601743f156049ef3b8454f96"),
    "humanoid_02": ("minion/minion-a02.glb", "7efd8a207b30a0261c10acafb08f173b975c4d2b"),
    "humanoid_03": ("minion/minion-b01.glb", "b8419a471e5f2619c17b2a8905dec1a04101430b"),
    "humanoid_04": ("minion/minion-b02.glb", "b351ace190813b69bd6c67b03f3755565ca1c2dc"),
    "humanoid_05": ("minion/minion-c01.glb", "584b85913b3a075948e6630b6a0d48883227c6d4"),
    "humanoid_06": ("minion/minion-c02.glb", "b776b3d91835e56009ea9ca79362039e89f7d3b5"),
    "humanoid_07": ("minion/minion-d01.glb", "ceb7beba04fa67b9607af9c8e704d1d084dd13ee"),
    "humanoid_08": ("minion/minion-d02.glb", "435125411965f24ec4d4693029eae7925201f0bb"),
    "beast_bat": ("animal/Bat.glb", "766de4372d17206835c491f80f6b0db367ca0012"),
    "beast_corgi": ("animal/Corgi.glb", "5e76b79fe002de2158309d56fdd02402de69f8af"),
    "beast_rhino": ("animal/Rhino.glb", "f638b1cf00a6472192beb85b1a4162535bfc189e"),
    "beast_shark": ("animal/Shark.glb", "d2bc2497bbae415bd1fa7e297dc201b5f3f38ae4"),
}
def download(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "New-Conquer-Offline-asset-fetch/1.0"})
    with urllib.request.urlopen(req, timeout=60) as response:
        if response.status != 200:
            raise RuntimeError(f"HTTP {response.status}: {url}")
        return response.read()
def git_blob_sha(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
def validate_glb(data: bytes, label: str) -> dict:
    if len(data) < 20:
        raise ValueError(f"{label}: truncated GLB")
    magic, version, total = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF" or version != 2 or total != len(data):
        raise ValueError(f"{label}: invalid GLB v2 header")
    json_len, json_type = struct.unpack_from("<I4s", data, 12)
    if json_type != b"JSON":
        raise ValueError(f"{label}: first GLB chunk is not JSON")
    doc = json.loads(data[20:20+json_len].decode("utf-8").rstrip(" \\t\\r\\n\\0"))
    if not doc.get("skins") or not doc.get("animations") or not doc.get("meshes"):
        raise ValueError(f"{label}: must contain mesh, skin and animation data")
    position_accessors = []
    for mesh in doc["meshes"]:
        for primitive in mesh.get("primitives", []):
            idx = primitive.get("attributes", {}).get("POSITION")
            if idx is not None:
                accessor = doc["accessors"][idx]
                if accessor.get("componentType") != 5126:
                    raise ValueError(f"{label}: POSITION is not float32")
                position_accessors.append(idx)
    if not position_accessors:
        raise ValueError(f"{label}: no float32 POSITION accessors")
    scene = trimesh.load_scene(io.BytesIO(data), file_type="glb", process=False)
    vertices = [np.asarray(g.vertices) for g in scene.geometry.values() if hasattr(g, "vertices")]
    if not vertices or not all(v.size and np.isfinite(v).all() for v in vertices):
        raise ValueError(f"{label}: trimesh found missing or non-finite geometry")
    # Verify conversion-safe coordinate representation without re-exporting (which could discard skinning).
    converted = [v.astype(np.float32, copy=False) for v in vertices]
    if not all(v.dtype == np.float32 for v in converted):
        raise ValueError(f"{label}: coordinate conversion failed")
    return {"skins": len(doc["skins"]), "animations": len(doc["animations"]),
            "meshes": len(doc["meshes"]), "position_accessors": len(position_accessors),
            "vertices": int(sum(len(v) for v in vertices)), "coordinate_dtype": "float32"}

def fetch_extended_assets() -> dict:
    manifest_bytes = download(API_URL)
    manifest = json.loads(manifest_bytes.decode("utf-8"))
    if manifest.get("schemaVersion") != 2:
        raise RuntimeError("Unexpected Gobkit free-model manifest schema")
    packs = {pack.get("id"): pack for pack in manifest.get("packs", [])}
    allowed_urls = set(manifest.get("glbs", []))
    result = {}
    for pack_id, wanted_names in EXTENDED_PACK_SELECTION.items():
        pack = packs.get(pack_id)
        if not pack:
            raise RuntimeError(f"Missing CC0 pack in Gobkit manifest: {pack_id}")
        if "CC0 1.0" not in str(pack.get("license", "")):
            raise RuntimeError(f"Pack is not explicitly CC0: {pack_id}")
        models = {model.get("name"): model for model in pack.get("models", [])}
        for model_name in wanted_names:
            model = models.get(model_name)
            if not model:
                raise RuntimeError(f"Missing model {model_name} in {pack_id}")
            url = str(model.get("url", ""))
            if url not in allowed_urls or not url.startswith("https://gobkit.com/freebies/") or not url.lower().endswith(".glb"):
                raise RuntimeError(f"Untrusted or unlisted GLB URL for {model_name}: {url}")
            if not model.get("rigged") or model.get("format") != "glb":
                raise RuntimeError(f"Model is not a rigged GLB: {model_name}")
            animation_names = {str(a.get("name", "")).lower() for a in model.get("animations", [])}
            if not {"idle", "walk", "attack"}.issubset(animation_names) or not ({"death", "dead"} & animation_names):
                raise RuntimeError(f"Required named animation metadata missing for {model_name}: {sorted(animation_names)}")
            data = download(url)
            info = validate_glb(data, "gobkit_" + model_name)
            filename = "gobkit_" + model_name + ".glb"
            (OUT / filename).write_bytes(data)
            result[model_name] = {
                "pack_id": pack_id, "url": url, "license": "CC0 1.0",
                "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data),
                "fps": model.get("fps", pack.get("fps", 24)),
                "animation_names": sorted(animation_names), **info
            }
            print(f"VALIDATED gobkit_{model_name}: named animations={','.join(sorted(animation_names))}")
    print(f"EXTENDED_CC0_ASSETS_PASS: {len(result)} named-clip rigged GLBs")
    return result

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    license_data = download(LICENSE_URL)
    if b"CC0 1.0 Universal" not in license_data:
        raise RuntimeError("Source license did not identify CC0-1.0")
    (OUT / "LICENSE-CC0.txt").write_bytes(license_data)
    report = {"source": "Ariescar/gobkit-free-assets", "commit": "4e73c68fa6e8ca9d948fcc0ce7215c830a022c3b",
              "license": "CC0-1.0", "assets": {}}
    for asset_id, (relative, expected_sha) in ASSETS.items():
        data = download(BASE + relative)
        actual_sha = git_blob_sha(data)
        if actual_sha != expected_sha:
            raise RuntimeError(f"{asset_id}: Git blob SHA mismatch {actual_sha} != {expected_sha}")
        info = validate_glb(data, asset_id)
        destination = OUT / (asset_id + ".glb")
        destination.write_bytes(data)
        report["assets"][asset_id] = {"source_path": relative, "git_blob_sha": actual_sha,
                                      "bytes": len(data), **info}
        print(f"VALIDATED {asset_id}: {info['skins']} skin(s), {info['animations']} animation(s), {info['vertices']} vertices")
    report["extended_assets"] = fetch_extended_assets()
    report["extended_asset_count"] = len(report["extended_assets"])
    (OUT / "manifest.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"CHARACTER_ASSET_FETCH_PASS: {len(ASSETS)} pinned CC0 rigged GLBs")
if __name__ == "__main__":
    main()
