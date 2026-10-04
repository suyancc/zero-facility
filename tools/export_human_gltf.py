"""Bake approved MakeHuman shape into vertices before glTF export.
Usage: python export_human_gltf.py /path/to/human-styled.blend output.glb
Requires bpy; no third-party addon code is needed to export this packed source.
Godot animation is in human_rig.gd, not the embedded modeling Walk_preview clip.
"""
import sys,bpy,json
from pathlib import Path
source=Path(sys.argv[1]).resolve();destination=Path(sys.argv[2]).resolve()
bpy.ops.wm.open_mainfile(filepath=str(source))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.animation_data_clear()
for b in rig.pose.bones:b.matrix_basis.identity()
for o in list(bpy.data.objects):
 if o.type not in ['ARMATURE','MESH']:bpy.data.objects.remove(o,do_unlink=True);continue
 if o.type=='MESH' and o.data.shape_keys:
  bpy.context.view_layer.objects.active=o
  bpy.ops.object.shape_key_remove(all=True,apply_mix=True)
  print('BAKED_MORPHS',o.name)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(destination),export_format='GLB',use_selection=True,export_skins=True,export_animations=False,export_morph=False,export_apply=True)
print('RUNTIME_HUMAN',destination,destination.stat().st_size)
