extends RefCounted
static var cache: Dictionary = {}
static var shapes:Dictionary={}

static func material(color: Color, metal: float = 0.0, glow: bool = false) -> StandardMaterial3D:
	var key := str(color)+str(metal)+str(glow)
	# Unique glowing materials are intentionally not shared (guard alerts).
	if not glow and cache.has(key): return cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.58
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.32
	else: cache[key] = mat
	return mat

static func transparent_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	return mat

static func box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, collision: bool = false, layer: int = 4) -> Node3D:
	var holder: Node3D = StaticBody3D.new() if collision else Node3D.new()
	parent.add_child(holder)
	holder.position = at
	var mesh := MeshInstance3D.new()
	var geometry := BoxMesh.new()
	geometry.size = size
	mesh.mesh = geometry
	mesh.material_override = mat
	holder.add_child(mesh)
	if collision:
		holder.collision_layer = layer
		holder.collision_mask = 2
		var physics := PhysicsMaterial.new()
		physics.friction = 0.12
		physics.bounce = 0.02
		holder.physics_material_override = physics
		var shape := CollisionShape3D.new()
		var form := BoxShape3D.new()
		form.size = size
		shape.shape = form
		holder.add_child(shape)
	return holder

static func cylinder(parent: Node3D, radius: float, height: float, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var form := CylinderMesh.new()
	form.top_radius = radius
	form.bottom_radius = radius
	form.height = height
	form.radial_segments = 20
	mesh.mesh = form
	mesh.material_override = mat
	parent.add_child(mesh)
	mesh.position = at
	return mesh

static func _bounds(node: Node3D, transform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var total := AABB()
	var actual := transform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		total = actual * node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var b := _bounds(child, actual)
			if b.size.length() > 0.001:
				total = b if total.size.length() < 0.001 else total.merge(b)
	return total

static func asset(parent: Node3D, name: String, at: Vector3, width: float, angle: float = 0.0) -> Node3D:
	var scene: PackedScene = load("res://assets/models/factory/"+name+".glb")
	var model: Node3D = scene.instantiate()
	var bounds := _bounds(model)
	var scale_factor: float = width / maxf(maxf(bounds.size.x, bounds.size.z), 0.01)
	var pivot := Node3D.new()
	parent.add_child(pivot)
	pivot.position = at
	pivot.rotation.y = angle
	pivot.add_child(model)
	model.scale *= scale_factor
	model.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z) * scale_factor
	return pivot
static func rounded(parent: Node3D, size: Vector3, at: Vector3, mat: Material, radius: float = 0.09) -> MeshInstance3D:
	var key:=str(size)+str(radius)
	if shapes.has(key):
		var cached:=MeshInstance3D.new()
		cached.mesh=shapes[key]
		cached.material_override=mat
		parent.add_child(cached)
		cached.position=at
		return cached
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half:=size*0.5
	var core:=half-Vector3.ONE*radius
	for normal in [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]:
		var u:Vector3=Vector3.RIGHT if absf(normal.y)>0.5 else normal.cross(Vector3.UP)
		var v:Vector3=normal.cross(u)
		for x in range(6):
			for y in range(6):
				for offset in [Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(1,0)]:
					var p:Vector3=(normal+u*((x+offset.x)/3.0-1.0)+v*((y+offset.y)/3.0-1.0))*half
					var c:=p.clamp(-core,core)
					var n:Vector3=(p-c).normalized()
					surface.set_normal(n)
					surface.add_vertex(c+n*radius)
	var mesh:=MeshInstance3D.new()
	mesh.mesh=surface.commit()
	shapes[key]=mesh.mesh
	mesh.material_override=mat
	parent.add_child(mesh)
	mesh.position=at
	return mesh

static func label(parent:Node3D,text:String,at:Vector3,color:Color=Color.WHITE)->Label3D:
	var l:=Label3D.new()
	l.font=load("res://assets/fonts/TensionSansSC.ttf")
	l.text=text
	l.font_size=32
	l.pixel_size=0.014
	l.outline_size=4
	l.modulate=color
	l.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test=true
	parent.add_child(l)
	l.position=at
	return l

