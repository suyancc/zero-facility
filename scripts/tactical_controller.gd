extends "res://scripts/level_controller.gd"
signal gear_sound(kind:String)
signal task_event(kind:String)
signal download_audio(active:bool)
signal operation_audio(kind:String,progress:float)
const Variants:=preload("res://scripts/mission_variants.gd")
var transfers:Dictionary={}
var fragments:int=0
var active_operation:String=""
const FX:=preload("res://scripts/gadget_fx.gd")
var reduced_fx:bool=false
var room_labels:Array[Label3D]=[]
const Guidance:=preload("res://scripts/task_guidance.gd")
const FLIGHT_TIME:float=0.55
var tracked_goal:String="auto"
var projectiles:Array[Dictionary]=[]
var jam_hits_last:int=0
const GEAR_NAMES:Dictionary={"smoke":"烟雾罐","jammer":"干扰器","pick":"撬锁工具","decoy":"声音诱饵"}
var loadout:Array[String]=["smoke","pick"]
var charges:Dictionary={}
var doors:Array[Dictionary]=[]
var security_cameras:Array[Node3D]=[]
var smoke_clouds:Array[Dictionary]=[]
var gear_cooldown:float=0
var selected_slot:int=0
var pick_armed:bool=false
var download_started:bool=false
var download_time:float=0
var download_taken:bool=false
var manual_override:bool=false
var core_delivered:bool=false
var core_index:int=-1
var core_at:Vector3
var core_visual:Node3D
var control_used:bool=false
func _ready()->void:
	super._ready()
	for c in security_cameras:c.contact_reported.connect(_camera_report)
	for i in range(data.items.size()):
		if data.items[i].kind=="core":core_index=i;core_at=data.items[i].at;core_visual=item_nodes[i]
	set_loadout(loadout)
func set_loadout(values:Array[String])->void:
	if playing or values.size()!=2 or values[0]==values[1]:return
	for value in values:
		if not GEAR_NAMES.has(value):return
	loadout=values.duplicate();charges.clear()
	for kind in loadout:charges[kind]=2 if kind in ["smoke","pick","decoy"] else 1
	decoys_left=int(charges.get("decoy",0));pick_armed=false
func equipment_status()->String:
	return "[1] %s ×%d    [2] %s ×%d"%[GEAR_NAMES[loadout[0]],charges.get(loadout[0],0),GEAR_NAMES[loadout[1]],charges.get(loadout[1],0)]
func preview_radius()->float:return 2.2 if loadout[selected_slot]=="smoke" else 3.0 if loadout[selected_slot]=="jammer" else 0.3
func throw_solution(at:Vector3)->Dictionary:
	var target:Vector3=decoy_target(at);target.y=0.11
	var from:Vector3=player.position+Vector3.UP*1.05
	var points:Array[Vector3]=[from];var clear:bool=true
	var previous:Vector3=from
	for i in range(1,25):
		var point:Vector3=FX.throw_point(from,target,float(i)/24)
		if clear and not _flight_segment_clear(previous,point):clear=false
		points.append(point);previous=point
	return {"from":from,"target":target,"points":points,"valid":clear}
func _flight_segment_clear(from:Vector3,to:Vector3)->bool:
	# A small swept envelope approximates the canister radius, not only its centre.
	for offset in [Vector3.ZERO,Vector3(0.07,0,0),Vector3(-0.07,0,0),Vector3(0,0,0.07),Vector3(0,0,-0.07)]:
		var ray:=PhysicsRayQueryParameters3D.create(from+offset,to+offset,4)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():return false
	return true
func valid_throw(at:Vector3)->bool:
	return bool(throw_solution(at).valid)
func _deploy_smoke(at:Vector3)->void:
	at.y=0
	var cloud:=FX.smoke(self,at)
	smoke_clouds.append({"at":at,"life":6.0,"node":cloud})
	pulse(at,Color("a8dbe1"),2.2);gear_sound.emit("smoke")
	notice.emit("烟雾落地 · 持续 6 秒 · 仍会被听见")
func _tick_projectiles(delta:float)->void:
	for i in range(projectiles.size()-1,-1,-1):
		var flight:Dictionary=projectiles[i]
		var begin:float=flight.age/FLIGHT_TIME
		flight.age=minf(FLIGHT_TIME,flight.age+delta)
		var end:float=flight.age/FLIGHT_TIME
		var previous:Vector3=FX.throw_point(flight.from,flight.target,begin)
		var collision:bool=false
		var steps:int=maxi(1,ceili((end-begin)*24))
		for step in range(1,steps+1):
			var t:float=lerpf(begin,end,float(step)/steps)
			var point:Vector3=FX.throw_point(flight.from,flight.target,t)
			if not _flight_segment_clear(previous,point):collision=true;break
			previous=point
			if Nav.is_walkable(data,Nav.cell(data,point)):flight.last_safe=Vector3(point.x,0,point.z)
		flight.node.position=previous
		if not reduced_fx:flight.node.rotation=Vector3(end*TAU,end*PI,0.4)
		if collision or end>=1:
			_deploy_smoke(flight.last_safe if collision else flight.target)
			flight.node.queue_free();projectiles.remove_at(i)
func use_slot(slot:int,at:Vector3)->bool:
	if not playing or slot<0 or slot>1:return false
	selected_slot=slot
	var kind:String=loadout[slot]
	if int(charges.get(kind,0))<=0:notice.emit("这件装备已用完 · 主路线仍然可走");return false
	if gear_cooldown>0:return false
	if kind=="pick":
		pick_armed=not pick_armed
		if pick_armed and data.mission==0 and tracked_goal in ["auto","card"] and not requirements_met():tracked_goal="exit_pick"
		notice.emit("撬锁已准备 · 靠近维修门长按 E" if pick_armed else "已收起撬锁工具");return true
	if kind=="decoy":return throw_decoy(at)
	var target:Vector3=decoy_target(at) if kind=="smoke" else player.position
	if kind=="smoke" and not valid_throw(target):notice.emit("投掷路线被挡住了 · 调整位置");return false
	if kind=="jammer":
		var hit:bool=false;jam_hits_last=0
		for device in security_cameras+guards:
			if device.position.distance_to(player.position)<3.0:
				device.jammed=maxf(device.jammed,4.0 if device in guards else 7.0);hit=true;jam_hits_last+=1
				FX.mark_device(device,reduced_fx)
		if not hit:notice.emit("范围内没有电子设备 · 未消耗");return false
		pulse(player.position,Color("71c8ff"),3.0)
		notice.emit("干扰命中 %d 台设备 · 不会清除警报"%jam_hits_last)
	else:
		var solution:=throw_solution(target)
		var node:=FX.canister(self,solution.from)
		projectiles.append({"from":solution.from,"target":solution.target,"age":0.0,"node":node,"last_safe":Vector3(player.position.x,0,player.position.z)})
		notice.emit("烟雾弹投出 · 落地后起雾")
	charges[kind]-=1;gear_cooldown=0.6;gear_sound.emit("throw" if kind=="smoke" else kind);return true
func pulse(at:Vector3,color:Color,radius:float)->void:
	FX.burst(self,at,color,radius,reduced_fx)
func throw_decoy(at:Vector3)->bool:
	if not loadout.has("decoy"):notice.emit("本次未携带诱饵 · 使用 1 / 2 装备");return false
	var ok:bool=super.throw_decoy(at)
	if ok:charges.decoy=decoys_left;gear_sound.emit("decoy")
	return ok
func sight_is_blocked(a:Vector3,b:Vector3)->bool:
	var start:=Vector2(a.x,a.z);var end:=Vector2(b.x,b.z)
	for cloud in smoke_clouds:
		var center:=Vector2(cloud.at.x,cloud.at.z)
		var point:=Geometry2D.get_closest_point_to_segment(center,start,end)
		if point.distance_to(center)<=2.2:return true
	return false
func _physics_process(delta:float)->void:
	if playing:
		gear_cooldown=maxf(0,gear_cooldown-delta)
		for i in range(smoke_clouds.size()-1,-1,-1):
			var cloud:Dictionary=smoke_clouds[i];cloud.life-=delta
			FX.tick_smoke(cloud.node,cloud.life,reduced_fx)
			if cloud.life<=0:cloud.node.queue_free();smoke_clouds.remove_at(i)
		_tick_projectiles(delta)
		if Variants.variant(data)==1 and data.mission==1:
			_tick_transfers(delta)
		elif download_started and not download_taken:
			var previous:float=download_time;download_time=minf(10.0,download_time+delta)
			if previous<10.0 and download_time>=10.0:
				download_audio.emit(false);task_event.emit("download_ready");notice.emit("下载完成 · 返回终端取走数据")
		for c in security_cameras:
			c.update_ai(delta,player,protection<=0)
		if player.carrying and is_instance_valid(core_visual):
			core_visual.position=player.position+Vector3(0,0.8,0)+Vector3.FORWARD.rotated(Vector3.UP,player.facing)*0.43
			core_visual.scale=Vector3.ONE*0.65
	else:
		for c in security_cameras:c.step(delta,false);c.intent.text="监控"
	var prior_escapes:int=escape_count
	super._physics_process(delta)
	if escape_count>prior_escapes:task_event.emit("escape")
	for c in security_cameras:nearest_risk=maxf(nearest_risk,c.confidence)
func _camera_report(_camera:Node3D,at:Vector3)->void:
	alert_count+=1;notice.emit("监控警报 · 巡检正在调查你的位置")
	for g in guards:g.hear(at,1000,"监控报告")
func requirements_met()->bool:
	if data.mission==0:
		if Variants.variant(data)==1:return (found.card>0 and control_used) or manual_override
		if Variants.variant(data)==2:return (found.card>0 and manual_override) or exit_open
		return found.card>0 or manual_override
	if data.mission==1:return download_taken
	return core_delivered
func option(id:String,kind:String,at:Vector3,title:String,duration:float,index:int=-1)->Dictionary:
	return {"id":id,"kind":kind,"at":at,"name":title,"duration":duration,"index":index}
func _nearest_interaction()->Dictionary:
	var best:Dictionary={};var distance:float=1.15
	for i in range(data.items.size()):
		var item:Dictionary=data.items[i];var kind:String=item.kind
		if taken.has(i) or (kind=="core" and (player.carrying or core_delivered)):continue
		if kind=="core" and Variants.variant(data)==1 and not control_used:continue
		if kind=="download" and Variants.variant(data)==2 and not control_used:continue
		if kind=="override" and data.mission==2 and not player.carrying:continue
		var at:Vector3=core_at if kind=="core" else item.at
		var d:float=Vector2(player.position.x-at.x,player.position.z-at.z).length()
		if d>=distance:continue
		var ray:=PhysicsRayQueryParameters3D.create(player.position+Vector3.UP,at+Vector3.UP,4)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
		var title:String=item.name;var duration:float=0.65
		if kind=="download":
			if Variants.variant(data)==1:
				if transfers.has(i) and float(transfers[i])<5:continue
				title=("取回" if transfers.has(i) else "启动 5 秒下载 · ")+item.name
			else:
				if download_started and download_time<10:continue
				title="取回下载数据" if download_started else "启动下载 · 10 秒后回来取"
		if kind=="override":
			duration=8.0 if data.mission==0 and Variants.variant(data)==1 and not control_used else 4.0
			title="手动解封 · 会发出声音"
			if data.mission==2:kind="deliver";title="静默交付核心 · 4 秒"
		if kind=="control":duration=1.5;title=item.name+" · 关闭监控 / 开启捷径"
		distance=d;best=option("item%d"%i,kind,at,title,duration,i)
	for i in range(data.intel.size()):
		if intel_taken.has(i):continue
		var at:Vector3=data.intel[i];var d:float=player.position.distance_to(at)
		if d<distance:distance=d;best=option("intel%d"%i,"intel",at,"收集档案",0.45,i)
	for i in range(doors.size()):
		var door:Dictionary=doors[i]
		if door.open or player.position.distance_to(door.at)>1.50:continue
		if pick_armed and int(charges.get("pick",0))>0:best=option("door%d"%i,"pick",door.at,"撬开维修门",2.2,i)
		elif found.card>0:best=option("door%d"%i,"door",door.at,"刷卡开启维修门",0.5,i)
	var exit_distance:float=Vector2(player.position.x-data.goal.x,player.position.z-data.goal.z).length()
	if exit_distance<1.35 and not exit_open:
		if data.mission==2 and player.carrying:best=option("deliver","deliver",data.goal,"把核心装入货运接口",1.0)
		elif requirements_met():best=option("exit","exit",data.goal,"解除出口封锁",1.1)
		elif data.mission==0 and pick_armed and int(charges.get("pick",0))>0:best=option("breach","breach",data.goal,"撬开出口锁 · 消耗工具",3.0)
	return best
func _tick_interaction(delta:float,held:bool,moving:bool)->void:
	var task:=_nearest_interaction()
	interact_hint="按住 E · "+str(task.name) if not task.is_empty() else "F 放下核心" if player.carrying else "撬锁已准备 · 靠近门后长按 E" if pick_armed else ""
	if task.is_empty() or not held or moving:cancel_operation();return
	if interact_target!=task.id:
		interact_target=task.id;interact_progress=0;interact_duration=task.duration

		if task.kind in ["override","pick","breach","download"]:emit_noise(task.at,10 if task.kind=="override" and Variants.variant(data)==1 and not control_used else 5,"调查设备操作声")
	active_operation=task.kind
	operation_audio.emit(task.kind,clampf(interact_progress/interact_duration,0,1))
	interact_progress+=delta
	if interact_progress<interact_duration:return
	operation_audio.emit("",0);active_operation=""
	var audio_event:String=task.kind
	match task.kind:
		"card":found.card+=1;taken[task.index]=true;item_nodes[task.index].hide();notice.emit("门禁卡已取得 · 可刷卡开维修门")
		"override":manual_override=true;taken[task.index]=true;item_nodes[task.index].hide();notice.emit("解封台授权完成 · 查看本局目标")
		"control":
			control_used=true;taken[task.index]=true;notice.emit("支线完成 · 监控离线 45 秒 / 维修门已开")
			for c in security_cameras:c.jammed=45;FX.mark_device(c,reduced_fx)
			for i in range(doors.size()):open_door(i)
		"download":
			if Variants.variant(data)==1:
				if not transfers.has(task.index):transfers[task.index]=0.0;download_audio.emit(true);audio_event="download_start"
				else:
					fragments+=1;taken[task.index]=true;item_nodes[task.index].hide();audio_event="download_collect"
					if fragments>=2:download_taken=true;found.terminal=1
				notice.emit("数据分片 %d/2 · 分别下载并取回"%fragments)
			elif not download_started:download_started=true;download_audio.emit(true);audio_event="download_start";notice.emit("下载启动 · 可以离开躲避，完成后回来取")
			else:download_taken=true;download_audio.emit(false);audio_event="download_collect";found.terminal=1;taken[task.index]=true;item_nodes[task.index].hide();notice.emit("数据已取回 · 前往出口")
		"core":
			player.carrying=true
			for child in core_visual.get_children():
				if child is Label3D:child.hide()
			notice.emit("正在搬运 · 不能奔跑 · F 可安全放下")
		"deliver":
			if Variants.variant(data)==2 and task.index<0:emit_noise(data.goal,12,"调查核心快接声")
			player.carrying=false;core_delivered=true;found.power=1;taken[core_index]=true;core_visual.hide();notice.emit("核心交付成功 · 解锁出口离开")
		"intel":intel_taken[task.index]=true;intel_count+=1;intel_nodes[task.index].hide();notice.emit("档案 %d/3"%intel_count)
		"pick":charges.pick-=1;pick_armed=false;open_door(task.index);gear_sound.emit("unlock");notice.emit("维修捷径已打开")
		"door":open_door(task.index)
		"breach":charges.pick-=1;pick_armed=false;manual_override=true;gear_sound.emit("unlock");unlock_exit()
		"exit":audio_event="door";unlock_exit()
	if requirements_met() and not exit_open:exit_label.text="出口就绪 · 按住 E";exit_label.modulate=Color("8debd3")
	interact_target="";interact_progress=0;task_event.emit(audio_event);scanned.emit()
func unlock_exit()->void:
	exit_open=true;exit_collision.set_deferred("disabled",true);exit_label.text="出口已开 · 穿过门禁"
	for i in range(exit_leaves.size()):create_tween().tween_property(exit_leaves[i],"position:x",-1.12 if i==0 else 1.12,0.35)
	notice.emit("门开了！穿过出口离开设施。")
func open_door(index:int)->void:
	var door:Dictionary=doors[index]
	if door.open:return
	door.open=true
	for child in door.body.get_children():
		if child is CollisionShape3D:child.set_deferred("disabled",true)
	create_tween().tween_property(door.body,"position:y",-1.0,0.4)
	door.label.text="维修通道已开";data.blocked.erase(door.cell)
	for g in guards:g.path_points.clear();g.path_goal=Vector2i(-999,-999)
func drop_core()->bool:
	if not playing or not player.carrying:return false
	core_at=player.position;core_at.y=0;core_visual.position=core_at;core_visual.scale=Vector3.ONE;player.carrying=false
	for child in core_visual.get_children():
		if child is Label3D:child.show()
	task_event.emit("core_drop");notice.emit("核心已放下 · 随时回来长按 E 搬起");return true
func mission_brief()->String:return Variants.brief(data)
func mission_status()->String:
	if exit_open:return "出口已开 · 穿过门禁"
	if requirements_met():return "主任务完成 · 前往出口长按 E"
	if data.mission==0:
		if Variants.variant(data)==1:return "警戒封锁 · 先关闭监控再刷卡，或强行解封"
		if Variants.variant(data)==2:return "双重授权 · 门禁卡 %d/1 · 解封台 %d/1"%[mini(found.card,1),int(manual_override)]
		return "突破封锁 · 门禁卡 / 手动解封 / 撬锁任选"
	if data.mission==1:
		if Variants.variant(data)==1:return "分段取证 · 已取回 %d/2 · 两端各下载 5 秒"%fragments
		if Variants.variant(data)==2 and not control_used:return "双端校验 · 先操作校验控制台"
		return "下载完成 · 返回终端取走数据" if download_time>=10 else "下载中 %d%% · 可离开躲避"%int(download_time*10) if download_started else "盗取数据 · 前往终端启动下载"
	if Variants.variant(data)==1 and not control_used:return "先稳后运 · 先操作核心稳定控制台"
	if Variants.variant(data)==2 and player.carrying:return "分流交付 · T 切换快接 / 静默接口"
	return "核心搬运中 · F 放下 / 出口 E 交付" if player.carrying else "能源转移 · 找到并搬起核心"
func target_position()->Vector3:return Guidance.current(self).at
func tracked_target()->Dictionary:return Guidance.current(self)
func cycle_target()->void:
	Guidance.cycle(self);notice.emit("正在跟踪："+str(tracked_target().name))

func smoke_ray_length(origin:Vector3,direction:Vector3,length:float)->float:
	for cloud in smoke_clouds:
		var offset:=Vector2(origin.x-cloud.at.x,origin.z-cloud.at.z)
		var dir:=Vector2(direction.x,direction.z)
		var b:float=offset.dot(dir);var c:float=offset.length_squared()-2.2*2.2
		if c<=0:return 0
		var discriminant:float=b*b-c
		if discriminant<0:continue
		var enter:float=-b-sqrt(discriminant)
		if enter>=0:length=minf(length,enter)
	return length

func update_labels(overview:bool)->void:
	for child in player.get_children():
		if child is Label3D:child.visible=overview or not playing or protection>0
	for label in room_labels:label.visible=overview
	for node in item_nodes+intel_nodes:
		for child in node.get_children():
			if child is Label3D:child.visible=(overview or node.position.distance_to(player.position)<5.0) and not (node==core_visual and player.carrying)
	for door in doors:door.label.visible=overview or door.at.distance_to(player.position)<5.0
	for device in guards+security_cameras:
		device.intent.visible=overview or device.position.distance_to(player.position)<5.5 or device.confidence>0.05 or device.jammed>0
		var badge:Node=device.get_node_or_null("InterferenceFeedback")
		if badge!=null:badge.reduced=reduced_fx
	var active:Vector3=target_position()
	for node in item_nodes+intel_nodes:
		if node==core_visual and player.carrying:continue
		if node.position.distance_to(active)<0.15:
			for child in node.get_children():
				if child is Label3D:child.show()

func cancel_operation()->void:
	interact_target="";interact_progress=0
	if active_operation!="":operation_audio.emit("",0);active_operation=""
func _tick_transfers(delta:float)->void:
	var running:bool=false
	for index in transfers:
		var before:float=transfers[index];transfers[index]=minf(5,before+delta)
		if before<5 and float(transfers[index])>=5:task_event.emit("download_ready");notice.emit(data.items[index].name+"下载完成 · 返回取回")
		if float(transfers[index])<5:running=true
	download_audio.emit(running)

func download_running()->bool:
	if data.mission==1 and Variants.variant(data)==1:
		for value in transfers.values():
			if float(value)<5:return true
		return false
	return download_started and download_time<10 and not download_taken

