#!/usr/bin/env python3
"""Publish the twelve validated six-city panorama frames to the project's HF dataset."""
from __future__ import annotations
import os
from pathlib import Path
from huggingface_hub import HfApi
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/"reports"/"visual-proof"
REPO="ZzwahwahzZ/clash-of-legends-terrain-assets"
DEST="reports/wuxia_imperial_city_v2"
def main():
 token=os.environ.get("HF_TOKEN")
 if not token: raise SystemExit("HF_TOKEN is required through GitHub Actions secrets; no token is read from source or logs")
 images=sorted(SOURCE.glob("*.png"))
 if len(images)!=12 or any(p.stat().st_size<1024 for p in images):
  raise SystemExit(f"Refusing incomplete visual proof set: found {len(images)} PNG files")
 cities=["TwinCity","DesertLand","VolcanoLand","IceLand","Waterlands","DarkForest"]
 lines=["# Wuxia Imperial City — 12 runtime panorama proofs","","Captured from the live Godot 4.3 runtime after the six-city validation gates passed.",""]
 for index,city in enumerate(cities,1):
  for suffix,label in [("01_aerial_overview","Aerial overview"),("02_inner_street","Inner street")]:
   matches=[p for p in images if p.name.lower().startswith(f"city_{index}_{city.lower()}_{suffix}")]
   if len(matches)!=1: raise SystemExit(f"Missing or duplicate proof image: {city} {suffix}")
   lines += [f"## {city} — {label}","",f"![{city} {label}]({matches[0].name})",""]
 (SOURCE/"README.md").write_text("\n".join(lines)+"\n",encoding="utf-8")
 api=HfApi(token=token)
 api.repo_info(repo_id=REPO,repo_type="dataset")
 api.upload_folder(repo_id=REPO,repo_type="dataset",folder_path=str(SOURCE),path_in_repo=DEST,commit_message="Publish twelve validated Wuxia imperial city panoramas")
 expected={DEST+"/"+p.name:p.stat().st_size for p in images}
 expected[DEST+"/README.md"]=(SOURCE/"README.md").stat().st_size
 remote={}
 for item in api.list_repo_tree(repo_id=REPO,repo_type="dataset",path_in_repo=DEST,recursive=True,expand=True):
  if getattr(item,"type",None)=="file" or item.__class__.__name__=="RepoFile":
   remote[item.path]=getattr(item,"size",None)
 missing=[name for name,size in expected.items() if name not in remote or remote[name]!=size]
 if missing: raise SystemExit("HF panorama verification failed: "+", ".join(missing))
 print(f"WUXIA_VISUAL_PROOF_HF_PASS: images={len(images)} files={len(expected)} bytes={sum(expected.values())}")
 print(f"https://huggingface.co/datasets/{REPO}/tree/main/{DEST}")
if __name__=="__main__": main()
