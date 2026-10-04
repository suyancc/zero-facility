extends RefCounted
# Guidance never changes mission requirements or silently spends equipment.
static func choices(level:Node3D)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	if level.requirements_met():
		result.append({"id":"exit","name":"撤离出口","at":level.data.goal,"optional":false})
	elif (level.data.mission in [1,2] and int(level.data.get("variant",0))==(2 if level.data.mission==1 else 1) and not level.control_used) or (level.data.mission==0 and int(level.data.get("variant",0))==1 and level.found.card>0 and not level.manual_override and not level.control_used):
		for item in level.data.items:
			if item.kind=="control":result.append({"id":"control","name":item.name,"at":item.at,"optional":false})
		if level.data.mission==0:
			for item in level.data.items:
				if item.kind=="override":result.append({"id":"override","name":"强行解封方案","at":item.at,"optional":false})
	elif level.data.mission==0:
		for item in level.data.items:
			if item.kind=="card" and level.found.card==0:result.append({"id":"card","name":"门禁卡方案","at":item.at,"optional":false})
			elif item.kind=="override" and not level.manual_override:result.append({"id":"override","name":"手动解封方案","at":item.at,"optional":false})
		if level.loadout.has("pick") and int(level.charges.get("pick",0))>0:
			result.append({"id":"exit_pick","name":"撬锁直达出口","at":level.data.goal,"optional":false})
	elif level.data.mission==1 and int(level.data.get("variant",0))==1:
		for i in range(level.data.items.size()):
			var item:Dictionary=level.data.items[i]
			if item.kind!="download" or level.taken.has(i):continue
			var suffix:String=" · 启动下载"
			if level.transfers.has(i):suffix=" · 取回分片" if float(level.transfers[i])>=5 else " · 下载 %d%%"%int(float(level.transfers[i])*20)
			result.append({"id":"fragment%d"%i,"name":item.name+suffix,"at":item.at,"optional":false})
	elif level.data.mission==1:
		result.append({"id":"download","name":"取回下载数据" if level.download_time>=10 else "下载终端","at":level.data.items[0].at,"optional":false})
	else:
		result.append({"id":"deliver" if level.player.carrying else "core","name":"核心交付点" if level.player.carrying else "搬起能源核心","at":level.data.goal if level.player.carrying else level.core_at,"optional":false})
	if level.data.mission==2 and int(level.data.get("variant",0))==2 and level.player.carrying and not level.core_delivered:
		for item in level.data.items:
			if item.kind=="override":result.append({"id":"deliver_silent","name":"静默交付 · 4 秒","at":item.at,"optional":false})
	if not level.control_used and not (result.size()>0 and result[0].id=="control"):
		for item in level.data.items:
			if item.kind=="control":result.append({"id":"control","name":"支线：局部控制器","at":item.at,"optional":true})
	if not level.doors.is_empty() and not level.doors[0].open and (level.found.card>0 or (level.loadout.has("pick") and int(level.charges.get("pick",0))>0)):
		result.append({"id":"door","name":"捷径：维修门","at":level.doors[0].at,"optional":true})
	var nearest:int=-1;var distance:float=INF
	for i in range(level.data.intel.size()):
		if level.intel_taken.has(i):continue
		var d:float=level.player.position.distance_to(level.data.intel[i])
		if d<distance:distance=d;nearest=i
	if nearest>=0:result.append({"id":"intel","name":"支线：最近档案","at":level.data.intel[nearest],"optional":true})
	return result
static func current(level:Node3D)->Dictionary:
	var options:=choices(level)
	for entry in options:
		if entry.id==level.tracked_goal:return entry
	# Completed/invalid guidance gracefully falls back to the live main objective.
	return options[0]
static func cycle(level:Node3D)->void:
	var options:=choices(level);var active:String=current(level).id
	for i in range(options.size()):
		if options[i].id==active:level.tracked_goal=options[(i+1)%options.size()].id;return

