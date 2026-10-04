extends RefCounted
const V:=preload("res://scripts/visual_factory.gd")
static func ring_mesh(radius:float=1.0,width:float=0.008,dashed:bool=true)->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(96):
		if dashed and i%6>=4:continue
		var a:float=TAU*float(i)/96;var b:float=TAU*float(i+1)/96
		var p:=Vector3(cos(a),0,sin(a));var q:=Vector3(cos(b),0,sin(b))
		for point in [p*(radius-width),p*(radius+width),q*(radius+width),p*(radius-width),q*(radius+width),q*(radius-width)]:surface.add_vertex(point)
	return surface.commit()
static func burst(parent:Node3D,at:Vector3,color:Color,radius:float,reduced:bool)->void:
	var ring:=MeshInstance3D.new();ring.mesh=ring_mesh(radius,0.02,false)
	var material:=V.transparent_material(Color(color,0.5 if reduced else 0.7));ring.material_override=material
	parent.add_child(ring);ring.position=at+Vector3.UP*0.07;ring.scale=Vector3.ONE*(1 if reduced else 0.12)
	var tween:=parent.create_tween().set_parallel(true)
	tween.tween_property(ring,"scale",Vector3.ONE,0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material,"albedo_color:a",0.0,0.65)
	tween.chain().tween_callback(ring.queue_free)
static func smoke(parent:Node3D,at:Vector3)->Node3D:
	var node:=Node3D.new();parent.add_child(node);node.position=at
	var shader:=Shader.new();shader.code="""
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform float age=0.0;
uniform float fade=0.0;
uniform float phase=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);}
void fragment(){
vec2 p=UV*2.0-1.0;
vec2 drift=vec2(age*0.10,-age*0.14)+phase;
float n=noise(UV*4.0+drift)*0.6+noise(UV*9.0-drift)*0.3+noise(UV*18.0+drift)*0.1;
float edge=1.0-smoothstep(0.30+n*0.20,1.0,length(p*vec2(1.0,0.95)));
ALBEDO=mix(vec3(0.35,0.46,0.52),vec3(0.72,0.79,0.81),n);
ALPHA=edge*smoothstep(0.16,0.74,n)*fade*0.42;
}
"""
	for i in range(3):
		var puff:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(4.4,2.9)
		var mat:=ShaderMaterial.new();mat.shader=shader;mat.set_shader_parameter("phase",float(i)*3.71)
		puff.mesh=quad;puff.material_override=mat;node.add_child(puff);puff.position=Vector3((i-1)*0.16,1.05+float(i)*0.06,(i-1)*0.12)
	V.cylinder(node,0.07,0.16,Vector3.UP*0.09,V.material(Color("78949b"),0.3))
	return node
static func tick_smoke(node:Node3D,life:float,reduced:bool)->void:
	var age:float=6-life;var fade:float=minf(clampf(age/0.3,0,1),clampf(life/1.1,0,1))
	for child in node.get_children():
		if child is MeshInstance3D and child.material_override is ShaderMaterial:
			child.material_override.set_shader_parameter("age",0.8 if reduced else age)
			child.material_override.set_shader_parameter("fade",fade)

static func throw_point(from:Vector3,to:Vector3,t:float)->Vector3:
	t=clampf(t,0,1)
	return from.lerp(to,t)+Vector3.UP*sin(PI*t)
static func arc_mesh(points:Array[Vector3])->ImmediateMesh:
	var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(points.size()-1):
		if i%3==2:continue
		mesh.surface_add_vertex(points[i]);mesh.surface_add_vertex(points[i+1])
	mesh.surface_end();return mesh
static func canister(parent:Node3D,at:Vector3)->Node3D:
	var node:=Node3D.new();parent.add_child(node);node.position=at
	var art:=preload("res://scripts/item_models.gd").spawn("smoke");node.add_child(art);art.scale=Vector3.ONE*0.30;art.position.y=-0.10
	return node
static func mark_device(device:Node3D,reduced:bool)->void:
	var old:=device.get_node_or_null("InterferenceFeedback")
	if old!=null:device.remove_child(old);old.queue_free()
	var feedback:=Node3D.new();feedback.name="InterferenceFeedback";feedback.set_script(preload("res://scripts/interference_feedback.gd"));feedback.reduced=reduced;device.add_child(feedback)

