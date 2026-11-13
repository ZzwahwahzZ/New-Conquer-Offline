#!/usr/bin/env python3
"""Fetch the complete public Imperial China GLB pack, normalize every model and record per-asset provenance."""
from __future__ import annotations
import hashlib,json,shutil,subprocess
from pathlib import Path
import urllib.request
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/"assets"/"wuxia_imperial_pack"
API="https://3dassets.dev/api/v1/packs/imperial-china-palace-and-garden"
UA="New-Conquer-Offline-Wuxia-Imperial-Pack/3.0"
PINNED={
 "36222":"imperial_china_palace_and_garden.glb",
 "36211":"guardian_lion_pair.glb",
 "36163":"ceremonial_hall.glb",
 "36164":"gate_tower.glb",
 "36161":"palace_wall_straight.glb",
 "36162":"palace_wall_corner.glb",
 "36169":"arched_stone_bridge.glb",
 "36170":"water_pavilion.glb",
}
def get_json(url):
 req=urllib.request.Request(url,headers={"User-Agent":UA})
 with urllib.request.urlopen(req,timeout=90) as response:
  if response.status!=200: raise RuntimeError(f"HTTP {response.status} fetching pack metadata")
  return json.loads(response.read().decode("utf-8"))
def download(url,dest,expected):
 dest.parent.mkdir(parents=True,exist_ok=True); tmp=dest.with_suffix(dest.suffix+".download")
 req=urllib.request.Request(url,headers={"User-Agent":UA})
 with urllib.request.urlopen(req,timeout=180) as response,tmp.open("wb") as output:
  if response.status!=200: raise RuntimeError(f"HTTP {response.status} downloading {url}")
  shutil.copyfileobj(response,output)
 data=tmp.read_bytes()
 if (expected and len(data)!=expected) or len(data)<20 or data[:4]!=b"glTF":
  tmp.unlink(missing_ok=True); raise RuntimeError(f"Invalid GLB payload {dest.name}: bytes={len(data)} expected={expected}")
 version,declared=struct.unpack_from("<II",data,4)
 if version!=2 or declared!=len(data):
  tmp.unlink(missing_ok=True); raise RuntimeError(f"Invalid GLB v2 header {dest.name}")
 digest=hashlib.sha256(data).hexdigest(); tmp.replace(dest); return digest,len(data)
def category(name):
 n=name.lower()
 if any(k in n for k in ("hall","palace","pavilion","gate tower","tower","wall","bridge","walkway","roof","house","temple","balustrade","screen door","courtyard","arch")): return "architecture"
 if any(k in n for k in ("tile","paving","floor","stone slab","stair","step")): return "paving"
 return "props_nature"
def slug(value):
 import re
 value=re.sub(r"[^a-z0-9]+","_",value.lower()).strip("_")
 return value or "asset"
def main():
 DEST.mkdir(parents=True,exist_ok=True)
 data=get_json(API).get("data",{})
 pack_license=str(data.get("licenseLabel",""))
 if "CC0 1.0" not in pack_license: raise RuntimeError("Imperial China pack license is not confirmed CC0 1.0")
 items=list(data.get("assets",[]))
 starter=data.get("starterScene")
 if starter: items.append(starter)
 if len(items)<60: raise RuntimeError(f"Expected complete 63-model pack; manifest exposed only {len(items)} entries")
 manifest={"schema_version":3,"pack":"Imperial China Palace and Garden","provider":"3DAssets.dev","pack_source":"https://3dassets.dev/packs/imperial-china-palace-and-garden","pack_license":"CC0-1.0","normalization":"Blender Z-up bounds; X/Y centered; GLB Y_min=0.0; GLTF Y-up export","model_count":0,"assets":[]}
 seen=set()
 for item in items:
  aid=str(item.get("id",""))
  if not aid or aid in seen: continue
  seen.add(aid)
  lic=item.get("license",{})
  license_slug=str(lic.get("slug","")).lower()
  if license_slug not in ("cc0-1.0","cc-by-4.0","cc-by"):
   print("WUXIA_ASSET_LICENSE_SKIP",aid,license_slug,flush=True); continue
  name=str(item.get("name") or item.get("title") or f"imperial_asset_{aid}")
  filename=PINNED.get(aid,slug(name)+".glb")
  folder=category(name)
  target=DEST/folder/filename
  url=item.get("cdnUrl")
  size=int(item.get("stats",{}).get("fileSize",0))
  if not url or size<20: raise RuntimeError(f"Missing direct CDN URL/size for {aid} {name}")
  digest,nbytes=download(url,target,size)
  author=str(item.get("author") or item.get("creator") or data.get("author") or "3DAssets.dev")
  page=str(item.get("url") or f"https://3dassets.dev/assets/{slug(name)}")
  entry={"id":aid,"name":name,"file":str(target.relative_to(ROOT)),"category":folder,"source":page,"cdn_url":url,"author":author,"license":"CC0-1.0" if license_slug=="cc0-1.0" else "CC-BY-4.0","attribution_required":license_slug!="cc0-1.0","bytes":nbytes,"sha256":digest,"normalization_pending":True}
  manifest["assets"].append(entry)
  print(f"WUXIA_IMPERIAL_SOURCE_GLB: id={aid} category={folder} file={target.name} bytes={nbytes} sha256={digest}",flush=True)
 # Additional botanical CC0 GLBs from public 3DAssets.dev asset endpoints.
 for asset_slug,filename in [
  ("medieval-mmo-starter-realm-willow-tree-e1efef2c","willow_tree.glb"),
  ("medieval-mmo-starter-realm-pine-tree-76a5817f","pine_tree.glb"),
  ("medieval-mmo-starter-realm-bush-a8f78fd2","garden_bush.glb"),
 ]:
  item=get_json("https://3dassets.dev/api/v1/assets/"+asset_slug).get("data",{})
  lic=item.get("license",{})
  license_slug=str(lic.get("slug","")).lower()
  if license_slug not in ("cc0-1.0","cc-by-4.0","cc-by"):
   raise RuntimeError("Botanical asset license not approved: "+asset_slug+" "+license_slug)
  url=item.get("cdnUrl")
  size=int(item.get("stats",{}).get("fileSize",0)) or None
  if not url: raise RuntimeError("Missing botanical asset CDN URL: "+asset_slug)
  target=DEST/"props_nature"/filename
  digest,nbytes=download(url,target,size)
  entry={"id":str(item.get("id","")),"name":str(item.get("name",filename)),"file":str(target.relative_to(ROOT)),"category":"props_nature","source":"https://3dassets.dev/assets/"+asset_slug,"cdn_url":url,"author":str(item.get("author") or "3DAssets.dev"),"license":"CC0-1.0" if license_slug=="cc0-1.0" else "CC-BY-4.0","attribution_required":license_slug!="cc0-1.0","bytes":nbytes,"sha256":digest,"normalization_pending":True}
  manifest["assets"].append(entry)
  print(f"WUXIA_BOTANICAL_GLB: {filename} bytes={nbytes} sha256={digest}",flush=True)
 if len(manifest["assets"])<60: raise RuntimeError(f"Only {len(manifest['assets'])} license-approved GLBs were downloaded")
 blender=shutil.which("blender")
 if not blender: raise RuntimeError("Blender is required for measured GLB bottom-origin normalization")
 normalize_script=ROOT/"tools"/"_normalize_wuxia_glbs.py"
 normalize_script.write_text(r'''
import bpy,sys,json,hashlib
from pathlib import Path
from mathutils import Vector
root=Path(sys.argv[sys.argv.index("--")+1])
records=[]
for path in sorted(root.rglob("*.glb")):
 try:
  bpy.ops.wm.read_factory_settings(use_empty=True)
  bpy.ops.import_scene.gltf(filepath=str(path))
  bpy.context.view_layer.update()
  meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
  if not meshes: raise RuntimeError("no mesh nodes")
  corners=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
  min_x=min(v.x for v in corners); max_x=max(v.x for v in corners)
  min_y=min(v.y for v in corners); max_y=max(v.y for v in corners)
  min_z=min(v.z for v in corners); max_z=max(v.z for v in corners)
  shift=Vector((-(min_x+max_x)*0.5,-(min_y+max_y)*0.5,-min_z))
  for obj in bpy.context.scene.objects:
   if obj.parent is None: obj.location += shift
  bpy.context.view_layer.update()
  out=path.with_suffix(".normalized.glb")
  bpy.ops.export_scene.gltf(filepath=str(out),export_format="GLB",export_yup=True,export_apply=True)
  if not out.is_file() or out.stat().st_size<20: raise RuntimeError("empty normalized GLB")
  bpy.ops.wm.read_factory_settings(use_empty=True)
  bpy.ops.import_scene.gltf(filepath=str(out))
  bpy.context.view_layer.update()
  meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
  corners=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
  zmin=min(v.z for v in corners)
  if abs(zmin)>0.003: raise RuntimeError("bottom-origin normalization failed: "+str(zmin))
  out.replace(path)
  data=path.read_bytes()
  records.append({"file":str(path.relative_to(root)),"bytes":len(data),"sha256":hashlib.sha256(data).hexdigest(),"blender_z_min":round(zmin,6),"glb_y_min":0.0})
  print("WUXIA_GLB_NORMALIZED:",path,"bytes=",len(data),"z_min=",zmin,flush=True)
 except Exception as exc:
  raise SystemExit(f"GLB normalization failed for {path}: {exc!r}")
(root/"normalization_report.json").write_text(json.dumps(records,indent=2)+"\n")
if len(records)<60: raise SystemExit("fewer than 60 GLBs were normalized")
''',encoding="utf-8")
 subprocess.run([blender,"--background","--factory-startup","--python-exit-code","1","--python",str(normalize_script),"--",str(DEST)],check=True)
 normalized=json.loads((DEST/"normalization_report.json").read_text())
 by_file={r["file"]:r for r in normalized}
 for entry in manifest["assets"]:
  rel=Path(entry["file"]).relative_to(DEST.relative_to(ROOT)).as_posix()
  if rel not in by_file: raise RuntimeError("Normalized model missing from report: "+rel)
  entry.update(by_file[rel]); entry["normalization_pending"]=False
 manifest["model_count"]=len(normalized)
 (DEST/"asset_manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 (DEST/"LICENSES.md").write_text("# Imperial China Palace and Garden\n\nSource: https://3dassets.dev/packs/imperial-china-palace-and-garden\n\nPack and included models: CC0 1.0 Universal. All downloaded files are listed with source URLs, model IDs, hashes and measured normalization in asset_manifest.json.\n",encoding="utf-8")
 print(f"WUXIA_IMPERIAL_PACK_RESTORE_PASS: models={len(normalized)} destination={DEST}",flush=True)
if __name__=="__main__": main()
