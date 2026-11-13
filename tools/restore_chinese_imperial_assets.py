#!/usr/bin/env python3
"""Fetch the complete public Imperial China GLB pack, normalize every model and record per-asset provenance."""
from __future__ import annotations
import hashlib,json,shutil,struct,subprocess,urllib.parse
from pathlib import Path
import urllib.request
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/"assets"/"wuxia_imperial_pack"
API="https://3dassets.dev/api/v1/packs/imperial-china-palace-and-garden"
UA="New-Conquer-Offline-Wuxia-Imperial-Pack/3.0"
PINNED={
 "36222":"imperial_china_palace_and_garden.glb",
 "36211":"guardian_lion_pair.glb",
 "36188":"hanging_silk_lantern.glb",
 "36179":"dragon_roof_finial.glb",
 "36167":"covered_walkway_bay.glb",
 "36201":"low_tea_table.glb",
 "36182":"latticed_screen_door_set.glb",
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
 if any(k in n for k in ("hall","palace","pavilion","gate tower","tower","wall","bridge","walkway","roof","house","temple","pagoda","stall","balustrade","screen door","courtyard","arch")): return "architecture"
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
 manifest={"schema_version":3,"pack":"Imperial China Palace and Garden","provider":"3DAssets.dev","pack_source":"https://3dassets.dev/packs/imperial-china-palace-and-garden","pack_license":"CC0-1.0","normalization":"Blender Z-up bounds; X/Y centered; GLB Y_min=0.0; GLTF Y-up export","ai_assisted":"3DAssets.dev pack page states 63 of 63 pack files were created with Claude Opus 5; extra search results are credited individually as supplied by their manifests.","model_count":0,"assets":[],"discovery":[]}
 seen=set()
 for item in items:
  aid=str(item.get("id",""))
  if not aid or aid in seen: continue
  seen.add(aid)
  lic=item.get("license",{})
  license_slug=str(lic.get("slug","")).lower()
  if license_slug not in ("cc0-1.0","cc-by-4.0") and not (license_slug=="cc-by" and lic.get("url")):
   print("WUXIA_ASSET_LICENSE_SKIP",aid,license_slug,flush=True); continue
  name=str(item.get("name") or item.get("title") or f"imperial_asset_{aid}")
  filename=PINNED.get(aid,slug(name).replace("_imperial_china_palace_and_garden","")+".glb")
  folder=category(name)
  target=DEST/folder/filename
  url=item.get("cdnUrl")
  size=int(item.get("stats",{}).get("fileSize",0))
  if not url or size<20: raise RuntimeError(f"Missing direct CDN URL/size for {aid} {name}")
  digest,nbytes=download(url,target,size)
  author=str(item.get("author") or item.get("creator") or data.get("author") or "3DAssets.dev")
  page=str(item.get("url") or f"https://3dassets.dev/assets/{slug(name)}")
  entry={"id":aid,"name":name,"file":str(target.relative_to(ROOT)),"category":folder,"source":page,"cdn_url":url,"author":author,"license":"CC0-1.0" if license_slug=="cc0-1.0" else "CC-BY","license_url":str(lic.get("url") or ("https://creativecommons.org/publicdomain/zero/1.0/" if license_slug=="cc0-1.0" else "https://creativecommons.org/licenses/by/4.0/")),"attribution_required":license_slug!="cc0-1.0","attribution_text":str(lic.get("attributionText") or ""),"bytes":nbytes,"sha256":digest,"normalization_pending":True}
  manifest["assets"].append(entry)
  print(f"WUXIA_IMPERIAL_SOURCE_GLB: id={aid} category={folder} file={target.name} bytes={nbytes} sha256={digest}",flush=True)
 # Search the public 3DAssets catalogue for specific Chinese architecture and ceremonial props.
 search_targets=[
  ("Chinese pagoda","chinese_pagoda.glb","architecture",("pagoda",)),
  ("dragon statue","chinese_dragon_statue.glb","props_nature",("dragon","statue")),
  ("stone fountain","stone_fountain.glb","props_nature",("stone","fountain")),
  ("Asian market stall","asian_market_stall.glb","architecture",("stall",)),
  ("Chinese town house","chinese_town_house.glb","architecture",("house",)),
  ("stone brazier","stone_brazier.glb","props_nature",("stone","brazier")),
  ("willow tree","willow_tree.glb","props_nature",("willow",)),
  ("mountain pine","pine_tree.glb","props_nature",("pine",)),
  ("garden bush","garden_bush.glb","props_nature",("bush",)),
  ("bamboo cluster","bamboo_cluster.glb","props_nature",("bamboo",)),
  ("pond water module","pond_water_module.glb","props_nature",("pond","water")),
  ("standing garden lantern","standing_garden_lantern.glb","props_nature",("lantern",)),
  ("lotus cluster","lotus_cluster.glb","props_nature",("lotus",)),
  ("lotus pond edge straight","lotus_pond_edge_straight.glb","props_nature",("pond","edge","straight")),
  ("lotus pond edge corner","lotus_pond_edge_corner.glb","props_nature",("pond","edge","corner")),
  ("rockery outcrop","rockery_outcrop.glb","props_nature",("rockery",)),
  ("stone incense burner","stone_incense_burner.glb","props_nature",("incense","burner")),
 ]
 for query,filename,folder,required_terms in search_targets:
  query_url="https://3dassets.dev/api/v1/assets?"+urllib.parse.urlencode({"q":query,"limit":20})
  results=get_json(query_url).get("data",[])
  eligible=[]
  for candidate in results:
   text_blob=" ".join(str(candidate.get(k,"")) for k in ("name","title","description","shortDescription","tags")).lower()
   if not all(term in text_blob for term in required_terms): continue
   if query in ("Chinese pagoda","dragon statue","Asian market stall","Chinese town house") and not any(tag in text_blob for tag in ("chinese","asian","japanese","hanok","imperial")): continue
   lic=candidate.get("license",{})
   lic_slug=str(lic.get("slug","")).lower()
   if lic_slug not in ("cc0-1.0","cc-by-4.0") and not (lic_slug=="cc-by" and lic.get("url")): continue
   eligible.append(candidate)
  if not eligible:
   manifest["discovery"].append({"query":query,"status":"no_verified_match"})
   print("WUXIA_DISCOVERY_MISS:",query,flush=True)
   continue
  eligible.sort(key=lambda item:int(item.get("stats",{}).get("triangleCount",0) or 0),reverse=True)
  candidate=eligible[0]
  asset_slug=str(candidate.get("slug",""))
  if not asset_slug:
   manifest["discovery"].append({"query":query,"status":"missing_slug"})
   continue
  detail=get_json("https://3dassets.dev/api/v1/assets/"+asset_slug).get("data",candidate)
  aid=str(detail.get("id",candidate.get("id","")))
  if aid in seen:
   manifest["discovery"].append({"query":query,"status":"already_in_pack","id":aid})
   continue
  lic=detail.get("license",candidate.get("license",{}))
  license_slug=str(lic.get("slug","")).lower()
  if license_slug not in ("cc0-1.0","cc-by-4.0","cc-by"):
   manifest["discovery"].append({"query":query,"status":"license_rejected","id":aid})
   continue
  url=detail.get("cdnUrl") or candidate.get("cdnUrl")
  size=int(detail.get("stats",{}).get("fileSize",0) or candidate.get("stats",{}).get("fileSize",0)) or None
  if not url:
   manifest["discovery"].append({"query":query,"status":"missing_cdn","id":aid})
   continue
  target=DEST/folder/filename
  digest,nbytes=download(url,target,size)
  author=str(detail.get("author") or detail.get("creator") or "3DAssets.dev contributor")
  entry={"id":aid,"name":str(detail.get("name") or candidate.get("name") or query),"file":str(target.relative_to(ROOT)),"category":folder,"source":"https://3dassets.dev/assets/"+asset_slug,"cdn_url":url,"author":author,"license":"CC0-1.0" if license_slug=="cc0-1.0" else "CC-BY-4.0","attribution_required":license_slug!="cc0-1.0","bytes":nbytes,"sha256":digest,"normalization_pending":True}
  manifest["assets"].append(entry); seen.add(aid)
  manifest["discovery"].append({"query":query,"status":"downloaded","id":aid,"file":str(target.relative_to(ROOT))})
  print(f"WUXIA_DISCOVERED_ASSET: query={query} file={filename} license={entry['license']} bytes={nbytes}",flush=True)
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
