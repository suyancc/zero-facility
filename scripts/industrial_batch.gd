extends RefCounted
# Only use on a wholly static decorative subtree (sector detail / rigid patrol shell).
# Never bake articulated worker limbs, doors or interactable objects together.
static func collect(node:Node3D,at:Transform3D,buckets:Dictionary,meshes:Array)->void:
	var tr:Transform3D=at*node.transform
	if node is MeshInstance3D and node.mesh!=null and node.visible:
		var mat:Material=node.material_override
		if mat!=null:
			var key:int=mat.get_instance_id()
			if not buckets.has(key):
				var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_material(mat);buckets[key]=tool
			for surface in range(node.mesh.get_surface_count()):
				buckets[key].append_from(node.mesh,surface,tr)
			meshes.append(node)
	for child in node.get_children():
		if child is Node3D:collect(child,tr,buckets,meshes)
static func bake(node:Node3D)->void:
	var buckets:Dictionary={};var meshes:Array=[]
	for child in node.get_children():
		if child is Node3D:collect(child,Transform3D.IDENTITY,buckets,meshes)
	for key in buckets:
		var mesh:=MeshInstance3D.new();mesh.mesh=buckets[key].commit();node.add_child(mesh)
	for mesh in meshes:mesh.get_parent().remove_child(mesh);mesh.free()

