extends RefCounted
const Base:=preload("res://scripts/level_generator.gd")
const Nav:=preload("res://scripts/navigation.gd")
static func generate(stage:int)->Dictionary:
	var d:=Base.generate(stage)
	var original_cover:Array=d.cover.duplicate()
	d.tactical=true
	var open_y:int=3 if stage%2==1 else 11
	var lock_y:int=14-open_y
	var walls:Array[Vector2i]=[]
	for y in range(15):
		if y!=open_y and y!=lock_y:walls.append(Vector2i(9,y))
	for x in range(19):
		if x not in [4,9,14]:walls.append(Vector2i(x,7))
	var start:Vector2i=Nav.cell(d,d.start);var goal:Vector2i=Nav.cell(d,d.goal)
	# Preserve each spawn and exit approach, including boundary exits.
	for c in walls.duplicate():
		if (c-start).length()<2 or (c-goal).length()<2:walls.erase(c)
	var door_cell:=Vector2i(9,lock_y)
	var blocked:Array[Vector2i]=walls.duplicate();blocked.append(door_cell)
	var cover:Array[Dictionary]=[]
	d.blocked=blocked
	# Reserve corridors adjacent to partitions; retain varied perimeter furniture.
	for spec in original_cover:
		var c:Vector2i=spec.cell
		if absi(c.x-9)<=1 or absi(c.y-7)<=1:continue
		blocked.append(c)
		if Nav.reachable(d,start).size()!=285-blocked.size():blocked.pop_back()
		else:cover.append(spec)
	d.cover=cover;d.walls=walls
	d.doors=[{"cell":door_cell,"at":Base.world(door_cell)}]
	d.rooms=[{"name":"监控室","at":Base.world(Vector2i(4,3)),"color":Color("23505b")},{"name":"数据机房","at":Base.world(Vector2i(14,3)),"color":Color("293e64")},{"name":"仓储区","at":Base.world(Vector2i(4,11)),"color":Color("4a3e35")},{"name":"能源舱","at":Base.world(Vector2i(14,11)),"color":Color("244b46")}]
	var pool:Array[Vector2i]=[]
	for x in range(1,18):
		for y in range(1,14):
			var c:=Vector2i(x,y)
			if Nav.is_walkable(d,c) and abs(x-9)>1 and abs(y-7)>1:pool.append(c)
	var rng:=RandomNumberGenerator.new();rng.seed=stage*10513+6081
	var used:Array[Vector2i]=[start,goal]
	var items:Array[Dictionary]=[]
	var kinds:Array=["card","override","control"] if d.mission==0 else ["download","control","card"] if d.mission==1 else ["core","control","card"]
	for kind in kinds:
		var c:=Base._pick(rng,pool,used)
		items.append({"at":Base.world(c),"kind":kind,"name":{"card":"门禁卡","override":"手动解封台","control":"局部控制器","download":"数据终端","core":"能源核心"}[kind],"duration":0.65})
	d.items=items;d.needs={"card":1} if d.mission==0 else {"terminal":1} if d.mission==1 else {"power":1}
	preload("res://scripts/mission_variants.gd").decorate(d,stage,rng,pool,used)
	d.intel=[]
	for i in range(3):d.intel.append(Base.world(Base._pick(rng,pool,used)))
	d.cameras=[]
	for i in range(2):
		var at:Vector3=items[0 if i==0 else 1].at+Vector3(0,0,-2.6)
		at=Nav.world(d,Nav.nearest(d,at))
		d.cameras.append({"at":at,"heading":PI,"range":4.5})
	for g in d.guards:
		g.nav={"width":19,"height":15,"cell":1.3,"blocked":blocked}
		for i in range(g.route.size()):g.route[i]=Nav.world(d,Nav.nearest(d,g.route[i]))
	d.title=["突破封锁","盗取数据","能源转移"][d.mission]
	return d
static func objectives_connected(d:Dictionary)->bool:
	return Base.objectives_connected(d)

