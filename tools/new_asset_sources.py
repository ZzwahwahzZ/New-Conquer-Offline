"""Additional official CC0 / CC BY asset sources for the imperial city pipeline.

Sources:
- Smithsonian 3D API: official Open Access GLB search endpoint (CC0 only).
- Kenney Nature Kit: official CC0 archive, pinned by SHA-256.
- Sketchfab Data/Download APIs: CC0 and CC BY only; downloads require OAuth.
"""
import os
import re
from pathlib import Path
from urllib.parse import quote


def _known(DISC, asset_id, source_url):
    for item in DISC:
        old_id = str(item.get("id") or item.get("asset_id") or "")
        if old_id == asset_id:
            return True
        if source_url and source_url in {
            str(item.get("source_url") or ""),
            str(item.get("direct_download_url") or ""),
        }:
            return True
    return False


def discover_smithsonian(getj, fetch, safe, sha, RAW, DISC, DOWN, ERR, SKIPPED):
    """Search real Smithsonian 3D Open Access GLBs for Chinese cultural props."""
    endpoint = "https://3d-api.si.edu/api/v1.0/content/file/search"
    queries = ("Chinese Art", "China", "dragon", "incense burner", "Buddha", "bronze")
    relevant = re.compile(
        r"\b(?:vase|bottle|bowl|dish|cup|incense|burner|bronze|dragon|buddha|"
        r"statue|sculpture|bell|ritual|animal|horse|deer|crane|elephant|"
        r"turtle|mask|urn|lantern|pot|jar|scepter|figure|relief)\b", re.I
    )
    seen = set()
    accepted = 0
    for term in queries:
        try:
            payload = getj(endpoint, {
                "q": term, "file_type": "glb", "model_type": "glb",
                "gltf_orientation_compliant": "true", "rows": 100, "start": 0,
            })
            rows = payload.get("rows", []) if isinstance(payload, dict) else []
            for row in rows:
                title = str(row.get("title") or "").strip()
                url_key = str(row.get("url") or "")
                uid = url_key.split(":")[-1] if ":" in url_key else url_key
                item_id = "smithsonian-" + safe(uid or title)
                content = row.get("content") or {}
                uri = content.get("uri")
                if not title or not uri or item_id in seen:
                    continue
                if not relevant.search(title):
                    continue
                # The Smithsonian 3D API documents that returned file records
                # belong to its Open Access initiative. Fail closed if an
                # explicit item-level usage field contradicts CC0.
                usage = str(content.get("media_usage_access") or row.get("media_usage_access") or "").strip().upper()
                if usage and usage != "CC0":
                    SKIPPED.append({"asset": item_id, "stage": "license",
                                    "reason": "Smithsonian item is not explicitly CC0: " + usage})
                    continue
                source_url = "https://3d.si.edu/explore?q=" + quote(title)
                if _known(DISC, item_id, source_url):
                    seen.add(item_id)
                    continue
                seen.add(item_id)
                rec = {
                    "id": item_id, "name": title, "source": "Smithsonian Open Access",
                    "source_url": source_url, "download_url": uri,
                    "license": "CC0 1.0", "authors": {"publisher": "Smithsonian Institution"},
                    "api_metadata": {"tags": "Chinese Art China National Museum of Asian Art " + term},
                    "target_category": "statues_and_props",
                    "matches": [("statues_and_props", "Chinese cultural artifacts")],
                }
                DISC.append(rec)
                try:
                    raw = fetch(uri, RAW / "smithsonian" / (safe(item_id) + ".glb"))
                    DOWN.append({**rec, "raw": str(raw), "download_sha256": sha(raw)})
                    accepted += 1
                except Exception as exc:
                    ERR.append({"asset": item_id, "stage": "download", "reason": str(exc)})
                if accepted >= 40:
                    break
        except Exception as exc:
            ERR.append({"asset": "Smithsonian:" + term, "stage": "search", "reason": str(exc)})
        if accepted >= 40:
            break
    print("SMITHSONIAN_SOURCE_COUNTS", {"downloaded": accepted, "unique_seen": len(seen)})


def discover_kenney_nature(fetch, safe, sha, RAW, DISC, DOWN, ERR, SKIPPED):
    """Fetch the official Kenney Nature Kit only when its pinned archive is new."""
    pack_id = "kenney-nature-kit"
    page = "https://kenney.nl/assets/nature-kit"
    archive = "https://kenney.nl/media/pages/assets/nature-kit/37ac38a37b-1677698939/kenney_nature-kit.zip"
    expected_sha = "fa7974a0d342bfe63c38664ba9f8ec1a4aab8ea25f099bdc56870e33588c4d9d"
    if _known(DISC, pack_id, page):
        SKIPPED.append({"asset": pack_id, "stage": "dedup",
                        "reason": "Official source page already exists in the approved manifest"})
        return
    rec = {
        "id": pack_id, "name": "Kenney Nature Kit", "source": "Kenney",
        "source_url": page, "download_url": archive,
        "license": "CC0 1.0 Universal", "authors": {"creator": "Kenney"},
        "target_category": "nature", "candidate_only": True,
        "matches": [("nature", "trees rocks foliage")],
        "pack": "kenney-nature-kit",
    }
    try:
        raw = fetch(archive, RAW / "kenney" / "kenney_nature-kit.zip")
        actual = sha(raw)
        if actual != expected_sha:
            raw.unlink(missing_ok=True)
            raise ValueError("Official archive SHA256 changed; refusing unpinned archive: " + actual)
        DISC.append(rec)
        DOWN.append({**rec, "raw": str(raw), "download_sha256": actual})
    except Exception as exc:
        ERR.append({"asset": pack_id, "stage": "download/integrity", "reason": str(exc)})


def discover_sketchfab(session, getj, fetch, safe, sha, RAW, DISC, DOWN, ERR, SKIPPED):
    """Use official Sketchfab APIs; download only with a user-authorized OAuth token."""
    token = os.getenv("SKETCHFAB_TOKEN", "").strip()
    endpoint = "https://api.sketchfab.com/v3/search"
    queries = (
        ("Chinese pagoda", "palaces_and_temples"),
        ("Chinese temple", "palaces_and_temples"),
        ("Chinese gate", "gates_walls_bridges"),
        ("Asian market house", "houses_and_shops"),
        ("Chinese lantern", "statues_and_props"),
        ("Chinese dragon ornament", "statues_and_props"),
        ("bamboo tree", "nature"),
        ("Asian pine tree", "nature"),
        ("Chinese stone bridge", "gates_walls_bridges"),
    )
    seen = set()
    found = 0
    downloaded = 0
    for term, category in queries:
        for license_filter in ("by", "cc0"):
            try:
                payload = getj(endpoint, {
                    "type": "models", "q": term, "downloadable": "true",
                    "license": license_filter, "count": 30,
                })
                results = payload.get("results", []) if isinstance(payload, dict) else []
                for model in results:
                    uid = str(model.get("uid") or "")
                    if not uid or uid in seen:
                        continue
                    lic = model.get("license") or {}
                    slug = str(lic.get("slug") if isinstance(lic, dict) else lic).lower()
                    if slug not in {"cc0", "cc0-1.0", "by", "cc-by", "cc-by-4.0",
                                    "cc-by-3.0", "cc-by-2.5", "cc-by-2.0", "cc-by-1.0"}:
                        continue
                    seen.add(uid)
                    found += 1
                    name = str(model.get("name") or uid)
                    user = model.get("user") or {}
                    creator = str(user.get("displayName") or user.get("username") or "Unknown Sketchfab creator")
                    viewer = str(model.get("viewerUrl") or ("https://sketchfab.com/3d-models/" + uid))
                    item_id = "sketchfab-" + safe(uid)
                    if _known(DISC, item_id, viewer):
                        continue
                    if not token:
                        continue
                    license_name = "CC0 1.0" if slug.startswith("cc0") else (
                        "CC BY (Sketchfab license slug: " + slug + ")"
                    )
                    headers = {"Authorization": "Bearer " + token}
                    response = session.get(
                        "https://api.sketchfab.com/v3/models/" + uid + "/download",
                        headers=headers, timeout=(20, 60),
                    )
                    response.raise_for_status()
                    download_data = response.json()
                    gltf = download_data.get("gltf") or {}
                    archive_url = gltf.get("url")
                    if not archive_url:
                        raise ValueError("Sketchfab Download API returned no glTF archive")
                    rec = {
                        "id": item_id, "name": name, "source": "Sketchfab",
                        "source_url": viewer, "download_url": None,
                        "license": license_name, "authors": {"creator": creator},
                        "target_category": category, "matches": [(category, term)],
                        "api_metadata": {"license_slug": slug, "creator": creator},
                    }
                    raw = fetch(archive_url, RAW / "sketchfab" / (safe(item_id) + ".zip"))
                    DISC.append(rec)
                    DOWN.append({**rec, "raw": str(raw), "download_sha256": sha(raw)})
                    downloaded += 1
                    if downloaded >= 40:
                        break
                if downloaded >= 40:
                    break
            except Exception as exc:
                ERR.append({"asset": "Sketchfab:" + term + ":" + license_filter,
                            "stage": "search/download", "reason": str(exc)})
        if downloaded >= 40:
            break
    if found and not token:
        SKIPPED.append({
            "asset": "Sketchfab", "stage": "authorization_required",
            "reason": str(found) + " downloadable CC0/CC BY candidates found; official Download API requires SKETCHFAB_TOKEN OAuth authorization",
        })
    print("SKETCHFAB_SOURCE_COUNTS", {"candidates": found, "downloaded": downloaded,
                                      "oauth_token_present": bool(token)})


def discover_polygonal_mind(getj, fetch, safe, sha, RAW, DISC, DOWN, ERR, SKIPPED):
    """Pull selected CC0 GLBs from Polygonal Mind's public asset registry."""
    root = "https://raw.githubusercontent.com/ToxSam/open-source-3d-assets/main/data"
    projects = getj(root + "/projects.json")
    project_map = {x.get("id"): x for x in projects if isinstance(x, dict)}
    selections = (
        ("pm-lunar-year", "lunar-year",
         "https://github.com/ToxSam/cc0-models-Polygonal-Mind/tree/main/projects/lunar-year"),
        ("pm-momuspark", "MomusPark",
         "https://github.com/ToxSam/cc0-models-Polygonal-Mind/tree/main/projects/MomusPark"),
    )
    downloaded = 0
    for project_id, folder, project_page in selections:
        project = project_map.get(project_id) or {}
        if not project.get("is_public") or str(project.get("license", "")).upper() != "CC0":
            SKIPPED.append({"asset": project_id, "stage": "license",
                            "reason": "Registry does not explicitly mark this public collection CC0"})
            continue
        try:
            assets = getj(root + "/assets/" + project_id + ".json")
            for item in assets:
                if not item.get("is_public") or item.get("is_draft") or str(item.get("format", "")).upper() != "GLB":
                    continue
                name = str(item.get("name") or item.get("id") or "")
                meta = item.get("metadata") or {}
                attrs = {str(a.get("trait_type", "")).lower(): str(a.get("value", ""))
                         for a in meta.get("attributes", []) if isinstance(a, dict)}
                if project_id == "pm-lunar-year":
                    source_category = attrs.get("category", "").lower()
                    if source_category not in {"architecture", "decoration", "cultural",
                                               "cultural symbol", "lighting", "furniture", "nature"}:
                        continue
                    target = ("gates_walls_bridges" if source_category == "architecture"
                              else "nature" if source_category == "nature"
                              else "statues_and_props")
                    style = attrs.get("style", "Asian Traditional")
                else:
                    source_category = attrs.get("category", "").lower()
                    source_type = attrs.get("type", "").lower()
                    if source_category not in {"nature", "terrain", "water feature"}:
                        continue
                    if "floating island" in source_type:
                        continue
                    target = "nature"
                    style = attrs.get("style", "Naturalistic")
                model_url = str(item.get("model_file_url") or "")
                if not model_url.startswith("https://raw.githubusercontent.com/ToxSam/cc0-models-Polygonal-Mind/") or not model_url.lower().endswith(".glb"):
                    SKIPPED.append({"asset": str(item.get("id")), "stage": "source_url",
                                    "reason": "Model URL is not an approved direct GLB URL in the public source repository"})
                    continue
                item_id = "polygonalmind-" + safe(str(item.get("id") or name))
                source_url = "https://github.com/ToxSam/cc0-models-Polygonal-Mind/blob/main/" + str(meta.get("github_path") or ("projects/" + folder + "/" + Path(model_url).name))
                if _known(DISC, item_id, source_url):
                    continue
                rec = {
                    "id": item_id, "name": name.replace("_", " "),
                    "source": "Polygonal Mind Lunar Year" if project_id == "pm-lunar-year" else "Polygonal Mind Nature",
                    "source_url": source_url, "download_url": model_url,
                    "license": "CC0 1.0 Universal",
                    "authors": {"creator": str(project.get("creator_id") or "Polygonal Mind")},
                    "target_category": target,
                    "api_metadata": {"tags": "Asian Traditional " + folder + " " + source_category + " " + style},
                    "matches": [(target, folder + " " + name)],
                }
                try:
                    raw = fetch(model_url, RAW / "polygonalmind" / project_id / (safe(item_id) + ".glb"))
                    DISC.append(rec)
                    DOWN.append({**rec, "raw": str(raw), "download_sha256": sha(raw)})
                    downloaded += 1
                except Exception as exc:
                    ERR.append({"asset": item_id, "stage": "download", "reason": str(exc)})
                if downloaded >= 100:
                    break
        except Exception as exc:
            ERR.append({"asset": project_id, "stage": "registry", "reason": str(exc)})
        if downloaded >= 100:
            break
    print("POLYGONAL_MIND_SOURCE_COUNTS", {"downloaded": downloaded})


def discover_innerscene_curated(fetch, safe, sha, RAW, DISC, DOWN, ERR, SKIPPED):
    """Fetch two individually verified, relevant CC0 GLBs through Innerscene's official download links."""
    assets = (
        {
            "id": "innerscene-buddhist-temple-pagoda-c5ebacdc",
            "name": "Buddhist Temple Pagoda",
            "page": "https://www.innerscene.com/tools/library/3d-parts/buddhist-temple-pagoda-c5ebacdc",
            "download": "https://www.innerscene.com/api/library/buddhist-temple-pagoda-c5ebacdc/download",
            "category": "palaces_and_temples",
            "tags": "East Asian Buddhist temple five storey timber pagoda imperial architecture",
            "creator": "Innerscene",
        },
        {
            "id": "innerscene-japanese-maple-tree-565c1604",
            "name": "Japanese Maple Tree",
            "page": "https://www.innerscene.com/tools/library/3d-parts/japanese-maple-tree-565c1604",
            "download": "https://www.innerscene.com/api/library/japanese-maple-tree-565c1604/download",
            "category": "nature",
            "tags": "Japanese maple tree East Asian landscape nature",
            "creator": "Innerscene",
        },
    )
    count = 0
    for item in assets:
        if _known(DISC, item["id"], item["page"]):
            SKIPPED.append({"asset": item["id"], "stage": "dedup",
                            "reason": "Exact source page already exists in the approved manifest"})
            continue
        rec = {
            "id": item["id"], "name": item["name"], "source": "Innerscene",
            "source_url": item["page"], "download_url": item["download"],
            "license": "CC0 1.0", "authors": {"creator": item["creator"]},
            "target_category": item["category"], "api_metadata": {"tags": item["tags"]},
            "matches": [(item["category"], item["tags"])],
        }
        try:
            raw = fetch(item["download"], RAW / "innerscene" / (safe(item["id"]) + ".glb"))
            DISC.append(rec)
            DOWN.append({**rec, "raw": str(raw), "download_sha256": sha(raw)})
            count += 1
        except Exception as exc:
            ERR.append({"asset": item["id"], "stage": "download", "reason": str(exc)})
    print("INNERSCENE_SOURCE_COUNTS", {"downloaded": count})
