#!/usr/bin/env python3
"""Download verified 2K JPG PBR maps from Poly Haven's public CC0 asset API."""
from __future__ import annotations
import hashlib, json, shutil, urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/"assets"/"environment"/"materials"/"polyhaven"
API="https://api.polyhaven.com"
ASSETS=("pavement_05","stone_pathway")
MAPS=("albedo","normal","roughness")
USER_AGENT="New-Conquer-Offline-Phase3A/1.0 (Powered by Poly Haven)"
def get_json(url: str) -> dict:
 req=urllib.request.Request(url,headers={"User-Agent":USER_AGENT})
 with urllib.request.urlopen(req,timeout=60) as response:
  if response.status!=200: raise RuntimeError(f"Poly Haven API HTTP {response.status}: {url}")
  return json.loads(response.read().decode("utf-8"))
def leaves(node,path=()):
 if isinstance(node,dict):
  if "url" in node and "md5" in node:
   yield "/".join(str(x) for x in path).lower(),node
   return
  for key,value in node.items(): yield from leaves(value,path+(key,))
 elif isinstance(node,list):
  for index,value in enumerate(node): yield from leaves(value,path+(str(index),))
def select_map(file_tree: dict,map_name: str) -> dict:
 candidates=[(p,e) for p,e in leaves(file_tree) if "2k" in p and "jpg" in p]
 if map_name=="albedo":
  candidates=[(p,e) for p,e in candidates if any(t in p for t in ("diffuse","diff","albedo","color")) and "disp" not in p]
 elif map_name=="normal":
  preferred=[(p,e) for p,e in candidates if "nor_gl" in p or "normal_gl" in p]
  candidates=preferred or [(p,e) for p,e in candidates if "normal" in p and "dx" not in p and "nor_dx" not in p]
 elif map_name=="roughness":
  candidates=[(p,e) for p,e in candidates if "rough" in p]
 if not candidates:
  available=[p for p,_ in leaves(file_tree) if "2k" in p and "jpg" in p]
  raise RuntimeError(f"Poly Haven 2K JPG {map_name} map missing; candidates={available}")
 candidates.sort(key=lambda item:(len(item[0]),item[0]))
 return candidates[0][1]
def download(entry: dict,destination: Path) -> dict:
 url=entry.get("url"); expected_md5=str(entry.get("md5","")).lower(); expected_size=int(entry.get("size",0))
 if not url or not expected_md5 or expected_size<=0: raise RuntimeError(f"Incomplete Poly Haven metadata: {destination.name}")
 destination.parent.mkdir(parents=True,exist_ok=True); temporary=destination.with_suffix(destination.suffix+".download")
 request=urllib.request.Request(url,headers={"User-Agent":USER_AGENT})
 with urllib.request.urlopen(request,timeout=180) as response,temporary.open("wb") as output:
  if response.status!=200: raise RuntimeError(f"Poly Haven download HTTP {response.status}: {url}")
  shutil.copyfileobj(response,output)
 data=temporary.read_bytes(); actual_md5=hashlib.md5(data).hexdigest()
 if len(data)!=expected_size or actual_md5!=expected_md5:
  temporary.unlink(missing_ok=True)
  raise RuntimeError(f"Poly Haven checksum mismatch {destination.name}: {len(data)}/{expected_size} md5={actual_md5}/{expected_md5}")
 temporary.replace(destination)
 return {"url":url,"size":len(data),"md5":actual_md5}
def main():
 DEST.mkdir(parents=True,exist_ok=True)
 manifest={"provider":"Poly Haven","license":"CC0 1.0","resolution":"2K JPG","assets":{}}
 for asset_id in ASSETS:
  info=get_json(f"{API}/info/{asset_id}"); tree=get_json(f"{API}/files/{asset_id}")
  if not isinstance(info,dict) or not info.get("name"): raise RuntimeError(f"Invalid Poly Haven asset info: {asset_id}")
  folder=DEST/asset_id; manifest["assets"][asset_id]={"name":info["name"],"source":f"https://polyhaven.com/a/{asset_id}","maps":{}}
  for map_name in MAPS:
   details=download(select_map(tree,map_name),folder/f"{map_name}.jpg")
   manifest["assets"][asset_id]["maps"][map_name]=details
   print(f"POLYHAVEN_PBR_MAP: asset={asset_id} map={map_name} bytes={details['size']} md5={details['md5']}",flush=True)
 (DEST/"manifest.json").write_text(json.dumps(manifest,indent=2),encoding="utf-8")
 (DEST/"LICENSE_CC0.txt").write_text("Poly Haven PBR assets are CC0 1.0 Universal.\nPavement 05: https://polyhaven.com/a/pavement_05\nStone Pathway: https://polyhaven.com/a/stone_pathway\n",encoding="utf-8")
 (DEST/"POWERED_BY_POLY_HAVEN.txt").write_text("Powered by Poly Haven — CC0 PBR textures for streets and plazas.\n",encoding="utf-8")
 print(f"POLYHAVEN_PBR_RESTORE_PASS: assets={len(ASSETS)} maps={len(ASSETS)*len(MAPS)} destination={DEST}",flush=True)
if __name__=="__main__": main()
