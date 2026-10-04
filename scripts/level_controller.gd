extends Node3D
const Nav:=preload("res://scripts/navigation.gd")
const V:=preload("res://scripts/visual_factory.gd")
signal completed(seconds:float)
signal failed(reason:String)
signal impact(strength:float)
signal spotted(position:Vector3)
signal scanned
signal notice(text:String)
signal decoy_used
signal foot_sound(loudness:float)
var data:Dictionary={}
var playing:bool=false
var elapsed:float=0
var protection:float=1.4
var nearest_risk:float=0
var guards:Array[Node]=[]
var camera:Camera3D
var found:Dictionary={"power":0,"card":0,"terminal":0}
var taken:Dictionary={}
var intel_taken:Dictionary={}
var intel_count:int=0
var alert_count:int=0
var item_nodes:Array[Node3D]=[]
var intel_nodes:Array[Node3D]=[]
var exit_node:Node3D
var exit_collision:CollisionShape3D
var exit_leaves:Array[Node3D]=[]
var exit_label:Label3D
var exit_open:bool=false
var interact_target:String=""
var interact_progress:float=0
var interact_duration:float=1
var interact_hint:String=""
var decoys_left:int=2
var decoy_cooldown:float=0
var decoys:Array[Dictionary]=[]
var radio_cooldown:float=0
var pursuit_count:int=0
var escape_count:int=0
var was_chased:bool=false
@onready var player:CharacterBody3D=$Player
func _ready()->void:
	player.lost.connect(_fail)
	player.impacted.connect(_on_impact)
	player.footstep.connect(func(radius:float):
		if playing:
			emit_noise(player.position,radius,"调查脚步声")
			foot_sound.emit(radius))
	guards=$Guards.get_children()
	for guard in guards:guard.contact_reported.connect(_report)
func start()->void:
	playing=true;player.set_active(true)
func requirements_met()->bool:
	for key in data.needs:
		if found[key]<data.needs[key]:return false
	return true
func _physics_process(delta:float)->void:
	if not playing or camera==null:
		for guard in guards:guard.step(delta,false)
		return
	elapsed+=delta;protection=maxf(0,protection-delta)
	decoy_cooldown=maxf(0,decoy_cooldown-delta);radio_cooldown=maxf(0,radio_cooldown-delta)
	var input:=Input.get_vector("gravity_left","gravity_right","gravity_up","gravity_down")
	var quiet:bool=Input.is_physical_key_pressed(KEY_CTRL)
	var sprint:bool=Input.is_physical_key_pressed(KEY_SHIFT)
	player.drive(delta,input,camera,quiet,sprint)
	_tick_decoys(delta)
	nearest_risk=0;pursuit_count=0
	for guard in guards:
		guard.update_ai(delta,player,protection<=0)
		nearest_risk=maxf(nearest_risk,guard.confidence)
		if guard.mode==guard.Mode.CHASE:pursuit_count+=1;nearest_risk=1
		if guard.caught and protection<=0:
			spotted.emit(player.global_position)
			_fail("被巡检拦截了。冲刺拉开距离，再绕高掩体断开视线。")
			return
	if was_chased and pursuit_count==0:escape_count+=1;notice.emit("暂时脱离追捕 · 搜索仍在继续")
	was_chased=pursuit_count>0
	_tick_interaction(delta,Input.is_physical_key_pressed(KEY_E),input.length()>0.1)
	if exit_open:
		var offset:Vector3=player.position-data.goal
		var outward:float=offset.dot(data.exit_direction)
		var sideways:float=absf(offset.dot(data.exit_direction.cross(Vector3.UP)))
		if outward>0.32 and sideways<0.68:_win()
func _nearest_interaction()->Dictionary:
	var best:Dictionary={};var distance:float=1.10
	for i in range(data.items.size()):
		if taken.has(i):continue
		var item:Dictionary=data.items[i]
		var d:float=Vector2(player.position.x-item.at.x,player.position.z-item.at.z).length()
		if d<distance:distance=d;best={"id":"item%d"%i,"kind":"item","index":i,"at":item.at,"name":item.name,"duration":item.duration}
	for i in range(data.intel.size()):
		if intel_taken.has(i):continue
		var at:Vector3=data.intel[i]
		var d:float=Vector2(player.position.x-at.x,player.position.z-at.z).length()
		if d<distance:distance=d;best={"id":"intel%d"%i,"kind":"intel","index":i,"at":at,"name":"收集档案","duration":0.45}
	var exit_distance:float=Vector2(player.position.x-data.goal.x,player.position.z-data.goal.z).length()
	if exit_distance<1.35 and not exit_open and requirements_met():best={"id":"exit","kind":"exit","at":data.goal,"name":"解除出口封锁","duration":1.1}
	return best
func _tick_interaction(delta:float,held:bool,moving:bool)->void:
	var option:=_nearest_interaction()
	interact_hint="按住 E · "+str(option.name) if not option.is_empty() else ""
	if option.is_empty() or not held or moving:
		interact_progress=0;interact_target="";return
	if interact_target!=option.id:
		interact_target=option.id;interact_progress=0;interact_duration=option.duration
		if option.kind=="exit" or (option.kind=="item" and data.items[option.index].kind=="terminal"):
			emit_noise(option.at,5.0,"调查终端声")
	var offset:Vector3=option.at-player.position
	if offset.length()>0.1:player.facing=atan2(-offset.x,-offset.z)
	interact_progress+=delta
	if interact_progress<interact_duration:return
	if option.kind=="item":
		var item:Dictionary=data.items[option.index]
		found[item.kind]+=1;taken[option.index]=true;item_nodes[option.index].hide()
		notice.emit("已取得 "+item.name+" · "+("出口可以解锁了" if requirements_met() else "继续寻找所需物品"))
		if requirements_met():exit_label.text="出口就绪 · 按住 E";exit_label.modulate=Color("8debd3")
	elif option.kind=="intel":
		intel_taken[option.index]=true;intel_count+=1;intel_nodes[option.index].hide()
		notice.emit("档案 %d/3 · 可选目标"%intel_count)
	else:
		exit_open=true;exit_collision.set_deferred("disabled",true);exit_label.text="出口已开 · 穿过门禁"
		for i in range(exit_leaves.size()):create_tween().tween_property(exit_leaves[i],"position:x",-1.12 if i==0 else 1.12,0.35)
		notice.emit("门开了！穿过出口离开设施。")
	interact_target="";interact_progress=0;scanned.emit()
func _report(reporter:Node3D,at:Vector3)->void:
	alert_count+=1;notice.emit("警报！用冲刺和掩体甩开追兵。")
	if radio_cooldown>0:return
	radio_cooldown=10
	var helper:Node3D=null;var distance:float=1000
	for guard in guards:
		if guard==reporter or guard.mode==guard.Mode.CHASE:continue
		var d:float=guard.position.distance_to(at)
		if d<distance:distance=d;helper=guard
	if helper!=null:helper.hear(at,1000,"无线电支援")
func emit_noise(at:Vector3,radius:float,reason:String="调查声响")->int:
	var heard:int=0
	for guard in guards:
		if guard.hear(at,radius,reason):heard+=1
	return heard
func _on_impact(strength:float)->void:
	if not playing:return
	impact.emit(strength);emit_noise(player.position,4.5,"调查撞击声")
func throw_decoy(at:Vector3)->bool:
	if not playing or decoys_left<=0 or decoy_cooldown>0:return false
	var from:=player.position;from.y=0
	var target:=decoy_target(at)
	decoys_left-=1;decoy_cooldown=0.7
	var node:=Node3D.new();add_child(node);node.position=from+Vector3.UP*0.7
	var art:=preload("res://scripts/item_models.gd").spawn("decoy");node.add_child(art);art.scale=Vector3.ONE*0.28;art.position.y=-0.07
	V.label(node,"声响诱饵",Vector3.UP*0.5,Color("ffd08a"))
	decoys.append({"node":node,"from":from,"target":target,"age":0.0,"pulse":0.45,"life":5.0})
	decoy_used.emit();return true
func _tick_decoys(delta:float)->void:
	for i in range(decoys.size()-1,-1,-1):
		var d:Dictionary=decoys[i];d.age+=delta;d.life-=delta;d.pulse-=delta
		var t:float=minf(1,d.age/0.45)
		d.node.position=d.from.lerp(d.target,t)+Vector3.UP*(0.1+sin(t*PI)*1.5)
		if d.pulse<=0:d.pulse=1.15;emit_noise(d.target,7,"调查诱饵")
		if d.life<=0:d.node.queue_free();decoys.remove_at(i)
func decoy_target(at:Vector3)->Vector3:
	var from:=player.position;from.y=0
	var offset:=Vector3(at.x,0,at.z)-from
	for reach in [5.0,4.4,3.8,3.2,2.6,2.0,1.0,0.0]:
		var target:=Nav.world(data,Nav.nearest(data,from+offset.limit_length(reach)))
		if target.distance_to(from)<=5:return target
	return from
func _win()->void:
	if not playing or not exit_open:return
	playing=false;player.set_active(false);player.outcome="escaped";completed.emit(elapsed)
func _fail(reason:String)->void:
	if not playing:return
	playing=false;player.set_active(false);player.outcome="caught";failed.emit(reason)
func mission_brief()->String:
	return "收集任意两份备用电源，再解锁出口。紫色档案为可选目标。" if data.mission==0 else "找到门禁卡与备用电源，再解锁出口。物品有多个候选位置。" if data.mission==1 else "接入一台门禁终端，再找到备用电源。操作终端会发出声音。"
func mission_status()->String:
	if exit_open:return "出口已开 · 穿过门禁逃生"
	if requirements_met():return "前往出口 · 按住 E 解锁"
	var parts:PackedStringArray=[]
	for key in data.needs:
		parts.append("%s %d/%d"%[{"power":"电源","card":"门禁卡","terminal":"终端"}[key],mini(found[key],data.needs[key]),data.needs[key]])
	return "  ·  ".join(parts)
func target_position()->Vector3:
	if requirements_met():return data.goal
	var nearest:Vector3=data.goal;var distance:float=1000
	for i in range(data.items.size()):
		var item:Dictionary=data.items[i]
		if taken.has(i) or found[item.kind]>=data.needs.get(item.kind,0):continue
		var d:float=player.position.distance_to(item.at)
		if d<distance:distance=d;nearest=item.at
	return nearest

