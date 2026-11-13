# Supplementary CC0 source discovery for the Wuxia imperial asset pipeline.
# Uses the documented 3DAssets.dev REST API response schema (data[] and data object).
import re
from urllib.parse import urlparse

ASSET3D_TERMS = {
    "architecture": ["imperial chinese palace", "chinese palace", "ceremonial hall", "gate tower", "moon gate", "palace wall", "covered walkway", "water pavilion", "arched stone bridge", "roof cassette", "roof ridge", "bracket set", "lattice screen", "pagoda", "chinese temple", "asian house", "chinese house", "japanese house", "wooden house", "market stall", "shop", "pagoda", "temple", "shrine", "arch bridge", "stone bridge", "watchtower", "stone wall", "pavilion"],
    "ornaments": ["guardian lion", "dragon roof finial", "garden lantern", "silk lantern", "bronze tripod cauldron", "stone incense burner", "bronze bell", "ceremonial drum", "dragon statue", "lion statue", "stone lantern", "chinese lantern", "fountain", "torch", "pillar"],
    "nature": ["bamboo clump", "plum tree blossom", "bonsai pine", "lotus cluster", "rockery outcrop", "peony planter", "willow tree", "pine tree", "bamboo", "cherry blossom", "rock", "bush", "grass"],
}

def _asset_rows(payload):
    if isinstance(payload, list):
        return [x for x in payload if isinstance(x, dict)]
    if not isinstance(payload, dict):
        return []
    data = payload.get("data", payload)
    if isinstance(data, list):
        return [x for x in data if isinstance(x, dict)]
    if isinstance(data, dict):
        for key in ("assets", "items", "results"):
            value = data.get(key)
            if isinstance(value, list):
                return [x for x in value if isinstance(x, dict)]
    return []

def discover_3dassets(getj, fetch, safe, sha, RAW, DISC, DOWN, ERR):
    seen = set()
    accepted_by_category = {"architecture": 0, "ornaments": 0, "nature": 0}
    for category, terms in ASSET3D_TERMS.items():
        for term in terms:
            if accepted_by_category[category] >= 40:
                break
            try:
                payload = getj("https://3dassets.dev/api/v1/assets", {"q": term, "limit": 30, "sort": "relevance"})
                rows = _asset_rows(payload)
                if not rows:
                    ERR.append({"asset":"3DAssets.dev:"+term,"stage":"search","reason":"Documented data[] search response contained no assets"})
                    continue
                for item in rows:
                    slug = item.get("slug")
                    if not slug or slug in seen:
                        continue
                    seen.add(slug)
                    try:
                        detail_payload = getj("https://3dassets.dev/api/v1/assets/" + str(slug))
                        detail = detail_payload.get("data", detail_payload) if isinstance(detail_payload, dict) else {}
                        license_info = detail.get("license") or {}
                        license_slug = str(license_info.get("slug", "") if isinstance(license_info, dict) else license_info).lower()
                        if license_slug not in ("cc0-1.0", "cc0", "cc0-1.0-universal"):
                            raise ValueError("License slug is not an explicitly accepted CC0 identifier: " + license_slug)
                        if detail.get("status") != "published":
                            raise ValueError("Asset status is not published: " + str(detail.get("status")))
                        cdn = detail.get("cdnUrl")
                        parsed = urlparse(cdn or "")
                        if parsed.scheme != "https" or parsed.netloc != "cdn.3dassets.dev" or not parsed.path.lower().endswith(".glb"):
                            raise ValueError("Expected canonical https://cdn.3dassets.dev direct GLB cdnUrl")
                        contributor = detail.get("contributor") or {}
                        creator = contributor.get("name") or contributor.get("username") or "Contributor not named in API" if isinstance(contributor, dict) else str(contributor)
                        title = detail.get("title") or str(slug)
                        rec = {"id":"3dassets-"+safe(slug),"name":title,"source":"3DAssets.dev","source_url":detail.get("url") or "https://3dassets.dev/assets/"+str(slug),"license":license_info.get("name","CC0 1.0 Universal") if isinstance(license_info,dict) else "CC0 1.0 Universal","authors":{"creator":str(creator)},"matches":[(category,term)],"download_url":cdn,"api_metadata":{"status":detail.get("status"),"license_slug":license_slug,"size_m":(detail.get("stats") or {}).get("sizeMeters")}}
                        DISC.append(rec)
                        path=fetch(cdn,RAW/"3dassets"/(safe(slug)+".glb"))
                        DOWN.append({**rec,"raw":str(path),"download_sha256":sha(path)})
                        accepted_by_category[category]+=1
                        if accepted_by_category[category]>=40: break
                    except Exception as exc:
                        ERR.append({"asset":"3DAssets.dev:"+str(slug),"stage":"detail/download","reason":str(exc)})
            except Exception as exc:
                ERR.append({"asset":"3DAssets.dev:"+term,"stage":"search","reason":str(exc)})
