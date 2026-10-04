extends PanelContainer
const UI:=preload("res://scripts/ui_theme.gd")
const Models:=preload("res://scripts/item_models.gd")
const Tile:=preload("res://scripts/gear_tile.gd")
const DETAILS:Dictionary={"smoke":"拉环式烟雾罐\n落地后起雾，阻挡视线 6 秒。","jammer":"双天线电磁干扰器\n暂停附近设备，不清除警报。","pick":"折叠式精密撬锁组\n长按操作门锁，完成才消耗。","decoy":"便携式声响诱饵\n投出后间歇发声，引开巡检。"}
var thumbnail_export:bool=false
var thumbnail_wait:float=0
var thumbnail_done:String=""
var viewport:SubViewport
var stage:Node3D
var model:Node3D
var title:Label
var badge:Label
var detail:Label
var kind:String=""
var slot:int=0
var reduced:bool=false
var enabled:bool=false
var selection_tween:Tween
var pedestal_material:StandardMaterial3D
func _ready()->void:
	if OS.has_feature("web"):thumbnail_export=bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('bake_items') === '1'"))
	add_theme_stylebox_override("panel",UI.panel(Color(0.035,0.085,0.115,0.96),16,12,Color("6ba9b7")))
	var layout:=VBoxContainer.new();layout.add_theme_constant_override("separation",10);add_child(layout)
	badge=UI.text("当前选中 · 格子 1",13,UI.ORANGE);layout.add_child(badge)
	title=UI.text("烟雾罐",23);layout.add_child(title)
	var container:=SubViewportContainer.new();container.custom_minimum_size=Vector2(250,240);container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;layout.add_child(container)
	viewport=SubViewport.new();viewport.size=Vector2i(500,480);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;container.add_child(viewport)
	stage=Node3D.new();viewport.add_child(stage)
	var world:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("0c1b26");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("91b6cc");env.ambient_light_energy=0.7;world.environment=env;stage.add_child(world)
	var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-42,-32,0);key.light_energy=1.7;key.shadow_enabled=true;stage.add_child(key)
	var fill:=OmniLight3D.new();fill.position=Vector3(-1.4,1.3,1);fill.light_color=Color("ffd6a5");fill.light_energy=0.6;fill.omni_range=4;stage.add_child(fill)
	var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(1.35,1.25,2.4);camera.look_at(Vector3(0,0.48,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.65;camera.current=true
	var V:=preload("res://scripts/visual_factory.gd")
	V.cylinder(stage,0.58,0.065,Vector3(0,-0.04,0),V.material(Color("233d4d"),0.3))
	pedestal_material=V.material(Color("e5b56b"),0,true).duplicate()
	Models.ring(stage,0.59,0.008,Vector3(0,0.006,0),pedestal_material)
	if thumbnail_export:
		viewport.transparent_bg=true;env.background_mode=Environment.BG_CLEAR_COLOR
		for child in stage.get_children():
			if child is MeshInstance3D:child.hide()
	detail=UI.text("",14,UI.MUTED);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.custom_minimum_size=Vector2(250,55);layout.add_child(detail)
func set_item(value:String,index:int,reduce:bool)->void:
	reduced=reduce or thumbnail_export
	if kind==value and slot==index:return
	kind=value;slot=index;thumbnail_wait=0.5
	title.text=Tile.NAMES[kind];badge.text="当前选中 · 已装入格子 %d"%(slot+1);detail.text=DETAILS[kind]
	if is_instance_valid(selection_tween):selection_tween.kill()
	if is_instance_valid(model):stage.remove_child(model);model.queue_free()
	model=Models.spawn(kind);stage.add_child(model);model.rotation.y=-0.2
	pedestal_material.albedo_color=Color(Models.COLORS[kind]);pedestal_material.emission=pedestal_material.albedo_color
	if not reduced:
		model.scale=Vector3.ONE*0.84
		selection_tween=create_tween();selection_tween.tween_property(model,"scale",Vector3.ONE,0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
func set_enabled(value:bool)->void:
	enabled=value;visible=value
	if viewport!=null:viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
func _process(delta:float)->void:
	if enabled and is_instance_valid(model) and not reduced:model.rotation.y+=delta*0.20
	if thumbnail_export and enabled and thumbnail_done!=kind:
		thumbnail_wait-=delta
		if thumbnail_wait<=0:
			var image:Image=viewport.get_texture().get_image()
			if image!=null and not image.is_empty():
				JavaScriptBridge.eval("window.__equipmentThumbnail="+JSON.stringify({"kind":kind,"png":Marshalls.raw_to_base64(image.save_png_to_buffer())}))
				thumbnail_done=kind

