#!/usr/bin/env python3
"""Download public CC0 AmbientCG PBR ZIPs and normalize map names for Godot."""
from __future__ import annotations
import hashlib,json,shutil,urllib.request,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/"assets"/"wuxia_imperial_pack"/"paving"/"ambientcg"
ASSETS=("PaintedWood003","GlazedTerracotta001")
RESOLUTION="2K-JPG"
BASE="https://ambientcg.com/get?file="
UA="New-Conquer-Offline-Wuxia-Imperial-Pack/3.0"
def main():
 DEST.mkdir(parents=True,exist_ok=True)
 manifest={"provider":"ambientCG","license":"CC0-1.0","resolution":RESOLUTION,"assets":{}}
 for asset in ASSETS:
  folder=DEST/asset; folder.mkdir(parents=True,exist_ok=True)
  url=BASE+asset+"_"+RESOLUTION+".zip"
  archive=folder/(asset+"_"+RESOLUTION+".zip")
  req=urllib.request.Request(url,headers={"User-Agent":UA})
  with urllib.request.urlopen(req,timeout=180) as response,archive.open("wb") as out:
   if response.status!=200: raise RuntimeError(f"ambientCG HTTP {response.status}: {url}")
   shutil.copyfileobj(response,out)
  if not zipfile.is_zipfile(archive): raise RuntimeError("ambientCG returned a non-ZIP payload: "+asset)
  maps={}
  with zipfile.ZipFile(archive) as z:
   for info in z.infolist():
    if info.is_dir(): continue
    name=Path(info.filename).name
    if not name.lower().endswith((".jpg",".jpeg",".png")): continue
    if any(x in name.lower() for x in ("_color.","_normalgl.","_roughness.")):
     target=folder/name
     with z.open(info) as src,target.open("wb") as dst: shutil.copyfileobj(src,dst)
     key="albedo" if "_color." in name.lower() else ("normal" if "_normalgl." in name.lower() else "roughness")
     data=target.read_bytes()
     maps[key]={"file":str(target.relative_to(ROOT)),"bytes":len(data),"sha256":hashlib.sha256(data).hexdigest()}
  missing={"albedo","normal","roughness"}-set(maps)
  if missing: raise RuntimeError(f"ambientCG {asset} missing maps: {sorted(missing)}")
  manifest["assets"][asset]={"source":"https://ambientcg.com/view?id="+asset,"download":url,"author":"ambientCG","license":"CC0-1.0","maps":maps}
  print(f"AMBIENTCG_WUXIA_PBR_PASS: {asset} maps={','.join(sorted(maps))}",flush=True)
 (DEST/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 (DEST/"LICENSE_CC0.txt").write_text("All downloaded AmbientCG materials are CC0 1.0 Universal.\n"+ "\n".join(v["source"] for v in manifest["assets"].values())+"\n",encoding="utf-8")
 print("AMBIENTCG_WUXIA_PBR_PASS: assets=2 maps=6")
if __name__=="__main__": main()
