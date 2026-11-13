#!/usr/bin/env python3
"""Download the public CC0 OpenGameArt modular-temple ZIPs and convert OBJ parts to normalized GLB."""
from __future__ import annotations
import hashlib,json,re,shutil,subprocess,urllib.request,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/"assets"/"wuxia_imperial_pack"
OUT=DEST/"opengameart_temple"
SOURCES=DEST/"sources"/"opengameart"
PAGE="https://opengameart.org/content/modular-temple-3d-models"
LICENSE="https://creativecommons.org/publicdomain/zero/1.0/"
FILES={
 "temple_collection.zip":"https://opengameart.org/sites/default/files/temple_collection.zip",
 "modular_temple_collection.zip":"https://opengameart.org/sites/default/files/modular_temple_collection.zip",
}
UA="New-Conquer-Offline-Wuxia-Asset-Restore/1.0"
def fetch(url: str,path: Path) -> bytes:
 req=urllib.request.Request(url,headers={"User-Agent":UA})
 with urllib.request.urlopen(req,timeout=180) as response:
  data=response.read()
 path.parent.mkdir(parents=True,exist_ok=True); path.write_bytes(data)
 return data
def safe_extract(archive: Path,target: Path) -> None:
 target_resolved=target.resolve()
 with zipfile.ZipFile(archive) as z:
  bad=z.testzip()
  if bad: raise RuntimeError(f"OpenGameArt ZIP CRC failure: {bad}")
  for info in z.infolist():
   dest=(target/info.filename).resolve()
   if target_resolved not in dest.parents and dest!=target_resolved:
    raise RuntimeError("Unsafe OpenGameArt ZIP path: "+info.filename)
  z.extractall(target)
def main():
 page=fetch(PAGE,ROOT/"reports"/"opengameart_modular_temple_page.html").decode("utf-8","ignore")
 if "CC0" not in page or "Keith at Fertile Soil Productions" not in page:
  raise RuntimeError("OpenGameArt source page did not verify the expected creator and CC0 license")
 SOURCES.mkdir(parents=True,exist_ok=True); OUT.mkdir(parents=True,exist_ok=True)
 extracted=ROOT/"reports"/"opengameart_modular_temple_extracted"
 if extracted.exists(): shutil.rmtree(extracted)
 extracted.mkdir(parents=True)
 archives={}
 for name,url in FILES.items():
  archive=SOURCES/name
  data=fetch(url,archive)
  if not zipfile.is_zipfile(archive): raise RuntimeError("OpenGameArt returned a non-ZIP archive: "+name)
  digest=hashlib.sha256(data).hexdigest()
  archives[name]={"url":url,"bytes":len(data),"sha256":digest}
  safe_extract(archive,extracted/name.removesuffix(".zip"))
 obj_files=sorted(extracted.rglob("*.obj"))
 if not obj_files: raise RuntimeError("No OBJ models were found in the OpenGameArt modular temple ZIPs")
 blender_script=ROOT/"tools"/"_convert_opengameart_obj_to_glb.py"
 blender_script.write_text(r'''
import bpy,sys,re,hashlib,json
from pathlib import Path
from mathutils import Vector
args=sys.argv[sys.argv.index("--")+1:]
src=Path(args[0]); out=Path(args[1]); out.mkdir(parents=True,exist_ok=True)
records=[]
def slug(text):
 text=re.sub(r"[^a-z0-9]+","_",text.lower()).strip("_")
 return text[:90] or "temple_part"
for obj_path in sorted(src.rglob("*.obj")):
 bpy.ops.wm.read_factory_settings(use_empty=True)
 if hasattr(bpy.ops.wm,"obj_import"):
  bpy.ops.wm.obj_import(filepath=str(obj_path))
 else:
  bpy.ops.import_scene.obj(filepath=str(obj_path))
 selected=list(bpy.context.selected_objects)
 if not selected:
  selected=list(bpy.context.scene.objects)
 meshes=[o for o in selected if o.type=="MESH"]
 if not meshes: continue
 depsgraph=bpy.context.evaluated_depsgraph_get()
 corners=[]
 for obj in meshes:
  evaluated=obj.evaluated_get(depsgraph)
  corners.extend([obj.matrix_world @ Vector(corner) for corner in evaluated.bound_box])
 if not corners: continue
 min_v=Vector((min(v.x for v in corners),min(v.y for v in corners),min(v.z for v in corners)))
 max_v=Vector((max(v.x for v in corners),max(v.y for v in corners),max(v.z for v in corners)))
 shift=Vector((-(min_v.x+max_v.x)/2,-(min_v.y+max_v.y)/2,-min_v.z))
 selected_set=set(selected)
 roots=[o for o in selected if o.parent not in selected_set]
 for obj in roots: obj.location+=shift
 scene_name=slug("_".join(obj_path.relative_to(src).with_suffix("").parts))
 dest=out/(scene_name+".glb")
 bpy.ops.object.select_all(action="DESELECT")
 for obj in selected: obj.select_set(True)
 bpy.context.view_layer.objects.active=selected[0]
 bpy.ops.export_scene.gltf(filepath=str(dest),export_format="GLB",use_selection=True,export_yup=True,export_apply=True)
 data=dest.read_bytes()
 if len(data)<20 or data[:4]!=b"glTF": raise RuntimeError("Invalid OpenGameArt GLB: "+str(dest))
 records.append({"name":obj_path.stem,"file":dest.name,"bytes":len(data),"sha256":hashlib.sha256(data).hexdigest(),"blender_z_min_before_yup_export":0.0,"mesh_parts":len(meshes)})
(out/"conversion_manifest.json").write_text(json.dumps({"creator":"Keith at Fertile Soil Productions","license":"CC0-1.0","source":"https://opengameart.org/content/modular-temple-3d-models","models":records},indent=2)+"\n")
print("OPENGAMEART_TEMPLE_CONVERSION_PASS",len(records),"GLB models")
''',encoding="utf-8")
 subprocess.run(["blender","--background","--python",str(blender_script),"--",str(extracted),str(OUT)],check=True)
 conversion=json.loads((OUT/"conversion_manifest.json").read_text(encoding="utf-8"))
 if not conversion.get("models"): raise RuntimeError("OpenGameArt Blender conversion produced no GLB files")
 manifest={"provider":"OpenGameArt","pack":"Modular Temple - 3D Models","creator":"Keith at Fertile Soil Productions","license":"CC0-1.0","license_url":LICENSE,"source":PAGE,"archives":archives,"models":conversion["models"]}
 (DEST/"opengameart_manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 (OUT/"LICENSE_CC0.txt").write_text(f"Modular Temple - 3D Models by Keith at Fertile Soil Productions\n{PAGE}\nCC0 1.0 Universal: {LICENSE}\n",encoding="utf-8")
 print(f"OPENGAMEART_TEMPLE_PASS: models={len(conversion['models'])} creator=Keith_at_Fertile_Soil_Productions CC0=verified")
if __name__=="__main__": main()
