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
# glTF defines linear dimensions in meters. Native Blender files must explicitly declare Metric units.
if ext in (".glb",".gltf"): unit_factor=1.0; assumed_meter_scale=False
elif ext==".blend" and bpy.context.scene.unit_settings.system=="METRIC":
 unit_factor=float(bpy.context.scene.unit_settings.scale_length)
 assumed_meter_scale=False
 if not math.isfinite(unit_factor) or unit_factor<=0: raise RuntimeError("Invalid Blender metric scale_length")
else:
 # Explicit fallback for source files with unspecified units: one Blender unit = one meter.
 unit_factor=1.0
 assumed_meter_scale=True
for obj in bpy.context.scene.objects:
 if obj.type=="MESH":
  for vert in obj.data.vertices: vert.co*=unit_factor
 obj.location*=unit_factor
objects_before=list(bpy.context.scene.objects)
meshes=[o for o in objects_before if o.type=="MESH"]
if not meshes: raise RuntimeError("No mesh objects")
hierarchy_before=sum(1 for o in objects_before if o.parent is not None)
materials_before=sum(1 for m in bpy.data.materials)
bpy.context.view_layer.update()
pts=[o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
minz=min(v.z for v in pts)
for o in [x for x in bpy.context.scene.objects if x.parent is None]: o.location.z-=minz
bpy.context.view_layer.update()
bpy.ops.export_scene.gltf(filepath=str(dst),export_format="GLB",export_yup=True,export_apply=False,export_materials="EXPORT",export_cameras=False,export_lights=False)
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=str(dst))
objects_after=list(bpy.context.scene.objects)
meshes2=[o for o in objects_after if o.type=="MESH"]
hierarchy_after=sum(1 for o in objects_after if o.parent is not None)
if len(meshes2)!=len(meshes): raise RuntimeError("Mesh count mismatch after GLB round-trip")
if len(objects_after)!=len(objects_before) or hierarchy_after!=hierarchy_before:
 raise RuntimeError("Object hierarchy changed during GLB round-trip")
pts2=[o.matrix_world @ Vector(c) for o in meshes2 for c in o.bound_box]
if not pts2: raise RuntimeError("Empty GLB geometry")
miny=min(v.y for v in pts2)
# Correct the exported glTF Y-up ground offset after round-trip. This is a rigid
# scene-root translation; it preserves mesh geometry, scale, and parent hierarchy.
if abs(miny)>1e-4:
 for root in [o for o in objects_after if o.parent is None]:
  root.location.y-=miny
 bpy.context.view_layer.update()
 bpy.ops.export_scene.gltf(filepath=str(dst),export_format="GLB",export_yup=True,export_apply=False,export_materials="EXPORT",export_cameras=False,export_lights=False)
 bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=str(dst))
 objects_after=list(bpy.context.scene.objects)
 meshes2=[o for o in objects_after if o.type=="MESH"]
 hierarchy_after=sum(1 for o in objects_after if o.parent is not None)
 pts2=[o.matrix_world @ Vector(c) for o in meshes2 for c in o.bound_box]
 miny=min(v.y for v in pts2)
if abs(miny)>1e-4: raise RuntimeError("Ground plane mismatch after root correction; min Y="+str(miny))
dims=[max(v[i] for v in pts2)-min(v[i] for v in pts2) for i in range(3)]
if any(not math.isfinite(x) or x<0.05 or x>80.0 for x in dims): raise RuntimeError("Bounding-box dimensions outside accepted 0.05m..80m range: "+str(dims))
mats=sum(1 for m in bpy.data.materials)
if mats==0: raise RuntimeError("No materials survived GLB export")
if mats!=materials_before: raise RuntimeError("Material count changed during GLB round-trip")
missing_images=[im.name for im in bpy.data.images if im.source=="FILE" and (im.size[0]==0 or im.size[1]==0)]
if missing_images: raise RuntimeError("Missing/invalid texture image data: "+", ".join(missing_images))
if dst.stat().st_size<1024: raise RuntimeError("GLB unexpectedly small")
(dst.with_suffix(".json")).write_text(json.dumps({"mesh_count":len(meshes2),"object_count":len(objects_after),"hierarchy_parent_links":hierarchy_after,"material_count":mats,"dimensions_m":dims,"min_y":miny,"assumed_meter_scale":assumed_meter_scale,"unit_scale_m_per_blender_unit":unit_factor,"human_reference_height_m":1.75,"height_in_human_units":round(dims[1]/1.75,4),"scale_policy":"metric real-world scale; preserve source proportions; shared 1.75m human reference; no arbitrary per-asset resize","axis_conversion":"Blender Z-up to glTF Y-up via glTF exporter","validated":True},indent=2))
