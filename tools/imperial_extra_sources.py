# Supplementary CC0 and CC BY source discovery for the Wuxia imperial asset pipeline.
# Uses the documented 3DAssets.dev REST API: search data[] and asset detail data object.
from urllib.parse import urlparse

ASSET3D_TERMS = {
    "architecture": [
        "imperial chinese palace", "chinese palace", "chinese courtyard house",
        "traditional chinese house", "asian village house", "asian house",
        "japanese house", "japanese machiya", "hanok house", "wooden village house",
        "traditional wooden house", "timber house", "wooden shopfront",
        "traditional asian shop", "chinese shop", "asian market stall",
        "tea house", "teahouse", "village shop", "traditional inn",
        "asian village buildings", "pagoda", "chinese temple", "asian temple",
        "ceremonial hall", "gate tower", "moon gate", "palace wall",
        "covered walkway", "water pavilion", "arched stone bridge",
        "roof ridge", "lattice screen", "watchtower", "stone wall",
        "courtyard gate", "wooden pavilion", "stone bridge",
    ],
    "ornaments": [
        "guardian lion", "dragon roof finial", "garden lantern", "silk lantern",
        "bronze tripod cauldron", "stone incense burner", "bronze bell",
        "ceremonial drum", "dragon statue", "lion statue", "stone lantern",
        "chinese lantern", "garden fountain", "wooden sign", "market props",
        "traditional furniture", "tea table", "ceremonial parasol",
    ],
    "nature": [
        "bamboo clump", "plum tree blossom", "bonsai pine", "lotus cluster",
        "rockery outcrop", "peony planter", "willow tree", "pine tree",
        "bamboo", "cherry blossom", "rock", "bush", "fern", "reed clump",
        "tall grass", "shrub", "tree clump", "flowering tree",
    ],
}

def _asset_rows(payload):
    if not isinstance(payload, dict):
        return []
    data = payload.get("data")
    return [x for x in data if isinstance(x, dict)] if isinstance(data, list) else []

def _tag_text(value):
    if isinstance(value, list):
        return " ".join(
            str(x.get("title") or x.get("slug") or "") if isinstance(x, dict) else str(x)
            for x in value
        )
    if isinstance(value, dict):
        return " ".join(str(v) for v in value.values() if isinstance(v, (str, int, float)))
    return str(value or "")

def discover_3dassets(getj, fetch, safe, sha, RAW, DISC, DOWN, ERR):
    # Targeted search only: do not mirror the catalogue.
    caps = {"architecture": 70, "ornaments": 45, "nature": 55}
    counts = {key: 0 for key in ASSET3D_TERMS}
    seen = set()
    for category, terms in ASSET3D_TERMS.items():
        for term in terms:
            if counts[category] >= caps[category]:
                break
            try:
                payload = getj("https://3dassets.dev/api/v1/assets",
                               {"q": term, "limit": 30, "sort": "relevance"})
                rows = _asset_rows(payload)
                if not rows:
                    ERR.append({"asset":"3DAssets.dev:"+term,"stage":"search","reason":"No published search results"})
                    continue
                for item in rows:
                    slug = item.get("slug")
                    if not slug or slug in seen or "3dassets-"+safe(slug) in {x.get("id") for x in DISC}:
                        continue
                    seen.add(slug)
                    try:
                        detail_payload = getj("https://3dassets.dev/api/v1/assets/" + str(slug))
                        detail = detail_payload.get("data", {}) if isinstance(detail_payload, dict) else {}
                        if not isinstance(detail, dict):
                            raise ValueError("Asset detail response has no data object")
                        license_info = detail.get("license") or {}
                        license_slug = str(license_info.get("slug", "") if isinstance(license_info, dict) else license_info).lower()
                        if license_slug not in ("cc0-1.0", "cc0", "cc0-1.0-universal",
                                                 "cc-by-4.0", "cc-by-3.0", "cc-by-2.0",
                                                 "cc-by-2.5", "cc-by-1.0",
                                                 "cc-by-sa-4.0", "cc-by-sa-3.0",
                                                 "oga-by-4.0", "oga-by-3.0",
                                                 "mit", "bsd-2-clause", "bsd-3-clause",
                                                 "zlib", "wtfpl", "unlicense",
                                                 "gpl-2.0", "gpl-3.0"):
                            raise ValueError("Asset license is not in the expanded explicit allow-list: " + license_slug)
                        if detail.get("status") != "published":
                            raise ValueError("Asset is not published: " + str(detail.get("status")))
                        cdn = detail.get("cdnUrl")
                        parsed = urlparse(cdn or "")
                        if parsed.scheme != "https" or parsed.netloc != "cdn.3dassets.dev" or not parsed.path.lower().endswith(".glb"):
                            raise ValueError("Missing canonical direct GLB cdnUrl")
                        cat = detail.get("category") or {}
                        tags = detail.get("tags") or []
                        contributor = detail.get("contributor") or {}
                        creator = (contributor.get("name") or contributor.get("username") or "3DAssets.dev contributor") if isinstance(contributor, dict) else str(contributor)
                        title = detail.get("title") or str(slug)
                        metadata = {
                            "category_slug": cat.get("slug", "") if isinstance(cat, dict) else str(cat),
                            "category_title": cat.get("title", "") if isinstance(cat, dict) else "",
                            "tags": _tag_text(tags),
                            "summary": detail.get("summary", ""),
                            "description": detail.get("description", ""),
                            "status": detail.get("status"),
                            "license_slug": license_slug,
                            "stats": detail.get("stats") or {},
                        }
                        identity = " ".join([str(title), str(metadata["category_slug"]), str(metadata["category_title"]), str(metadata["tags"]), str(metadata["summary"]), str(metadata["description"])]).lower()
                        asian = any(term in identity for term in ("chinese", "asian", "japanese", "korean", "hanok", "wuxia", "imperial", "east asian"))
                        building = any(term in identity for term in ("house", "shop", "storefront", "market stall", "teahouse", "tea house", "inn", "pavilion", "building", "village"))
                        candidate_only = category == "architecture" and building and not asian
                        rec = {
                            "id":"3dassets-"+safe(slug), "name":title, "source":"3DAssets.dev",
                            "source_url":detail.get("url") or "https://3dassets.dev/assets/"+str(slug),
                            "license":license_info.get("name", license_slug.upper()) if isinstance(license_info,dict) else license_slug.upper(),
                            "authors":{"creator":str(creator)}, "matches":[(category,term)],
                            "download_url":cdn, "api_metadata":metadata, "candidate_only":candidate_only,
                            "pack":"3DAssets.dev "+str(metadata["category_title"]),
                        }
                        DISC.append(rec)
                        path=fetch(cdn,RAW/"3dassets"/(safe(slug)+".glb"))
                        DOWN.append({**rec,"raw":str(path),"download_sha256":sha(path)})
                        counts[category] += 1
                        if counts[category] >= caps[category]:
                            break
                    except Exception as exc:
                        ERR.append({"asset":"3DAssets.dev:"+str(slug),"stage":"detail/download","reason":str(exc)})
            except Exception as exc:
                ERR.append({"asset":"3DAssets.dev:"+term,"stage":"search","reason":str(exc)})
    print("3DASSETS_SOURCE_COUNTS", counts)


def discover_hanok_pack(getj, fetch, safe, sha, RAW, DISC, DOWN, ERR):
    """Import the complete, coherent CC0 Korean Hanok Village and Street pack."""
    pack_slug = "korean-hanok-village-and-street"
    try:
        payload = getj("https://3dassets.dev/api/v1/packs/" + pack_slug)
        data = payload.get("data", payload) if isinstance(payload, dict) else payload
        pack_info = data.get("pack", data) if isinstance(data, dict) else {}
        rows = []
        if isinstance(data, dict):
            for key in ("assets", "models", "items"):
                if isinstance(data.get(key), list):
                    rows = data[key]
                    break
        if not rows and isinstance(pack_info, dict):
            for key in ("assets", "models", "items"):
                if isinstance(pack_info.get(key), list):
                    rows = pack_info[key]
                    break
        if not rows:
            raise ValueError("Published pack manifest did not contain an assets/models array")
        existing = {x.get("id") for x in DISC}
        downloaded = 0
        for item in rows:
            if not isinstance(item, dict):
                continue
            slug = item.get("slug") or item.get("id")
            if not slug:
                continue
            asset_id = "3dassets-" + safe(slug)
            if asset_id in existing:
                continue
            detail = item
            cdn = item.get("cdnUrl") or item.get("cdn_url") or item.get("modelUrl")
            if not (isinstance(cdn, str) and cdn.startswith("https://cdn.3dassets.dev/") and cdn.lower().endswith(".glb")):
                detail_payload = getj("https://3dassets.dev/api/v1/assets/" + str(slug))
                detail = detail_payload.get("data", {}) if isinstance(detail_payload, dict) else {}
                cdn = detail.get("cdnUrl") or detail.get("cdn_url")
            if not (isinstance(cdn, str) and cdn.startswith("https://cdn.3dassets.dev/") and cdn.lower().endswith(".glb")):
                ERR.append({"asset":"3DAssets.dev:Hanok:"+str(slug),"stage":"manifest","reason":"No canonical direct GLB CDN URL in pack/detail API"})
                continue
            name = item.get("name") or item.get("title") or detail.get("name") or detail.get("title") or str(slug)
            description = item.get("description") or detail.get("description") or ""
            rec = {
                "id": asset_id, "name": name, "source": "3DAssets.dev",
                "source_url": "https://3dassets.dev/assets/" + str(slug),
                "license": "CC0 1.0 Universal",
                "authors": {"creator": "3DAssets.dev"},
                "matches": [("architecture", "Korean Hanok Village and Street")],
                "download_url": cdn,
                "api_metadata": {
                    "description": description,
                    "tags": "Korean Hanok traditional East Asian village architecture",
                    "pack_description": "Traditional Korean Hanok village with timber houses, tiled roofs, courtyard walls and market street",
                },
                "pack": pack_slug,
            }
            try:
                local_path = fetch(cdn, RAW/"3dassets"/"hanok-pack"/(safe(slug)+".glb"))
                DISC.append(rec)
                DOWN.append({**rec, "raw": str(local_path), "download_sha256": sha(local_path)})
                existing.add(asset_id)
                downloaded += 1
            except Exception as exc:
                ERR.append({"asset":"3DAssets.dev:Hanok:"+str(slug),"stage":"download","reason":str(exc)})
        print("HANOK_PACK_COUNTS", {"manifest":len(rows),"downloaded":downloaded})
    except Exception as exc:
        ERR.append({"asset":"3DAssets.dev:"+pack_slug,"stage":"pack_manifest","reason":str(exc)})


def discover_imperial_china_pack(getj, fetch, safe, sha, RAW, DISC, DOWN, ERR):
    """Import the complete 63-model CC0 Imperial China Palace and Garden pack."""
    pack_slug = "imperial-china-palace-and-garden"
    try:
        payload = getj("https://3dassets.dev/api/v1/packs/" + pack_slug)
        data = payload.get("data", payload) if isinstance(payload, dict) else payload
        pack_info = data.get("pack", data) if isinstance(data, dict) else {}
        rows = data if isinstance(data, list) else []
        if isinstance(data, dict):
            for key in ("assets", "models", "items"):
                if isinstance(data.get(key), list):
                    rows = data[key]
                    break
        if not rows and isinstance(pack_info, dict):
            for key in ("assets", "models", "items"):
                if isinstance(pack_info.get(key), list):
                    rows = pack_info[key]
                    break
        if not rows:
            raise ValueError("Published pack manifest did not contain an assets/models array")
        existing = {x.get("id") for x in DISC}
        downloaded = 0
        for item in rows:
            if not isinstance(item, dict):
                continue
            slug = item.get("slug") or item.get("id")
            if not slug:
                continue
            asset_id = "3dassets-" + safe(slug)
            if asset_id in existing:
                continue
            detail = item
            cdn = item.get("cdnUrl") or item.get("cdn_url") or item.get("modelUrl")
            if not (isinstance(cdn, str) and cdn.startswith("https://cdn.3dassets.dev/") and cdn.lower().endswith(".glb")):
                detail_payload = getj("https://3dassets.dev/api/v1/assets/" + str(slug))
                detail = detail_payload.get("data", {}) if isinstance(detail_payload, dict) else {}
                cdn = detail.get("cdnUrl") or detail.get("cdn_url")
            if not (isinstance(cdn, str) and cdn.startswith("https://cdn.3dassets.dev/") and cdn.lower().endswith(".glb")):
                ERR.append({"asset":"3DAssets.dev:ImperialChina:"+str(slug),"stage":"manifest","reason":"No canonical direct GLB CDN URL in pack/detail API"})
                continue
            name = item.get("name") or item.get("title") or detail.get("name") or detail.get("title") or str(slug)
            description = item.get("description") or detail.get("description") or ""
            rec = {
                "id": asset_id, "name": name, "source": "3DAssets.dev",
                "source_url": "https://3dassets.dev/assets/" + str(slug),
                "license": "CC0 1.0 Universal",
                "authors": {"creator": "3DAssets.dev"},
                "matches": [("architecture", "Imperial China Palace and Garden")],
                "download_url": cdn,
                "api_metadata": {
                    "description": description,
                    "tags": "Chinese imperial palace traditional East Asian wuxia architecture",
                    "pack_description": "Imperial Chinese palace court with ceremonial hall, gate tower, moon gates, covered walkways, arched bridge and garden",
                },
                "pack": pack_slug,
            }
            try:
                local_path = fetch(cdn, RAW/"3dassets"/"imperial-china-pack"/(safe(slug)+".glb"))
                DISC.append(rec)
                DOWN.append({**rec, "raw": str(local_path), "download_sha256": sha(local_path)})
                existing.add(asset_id)
                downloaded += 1
            except Exception as exc:
                ERR.append({"asset":"3DAssets.dev:ImperialChina:"+str(slug),"stage":"download","reason":str(exc)})
        print("IMPERIAL_CHINA_PACK_COUNTS", {"manifest":len(rows),"downloaded":downloaded})
    except Exception as exc:
        ERR.append({"asset":"3DAssets.dev:"+pack_slug,"stage":"pack_manifest","reason":str(exc)})
