extends SubViewportContainer
var viewport:SubViewport
var model:Node3D
var active:bool=false
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;stretch=true
	viewport=SubViewport.new();viewport.size=Vector2i(380,510);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
	var world:=Node3D.new();viewport.add_child(world)
	var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_CLEAR_COLOR;env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("b8c9d1");env.ambient_light_energy=0.8;environment.environment=env;world.add_child(environment)
	var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-28,-28,0);key.light_energy=1.5;world.add_child(key)
	var rim:=DirectionalLight3D.new();rim.rotation_degrees=Vector3(-30,140,0);rim.light_color=Color("69d7ff");rim.light_energy=0.6;world.add_child(rim)
	model=load("res://scenes/characters/maintenance_worker.scn").instantiate();world.add_child(model);model.rotation.y=0.26
	model.get_node("TorsoPivot/Head").rotation.y=-0.10
	for prefix in ["Left","Right"]:
		model.get_node("TorsoPivot/"+prefix+"UpperArm/"+prefix+"Forearm").rotation.x=0.18
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,1.15,-3.8);camera.look_at(Vector3(0,0.9,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.15;camera.current=true
func set_enabled(value:bool)->void:
	if active==value:return
	active=value;visible=value
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE if value else SubViewport.UPDATE_DISABLED

