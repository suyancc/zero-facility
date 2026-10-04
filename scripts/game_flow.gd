extends Node3D
const Generator:=preload("res://scripts/level_generator.gd")
const Builder:=preload("res://scripts/level_builder.gd")
const Store:=preload("res://scripts/progress_store.gd")
const V:=preload("res://scripts/visual_factory.gd")
enum State { READY, PLAYING, PAUSED, WON, LOST }
var state:State=State.READY
var level:Node3D
var muted:bool=false
var attempt:int=0
var stage:int=1
var settings_data:Dictionary={"stage":1,"volume":0.65,"muted":false,"reduced":false,"records":{}}
var test_mode:bool=false
var tactical_mode:bool=true
var selected_gear:Array[String]=["smoke","pick"]
var shake:float=0
var tension:=preload("res://scripts/tension_director.gd").new()
var tension_alerts:int=0
var qa_enabled:bool=false
var qa_clock:float=0
var impact_count:int=0
var camera_focus:Vector3=Vector3.ZERO
var toast_time:float=0
var arc:MeshInstance3D
var target_marker:MeshInstance3D
var arc_clock:float=0
var aim_valid:bool=true
var aim_cached:Vector3=Vector3.ZERO
var aim_from:Vector3=Vector3.ZERO
var aim_obstacles:int=-1
var aim_steps:int=0
var aim:MeshInstance3D
@onready var hud:CanvasLayer=$HUD
@onready var camera:Camera3D=$Camera3D
@onready var audio:Node=$Audio
func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	_setup_input();camera.look_at(Vector3.ZERO)
	get_window().title="零号设施 · 潜行逃生"
	if not test_mode:settings_data=Store.read()
	stage=settings_data.stage;muted=settings_data.muted;audio.master=settings_data.volume
	audio.music_level=float(settings_data.get("music_volume",0.8));audio.heartbeat_level=float(settings_data.get("heartbeat_volume",0.75))
	hud.music_slider.set_value_no_signal(audio.music_level);hud.heartbeat_slider.set_value_no_signal(audio.heartbeat_level);hud.edge_toggle.set_pressed_no_signal(bool(settings_data.get("edge_heartbeat",true)))
	hud.music_changed.connect(func(v:float):audio.music_level=v;settings_data.music_volume=v;_save())
	hud.heartbeat_changed.connect(func(v:float):audio.heartbeat_level=v;settings_data.heartbeat_volume=v;_save())
	hud.edge_changed.connect(func(v:bool):settings_data.edge_heartbeat=v;_save())
	AudioServer.set_bus_mute(0,muted)
	hud.volume_slider.set_value_no_signal(settings_data.volume)
	hud.motion_toggle.set_pressed_no_signal(settings_data.reduced)
	hud.reduced_motion=settings_data.reduced;hud.mute_button.text="声音关" if muted else "声音开"
	hud.tracking_pressed.connect(_cycle_tracking)
	hud.gear_focused.connect(func(slot:int):
		audio.unlock();audio.click()
		if tactical_mode and is_instance_valid(level):level.selected_slot=slot)
	hud.gear_changed.connect(func(values:Array[String]):
		audio.unlock();audio.click()
		if state==State.READY and tactical_mode:selected_gear=values;level.set_loadout(values))
	hud.primary_pressed.connect(_primary);hud.practice_pressed.connect(_practice)
	hud.retry_pressed.connect(retry);hud.pause_pressed.connect(toggle_pause);hud.mute_pressed.connect(toggle_mute)
	hud.settings_opened.connect(func():audio.click();_open_settings())
	hud.volume_changed.connect(func(value:float):audio.master=value;settings_data.volume=value;_save())
	hud.motion_changed.connect(func(value:bool):
		settings_data.reduced=value
		if is_instance_valid(level):
			for guard in level.guards:guard.reduced_fx=value
		_save())
	if OS.has_feature("web"):
		qa_enabled=bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa') === '1'"))
		if qa_enabled:
			var qa_stage:int=int(JavaScriptBridge.eval("Number(new URLSearchParams(location.search).get('stage') || 0)"))
			if qa_stage>0:test_mode=true;stage=clampi(qa_stage,1,10000)
		JavaScriptBridge.eval("document.title='零号设施 · 潜行逃生'")
	load_level()
func _setup_input()->void:
	var mapping:Dictionary={"gravity_left":[KEY_A,KEY_LEFT],"gravity_right":[KEY_D,KEY_RIGHT],"gravity_up":[KEY_W,KEY_UP],"gravity_down":[KEY_S,KEY_DOWN]}
	for action in mapping:
		if not InputMap.has_action(action):
			InputMap.add_action(action,0.02)
			for key in mapping[action]:
				var event:=InputEventKey.new();event.physical_keycode=key;InputMap.action_add_event(action,event)
func load_level()->void:
	get_tree().paused=false;_release_input();audio.stop_effects();tension.reset();tension_alerts=0;shake=0;impact_count=0
	if is_instance_valid(level):remove_child(level);level.queue_free()
	var data:Dictionary=preload("res://scripts/tactical_generator.gd").generate(stage) if tactical_mode else Generator.generate(stage)
	level=Builder.build(data);level.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(level);level.camera=camera
	level.completed.connect(_completed);level.failed.connect(_failed);level.impact.connect(_impact)
	level.scanned.connect(func():
		if not tactical_mode:audio.tone(880,0.18,-12)
		hud.feedback(Color("6eddd0")))
	level.notice.connect(_notice)
	if tactical_mode:
		level.gear_sound.connect(func(kind:String):audio.gadget(kind))
		level.task_event.connect(audio.task_event)
		level.download_audio.connect(audio.set_download_active)
		level.operation_audio.connect(audio.set_operation)
	else:level.decoy_used.connect(func():audio.tone(660,0.09,-17))
	if tactical_mode:level.set_loadout(selected_gear)
	level.foot_sound.connect(func(radius:float):audio.step_sound(radius))
	level.spotted.connect(func(_at:Vector3):pass)
	for guard in level.guards:guard.reduced_fx=settings_data.reduced
	attempt+=1;state=State.READY
	hud.set_stage(stage,data.title,data.guards.size())
	hud.show_message("本局目标 · "+str(data.variant_title) if tactical_mode else "离开这座设施。",level.mission_brief(),"开始逃生 · 空格")
	hud.toast.text=""
	hud.show_equipment(tactical_mode,selected_gear)
	camera_focus=Vector3(clampf(data.start.x,-7,7),0,clampf(data.start.z,-5,5))
	camera.position=Vector3(10,15,18)+camera_focus;camera.size=16.5
	aim=MeshInstance3D.new();aim.mesh=preload("res://scripts/gadget_fx.gd").ring_mesh()
	aim.material_override=V.transparent_material(Color(0.40,0.78,0.88,0.23));level.add_child(aim);aim.hide()
	arc=MeshInstance3D.new();arc.material_override=V.transparent_material(Color(0.60,0.90,0.91,0.5));level.add_child(arc);arc.hide();arc_clock=0;aim_obstacles=-1;aim_steps=0
	target_marker=MeshInstance3D.new();target_marker.mesh=preload("res://scripts/gadget_fx.gd").ring_mesh(0.5,0.012,true)
	target_marker.material_override=V.transparent_material(Color(1.0,0.73,0.40,0.65));level.add_child(target_marker);target_marker.hide()

func _cycle_tracking()->void:
	if tactical_mode and state in [State.READY,State.PLAYING]:level.cycle_target();audio.unlock();audio.click()
func _notice(text:String)->void:hud.toast.text=text;toast_time=3.5
func _primary()->void:
	audio.unlock()
	match state:
		State.READY:state=State.PLAYING;level.start();hud.hide_message();audio.click()
		State.PAUSED:get_tree().paused=false;audio.set_task_paused(false);state=State.PLAYING;hud.hide_message();audio.click()
		State.WON:stage+=1;attempt=0;load_level()
		State.LOST:retry()
func retry()->void:audio.unlock();load_level();audio.click()
func _practice()->void:stage=1;attempt=0;load_level();_notice("练习首区 · 原进度已保留")
func toggle_pause()->void:
	if state==State.PLAYING:
		state=State.PAUSED;get_tree().paused=true;_release_input();audio.set_task_paused(true)
		hud.show_message("暂时安全。","人物、巡检和计时都已暂停。","继续逃生 · 空格","paused")
	elif state==State.PAUSED:_primary()
func _open_settings()->void:
	if state==State.PLAYING:toggle_pause()
func toggle_mute()->void:
	muted=not muted;AudioServer.set_bus_mute(0,muted);settings_data.muted=muted;audio.clear_tasks();
	if tactical_mode and is_instance_valid(level):audio.set_download_active(level.download_running() and state in [State.PLAYING,State.PAUSED]);audio.set_task_paused(state==State.PAUSED)
	hud.mute_button.text="声音关" if muted else "声音开";_save()
func _completed(seconds:float)->void:
	if state!=State.PLAYING:return
	state=State.WON;_release_input();audio.task_event("mission")
	var stars:int=1+int(level.alert_count==0)+int(level.intel_count>=2)
	var previous:Dictionary=settings_data.records.get(str(stage),{"seconds":seconds,"stars":1,"intel":0})
	var best:float=minf(previous.seconds,seconds)
	settings_data.records[str(stage)]={"seconds":best,"stars":maxi(stars,previous.stars),"intel":maxi(level.intel_count,previous.intel)}
	settings_data.records=Store.clean_records(settings_data.records)
	settings_data.stage=maxi(settings_data.stage,stage+1);_save()
	hud.feedback(Color("69dac9"))
	hud.show_message("成功逃离。","评价 %d/3 · 档案 %d/3 · 警报 %d 次\n用时 %.1f 秒 · 本区最佳 %.1f 秒\n无警报、收集至少两份档案各加一星。"%[stars,level.intel_count,level.alert_count,seconds,best],"下一区域 · 空格","won")
	hud.toast.text=""
func _failed(reason:String)->void:
	if state!=State.PLAYING:return
	state=State.LOST;_release_input();audio.task_event("captured");hud.feedback(Color("ff596d"))
	hud.show_message("逃生中断。",reason,"再试一次 · 空格","lost");hud.toast.text=""
func _impact(strength:float)->void:
	if state!=State.PLAYING:return
	impact_count+=1;audio.collision(strength)
	if not settings_data.reduced:shake=minf(strength*0.01,0.045)
func _unhandled_key_input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1,KEY_2:
				if state==State.PLAYING and tactical_mode:level.use_slot(0 if event.physical_keycode==KEY_1 else 1,_decoy_aim())
			KEY_T:_cycle_tracking()
			KEY_F:
				if state==State.PLAYING and tactical_mode:level.drop_core()
			KEY_R:retry()
			KEY_ESCAPE:hud.settings.hide();toggle_pause()
			KEY_M:toggle_mute()
			KEY_TAB:get_viewport().set_input_as_handled()
			KEY_Q:
				if state==State.PLAYING:level.throw_decoy(_decoy_aim())
			KEY_ENTER,KEY_SPACE:
				if state!=State.PLAYING and not hud.settings.visible:_primary()
func _unhandled_input(event:InputEvent)->void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and state==State.PLAYING:level.throw_decoy(_decoy_aim())
func _notification(what:int)->void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		if state==State.PLAYING:toggle_pause()
		_release_input()
func _release_input()->void:
	if tactical_mode and is_instance_valid(level):level.cancel_operation()
	audio.set_operation("",0)
	for action in ["gravity_left","gravity_right","gravity_up","gravity_down"]:Input.action_release(action)
func _save()->void:
	if test_mode:return
	if Store.write(settings_data)!=OK:_notice("本地记录暂不可用，不影响继续游玩。")
func _decoy_aim()->Vector3:
	var mouse:=get_viewport().get_mouse_position()
	var point=Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
	return level.decoy_target(point if point is Vector3 else level.player.position+Vector3.RIGHT*4)
func _process(delta:float)->void:
	if not is_instance_valid(level):return
	hud.update_readout(level.elapsed,level.interact_progress/maxf(level.interact_duration,0.01),level.nearest_risk,level.protection,state)
	hud.set_mission(level.mission_status())
	hud.update_escape(level.player.stamina,level.decoys_left,level.player.sneaking,level.player.running,level.pursuit_count,level.intel_count,level.interact_hint)
	if tactical_mode:
		hud.update_inventory(level.loadout,level.charges,level.selected_slot,level.gear_cooldown,state==State.READY)
		level.reduced_fx=settings_data.reduced
		for c in level.security_cameras:c.reduced_fx=settings_data.reduced
	toast_time-=delta
	if toast_time<=0:hud.toast.text=""
	var overview:bool=Input.is_physical_key_pressed(KEY_TAB)
	if tactical_mode:level.update_labels(overview)
	var focus:=Vector3.ZERO if overview else Vector3(clampf(level.player.position.x,-7,7),0,clampf(level.player.position.z,-5,5))
	camera_focus=camera_focus.lerp(focus,1-exp(-delta*4))
	camera.position=Vector3(10,15,18)+camera_focus;camera.size=lerpf(camera.size,30.0 if overview else 16.5,1-exp(-delta*5))
	hud.update_target(camera.unproject_position(level.target_position()+Vector3.UP*0.65),state==State.PLAYING)
	if tactical_mode:
		var tracked:Dictionary=level.tracked_target()
		hud.update_tracking(tracked.name,level.player.position.distance_to(tracked.at),state in [State.READY,State.PLAYING])
		target_marker.visible=state==State.PLAYING or state==State.READY
		target_marker.position=tracked.at+Vector3.UP*0.055
	arc.hide();arc_clock-=delta
	aim.visible=state==State.PLAYING and (tactical_mode or level.decoys_left>0) and not overview
	if aim.visible:
		aim.position=_decoy_aim()+Vector3.UP*0.05
		if tactical_mode:
			var kind:String=level.loadout[level.selected_slot]
			if kind=="jammer":aim.position=level.player.position+Vector3.UP*0.05
			aim.scale=Vector3.ONE*level.preview_radius()
			if kind=="smoke":
				var target:Vector3=_decoy_aim()
				if arc_clock<=0 or aim_cached!=target or aim_from.distance_to(level.player.position)>0.18 or aim_obstacles!=level.data.blocked.size():
					arc_clock=0.10;aim_cached=target;aim_from=level.player.position;aim_obstacles=level.data.blocked.size()
					var solution:Dictionary=level.throw_solution(target);aim_valid=solution.valid;aim_steps=solution.points.size()
					arc.mesh=preload("res://scripts/gadget_fx.gd").arc_mesh(solution.points)
				arc.visible=int(level.charges.get(kind,0))>0
			else:aim_valid=true
			aim.material_override.albedo_color=Color(0.4,0.8,0.9,0.23) if aim_valid else Color(0.9,0.4,0.4,0.25)
			arc.material_override.albedo_color=Color(0.6,0.9,0.92,0.5) if aim_valid else Color(0.94,0.4,0.4,0.5)
			aim.visible=kind!="pick" and int(level.charges.get(kind,0))>0
	shake=move_toward(shake,0,delta*0.25);camera.v_offset=sin(Time.get_ticks_msec()*0.055)*shake
	audio.mix_state(delta,state,level.nearest_risk)
	var risk:float=0;var chasing:bool=false;var searching:bool=false
	for device in level.guards+(level.security_cameras if tactical_mode else []):
		if device.jammed>0:continue
		risk=maxf(risk,device.confidence)
		if device in level.guards:
			chasing=chasing or device.mode==device.Mode.CHASE
			searching=searching or device.mode==device.Mode.SEARCH
	var alarm:bool=level.alert_count>tension_alerts;tension_alerts=level.alert_count
	var mood:Dictionary=tension.tick(delta,state,risk,chasing,searching,alarm)
	audio.mix_tension(delta,mood,state)
	hud.tension_edge.update_tension(mood,bool(settings_data.get("edge_heartbeat",true)),settings_data.reduced)
	if qa_enabled:
		qa_clock-=delta
		if qa_clock<=0:qa_clock=0.12;JavaScriptBridge.eval("window.__gravityCourierQA="+JSON.stringify(snapshot()))
func snapshot()->Dictionary:
	var p:Vector3=level.player.position;var v:Vector3=level.player.velocity
	var gs:Array=[]
	for g in level.guards:gs.append({"position":[g.position.x,g.position.z],"forward":[g.forward.x,g.forward.z],"mode":g.state_name(),"confidence":g.confidence,"range":g.vision_range,"cone_alpha":g.cone_material.albedo_color.a})
	var result:Dictionary={"state":state,"stage":stage,"time":level.elapsed,"position":[p.x,p.z],"velocity":[v.x,v.z],"guards":gs,"found":level.found,"needed":level.data.needs,"intel":level.intel_count,"alerts":level.alert_count,"escapes":level.escape_count,"stamina":level.player.stamina,"pose":level.player.pose,"decoys":level.decoys_left,"exit_open":level.exit_open,"goal":[level.data.goal.x,level.data.goal.z],"risk":level.nearest_risk,"attempt":attempt,"muted":muted,"detection_count":audio.detection_count,"music_volume":audio.music_level,"heartbeat_volume":audio.heartbeat_level,"edge_enabled":bool(settings_data.get("edge_heartbeat",true)),"tension_mode":tension.mode,"tension_intensity":tension.intensity,"tension_bpm":tension.bpm,"heartbeat_count":audio.heartbeat_count,"tension_phase":tension.phase,"music_weights":audio.tension_weights,"music_duck":audio.tension_duck,"edge_visible":hud.tension_edge.visible,"music_playing":audio.music.playing,"fps":Engine.get_frames_per_second()}
	if tactical_mode:
		result.merge({"loadout":level.loadout,"charges":level.charges,"mission":level.data.title,"carrying":level.player.carrying,"download":level.download_time,"download_taken":level.download_taken,"control_used":level.control_used,"maintenance_open":level.doors[0].open,"smoke_count":level.smoke_clouds.size(),"projectiles":level.projectiles.size(),"tracking":level.tracked_target().id,"tracking_name":level.tracked_target().name,"tracking_point":[level.target_position().x,level.target_position().z],"jam_hits":level.jam_hits_last,"selected_slot":level.selected_slot,"aim_valid":aim_valid,"arc_points":aim_steps,"preview_kind":hud.model_preview.kind,"preview_slot":hud.model_preview.slot,"preview_visible":hud.model_preview.visible,"variant":level.data.get("variant",0),"variant_title":level.data.get("variant_title",""),"objective":level.mission_status(),"operation_audio":audio.operation_kind,"operation_playing":audio.operation_player.playing,"interaction_progress":level.interact_progress,"task_audio":audio.task_current,"task_queue":audio.task_queue,"task_playing":audio.task_player.playing,"task_paused":audio.task_paused,"download_audio":audio.download_player.playing})
	if qa_enabled:
		var centers:Array=[]
		for tile in hud.catalog_tiles:
			var point:Vector2=tile.get_global_rect().get_center();centers.append([point.x,point.y])
		result["catalog_centers"]=centers
		var cells:Array=[]
		for cell in level.data.blocked:cells.append([cell.x,cell.y])
		result["blocked"]=cells
		var points:Array=[]
		for item in level.data.items:points.append({"kind":item.kind,"at":[item.at.x,item.at.z]})
		result["items"]=points
		var right:Vector3=camera.global_basis.x;right.y=0;right=right.normalized()
		var forward:Vector3=-camera.global_basis.z;forward.y=0;forward=forward.normalized()
		result["right_axis"]=[right.x,right.z];result["forward_axis"]=[forward.x,forward.z]
		result["brief"]=level.mission_brief();result["ready_heading"]=hud.heading.text
	return result
func _exit_tree()->void:V.cache.clear();V.shapes.clear();preload("res://scripts/item_models.gd").scenes.clear()

