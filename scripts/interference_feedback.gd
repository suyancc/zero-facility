extends Node3D
const V:=preload("res://scripts/visual_factory.gd")
var duration:float=1
var reduced:bool=false
var age:float=0
var badge:MeshInstance3D
var bar:MeshInstance3D
var circuit:MeshInstance3D
func _ready()->void:
	duration=maxf(0.01,float(get_parent().jammed))
	var image:=Image.new()
	image.load_svg_from_string("<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64'><g stroke='#99e5ff' stroke-width='5' stroke-linecap='round' fill='none'><path d='M32 8v23 M20 17a21 21 0 1 0 24 0'/><path d='M10 53l44-42' stroke='#d4f4ff' stroke-width='4'/></g></svg>")
	var material:=V.transparent_material(Color.WHITE);material.albedo_texture=ImageTexture.create_from_image(image);material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	badge=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(0.35,0.35);badge.mesh=quad;badge.material_override=material;add_child(badge);badge.position.y=2.50
	bar=MeshInstance3D.new();var strip:=QuadMesh.new();strip.size=Vector2(0.48,0.04);bar.mesh=strip
	var fill:=V.transparent_material(Color("81d7f0"));fill.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;bar.material_override=fill;add_child(bar);bar.position.y=2.25
	circuit=MeshInstance3D.new();var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for side in [-1.0,1.0]:
		var points:Array[Vector3]=[Vector3(side*0.52,0.3,0),Vector3(side*0.65,0.65,0),Vector3(side*0.45,0.91,0),Vector3(side*0.6,1.22,0)]
		for i in range(points.size()-1):mesh.surface_add_vertex(points[i]);mesh.surface_add_vertex(points[i+1])
	mesh.surface_end();circuit.mesh=mesh;circuit.material_override=V.transparent_material(Color(0.55,0.85,1,0.7));add_child(circuit)
	update_feedback(0)
func _process(delta:float)->void:update_feedback(delta)
func update_feedback(delta:float)->void:
	var device=get_parent()
	if not is_instance_valid(device) or float(device.jammed)<=0:queue_free();return
	age+=delta;bar.scale.x=clampf(float(device.jammed)/duration,0,1)
	circuit.visible=not reduced and age<0.55
	circuit.material_override.albedo_color.a=maxf(0,0.65*(1-age/0.55))
