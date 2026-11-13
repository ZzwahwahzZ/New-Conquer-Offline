#!/usr/bin/env python3
"""Upload only the verified v2 imperial city kit to the existing private HF dataset."""
from __future__ import annotations
import hashlib,os
from pathlib import Path
from huggingface_hub import HfApi
ROOT=Path(__file__).resolve().parents[1]
FOLDER=ROOT/"assets"/"imperial_city_kit_v2"
REPO="ZzwahwahzZ/clash-of-legends-terrain-assets"
PREFIX="assets/imperial_city_kit_v2"
PREFABS=ROOT/"assets"/"prefabs"/"city"
PREFAB_PREFIX="assets/prefabs/city"
def main():
 token=os.environ.get("HF_TOKEN","")
 if not token: raise SystemExit("HF_TOKEN is required in the existing GitHub Actions secret; no new credential is requested.")
 files=sorted(p for p in FOLDER.rglob("*") if p.is_file())
 prefabs=sorted(p for p in PREFABS.rglob("*") if p.is_file()) if PREFABS.is_dir() else []
 if not files or not prefabs: raise SystemExit(f"Refusing incomplete upload: kit_files={len(files)} prefab_files={len(prefabs)}")
 api=HfApi(token=token); api.repo_info(REPO,repo_type="dataset")
 expected={PREFIX+"/"+p.relative_to(FOLDER).as_posix():p.stat().st_size for p in files}
 expected.update({PREFAB_PREFIX+"/"+p.relative_to(PREFABS).as_posix():p.stat().st_size for p in prefabs})
 api.upload_folder(repo_id=REPO,repo_type="dataset",folder_path=str(FOLDER),path_in_repo=PREFIX,
                   commit_message="Upload verified Imperial City Kit v2 official CC0 assets")
 api.upload_folder(repo_id=REPO,repo_type="dataset",folder_path=str(PREFABS),path_in_repo=PREFAB_PREFIX,
                   commit_message="Upload normalized Imperial City v2 Godot prefab scenes")
 remote={}
 for target_prefix in (PREFIX,PREFAB_PREFIX):
  for item in api.list_repo_tree(repo_id=REPO,repo_type="dataset",path_in_repo=target_prefix,recursive=True,expand=True):
   if getattr(item,"type",None)=="file" or item.__class__.__name__=="RepoFile":
    remote[item.path]=getattr(item,"size",None)
 missing=sorted(set(expected)-set(remote))
 mismatched=[(k,v,remote.get(k)) for k,v in expected.items() if k in remote and remote[k] is not None and remote[k]!=v]
 if missing or mismatched: raise SystemExit(f"HF verification failed missing={missing[:10]} size_mismatch={mismatched[:10]}")
 print(f"HF_IMPERIAL_CITY_V2_UPLOAD_PASS kit_files={len(files)} prefab_files={len(prefabs)} total_files={len(expected)} bytes={sum(expected.values())}")
 print(f"https://huggingface.co/datasets/{REPO}/tree/main/{PREFIX}")
 print(f"https://huggingface.co/datasets/{REPO}/tree/main/{PREFAB_PREFIX}")
if __name__=="__main__": main()
