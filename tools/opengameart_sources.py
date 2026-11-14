"""OpenGameArt and Quaternius adapters with explicit per-asset license verification.

Only assets whose live source pages expose an exact permitted license are downloaded.
Search is targeted to East Asian architecture, market props, bridges and vegetation.
"""
from html.parser import HTMLParser
from urllib.parse import urljoin, urlparse, urlencode
from pathlib import Path
import re

SOURCES = [
    {"slug":"big-stone-bridge","page":"https://opengameart.org/content/big-stone-bridge","creator":"KHORNE","category":"architecture","term":"stone bridge"},
    {"slug":"stone-bridge-2","page":"https://opengameart.org/content/stone-bridge-2","creator":"Paul Wortmann","category":"architecture","term":"stone bridge"},
    {"slug":"stone-bridge-0","page":"https://opengameart.org/content/stone-bridge-0","creator":"JamesWhite","category":"architecture","term":"stone bridge"},
    {"slug":"watchtower-wood","page":"https://opengameart.org/content/watchtower-wood","creator":"atze","category":"architecture","term":"wooden watchtower"},
    {"slug":"modular-temple-3d-models","page":"https://opengameart.org/content/modular-temple-3d-models","creator":"Keith at Fertile Soil Productions","category":"architecture","term":"temple"},
    {"slug":"shrine-shinto-japan","page":"https://opengameart.org/content/shrine-shinto-japan","creator":"Gladius.s","category":"architecture","term":"East Asian shrine temple"},
    {"slug":"kenney-building-kit","page":"https://opengameart.org/content/building-kit","creator":"Kenney","category":"architecture","term":"building kit walls doors roofs"},
    {"slug":"kenney-modular-buildings","page":"https://opengameart.org/content/modular-buildings","creator":"Kenney","category":"architecture","term":"modular buildings city houses"},
    {"slug":"dragon","page":"https://opengameart.org/content/dragon","creator":"Bitiquinho","category":"ornaments","term":"dragon model"},
    {"slug":"free-bamboo-v1","page":"https://opengameart.org/content/free-bamboo-v1","creator":"Yughues","category":"nature","term":"bamboo"},
    {"slug":"stylized-nature-megakit","page":"https://opengameart.org/content/stylized-nature-megakit","creator":"Quaternius","category":"nature","term":"nature pack"},
    {"slug":"pbr-marble-and-tile-texture-set","page":"https://opengameart.org/content/pbr-marble-and-tile-texture-set","creator":"Vosuna","category":"pbr","term":"marble and tile PBR textures"},
    {"slug":"pbr-texture-pack-0","page":"https://opengameart.org/content/pbr-texture-pack-0","creator":"Vosuna","category":"pbr","term":"stone tile marble carpet PBR maps"},
    {"slug":"pbr-texture-pack","page":"https://opengameart.org/content/pbr-texture-pack","creator":"Vosuna","category":"pbr","term":"low resolution stone tile marble PBR maps"},
]

SEARCH_TERMS = (
    ("chinese pagoda", "architecture", "pagoda"),
    ("imperial chinese palace", "architecture", "imperial palace"),
    ("chinese temple", "architecture", "chinese temple"),
    ("asian gate tower", "architecture", "gate tower"),
    ("stone arch bridge", "architecture", "arched stone bridge"),
    ("chinese palace wall", "architecture", "palace wall"),
    ("asian market stall", "architecture", "market stall"),
    ("chinese wooden house", "architecture", "asian house"),
    ("cherry blossom tree", "nature", "cherry blossom"),
    ("sakura tree", "nature", "cherry blossom"),
    ("bamboo tree", "nature", "bamboo"),
    ("willow tree", "nature", "willow"),
    ("chinese lantern", "ornaments", "chinese lantern"),
)

class _Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self._href = None
        self._text = []
    def handle_starttag(self, tag, attrs):
        if tag.lower() == "a":
            self._href = dict(attrs).get("href")
            self._text = []
    def handle_data(self, data):
        if self._href is not None:
            self._text.append(data)
    def handle_endtag(self, tag):
        if tag.lower() == "a" and self._href is not None:
            self.links.append((self._href, " ".join(self._text).strip()))
            self._href = None
            self._text = []

def _license_from_page(html):
    """Return a normalized, exact allow-listed license and its canonical URL."""
    text = re.sub(r"<[^>]+>", " ", html or "")
    text = re.sub(r"\s+", " ", text).lower() + " " + (html or "").lower()
    checks = [
        (r"\bcc0\b|publicdomain/zero/1\.0|public domain", "CC0 1.0 Universal", "https://creativecommons.org/publicdomain/zero/1.0/"),
        (r"oga[- ]by\s*[- ]?(4\.0|3\.0)", None, None),
        (r"creativecommons\.org/licenses/by-sa/(4\.0|3\.0)|\bcc[- ]?by[- ]?sa[- ]?(4\.0|3\.0)", None, None),
        (r"creativecommons\.org/licenses/by/(4\.0|3\.0|2\.5|2\.0|1\.0)|\bcc[- ]?by(?![- ]?(?:sa|nc|nd))[- ]?(4\.0|3\.0|2\.5|2\.0|1\.0)", None, None),
        (r"\bmit license\b|spdx-license-identifier:\s*mit", "MIT", "https://opensource.org/license/mit/"),
        (r"\bbsd[- ]?2[- ]clause\b", "BSD-2-Clause", "https://opensource.org/license/bsd-2-clause/"),
        (r"\bbsd[- ]?3[- ]clause\b|\bbsd license\b", "BSD-3-Clause", "https://opensource.org/license/bsd-3-clause/"),
        (r"\bzlib license\b|spdx-license-identifier:\s*zlib", "Zlib", "https://opensource.org/license/zlib/"),
        (r"\bwtfpl\b|do what the fuck you want to public license", "WTFPL", "http://www.wtfpl.net/txt/copying/"),
        (r"\bunlicense\b", "Unlicense", "https://unlicense.org/"),
        (r"\bgpl[- ]?(2\.0|3\.0)\b|gnu general public license (?:version )?(2|3)", None, None),
    ]
    for pattern, fixed, url in checks:
        m = re.search(pattern, text, re.I)
        if not m:
            continue
        if fixed:
            return fixed, url
        if "oga" in pattern:
            version = m.group(1)
            return "OGA-BY " + version, "https://opengameart.org/content/oga-by-40-faq" if version == "4.0" else "https://opengameart.org/content/oga-by-30-faq"
        if "by-sa" in pattern:
            version = next((g for g in m.groups() if g), None)
            return "CC BY-SA " + version, "https://creativecommons.org/licenses/by-sa/" + version + "/"
        if "creativecommons.org/licenses/by/" in pattern or ("cc" in pattern and "by" in pattern):
            version = next((g for g in m.groups() if g), "4.0")
            return "CC BY " + version, "https://creativecommons.org/licenses/by/" + version + "/"
        if "gpl" in pattern:
            version = m.group(1) or (m.group(2) + ".0")
            return "GPL " + version, "https://www.gnu.org/licenses/old-licenses/gpl-" + version.replace(".0", "") + ".0.html"
    return None, None

def _page_creator(html, fallback=None):
    if fallback:
        return fallback
    m = re.search(r"(?:Author|Creator)\s*:?\s*</?[^>]*>\s*<a[^>]*>([^<]{2,100})</a>", html or "", re.I)
    if m:
        return re.sub(r"\s+", " ", m.group(1)).strip()
    m = re.search(r'<meta[^>]+name=["\']author["\'][^>]+content=["\']([^"\']+)', html or "", re.I)
    return m.group(1).strip() if m else None

def _asset_files(page, html):
    parser = _Links()
    parser.feed(html)
    supported = {".zip", ".7z", ".blend", ".glb", ".gltf", ".fbx", ".obj", ".dae", ".stl", ".ply"}
    found = []
    for href, label in parser.links:
        absolute = urljoin(page, href)
        path = urlparse(absolute).path
        ext = Path(path).suffix.lower()
        if "/sites/default/files/" in path and ext in supported:
            found.append((absolute, label, ext))
    return found

def _target_category(category, term):
    text = (str(category) + " " + str(term)).lower()
    if category == "nature":
        return "nature"
    if category == "ornaments":
        return "statues_and_props"
    if category == "pbr":
        return "pbr_materials"
    if re.search(r"bridge|gate|wall|watchtower|tower", text):
        return "gates_walls_bridges"
    if re.search(r"palace|temple|pagoda|shrine", text):
        return "palaces_and_temples"
    if re.search(r"shop|stall|house|market|teahouse|tea house", text):
        return "houses_and_shops"
    return None

def _download_page_asset(session, fetch, sha, RAW, DISC, DOWN, ERR, page, slug, creator, category, term):
    if any(str(x.get("source_url", "")) == page for x in DISC):
        return False
    response = session.get(page, timeout=(20, 60), headers={"User-Agent":"NewConquerOffline-AssetFetcher/1.0"})
    response.raise_for_status()
    html = response.text
    license_name, license_url = _license_from_page(html)
    if not license_name:
        raise ValueError("Live page has no explicit allow-listed license marker")
    author = _page_creator(html, creator)
    if not author:
        raise ValueError("Creator/author could not be verified from the source page")
    files = _asset_files(page, html)
    if not files:
        raise ValueError("No direct downloadable model/archive link on the source page")
    for index, (url, label, ext) in enumerate(files[:3]):
        aid = "opengameart-" + slug + ("-" + str(index + 1) if index else "")
        if aid in {x.get("id") for x in DISC}:
            continue
        rec = {
            "id": aid, "name": label or slug, "source": "OpenGameArt",
            "source_url": page, "download_url": url, "license": license_name,
            "license_url": license_url, "authors": {"creator": author},
            "matches": [(category, term)], "target_category": _target_category(category, term), "candidate_only": category != "pbr", "api_metadata": {"license_verified_from_live_page": True},
        }
        raw = fetch(url, RAW / "opengameart" / (aid + ext))
        DISC.append(rec)
        DOWN.append({**rec, "raw": str(raw), "download_sha256": sha(raw)})
    return True

def discover_opengameart(session, fetch, safe, sha, RAW, DISC, DOWN, ERR):
    """Search OGA pages and targeted query results; accept every explicitly allowed license."""
    visited = set()
    discovered = 0
    for src in SOURCES:
        page = src["page"]
        visited.add(page)
        try:
            if _download_page_asset(session, fetch, sha, RAW, DISC, DOWN, ERR, page,
                                    src["slug"], src.get("creator"), src["category"], src["term"]):
                discovered += 1
        except Exception as exc:
            ERR.append({"asset":"OpenGameArt:"+src["slug"],"stage":"discover/download","reason":str(exc)})
    for query, category, term in SEARCH_TERMS:
        if discovered >= 30:
            break
        try:
            search_url = "https://opengameart.org/art-search-advanced?" + urlencode({"keys": query})
            response = session.get(search_url, timeout=(20, 60), headers={"User-Agent":"NewConquerOffline-AssetFetcher/1.0"})
            response.raise_for_status()
            parser = _Links()
            parser.feed(response.text)
            pages = []
            for href, label in parser.links:
                absolute = urljoin(search_url, href).split("#", 1)[0]
                if "/content/" in urlparse(absolute).path and absolute not in visited:
                    visited.add(absolute)
                    pages.append((absolute, label))
            for page, label in pages[:8]:
                if discovered >= 30:
                    break
                slug = urlparse(page).path.rstrip("/").split("/")[-1]
                try:
                    if _download_page_asset(session, fetch, sha, RAW, DISC, DOWN, ERR, page,
                                            slug, None, category, term):
                        discovered += 1
                except Exception as exc:
                    ERR.append({"asset":"OpenGameArt:"+slug,"stage":"search-result","reason":str(exc)})
        except Exception as exc:
            ERR.append({"asset":"OpenGameArt:search:"+query,"stage":"search","reason":str(exc)})
    print("OPENGAMEART_SOURCE_COUNTS", {"pages_checked":len(visited),"source_assets_added":discovered})

def discover_quaternius(session, fetch, safe, sha, RAW, DISC, DOWN, ERR):
    """Download only packs whose individual official page explicitly says CC0."""
    packs = [
        {"slug":"buildings-pack","page":"https://quaternius.com/packs/buildings.html","category":"architecture","term":"building"},
        {"slug":"ultimate-buildings-pack","page":"https://quaternius.com/packs/ultimatetexturedbuildings.html","category":"architecture","term":"building"},
        {"slug":"simple-buildings-pack","page":"https://quaternius.com/packs/simplebuildings.html","category":"architecture","term":"building"},
        {"slug":"ultimate-fantasy-rts","page":"https://quaternius.com/packs/ultimatefantasyrts.html","category":"architecture","term":"fantasy buildings towers architecture"},
        {"slug":"ultimate-nature-pack","page":"https://quaternius.com/packs/ultimatenature.html","category":"nature","term":"nature"},
        {"slug":"ultimate-stylized-nature-pack","page":"https://quaternius.com/packs/ultimatestylizednature.html","category":"nature","term":"trees flowers vegetation"},
        {"slug":"stylized-nature-megakit","page":"https://quaternius.com/packs/stylizednaturemegakit.html","category":"nature","term":"trees flowers vegetation"},
    ]
    for pack in packs:
        if any(x.get("source_url") == pack["page"] for x in DISC):
            continue
        try:
            response = session.get(pack["page"], timeout=(20, 60), headers={"User-Agent":"NewConquerOffline-AssetFetcher/1.0"})
            response.raise_for_status()
            html = response.text
            license_name, license_url = _license_from_page(html)
            if license_name != "CC0 1.0 Universal":
                raise ValueError("Official pack page is not explicitly CC0: " + str(license_name))
            parser = _Links()
            parser.feed(html)
            candidates = []
            for href, label in parser.links:
                absolute = urljoin(pack["page"], href)
                parsed = urlparse(absolute)
                if Path(parsed.path).suffix.lower() in (".zip", ".7z", ".glb", ".gltf", ".blend", ".fbx", ".obj"):
                    candidates.append((absolute, label))
                if "drive.google.com" in absolute:
                    match = re.search(r"/file/d/([A-Za-z0-9_-]+)|[?&]id=([A-Za-z0-9_-]+)", absolute)
                    if match:
                        file_id = match.group(1) or match.group(2)
                        candidates.append(("https://drive.google.com/uc?export=download&id=" + file_id, label or "official pack archive"))
            if not candidates:
                folder = re.search(r"drive/folders/([A-Za-z0-9_-]+)", html)
                if folder:
                    candidates = [("https://drive.google.com/uc?export=download&id=" + folder.group(1), "official Quaternius pack archive")]
            if not candidates:
                raise ValueError("No downloadable file/Drive link was exposed by the official page")
            unique = []
            for item in candidates:
                if item[0] not in {x[0] for x in unique}:
                    unique.append(item)
            for index, (url, label) in enumerate(unique[:2]):
                aid = "quaternius-" + pack["slug"] + ("-" + str(index + 1) if index else "")
                if aid in {x.get("id") for x in DISC}:
                    continue
                rec = {
                    "id": aid, "name": label or pack["slug"], "source":"Quaternius",
                    "source_url": pack["page"], "download_url": url,
                    "license": license_name, "license_url": license_url,
                    "authors":{"creator":"Quaternius"},
                    "matches":[(pack["category"], pack["term"])],
                    "pack":pack["slug"],
                    "candidate_only": True, "target_category": "nature" if pack["category"] == "nature" else None,
                }
                ext = Path(urlparse(url).path).suffix.lower() or (".zip" if "drive.google.com" in url else ".zip")
                raw = fetch(url, RAW / "quaternius" / (safe(aid) + ext))
                DISC.append(rec)
                DOWN.append({**rec, "raw":str(raw), "download_sha256":sha(raw)})
        except Exception as exc:
            ERR.append({"asset":"Quaternius:"+pack["slug"],"stage":"discover/download","reason":str(exc)})
