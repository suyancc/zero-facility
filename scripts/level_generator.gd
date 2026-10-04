extends RefCounted
const Nav:=preload("res://scripts/navigation.gd")
const WIDTH:int=19
const HEIGHT:int=15
const CELL:float=1.3
static func world(c:Vector2i)->Vector3:
	return Vector3((c.x-9)*CELL,0,(c.y-7)*CELL)
static func _pick(rng:RandomNumberGenerator,pool:Array[Vector2i],used:Array[Vector2i])->Vector2i:
	var best:int=0
	var score:float=-1
	for i in range(pool.size()):
		var distance:float=100
		for c in used:distance=minf(distance,absi(c.x-pool[i].x)+absi(c.y-pool[i].y))
		var value:float=distance+rng.randf()*4.0
		if value>score:score=value;best=i
	var chosen:=pool[best]
	pool.remove_at(best)
	used.append(chosen)
	return chosen
static func generate(stage:int)->Dictionary:
	stage=maxi(stage,1)
	var difficulty:int=mini(stage-1,23)
	var rng:=RandomNumberGenerator.new()
	rng.seed=(stage%2147483647)*7919+1050031
	var starts:Array[Vector2i]=[Vector2i(1,1),Vector2i(17,1),Vector2i(1,13),Vector2i(17,13)]
	var start_cell:Vector2i=starts[rng.randi_range(0,3)]
	var exits:Array[Vector2i]=[]
	for x in range(2,17):
		for y in [0,14]:
			if absi(start_cell.x-x)+absi(start_cell.y-y)>18:exits.append(Vector2i(x,y))
	for y in range(2,13):
		for x in [0,18]:
			if absi(start_cell.x-x)+absi(start_cell.y-y)>18:exits.append(Vector2i(x,y))
	var goal_cell:Vector2i=exits[rng.randi_range(0,exits.size()-1)]
	var exit_direction:Vector3=Vector3.LEFT if goal_cell.x==0 else Vector3.RIGHT if goal_cell.x==18 else Vector3.FORWARD if goal_cell.y==0 else Vector3.BACK
	var blocked:Array[Vector2i]=[]
	var outer:Array[Vector2i]=[]
	var inner:Array[Vector2i]=[]
	for x in range(WIDTH):
		for y in range(HEIGHT):
			var c:=Vector2i(x,y)
			if absi(c.x-start_cell.x)<=1 and absi(c.y-start_cell.y)<=1:continue
			if absi(c.x-goal_cell.x)<=1 and absi(c.y-goal_cell.y)<=1:continue
			if x<=1 or x>=17 or y<=1 or y>=13:outer.append(c)
			else:inner.append(c)
	var data:Dictionary={"width":WIDTH,"height":HEIGHT,"cell":CELL,"blocked":blocked}
	var target:int=mini(48+difficulty,68)
	var outside:int=0
	while blocked.size()<target and (not outer.is_empty() or not inner.is_empty()):
		var edge:bool=(outside<22 and not outer.is_empty()) or inner.is_empty()
		var choices:Array[Vector2i]=outer if edge else inner
		var i:=rng.randi_range(0,choices.size()-1)
		var c:=choices[i];choices.remove_at(i)
		blocked.append(c)
		if Nav.reachable(data,start_cell).size()!=WIDTH*HEIGHT-blocked.size():blocked.pop_back()
		elif edge:outside+=1
	var cover:Array[Dictionary]=[]
	for i in range(blocked.size()):cover.append({"cell":blocked[i],"kind":(i+stage)%5})
	var count:int=mini(2+stage/8,4)
	var anchors:Array=[
		[Vector2i(3,3),Vector2i(3,11),Vector2i(8,11),Vector2i(8,3)],
		[Vector2i(11,3),Vector2i(15,3),Vector2i(15,11),Vector2i(11,11)],
		[Vector2i(1,7),Vector2i(9,1),Vector2i(17,7),Vector2i(9,13)],
		[Vector2i(4,6),Vector2i(14,6),Vector2i(14,10),Vector2i(4,10)]]
	var guards:Array[Dictionary]=[]
	for i in range(count):
		var route:Array[Vector3]=[]
		var points:Array=anchors[i].duplicate()
		if rng.randf()>0.5:points.reverse()
		for c in points:route.append(Nav.world(data,Nav.nearest(data,world(c))))
		for j in range(route.size()):
			if route[0].distance_to(world(start_cell))>6:break
			route.append(route.pop_front())
		guards.append({"route":route,"range":minf(3.7+difficulty*0.03,4.35),"fov":72.0,"speed":1.05+difficulty*0.012,"chase_speed":2.65+difficulty*0.018,"pause":0.65,"id":i,"nav":data.duplicate()})
	var pool:Array[Vector2i]=[]
	for x in range(1,18):
		for y in range(1,14):
			var c:=Vector2i(x,y)
			if Nav.is_walkable(data,c):pool.append(c)
	var used:Array[Vector2i]=[start_cell,goal_cell]
	var mission:int=(stage-1)%3
	var needs:Dictionary={"power":2} if mission==0 else {"power":1,"card":1} if mission==1 else {"power":1,"terminal":1}
	var kinds:Array=["power","power","power"] if mission==0 else ["power","power","card","card"] if mission==1 else ["power","power","terminal","terminal"]
	var items:Array[Dictionary]=[]
	for kind in kinds:
		var c:=_pick(rng,pool,used)
		items.append({"at":world(c),"kind":kind,"name":{"power":"备用电源","card":"门禁卡","terminal":"门禁终端"}[kind],"duration":1.35 if kind=="terminal" else 0.65})
	var intel:Array[Vector3]=[]
	for i in range(3):intel.append(world(_pick(rng,pool,used)))
	data.merge({"stage":stage,"seed":rng.seed,"difficulty":difficulty,"mission":mission,"start":world(start_cell)+Vector3.UP*0.10,"goal":world(goal_cell),"exit_direction":exit_direction,"guards":guards,"cover":cover,"needs":needs,"items":items,"intel":intel,"title":["封锁车间","冷却舱","电力中枢","装卸平台","维修通道","通讯隔舱"][(stage-1)%6]})
	return data
static func objectives_connected(data:Dictionary)->bool:
	var from:=Nav.nearest(data,data.start)
	for item in data.items:
		if Nav.cells(data,from,Nav.nearest(data,item.at)).is_empty():return false
	return not Nav.cells(data,from,Nav.nearest(data,data.goal)).is_empty()

