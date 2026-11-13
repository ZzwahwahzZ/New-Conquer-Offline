"""OpenGameArt CC0 source adapter. Each candidate is re-checked against its live page
before any file is downloaded; direct file URLs are extracted from the page, never guessed.
"""
from html.parser import HTMLParser
from urllib.parse import urljoin, urlparse
from pathlib import Path
import re

SOURCES = [
    {"slug":"big-stone-bridge","page":"https://opengameart.org/content/big-stone-bridge","creator":"KHORNE","category":"architecture","term":"stone bridge"},
    {"slug":"modular-temple-3d-models","page":"https://opengameart.org/content/modular-temple-3d-models","creator":"Keith at Fertile Soil Productions","category":"architecture","term":"temple"},
    {"slug":"dragon","page":"https://opengameart.org/content/dragon","creator":"Bitiquinho","category":"ornaments","term":"dragon model"},
    {"slug":"free-bamboo-v1","page":"https://opengameart.org/content/free-bamboo-v1","creator":"Yughues","category":"nature","term":"bamboo"},
    {"slug":"medieval-stone-temple","page":"https://opengameart.org/content/medieval-stone-temple","creator":"AnyRPG","category":"architecture","term":"stone temple"},
    {"slug":"stylized-nature-megakit","page":"https://opengameart.org/content/stylized-nature-megakit","creator":"Quaternius","category":"nature","term":"nature pack"},
    {"slug":"pbr-marble-and-tile-texture-set","page":"https://opengameart.org/content/pbr-marble-and-tile-texture-set","creator":"Vosuna","category":"pbr","term":"marble and tile PBR textures"},
    {"slug":"pbr-texture-pack-0","page":"https://opengameart.org/content/pbr-texture-pack-0","creator":"Vosuna","category":"pbr","term":"stone tile marble carpet PBR maps"},
    {"slug":"pbr-texture-pack","page":"https://opengameart.org/content/pbr-texture-pack","creator":"Vosuna","category":"pbr","term":"low resolution stone tile marble PBR maps"},
]

class _Links(HTMLParser):
    def __init__(self):
        super().__init__(); self.links=[]; self._href=None; self._text=[]
    def handle_starttag(self, tag, attrs):
        if tag.lower()=="a":
            self._href=dict(attrs).get("href"); self._text=[]
    def handle_data(self, data):
        if self._href is not None: self._text.append(data)
    def handle_endtag(self, tag):
        if tag.lower()=="a" and self._href is not None:
            self.links.append((self._href," ".join(self._text).strip())); self._href=None; self._text=[]

def discover_opengameart(session, fetch, safe, sha, RAW, DISC, DOWN, ERR):
    seen=set()
    supported={".zip",".blend",".glb",".gltf",".fbx",".obj",".dae",".stl",".ply",".7z"}
    for src in SOURCES:
        try:
            response=session.get(src["page"],timeout=(20,60),headers={"User-Agent":"NewConquerOffline-AssetFetcher/1.0"})
            response.raise_for_status()
            html=response.text
            # Only accept explicit CC0 on these pre-vetted pages. CC-BY candidates can be added
            # later with their complete attribution statement once independently reviewed.
            if not re.search(r"CC0|publicdomain/zero/1\\.0",html,re.I):
                raise ValueError("Live page did not expose a verifiable CC0 license marker")
            parser=_Links(); parser.feed(html)
            files=[]
            for href,label in parser.links:
                absolute=urljoin(src["page"],href)
                path=urlparse(absolute).path
                ext=Path(path).suffix.lower()
                if "/sites/default/files/" in path and ext in supported and absolute not in seen:
                    files.append((absolute,label,ext)); seen.add(absolute)
            if not files:
                raise ValueError("No supported direct asset file link found on the live page")
            # A page can expose more than one model archive; download all supported files.
            for index,(url,label,ext) in enumerate(files[:3]):
                aid="opengameart-"+src["slug"]+("-"+str(index+1) if index else "")
                rec={"id":aid,"name":label or src["slug"],"source":"OpenGameArt","source_url":src["page"],"license":"CC0 1.0 Universal","authors":{"creator":src["creator"]},"matches":[(src["category"],src["term"])],"download_url":url}
                DISC.append(rec)
                path=fetch(url,RAW/"opengameart"/(safe(aid)+ext))
                DOWN.append({**rec,"raw":str(path),"download_sha256":sha(path)})
        except Exception as exc:
            ERR.append({"asset":"OpenGameArt:"+src["slug"],"stage":"discover/download","reason":str(exc)})

def discover_quaternius(session, fetch, safe, sha, RAW, DISC, DOWN, ERR):
    """Try official Quaternius pack pages. Only use direct file links actually exposed by the live page."""
    packs = [
        {"slug":"ultimate-nature-pack","page":"https://quaternius.com/packs/ultimatenature.html","creator":"Quaternius"},
        {"slug":"stylized-nature-megakit-official","page":"https://quaternius.com/packs/stylizednaturemegakit.html","creator":"Quaternius"},
    ]
    for pack in packs:
        try:
            response=session.get(pack["page"],timeout=(20,60),headers={"User-Agent":"NewConquerOffline-AssetFetcher/1.0"})
            response.raise_for_status()
            html=response.text
            if not re.search(r"CC0|publicdomain/zero/1\\.0",html,re.I):
                raise ValueError("Official Quaternius page did not expose CC0 license text")
            parser=_Links(); parser.feed(html)
            candidates=[]
            for href,label in parser.links:
                absolute=urljoin(pack["page"],href)
                path=urlparse(absolute).path.lower()
                if Path(path).suffix in (".zip",".glb",".gltf",".blend",".fbx",".obj"):
                    candidates.append((absolute,label))
            if not candidates:
                raise ValueError("No direct downloadable model file link exposed; official page points to a hosted download flow")
            for index,(url,label) in enumerate(candidates[:2]):
                rec={"id":"quaternius-"+pack["slug"]+("-"+str(index+1) if index else ""),"name":label or pack["slug"],"source":"Quaternius","source_url":pack["page"],"license":"CC0 1.0 Universal","authors":{"creator":pack["creator"]},"matches":[("nature",pack["slug"])],"download_url":url}
                DISC.append(rec)
                ext=Path(urlparse(url).path).suffix.lower()
                path=fetch(url,RAW/"quaternius"/(safe(rec["id"])+ext))
                DOWN.append({**rec,"raw":str(path),"download_sha256":sha(path)})
        except Exception as exc:
            ERR.append({"asset":"Quaternius:"+pack["slug"],"stage":"discover/download","reason":str(exc)})
