#!/usr/bin/env python3
"""Restore three exact Poly Haven CC0 PBR sets without credentials or API keys."""
from __future__ import annotations
import hashlib,json,shutil,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/"assets"/"imperial_city_kit_v2"/"pbr"
API="https://api.polyhaven.com"
ASSETS=("stone_tiles_02","cobblestone_floor_04","marble_01")
MAPS=("albedo","normal","roughness")
UA="New-Conquer-Offline-Imperial-City-Kit/2.0"
def get(url):
 req=urllib.request.Request(url,headers={"User-Agent":UA})
 with urllib.request.urlopen(req,timeout=90) as r:
  if r.status!=200: raise RuntimeError(f"HTTP {r.status}: {url}")
  import json
  return json.loads(r.read().decode())
def leaves(node,path=()):
 if isinstance(node,dict):
  if "url" in node and "md5" in node: yield "/".join(map(str,path)).lower(),node; return
  for k,v in node.items(): yield from leaves(v,path+(k,))
 elif isinstance(node,list):
  for i,v in enumerate(node): yield from leaves(v,path+(i,))
def choose(tree,kind):
 candidates=[(p,e) for p,e in leaves(tree) if "2k" in p and "jpg" in p]
 if kind=="albedo": candidates=[x for x in candidates if any(t in x[0] for t in ("diffuse","diff","albedo","color")) and "disp" not in x[0]]
 elif kind=="normal": candidates=[x for x in candidates if ("nor_gl" in x[0] or "normal_gl" in x[0])]
 else: candidates=[x for x in candidates if "rough" in x[0]]
 if not candidates: raise RuntimeError(f"Missing 2K JPG {kind} map")
 return sorted(candidates,key=lambda x:(len(x[0]),x[0]))[0][1]
def main():
 DEST.mkdir(parents=True,exist_ok=True); manifest={"provider":"Poly Haven","license":"CC0-1.0","resolution":"2K JPG","assets":{}}
 for aid in ASSETS:
  info=get(f"{API}/info/{aid}"); tree=get(f"{API}/files/{aid}")
  if not info.get("name"): raise RuntimeError("Poly Haven asset metadata missing: "+aid)
  entry={"name":info["name"],"source":f"https://polyhaven.com/a/{aid}","maps":{}}
  folder=DEST/aid; folder.mkdir(parents=True,exist_ok=True)
  for kind in MAPS:
   meta=choose(tree,kind); url=meta["url"]; expected=meta["md5"].lower(); size=int(meta["size"])
   target=folder/f"{kind}.jpg"; tmp=target.with_suffix(".download")
   req=urllib.request.Request(url,headers={"User-Agent":UA})
   with urllib.request.urlopen(req,timeout=180) as r,tmp.open("wb") as out:
    if r.status!=200: raise RuntimeError(f"HTTP {r.status}: {url}")
    shutil.copyfileobj(r,out)
   data=tmp.read_bytes(); digest=hashlib.md5(data).hexdigest()
   if len(data)!=size or digest!=expected: tmp.unlink(missing_ok=True); raise RuntimeError(f"Checksum mismatch: {aid}/{kind}")
   tmp.replace(target); entry["maps"][kind]={"url":url,"bytes":len(data),"md5":digest}
   print(f"POLYHAVEN_V2_MAP_PASS: {aid}/{kind} bytes={len(data)} md5={digest}",flush=True)
  manifest["assets"][aid]=entry
 (DEST/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
 (DEST/"LICENSE_CC0.txt").write_text("Poly Haven textures are CC0 1.0 Universal.\n"+"\n".join(x["source"] for x in manifest["assets"].values())+"\n")
 print("POLYHAVEN_IMPERIAL_V2_PASS: 3 assets x 3 verified maps")
if __name__=="__main__": main()
