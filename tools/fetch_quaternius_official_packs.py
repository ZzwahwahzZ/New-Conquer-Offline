#!/usr/bin/env python3
"""Download Quaternius CC0 packs from public folders linked by quaternius.com and normalize models to GLB."""
from __future__ import annotations
import hashlib,json,shutil,subprocess,zipfile,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
CACHE=Path.home()/".cache"/"quaternius-official"
DEST=ROOT/"assets"/"wuxia_imperial_pack"/"quaternius"
PACKS={
"modular_medieval_buildings":("https://quaternius.com/packs/modularmedievalbuildings.html","https://drive.google.com/drive/folders/1WCmnrS1fYQLYfRwztVErgAOyWXdJiVIo?usp=sharing"),
"ultimate_buildings":("https://quaternius.com/packs/ultimatetexturedbuildings.html","https://drive.google.com/drive/folders/1RE3qXhbE5yGS3t-xGFJ8GmOtTgCUF3LQ?usp=sharing"),
"ultimate_nature":("https://quaternius.com/packs/ultimatenature.html","https://drive.google.com/drive/folders/1-Kl0L_Jg8awbh0S5T-z3zxh4mVlnxTpa?usp=sharing"),
"modular_platformer":("https://quaternius.com/packs/modularplatformer.html","https://drive.google.com/drive/folders/1ku_XmbHOZ5ypgKCAjpzX6hlXaOJT7Uoq?usp=sharing"),
"modular_streets":("https://quaternius.com/packs/modularstreets.html","https://drive.google.com/drive/folders/1-YvMpLDYBIy-0Ms7ZlFmUpChTbHku8IJ?usp=sharing"),
"ultimate_fantasy_rts":("https://quaternius.com/packs/ultimatefantasyrts.html","https://drive.google.com/drive/folders/1h7sztlZyavWla-JDk3jp6KiWDdMh08yd?usp=sharing"),
"medieval_village":("https://quaternius.com/packs/medievalvillage.html","https://drive.google.com/drive/folders/18T92VcNldHG0ugWo1u0hSJGDLua-n7o5?usp=sharing"),
"ultimate_rpg_props":("https://quaternius.com/packs/ultimaterpg.html","https://drive.google.com/drive/folders/1IhdL3W5XdJrjf_axqAnKvEybMaC3FwF-?usp=sharing"),
"ultimate_platformer":("https://quaternius.com/packs/ultimateplatformer.html","https://drive.google.com/drive/folders/1NDZn_aGnn0vfFV3M22Y8GPcDjO8BVcLs?usp=sharing"),
}
EXTS={".fbx",".obj",".glb",".gltf"}
def safe_extract(z,p):
 p.mkdir(parents=True,exist_ok=True); root=p.resolve()
 with zipfile.ZipFile(z) as f:
  for m in f.infolist():
   q=(p/m.filename).resolve()
   if q!=root and root not in q.parents: raise RuntimeError("Unsafe ZIP path: "+m.filename)
  f.extractall(p)
def main():
 import gdown
 CACHE.mkdir(parents=True,exist_ok=True); DEST.mkdir(parents=True,exist_ok=True)
 source_root=CACHE/"sources"
 if source_root.exists(): shutil.rmtree(source_root)
 source_root.mkdir()
 source_files=[]
 verified_packs={}
 for slug,(page,url) in PACKS.items():
  request=urllib.request.Request(page,headers={"User-Agent":"New-Conquer-Offline-License-Check/1.0"})
  with urllib.request.urlopen(request,timeout=60) as response:
   page_html=response.read().decode("utf-8","ignore")
  if "CC0" not in page_html:
   print("QUATERNIUS_LICENSE_REJECTED_OR_UNCLEAR",slug,page,flush=True)
   continue
  verified_packs[slug]=(page,url)
  folder=CACHE/slug
  if folder.exists(): shutil.rmtree(folder)
  folder.mkdir()
  print("QUATERNIUS_OFFICIAL_SOURCE",slug,page,url,flush=True)
  files=gdown.download_folder(url=url,output=str(folder/"download"),quiet=False,use_cookies=False,remaining_ok=True)
  if not files: raise RuntimeError("No files in official public folder: "+slug)
  archives=sorted(folder.rglob("*.zip"))
  if not archives: raise RuntimeError("Official linked folder has no ZIP archive: "+slug)
  extracted=folder/"extracted"
  for i,z in enumerate(archives): safe_extract(z,extracted/f"zip_{i:02d}")
  dst=source_root/slug; dst.mkdir(parents=True)
  for p in extracted.rglob("*"):
   if p.is_file() and (p.suffix.lower() in EXTS or p.suffix.lower() in {".png",".jpg",".jpeg",".tga"}):
    q=dst/p.relative_to(extracted); q.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(p,q)
    source_files.append({"pack":slug,"source_page":page,"license":"CC0-1.0 (official pack page)","file":str(q.relative_to(source_root)),"bytes":q.stat().st_size})
 models=[p for p in source_root.rglob("*") if p.is_file() and p.suffix.lower() in EXTS]
 if not verified_packs: raise RuntimeError("No Quaternius packs passed live official CC0 license verification")
 if not models: raise RuntimeError("No model files found in official ZIP archives")
 blender=shutil.which("blender")
 if not blender: raise RuntimeError("Blender missing; cannot convert official FBX/OBJ files to GLB")
 script=CACHE/"convert.py"; report=CACHE/"models.json"
 script.write_text(r'''
import bpy,sys,json,hashlib,re
from pathlib import Path
from mathutils import Vector
src,out,report=map(Path,sys.argv[sys.argv.index("--")+1:][:3])
def slug(s):
 s=re.sub(r"[^A-Za-z0-9_-]+","_",s).strip("_").lower()
 return s or "model"
records=[]
for p in sorted(x for x in src.rglob("*") if x.is_file() and x.suffix.lower() in {".fbx",".obj",".glb",".gltf"}):
 try:
  bpy.ops.wm.read_factory_settings(use_empty=True)
  if p.suffix.lower()==".fbx": bpy.ops.import_scene.fbx(filepath=str(p),automatic_bone_orientation=False)
  elif p.suffix.lower()==".obj":
   bpy.ops.wm.obj_import(filepath=str(p)) if hasattr(bpy.ops.wm,"obj_import") else bpy.ops.import_scene.obj(filepath=str(p))
  else: bpy.ops.import_scene.gltf(filepath=str(p))
  bpy.context.view_layer.update()
  meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
  if not meshes: raise RuntimeError("no mesh")
  corners=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
  mn=Vector((min(v.x for v in corners),min(v.y for v in corners),min(v.z for v in corners)))
  mx=Vector((max(v.x for v in corners),max(v.y for v in corners),max(v.z for v in corners)))
  # Blender is Z-up; export_yup=True converts this Z_min=0 to GLB Y_min=0.
  shift=Vector((-(mn.x+mx.x)/2,-(mn.y+mx.y)/2,-mn.z))
  for o in bpy.context.scene.objects:
   if o.parent is None: o.location+=shift
  bpy.context.view_layer.update()
  corners=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
  y0=min(v.z for v in corners)
  if abs(y0)>0.002: raise RuntimeError("GLB Y_min normalization error "+str(y0))
  dims=[max(v.x for v in corners)-min(v.x for v in corners),max(v.z for v in corners)-min(v.z for v in corners),max(v.y for v in corners)-min(v.y for v in corners)]
  rel=p.relative_to(src); pack=slug(rel.parts[0]); outdir=out/pack; outdir.mkdir(parents=True,exist_ok=True)
  name=slug(p.stem)+"_"+hashlib.sha1(str(rel).encode()).hexdigest()[:8]+".glb"; target=outdir/name
  bpy.ops.export_scene.gltf(filepath=str(target),export_format="GLB",export_apply=True,export_yup=True,export_animations=False,export_materials="EXPORT")
  data=target.read_bytes()
  if data[:4]!=b"glTF": raise RuntimeError("not GLB")
  records.append({"source":str(rel),"path":str(target.relative_to(out)),"bytes":len(data),"sha256":hashlib.sha256(data).hexdigest(),"aabb_size_m":[round(x,5) for x in dims],"normalized_y_min":round(y0,6)})
  print("QUATERNIUS_V2_MODEL_PASS",rel,target,dims,flush=True)
 except Exception as e: print("QUATERNIUS_V2_MODEL_SKIP",p,repr(e),flush=True)
report.write_text(json.dumps(records,indent=2),encoding="utf-8")
if not records: raise SystemExit("No GLBs converted")
''',encoding="utf-8")
 subprocess.run([blender,"--background","--factory-startup","--python-exit-code","1","--python",str(script),"--",str(source_root),str(DEST),str(report)],check=True)
 converted=json.loads(report.read_text())
 counts={}
 for r in converted: counts[r["source"].split("/")[0]]=counts.get(r["source"].split("/")[0],0)+1
 missing=sorted(set(verified_packs)-set(counts))
 if missing: raise RuntimeError("No converted models from packs: "+", ".join(missing))
 manifest={"schema_version":2,"source":"Official Quaternius download folders linked from quaternius.com","license":"CC0-1.0 per each official pack page","normalization":"GLB; X/Z centered; world-space Y_min=0.0","packs":{k:{"page":v[0],"download_folder":v[1],"license":"CC0-1.0","author":"Quaternius"} for k,v in verified_packs.items()},"source_files":source_files,"converted_models":converted,"model_count":len(converted),"model_count_by_pack":counts}
 (DEST.parent/"quaternius_manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 (DEST.parent/"QUATERNIUS_CC0_LICENSES.txt").write_text("\n".join(f"{k}: {v[0]} | Quaternius | CC0-1.0" for k,v in verified_packs.items())+"\nModels converted from official pack ZIPs; bottom-centered at Y=0.\n",encoding="utf-8")
 print("QUATERNIUS_OFFICIAL_PACKS_PASS",len(verified_packs),"packs",len(converted),"models",counts,flush=True)
if __name__=="__main__": main()
