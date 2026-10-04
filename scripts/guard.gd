extends Node3D
const Nav:=preload("res://scripts/navigation.gd")
signal contact_reported(guard:Node3D,at:Vector3)
enum Mode { PATROL, INVESTIGATE, CHASE, SEARCH, RETURN }
var mode:Mode=Mode.PATROL
var confidence:float=0
var chase_speed:float=2.1
var nav:Dictionary={}
var last_seen:Vector3=Vector3.ZERO
var last_heard:Vector3=Vector3.ZERO
var sight_lost:float=0
var search_time:float=0
var search_index:int=0
var path_points:Array[Vector3]=[]
var path_goal:Vector2i=Vector2i(-999,-999)
var intent:Label3D
var identity:int=0
var caught:bool=false
var jammed:float=0
var reduced_fx:bool=false
var alert_light:OmniLight3D
var investigation_reason:String="调查声响"
const Visual := preload("res://scripts/visual_factory.gd")
var route: Array = []
var vision_range: float = 2.3
var fov_degrees: float = 54.0
var speed: float = 0.6
var pause_duration: float = 1.2
var target_index: int = 1
var pause_remaining: float = 0.8
var heading: float = 0.0
var forward: Vector3 = Vector3.FORWARD
var visual: Node3D
var cone: MeshInstance3D
var rim: MeshInstance3D
var eye_material: StandardMaterial3D
var cone_material: StandardMaterial3D
var rim_material: StandardMaterial3D
var redraw: float = 0.0
var anim_clock: float = 0.0
var detected: bool = false

func configure(data: Dictionary) -> void:
	nav=data.get("nav",{})
	identity=data.get("id",0)
	chase_speed=data.get("chase_speed",2.1)
	route = data.route
	vision_range = data.range
	fov_degrees = data.fov
	speed = data.speed
	pause_duration = data.pause
	position = route[0]
	var dir: Vector3 = (route[1] - route[0]).normalized()
	heading = atan2(-dir.x, -dir.z)
	forward = dir

func _ready() -> void:
	visual = Node3D.new()
	add_child(visual)
	var dark := Visual.material(Color("173d50"),0.25)
	var shell := Visual.material(Color("eee6ce"),0.12)
	var blue := Visual.material(Color("4da1b6"),0.22)
	eye_material=Visual.material(Color("ffcd77"),0,true)
	Visual.rounded(visual,Vector3(0.66,0.55,0.53),Vector3(0,0.63,0),blue,0.13)
	Visual.rounded(visual,Vector3(0.85,0.56,0.63),Vector3(0,1.16,-0.025),shell,0.15)
	Visual.rounded(visual,Vector3(0.68,0.30,0.08),Vector3(0,1.16,-0.345),dark,0.025)
	for side in [-1,1]:
		Visual.rounded(visual,Vector3(0.105,0.145,0.045),Vector3(side*0.16,1.18,-0.396),eye_material,0.018)
		Visual.rounded(visual,Vector3(0.19,0.34,0.21),Vector3(side*0.43,0.65,0),shell,0.07)
		var wheel:=Visual.cylinder(visual,0.22,0.13,Vector3(side*0.31,0.22,0),dark)
		wheel.rotation.z=PI/2
		var hub:=Visual.cylinder(visual,0.10,0.145,Vector3(side*0.32,0.22,0),shell)
		hub.rotation.z=PI/2
	Visual.box(visual,Vector3(0.24,0.15,0.03),Vector3(0,0.65,-0.285),shell)
	Visual.cylinder(visual,0.027,0.2,Vector3(0.22,1.51,0),dark)
	Visual.cylinder(visual,0.073,0.085,Vector3(0.22,1.63,0),eye_material)
	cone = MeshInstance3D.new()
	rim = MeshInstance3D.new()
	add_child(cone)
	add_child(rim)
	cone_material = Visual.transparent_material(Color(1.0, 0.43, 0.06, 0.28))
	rim_material = Visual.transparent_material(Color(1.0, 0.48, 0.09, 0.95))
	cone.material_override = cone_material
	rim.material_override = rim_material
	intent=Visual.label(self,"巡逻",Vector3(0,1.98,0),Color("c5efdf"))
	alert_light=OmniLight3D.new();add_child(alert_light)
	alert_light.position.y=0.7;alert_light.omni_range=2.5;alert_light.light_color=Color("ff393b")
	alert_light.light_energy=0;alert_light.visible=false

static func in_sector(origin: Vector3, facing: Vector3, target: Vector3, distance: float, degrees: float) -> bool:
	var offset := target - origin
	offset.y = 0.0
	var length := offset.length()
	if length > distance or length < 0.02: return false
	return facing.normalized().dot(offset / length) >= cos(deg_to_rad(degrees * 0.5))

func sees_point(point: Vector3) -> bool:
	if not in_sector(global_position, forward, point, vision_range, fov_degrees): return false
	var level=get_parent().get_parent()
	if level!=null and level.has_method("sight_is_blocked") and level.sight_is_blocked(global_position,point):return false
	var eye := global_position + Vector3.UP * 1.28
	var target := point
	var query := PhysicsRayQueryParameters3D.create(eye, target, 4)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func sees(parcel: Node3D) -> bool:
	for offset in [Vector3.ZERO, Vector3(0.24,0,0), Vector3(-0.24,0,0), Vector3(0,0,0.24), Vector3(0,0,-0.24)]:
		if sees_point(parcel.global_position + Vector3.UP*float(parcel.get("vision_height")) + offset): return true
	return false

func _set_mode(value:Mode)->void:
	if mode==value:return
	mode=value
	path_points.clear()
	path_goal=Vector2i(-999,-999)
	pause_remaining=0
	if mode==Mode.SEARCH:
		search_time=6.0
		search_index=0

func hear(at:Vector3,radius:float,reason:String="调查声响")->bool:
	if global_position.distance_to(at)>radius:return false
	if mode==Mode.CHASE and sight_lost<0.6:return false
	last_heard=at
	investigation_reason=reason
	_set_mode(Mode.INVESTIGATE)
	return true

func _go_to(at:Vector3,velocity:float,delta:float)->bool:
	if nav.is_empty():return true
	var destination:=Nav.nearest(nav,at)
	if destination!=path_goal:
		path_goal=destination
		path_points=Nav.path(nav,position,Nav.world(nav,destination))
	while not path_points.is_empty() and position.distance_to(path_points[0])<0.045:
		path_points.pop_front()
	if path_points.is_empty():
		var endpoint:Vector3=at if Nav.cell(nav,at)==destination else Nav.world(nav,destination)
		endpoint.y=0
		if position.distance_to(endpoint)<0.045:return true
		path_points.append(endpoint)
	var next:Vector3=path_points[0]
	var desired:Vector3=(next-position).normalized()
	if desired.length()>0.1:
		heading=lerp_angle(heading,atan2(-desired.x,-desired.z),1-exp(-delta*6))
	position=position.move_toward(next,velocity*delta)
	return false

func update_ai(delta:float,parcel:Node3D,observable:bool)->void:
	caught=false
	if jammed>0:
		jammed=maxf(0,jammed-delta);show_jammed_visual();return
	cone.show();rim.show()
	var visible:bool=observable and sees(parcel)
	if visible:
		last_seen=parcel.global_position
		last_seen.y=0
		sight_lost=0
		confidence=minf(1.0,confidence+delta/0.65)
		if confidence>=1.0 and mode!=Mode.CHASE:
			_set_mode(Mode.CHASE)
			contact_reported.emit(self,last_seen)
	else:
		sight_lost+=delta
		confidence=maxf(0,confidence-delta*0.65)
	match mode:
		Mode.PATROL:
			if confidence>0.03:
				var direction:Vector3=(last_seen-position).normalized()
				heading=lerp_angle(heading,atan2(-direction.x,-direction.z),1-exp(-delta*5))
			elif pause_remaining>0:
				pause_remaining-=delta
				heading+=delta*0.65
			elif _go_to(route[target_index],speed,delta):
				target_index=(target_index+1)%route.size()
				pause_remaining=pause_duration
		Mode.INVESTIGATE:
			if _go_to(last_heard,speed*1.25,delta):
				last_seen=last_heard
				_set_mode(Mode.SEARCH)
		Mode.CHASE:
			_go_to(last_seen,chase_speed,delta)
			var flat:=Vector2(position.x-parcel.position.x,position.z-parcel.position.z)
			if observable and flat.length()<0.72:
				var ray:=PhysicsRayQueryParameters3D.create(position+Vector3.UP*0.7,parcel.position,4)
				caught=get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
			if not visible and sight_lost>1.5 and position.distance_to(last_seen)<1.5:
				_set_mode(Mode.SEARCH)
			elif sight_lost>4.0:_set_mode(Mode.SEARCH)
		Mode.SEARCH:
			search_time-=delta
			var offsets:Array[Vector3]=[Vector3(0,0,-1.3),Vector3(1.3,0,0),Vector3(0,0,1.3),Vector3(-1.3,0,0)]
			if _go_to(last_seen+offsets[(search_index+identity)%4],speed*0.8,delta):
				heading+=delta*1.8
				pause_remaining+=delta
				if pause_remaining>0.9:
					pause_remaining=0
					search_index+=1
			if search_time<=0:_set_mode(Mode.RETURN)
		Mode.RETURN:
			if _go_to(route[target_index],speed,delta):_set_mode(Mode.PATROL)
	forward=Vector3(-sin(heading),0,-cos(heading))
	step(delta,true)

func step(delta:float,moving:bool)->void:
	if jammed>0:show_jammed_visual();return
	intent.font_size=32
	if moving:anim_clock+=delta
	visual.position.y=sin(anim_clock*7.0)*0.025
	visual.rotation.y=heading
	visual.rotation.z=sin(anim_clock*3.5)*0.028
	var color:=Color("e2b778")
	var names:Array[String]=["巡逻",investigation_reason,"追捕！","搜索盲区","返回巡逻"]
	var label_text:String=names[mode]
	var detecting:bool=confidence>0.01 or mode==Mode.CHASE
	var pulse:float=0.65 if reduced_fx else 0.5+0.5*sin(anim_clock*TAU*1.7)
	if detecting:color=Color("ff434b")
	elif mode==Mode.SEARCH or mode==Mode.INVESTIGATE:color=Color("f9ca6b")
	elif mode==Mode.RETURN:color=Color("74b9ce")
	if confidence>0 and mode!=Mode.CHASE:label_text="确认目标 %d%%"%int(confidence*100)
	if intent.text!=label_text:intent.text=label_text
	intent.modulate=color
	eye_material.albedo_color=color;eye_material.emission=color
	cone_material.albedo_color=Color(color,0.18+pulse*0.24 if detecting else 0.16)
	rim_material.albedo_color=Color(color,0.50+pulse*0.50 if detecting else 0.7)
	alert_light.visible=detecting
	alert_light.light_energy=0.30+pulse*0.65 if detecting else 0
	redraw-=delta
	if redraw<=0:
		redraw=0.10
		_draw_vision()

func alert()->void:
	confidence=1.0
	_set_mode(Mode.CHASE)

func state_name()->String:
	return ["巡逻","调查","追捕","搜索","返回"][mode]

func _draw_vision() -> void:
	var points: Array[Vector3] = []
	for i in range(33):
		var angle := lerpf(-fov_degrees/2.0, fov_degrees/2.0, float(i)/32.0)
		var direction := forward.rotated(Vector3.UP, deg_to_rad(angle))
		var from := global_position + Vector3.UP * 1.28
		var to := from + direction * vision_range
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 4))
		var length: float = vision_range
		if not hit.is_empty(): length = maxf(0.0, from.distance_to(hit.position)-0.03)
		var level=get_parent().get_parent()
		if level!=null and level.has_method("smoke_ray_length"):length=level.smoke_ray_length(global_position,direction,length)
		points.append(direction * length + Vector3.UP * 0.035)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()-1):
		surface.add_vertex(Vector3.UP * 0.035)
		surface.add_vertex(points[i])
		surface.add_vertex(points[i+1])
	cone.mesh = surface.commit()
	var outline := ImmediateMesh.new()
	outline.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	outline.surface_add_vertex(Vector3.UP*0.045)
	for point in points: outline.surface_add_vertex(point + Vector3.UP*0.01)
	outline.surface_add_vertex(Vector3.UP*0.045)
	outline.surface_end()
	rim.mesh = outline
func show_jammed_visual()->void:
	cone.hide();rim.hide();alert_light.hide();intent.text="离线 %.1f 秒"%jammed
	intent.font_size=24;intent.modulate=Color("83d8ed");eye_material.albedo_color=Color("42738a");eye_material.emission=Color("1c394b")

