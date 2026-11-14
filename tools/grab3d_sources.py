"""Grab3D CC0 asset discovery adapter; mobile-conscious GLB selection."""
from __future__ import annotations
import re
from pathlib import Path
from urllib.parse import urlparse

API = "https://grab3d.com/api/v1/models.json"
LICENSE = "CC0 1.0"
LICENSE_URL = "https://creativecommons.org/publicdomain/zero/1.0/"
NATURE = {"cherry":"flowering trees","blossom":"flowering trees","bamboo":"bamboo","pine":"pine trees","willow":"willow trees","plum":"plum blossom","lotus":"lotus gardens","bonsai":"bonsai","rock":"rocks","boulder":"boulders","fern":"ferns","mushroom":"forest mushrooms","reed":"reeds","grass":"wild grasses","shrub":"shrubs","tree":"trees"}
CREATURE = {"chinese-dragon":"Chinese dragon","dragon":"dragon","wyvern":"wyvern","goblin":"goblin","orc":"orc","wolf":"wolf","tiger":"tiger","boar":"boar","bear":"bear","fox":"fox","deer":"deer","spider":"spider","snake":"snake","skeleton":"skeleton","monster":"monster","phoenix":"phoenix","griffin":"griffin"}
ARCH = {"tea-house":("houses_and_shops","East Asian tea house"),"village-gate":("gates_walls_bridges","village gate"),"pagoda":("palaces_and_temples","pagoda"),"temple":("palaces_and_temples","temple"),"pavilion":("palaces_and_temples","pavilion"),"market-stall":("houses_and_shops","market stall"),"shop":("houses_and_shops","shop"),"lantern":("statues_and_props","lantern"),"stone-lion":("statues_and_props","stone guardian lion")}

def _text(value):
    if isinstance(value, dict): return " ".join(_text(v) for v in value.values())
    if isinstance(value, (list, tuple)): return " ".join(_text(v) for v in value)
    return str(value or "")

def discover_grab3d(getj, fetch, safe, sha, raw_root, disc, down, errors, skipped):
    try:
        payload = getj(API)
        models = payload.get("models", []) if isinstance(payload, dict) else []
        if not isinstance(models, list): raise ValueError("Grab3D API response did not contain a models list")
    except Exception as exc:
        errors.append({"asset":"Grab3D","stage":"discover","reason":str(exc)})
        return
    existing = {str(x.get("id","")).lower() for x in disc}
    selected = []
    for model in models:
        slug = str(model.get("slug") or "").strip().lower()
        if not slug or slug in existing: continue
        if str(model.get("license") or "").strip().upper() not in {"CC0-1.0","CC0","CC0 1.0"}: continue
        name = _text(model.get("name")).strip() or slug.replace("-"," ").title()
        tags = model.get("tags") or []
        hay = (slug+" "+name+" "+_text(tags)+" "+_text(model.get("summary"))).lower().replace("_"," ").replace("-"," ")
        target = term = None
        candidate_only = False
        for key, value in ARCH.items():
            if key.replace("-"," ") in hay:
                target, term = value; candidate_only = True; break
        if target is None:
            for token, label in NATURE.items():
                if re.search(r"(?<![a-z0-9])"+re.escape(token)+r"(?![a-z0-9])",hay):
                    target, term = "nature", label; break
        if target is None:
            for token, label in CREATURE.items():
                if re.search(r"(?<![a-z0-9])"+re.escape(token.replace("-"," ")) + r"(?![a-z0-9])",hay):
                    target, term = "creatures_and_wildlife", label; candidate_only = True; break
        if target is None: continue
        tier = str(model.get("tier") or "").lower()
        files = [x for x in (model.get("files") or []) if str(x.get("format","")).lower()=="glb" and x.get("url")]
        if not files:
            skipped.append({"asset":"Grab3D:"+slug,"stage":"format","reason":"No direct GLB download in published API"}); continue
        light = [x for x in files if str(x.get("variant","")).lower()=="light"]
        full = [x for x in files if str(x.get("variant","")).lower()=="full"]
        choice = light[0] if tier=="high-detail" and light else full[0] if full else light[0] if light else files[0]
        size = int(choice.get("bytes") or 0)
        if size and size > 45*1024*1024:
            skipped.append({"asset":"Grab3D:"+slug,"stage":"size","reason":"GLB exceeds 45 MB mobile-source cap"}); continue
        selected.append((model,slug,name,target,term,candidate_only,choice))
    limits={"nature":22,"creatures_and_wildlife":14,"architecture":12}
    counts={k:0 for k in limits}
    for model,slug,name,target,term,candidate_only,choice in selected:
        bucket="nature" if target=="nature" else "creatures_and_wildlife" if target=="creatures_and_wildlife" else "architecture"
        if counts[bucket]>=limits[bucket]: continue
        counts[bucket]+=1
        origin=model.get("origin") or {}
        page=str(model.get("page") or "https://grab3d.com/models/"+slug+"/")
        record={"id":"grab3d-"+slug,"name":name,"source":"Grab3D","source_url":page,"download_url":str(choice["url"]),
          "license":LICENSE,"license_url":str(origin.get("licenseUrl") or LICENSE_URL),"authors":{"creator":"Grab3D"},
          "matches":[(target,term)],"target_category":target,"candidate_only":candidate_only,
          "api_metadata":{"slug":slug,"tags":tags if isinstance(tags,list) else [],"tier":tier,
          "triangles":(model.get("specs") or {}).get("trianglesLight") if choice.get("variant")=="light" else (model.get("specs") or {}).get("triangles"),
          "dimensions_m":(model.get("specs") or {}).get("dimensionsMeters"),"origin":origin,"ai_disclosure":origin.get("method")}}
        try:
            ext=Path(urlparse(record["download_url"]).path).suffix.lower() or ".glb"
            path=fetch(record["download_url"],raw_root/"grab3d"/(safe(slug)+ext),limit=45*1024*1024)
            disc.append(record); down.append({**record,"raw":str(path),"download_sha256":sha(path)})
        except Exception as exc:
            errors.append({"asset":record["id"],"stage":"download","reason":str(exc)})
