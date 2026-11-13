# Supplementary CC0 source discovery for the Wuxia imperial asset pipeline.
# 3DAssets.dev public read API requires no API key. Published models are CC0 1.0.
import re
from urllib.parse import urlparse

ASSET3D_TERMS = {
    "architecture": ["pagoda", "chinese temple", "asian house", "chinese gate", "stone bridge", "watchtower", "stone wall", "pavilion"],
    "ornaments": ["dragon statue", "lion statue", "stone lantern", "chinese lantern", "fountain", "torch", "pillar"],
    "nature": ["willow tree", "pine tree", "bamboo", "cherry blossom", "rock", "bush", "grass"],
}

def _asset_rows(payload):
    if isinstance(payload, list):
        return [x for x in payload if isinstance(x, dict)]
    if isinstance(payload, dict):
        for key in ("assets", "items", "results", "data"):
            value = payload.get(key)
            if isinstance(value, list):
                return [x for x in value if isinstance(x, dict)]
            if isinstance(value, dict):
                return [dict(v, slug=k) if isinstance(v, dict) else {} for k, v in value.items()]
    return []

def discover_3dassets(getj, fetch, safe, sha, RAW, DISC, DOWN, ERR):
    seen = set()
    accepted_by_category = {"architecture": 0, "ornaments": 0, "nature": 0}
    for category, terms in ASSET3D_TERMS.items():
        for term in terms:
            if accepted_by_category[category] >= 20:
                break
            try:
                payload = getj("https://3dassets.dev/api/v1/assets", {"q": term, "limit": 30, "sort": "relevance"})
                for item in _asset_rows(payload):
                    slug = item.get("slug") or item.get("id") or item.get("assetSlug")
                    if not slug or slug in seen:
                        continue
                    seen.add(slug)
                    detail = getj("https://3dassets.dev/api/v1/assets/" + str(slug))
                    # API detail endpoint returns {"data": {...}}.
                    detail = detail.get("data", detail) if isinstance(detail, dict) else {}
                    license_info = detail.get("license", item.get("license", {}))
                    if isinstance(license_info, dict):
                        license_id = (license_info.get("spdx") or license_info.get("id") or license_info.get("slug") or license_info.get("name") or "").lower()
                    else:
                        license_id = str(license_info).lower()
                    if not any(x in license_id for x in ("cc0", "cc0-1.0", "creative commons zero")):
                        raise ValueError("Asset metadata does not explicitly declare CC0: " + str(license_info))
                    if detail.get("status") not in (None, "published"):
                        raise ValueError("Asset is not published: " + str(detail.get("status")))
                    cdn = detail.get("cdnUrl") or detail.get("downloadUrl") or item.get("cdnUrl") or item.get("downloadUrl")
                    if not cdn:
                        raise ValueError("Canonical asset record has no cdnUrl/downloadUrl")
                    parsed = urlparse(cdn)
                    if parsed.scheme != "https" or not parsed.netloc or not parsed.path.lower().endswith(".glb"):
                        raise ValueError("Expected direct HTTPS GLB URL; got " + str(cdn))
                    creator = detail.get("contributor") or item.get("contributor") or detail.get("creator") or detail.get("author") or item.get("creator") or "Not credited in API metadata"
                    if isinstance(creator, dict):
                        creator = creator.get("name") or creator.get("username") or creator.get("displayName") or "Not credited in API metadata"
                    title = detail.get("title") or detail.get("name") or item.get("title") or item.get("name") or str(slug)
                    rec = {"id":"3dassets-"+safe(slug),"name":title,"source":"3DAssets.dev","source_url":detail.get("url") or "https://3dassets.dev/assets/"+str(slug),"license":license_info.get("name", "CC0 1.0 Universal") if isinstance(license_info, dict) else "CC0 1.0 Universal","authors":{"creator":str(creator)},"matches":[(category,term)],"download_url":cdn,"api_metadata":{"status":detail.get("status"),"license_slug":license_id,"cdn_url":cdn,"size_m":(detail.get("stats") or {}).get("sizeMeters")}}
                    DISC.append(rec)
                    path = fetch(cdn, RAW/"3dassets"/(safe(slug)+".glb"))
                    DOWN.append({**rec,"raw":str(path),"download_sha256":sha(path)})
                    accepted_by_category[category] += 1
                    if accepted_by_category[category] >= 20:
                        break
            except Exception as exc:
                ERR.append({"asset":"3DAssets.dev:"+term,"stage":"discover/download","reason":str(exc)})
