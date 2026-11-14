"""Additional verified open-license asset sources for the imperial city pipeline.

Sources:
- Smithsonian 3D API: official Open Access GLB search endpoint (CC0 only).
- Kenney Nature Kit: official CC0 archive, pinned by SHA-256.
- Sketchfab Data/Download APIs: CC0, CC BY and CC BY-SA; downloads require OAuth.
- GitHub public repositories: model files are accepted only when the repository declares an allow-listed SPDX license.
- Poly Pizza: published v1.1 API only; requires an API key and an explicit enable flag; CDN GLBs are magic-byte checked.
"""
import os
import re
from pathlib import Path
from urllib.parse import quote, urlparse


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
        ("Japanese cherry tree low poly", "nature"),
        ("Cherry blossom trees", "nature"),
        ("Chinese plum blossom tree", "nature"),
        ("Chinese market stall", "houses_and_shops"),
        ("Imperial Chinese palace", "palaces_and_temples"),
    )
    seen = set()
    found = 0
    downloaded = 0
    for term, category in queries:
        for license_filter in ("by-sa", "by", "cc0"):
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
                                    "cc-by-3.0", "cc-by-2.5", "cc-by-2.0", "cc-by-1.0",
                                    "by-sa", "cc-by-sa", "cc-by-sa-4.0", "cc-by-sa-3.0"}:
                        continue
                    sa_version = None
                    if "sa" in slug:
                        license_details = " ".join(str(lic.get(k) or "") for k in ("url", "uri", "fullName", "label")) if isinstance(lic, dict) else ""
                        sa_version = next((v for v in ("4.0", "3.0") if v in license_details), None)
                        if not sa_version:
                            SKIPPED.append({"asset":"Sketchfab:"+uid,"stage":"license_version",
                                            "reason":"CC-BY-SA license slug found but exact 3.0/4.0 version is not exposed; fail-closed"})
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
                    license_name = ("CC0 1.0 Universal" if slug.startswith("cc0") else
                        "CC BY-SA " + sa_version if "sa" in slug else "CC BY 4.0")
                    license_url = ("https://creativecommons.org/publicdomain/zero/1.0/" if slug.startswith("cc0") else
                        "https://creativecommons.org/licenses/by-sa/" + sa_version + "/" if "sa" in slug else
                        "https://creativecommons.org/licenses/by/4.0/")
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
                        "license": license_name, "license_url": license_url, "authors": {"creator": creator},
                        "target_category": category, "matches": [(category, term)],
                        "api_metadata": {"license_slug": slug, "creator": creator},
                        "candidate_only": True,
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
            "reason": str(found) + " downloadable CC0/CC BY/CC BY-SA candidates found; official Download API requires SKETCHFAB_TOKEN OAuth authorization",
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
    """Fetch individually verified, relevant CC0 GLBs through Innerscene's official download links."""
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
        {
            "id": "innerscene-flowering-cherry-tree-6d80049e",
            "name": "Flowering Cherry Tree",
            "page": "https://www.innerscene.com/tools/library/3d-parts/flowering-cherry-tree-6d80049e",
            "download": "https://www.innerscene.com/api/library/flowering-cherry-tree-6d80049e/download",
            "category": "nature",
            "tags": "flowering cherry tree sakura cherry blossom East Asian garden",
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


def discover_github_open_assets(session, fetch, safe, sha, RAW, DISC, DOWN, ERR, SKIPPED):
    """Discover relevant model files in public GitHub repos with an explicit SPDX license."""
    token = os.getenv("GITHUB_TOKEN", "").strip()
    headers = {"Accept": "application/vnd.github+json",
               "X-GitHub-Api-Version": "2022-11-28",
               "User-Agent": "NewConquerOffline-OpenAssetAudit/1.0"}
    if token:
        headers["Authorization"] = "Bearer " + token
    allowed_spdx = {
        "CC0-1.0", "CC-BY-4.0", "CC-BY-3.0", "CC-BY-SA-4.0", "CC-BY-SA-3.0",
        "MIT", "BSD-2-Clause", "BSD-3-Clause", "Zlib", "WTFPL", "Unlicense",
        "GPL-2.0", "GPL-3.0", "GPL-2.0-only", "GPL-2.0-or-later", "GPL-3.0-only", "GPL-3.0-or-later", "Public Domain",
    }
    queries = (
        "pagoda 3d assets",
        "chinese temple 3d model",
        "asian architecture 3d models",
        "cherry blossom tree glb",
        "sakura tree 3d model",
        "chinese bridge 3d model",
        "market stall 3d game assets",
    )
    model_exts = {".glb", ".fbx", ".obj", ".blend", ".dae", ".stl", ".ply", ".zip", ".7z"}
    relevant = re.compile(
        r"(pagoda|temple|palace|imperial|chinese|asian|east.?asian|gate|wall|bridge|"
        r"watchtower|pavilion|market.?stall|shopfront|teahouse|cherry|sakura|blossom|"
        r"plum.?tree|bamboo|willow|pine.?tree|lotus|lantern|dragon|guardian.?lion)",
        re.I,
    )
    seen_repos = set()
    downloaded = 0
    inspected = 0
    for query in queries:
        if downloaded >= 30:
            break
        try:
            response = session.get(
                "https://api.github.com/search/repositories",
                params={"q": query + " in:name,description,readme", "sort": "updated",
                        "per_page": 15},
                headers=headers, timeout=(20, 60),
            )
            response.raise_for_status()
            repositories = response.json().get("items", [])
        except Exception as exc:
            ERR.append({"asset":"GitHub:"+query,"stage":"repository_search","reason":str(exc)})
            continue
        for repository in repositories:
            if downloaded >= 30:
                break
            full_name = str(repository.get("full_name") or "")
            if not full_name or full_name in seen_repos:
                continue
            seen_repos.add(full_name)
            license_info = repository.get("license") or {}
            spdx = str(license_info.get("spdx_id") or "").strip()
            if spdx in ("", "NOASSERTION") and "public domain" in str(license_info.get("name") or "").lower():
                spdx = "Public Domain"
            if spdx not in allowed_spdx:
                SKIPPED.append({"asset":"GitHub:"+full_name,"stage":"license",
                                "reason":"Repository license is missing or outside the explicit allow-list: "+(spdx or "NOASSERTION")})
                continue
            branch = str(repository.get("default_branch") or "main")
            try:
                tree_response = session.get(
                    "https://api.github.com/repos/" + full_name + "/git/trees/" + quote(branch, safe="") + "?recursive=1",
                    headers=headers, timeout=(20, 90),
                )
                tree_response.raise_for_status()
                tree = tree_response.json().get("tree", [])
                inspected += 1
            except Exception as exc:
                ERR.append({"asset":"GitHub:"+full_name,"stage":"tree","reason":str(exc)})
                continue
            owner = (repository.get("owner") or {}).get("login") or full_name.split("/")[0]
            for node in tree:
                if downloaded >= 30:
                    break
                if node.get("type") != "blob":
                    continue
                path = str(node.get("path") or "")
                ext = Path(path).suffix.lower()
                if ext not in model_exts or not relevant.search(path):
                    continue
                if any(x in path.lower() for x in ("/test/", "/tests/", "preview", "thumbnail", "sample_scene")):
                    continue
                size = int(node.get("size") or 0)
                if size and size > 200 * 1024 * 1024:
                    continue
                asset_id = "github-" + safe(full_name.replace("/", "-") + "-" + path)
                source_url = "https://github.com/" + full_name + "/blob/" + quote(branch, safe="") + "/" + quote(path, safe="/")
                if _known(DISC, asset_id, source_url):
                    continue
                stem = Path(path).stem.replace("_", " ").replace("-", " ")
                lower = (path + " " + str(repository.get("description") or "")).lower()
                if re.search(r"(cherry|sakura|blossom|plum|bamboo|willow|pine|lotus|tree)", lower):
                    category = "nature"
                    target_category = "nature"
                elif re.search(r"(lantern|dragon|lion|statue|bell|ornament)", lower):
                    category = "ornaments"
                    target_category = "statues_and_props"
                elif re.search(r"(bridge|gate|wall|watchtower|tower)", lower):
                    category = "architecture"
                    target_category = "gates_walls_bridges"
                elif re.search(r"(temple|pagoda|palace|shrine)", lower):
                    category = "architecture"
                    target_category = "palaces_and_temples"
                elif re.search(r"(market.?stall|shop|teahouse|tea.?house|house)", lower):
                    category = "architecture"
                    target_category = "houses_and_shops"
                else:
                    category = "architecture"
                    target_category = None
                if spdx.startswith("CC0"):
                    license_name, license_url = "CC0 1.0 Universal", "https://creativecommons.org/publicdomain/zero/1.0/"
                elif spdx.startswith("CC-BY-SA"):
                    version = spdx.rsplit("-", 1)[-1]
                    license_name, license_url = "CC BY-SA " + version, "https://creativecommons.org/licenses/by-sa/" + version + "/"
                elif spdx.startswith("CC-BY"):
                    version = spdx.rsplit("-", 1)[-1]
                    license_name, license_url = "CC BY " + version, "https://creativecommons.org/licenses/by/" + version + "/"
                else:
                    license_name, license_url = spdx, str(license_info.get("url") or "")
                raw_url = "https://raw.githubusercontent.com/" + full_name + "/" + quote(branch, safe="") + "/" + quote(path, safe="/")
                record = {
                    "id": asset_id, "name": stem, "source": "GitHub Open Assets",
                    "source_url": source_url, "download_url": raw_url,
                    "license": license_name, "license_url": license_url,
                    "authors": {"repository_publisher": owner},
                    "target_category": target_category,
                    "matches": [(category, query)],
                    "pack": full_name,
                    "api_metadata": {"spdx_id": spdx, "repository": full_name,
                                     "repository_owner": owner, "file_path": path,
                                     "repository_license_url": license_info.get("url"),"license_basis":"repository-level SPDX declaration; held as candidate pending per-file license/exception review"},
                    "candidate_only": True,
                }
                try:
                    raw = fetch(raw_url, RAW / "github" / safe(full_name.replace("/", "-")) / (safe(path.replace("/", "__"))))
                    DISC.append(record)
                    DOWN.append({**record, "raw": str(raw), "download_sha256": sha(raw)})
                    downloaded += 1
                except Exception as exc:
                    ERR.append({"asset":"GitHub:"+full_name+":"+path,"stage":"download","reason":str(exc)})
    print("GITHUB_OPEN_ASSET_COUNTS", {"repositories_seen":len(seen_repos),
                                       "repositories_with_trees":inspected,
                                       "downloaded":downloaded, "oauth_token_present":bool(token)})


def discover_poly_pizza(session, fetch, safe, sha, RAW, DISC, DOWN, ERR, SKIPPED):
    """Use Poly Pizza's published v1.1 API only; never scrape its website."""
    token = os.getenv("POLY_PIZZA_KEY", "").strip()
    enabled = os.getenv("POLY_PIZZA_ENABLE", "").strip().lower() == "true"
    if not token or not enabled:
        reason = "Set POLY_PIZZA_KEY and POLY_PIZZA_ENABLE=true after reviewing the official API terms/pricing; no website scraping is performed"
        SKIPPED.append({"asset":"Poly Pizza","stage":"api_auth_or_cost_gate","reason":reason})
        print("POLY_PIZZA_SOURCE_COUNTS", {"downloaded":0,"api_key_present":bool(token),"enabled":enabled})
        return

    headers = {"x-auth-token": token, "User-Agent":"NewConquerOffline-AssetFetcher/1.0"}
    queries = (
        ("pagoda", "palaces_and_temples"),
        ("chinese temple", "palaces_and_temples"),
        ("temple", "palaces_and_temples"),
        ("imperial palace", "palaces_and_temples"),
        ("pavilion", "palaces_and_temples"),
        ("gate tower", "gates_walls_bridges"),
        ("watchtower", "gates_walls_bridges"),
        ("stone bridge", "gates_walls_bridges"),
        ("arched bridge", "gates_walls_bridges"),
        ("market stall", "houses_and_shops"),
        ("chinese house", "houses_and_shops"),
        ("asian shop", "houses_and_shops"),
        ("cherry blossom", "nature"),
        ("sakura tree", "nature"),
        ("bamboo", "nature"),
        ("willow tree", "nature"),
        ("chinese lantern", "statues_and_props"),
    )
    seen = {str(x.get("api_metadata", {}).get("poly_pizza_id")) for x in DISC
            if isinstance(x.get("api_metadata"), dict)}
    downloaded = 0
    details_checked = 0
    for term, category in queries:
        if downloaded >= 30:
            break
        try:
            search_url = "https://api.poly.pizza/v1.1/search/" + quote(term, safe="")
            response = session.get(search_url, headers=headers, params={"Limit":32}, timeout=(15, 45))
            response.raise_for_status()
            search_data = response.json()
            models = search_data.get("results", []) if isinstance(search_data, dict) else []
        except Exception as exc:
            ERR.append({"asset":"Poly Pizza:"+term,"stage":"api_search","reason":str(exc)})
            continue

        for model in models:
            if downloaded >= 30 or not isinstance(model, dict):
                break
            uid = str(model.get("ID") or "").strip()
            if not uid or uid in seen:
                continue
            seen.add(uid)
            try:
                detail_url = "https://api.poly.pizza/v1.1/model/" + quote(uid, safe="")
                detail_response = session.get(detail_url, headers=headers, timeout=(15, 45))
                detail_response.raise_for_status()
                detail = detail_response.json()
                details_checked += 1
                if not isinstance(detail, dict):
                    raise ValueError("Model detail endpoint returned a non-object response")
            except Exception as exc:
                ERR.append({"asset":"Poly Pizza:"+uid,"stage":"api_model_detail","reason":str(exc)})
                continue

            licence = str(detail.get("Licence") or model.get("Licence") or "").strip()
            lower_licence = licence.lower()
            if any(x in lower_licence for x in ("by-nc","by-nd","noncommercial","non-commercial","no derivatives")):
                SKIPPED.append({"asset":"Poly Pizza:"+uid,"stage":"license",
                                "reason":"Non-commercial or no-derivatives license excluded: "+licence})
                continue
            if "cc0" in lower_licence or "public domain" in lower_licence:
                license_name, license_url = "CC0 1.0 Universal", "https://creativecommons.org/publicdomain/zero/1.0/"
            elif "cc-by" in lower_licence or "cc by" in lower_licence or "creative commons attribution" in lower_licence:
                version_match = re.search(r"(3\.0|4\.0)", lower_licence)
                if version_match:
                    version = version_match.group(1)
                    license_name, license_url = "CC BY " + version, "https://creativecommons.org/licenses/by/" + version + "/"
                else:
                    license_name = "CC BY (Poly Pizza API declaration)"
                    license_url = "https://poly.pizza/m/" + uid
            else:
                SKIPPED.append({"asset":"Poly Pizza:"+uid,"stage":"license",
                                "reason":"Per-model license is not explicitly CC0 or CC-BY: "+licence})
                continue

            download_url = str(detail.get("Download") or "")
            if urlparse(download_url).scheme != "https":
                ERR.append({"asset":"Poly Pizza:"+uid,"stage":"download_url",
                            "reason":"Official model-detail API returned no HTTPS GLB download URL"})
                continue
            creator_data = detail.get("Creator") or model.get("Creator") or {}
            if isinstance(creator_data, dict):
                creator = str(creator_data.get("Username") or "").strip()
                creator_url = str(creator_data.get("PURL") or creator_data.get("ProfileURL") or "")
            else:
                creator = str(creator_data or "").strip()
                creator_url = ""
            attribution = str(detail.get("Attribution") or model.get("Attribution") or "").strip()
            if not creator and attribution:
                creator = attribution
            if not creator:
                SKIPPED.append({"asset":"Poly Pizza:"+uid,"stage":"attribution",
                                "reason":"Creator attribution was not exposed by the API; download skipped"})
                continue
            title = str(detail.get("Title") or model.get("Title") or ("Poly Pizza model " + uid))
            page = "https://poly.pizza/m/" + uid
            if not creator_url:
                creator_url = "https://poly.pizza/u/" + quote(creator, safe="")
            record = {
                "id":"poly-pizza-"+safe(uid), "name":title, "source":"Poly Pizza",
                "source_url":page, "download_url":download_url,
                "license":license_name, "license_url":license_url,
                "authors":{"creator":creator,"creator_profile":creator_url},
                "target_category":category, "matches":[(category,term)],
                "candidate_only":True,
                "api_metadata":{"poly_pizza_id":uid,"license_as_published":licence,
                                "attribution":attribution,"tags":detail.get("Tags") or model.get("Tags") or [],
                                "triangle_count":detail.get("Tri Count") or model.get("Tri Count"),
                                "animated":detail.get("Animated",model.get("Animated")),
                                "format":"GLB"},
            }
            try:
                raw = fetch(download_url, RAW/"poly_pizza"/(safe(uid)+".glb"))
                with raw.open("rb") as handle:
                    magic = handle.read(4)
                if magic != b"glTF":
                    raw.unlink(missing_ok=True)
                    raise ValueError("Poly Pizza CDN returned a non-GLB file or Cloudflare challenge")
                DISC.append(record)
                DOWN.append({**record,"raw":str(raw),"download_sha256":sha(raw)})
                downloaded += 1
            except Exception as exc:
                message = str(exc)
                if "403" in message or "Cloudflare" in message:
                    message += " (Poly Pizza CDN may block cloud/datacenter IPs; this is separate from API authentication)"
                ERR.append({"asset":"Poly Pizza:"+uid,"stage":"cdn_download","reason":message})
    print("POLY_PIZZA_SOURCE_COUNTS", {"downloaded":downloaded,"details_checked":details_checked,
                                       "unique_models_seen":len(seen)})
