#!/usr/bin/env python3
"""Restore selected original CC0 Imperial China GLB assets with manifest/license checks."""
from __future__ import annotations
import hashlib, json, shutil, struct, urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/"assets"/"environment"/"architecture"
MANIFEST_URL="https://3dassets.dev/api/v1/packs/imperial-china-palace-and-garden"
ASSETS={"36222":"imperial_china_palace_and_garden.glb","36163":"ceremonial_hall.glb","36164":"gate_tower.glb","36161":"palace_wall_straight.glb","36162":"palace_wall_corner.glb","36169":"arched_stone_bridge.glb","36170":"water_pavilion.glb"}
def get_json(url):
 req=urllib.request.Request(url,headers={"User-Agent":"New-Conquer-Offline-CC0-Asset-Restore/1.0"})
 with urllib.request.urlopen(req,timeout=60) as response:
  if response.status!=200: raise RuntimeError(f"HTTP {response.status} fetching CC0 manifest")
  return json.loads(response.read().decode("utf-8"))
def download(url,dest,expected):
 dest.parent.mkdir(parents=True,exist_ok=True); temp=dest.with_suffix(dest.suffix+".download")
 req=urllib.request.Request(url,headers={"User-Agent":"New-Conquer-Offline-CC0-Asset-Restore/1.0"})
 with urllib.request.urlopen(req,timeout=120) as response,temp.open("wb") as output:
  if response.status!=200: raise RuntimeError(f"HTTP {response.status} downloading {url}")
  shutil.copyfileobj(response,output)
 data=temp.read_bytes()
 if len(data)!=expected or len(data)<20 or data[:4]!=b"glTF": temp.unlink(missing_ok=True); raise RuntimeError(f"Invalid GLB payload {dest.name}: bytes={len(data)} expected={expected}")
 version,declared=struct.unpack_from("<II",data,4)
 if version!=2 or declared!=len(data): temp.unlink(missing_ok=True); raise RuntimeError(f"Invalid GLB v2 header {dest.name}")
 digest=hashlib.sha256(data).hexdigest(); temp.replace(dest); return digest
def main():
 manifest=get_json(MANIFEST_URL)["data"]
 license_label=str(manifest.get("licenseLabel",""))
 if "CC0 1.0" not in license_label: raise RuntimeError("Pack license label is not confirmed CC0 1.0")
 entries={str(manifest.get("starterScene",{}).get("id")):manifest.get("starterScene",{})}
 entries.update({str(a.get("id")):a for a in manifest.get("assets",[])})
 for asset_id,name in ASSETS.items():
  item=entries.get(asset_id)
  if not item: raise RuntimeError(f"Missing pinned asset ID {asset_id}")
  item_lic=item.get("license",{})
  if item_lic.get("slug")!="cc0-1.0" or item_lic.get("attributionRequired",False): raise RuntimeError(f"Asset {asset_id} is not CC0")
  size=int(item.get("stats",{}).get("fileSize",0)); url=item.get("cdnUrl")
  if not url or size<=20: raise RuntimeError(f"Invalid manifest entry for {asset_id}")
  digest=download(url,DEST/name,size)
  print(f"IMPERIAL_CHINA_CC0_ASSET: id={asset_id} file={name} bytes={size} sha256={digest}",flush=True)
 DEST.mkdir(parents=True,exist_ok=True)
 (DEST/"LICENSE_CC0.txt").write_text("Imperial China Palace and Garden asset pack\nSource: https://3dassets.dev/packs/imperial-china-palace-and-garden\nManifest: "+MANIFEST_URL+"\nLicense: CC0 1.0 Universal; no attribution required.\n",encoding="utf-8")
 print(f"IMPERIAL_CHINA_CC0_RESTORE_PASS: models={len(ASSETS)} destination={DEST}",flush=True)
if __name__=="__main__": main()
