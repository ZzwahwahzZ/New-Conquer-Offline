import bpy,sys,json,argparse,math
from pathlib import Path
from mathutils import Vector
argv=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
p=argparse.ArgumentParser(); p.add_argument("--input",required=True); p.add_argument("--output",required=True); a=p.parse_args(argv)
src=Path(a.input); dst=Path(a.output); dst.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True); ext=src.suffix.lower()
if ext==".blend": bpy.ops.wm.open_mainfile(filepath=str(src))
elif ext in (".glb",".gltf"): bpy.ops.import_scene.gltf(filepath=str(src))
elif ext==".fbx": bpy.ops.import_scene.fbx(filepath=str(src))
elif ext==".obj": bpy.ops.wm.obj_import(filepath=str(src))
elif ext==".dae": bpy.ops.wm.collada_import(filepath=str(src))
elif ext==".stl": bpy.ops.wm.stl_import(filepath=str(src))
elif ext==".ply": bpy.ops.wm.ply_import(filepath=str(src))
else: raise RuntimeError("Unsupported input format "+ext)
meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
if not meshes: raise RuntimeError("No mesh objects")
bpy.context.view_layer.update()
pts=[o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
minz=min(v.z for v in pts)
for o in [x for x in bpy.context.scene.objects if x.parent is None]: o.location.z-=minz
bpy.context.view_layer.update()
bpy.ops.export_scene.gltf(filepath=str(dst),export_format="GLB",export_yup=True,export_apply=False,export_materials="EXPORT",export_cameras=False,export_lights=False)
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=str(dst))
meshes2=[o for o in bpy.context.scene.objects if o.type=="MESH"]
if len(meshes2)!=len(meshes): raise RuntimeError("Mesh count mismatch after GLB round-trip")
pts2=[o.matrix_world @ Vector(c) for o in meshes2 for c in o.bound_box]
if not pts2: raise RuntimeError("Empty GLB geometry")
miny=min(v.y for v in pts2); dims=[max(v[i] for v in pts2)-min(v[i] for v in pts2) for i in range(3)]
if abs(miny)>1e-4: raise RuntimeError("Ground plane mismatch; min Y="+str(miny))
if any(not math.isfinite(x) or x<=1e-6 for x in dims): raise RuntimeError("Invalid dimensions")
mats=sum(1 for m in bpy.data.materials)
if mats==0: raise RuntimeError("No materials survived GLB export")
if dst.stat().st_size<1024: raise RuntimeError("GLB unexpectedly small")
(dst.with_suffix(".json")).write_text(json.dumps({"mesh_count":len(meshes2),"object_count":len(bpy.context.scene.objects),"material_count":mats,"dimensions_m":dims,"min_y":miny,"validated":True},indent=2))
