extends SceneTree
const Nav:=preload("res://scripts/navigation.gd")
func _initialize()->void:call_deferred("run")
func key(code:Key,pressed:bool)->void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=pressed;Input.parse_input_event(e)
func release()->void:
	for action in ["gravity_left","gravity_right","gravity_up","gravity_down"]:Input.action_release(action)
func risk_path(level:Node3D,start:Vector3,goal:Vector3)->Array[Vector3]:
	var from:Vector2i=Nav.nearest(level.data,start);var to:Vector2i=Nav.nearest(level.data,goal)
	var costs:Dictionary={};var previous:Dictionary={from:from};var distance:Dictionary={from:0.0};var todo:Array[Vector2i]=[from]
	while not todo.is_empty():
		var best:int=0
		for i in range(todo.size()):
			if distance[todo[i]]<distance[todo[best]]:best=i
		var c:Vector2i=todo[best];todo.remove_at(best)
		if c==to:break
		for offset in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next:Vector2i=c+offset
			if not Nav.is_walkable(level.data,next):continue
			if not costs.has(next):
				var point:Vector3=Nav.world(level.data,next);var cost:float=1.0
				for guard in level.guards+level.security_cameras:
					if guard.jammed>1:continue
					var range_to:float=point.distance_to(guard.position)
					if guard in level.guards:cost+=maxf(0,3.8-range_to)*8
					if guard.sees_point(point+Vector3.UP*1.28):cost+=18
				costs[next]=cost
			var score:float=distance[c]+costs[next]
			if not distance.has(next) or score<distance[next]:
				distance[next]=score;previous[next]=c
				if not todo.has(next):todo.append(next)
	var result:Array[Vector3]=[]
	if not previous.has(to):return result
	var cursor:Vector2i=to
	while cursor!=from:result.push_front(Nav.world(level.data,cursor));cursor=previous[cursor]
	result.push_front(Nav.world(level.data,from));result[result.size()-1]=goal
	return result
func find_refuge(level:Node3D,p:Vector3)->Vector3:
	var best:Vector3=p;var score:float=-10000
	for c in Nav.reachable(level.data,Nav.nearest(level.data,p)):
		var point:Vector3=Nav.world(level.data,c);var distance:float=point.distance_to(p)
		if distance<2 or distance>4.7:continue
		var length:int=Nav.cells(level.data,Nav.nearest(level.data,p),c).size()
		if length>8:continue
		var value:float=-length*0.3
		for g in level.guards+level.security_cameras:
			value+=minf(6,point.distance_to(g.position))
			if g.sees_point(point+Vector3.UP*1.28):value-=20
		if value>score:score=value;best=point
	return best
func run()->void:
	var game=load("res://scenes/main.tscn").instantiate();game.test_mode=true;root.add_child(game);await process_frame
	var all_pass:bool=true
	for stage in [1,2,3]:
		game.stage=stage;game.load_level()
		var gear:Array[String]=[];gear.assign(["smoke","pick"] if stage==1 else ["smoke","jammer"])
		game.level.set_loadout(gear);game._primary()
		if stage==1:game.level.use_slot(1,game.level.player.position)
		var refuge:=Vector3.INF
		var path:Array[Vector3]=[];var frame:int=0;var previous_goal:=Vector3(999,0,999)
		while frame<18000 and game.state==game.State.PLAYING:
			var level=game.level;var player=level.player;var p:Vector3=player.position;p.y=0
			var goal:Vector3=level.data.goal-level.data.exit_direction*0.8
			if level.exit_open:goal=level.data.goal+level.data.exit_direction*0.55
			elif stage==3 and not level.control_used:goal=level.data.items[1].at
			elif stage==2 and not level.download_taken:goal=level.data.items[0].at
			elif stage==3 and not player.carrying and not level.core_delivered:goal=level.core_at
			if stage==2 and level.download_started and level.download_time<9.5:
				if refuge==Vector3.INF:refuge=find_refuge(level,p)
				goal=refuge
			var exit_approach:bool=goal==level.data.goal-level.data.exit_direction*0.8
			var near:bool=(p.distance_to(level.data.goal)<1.22 if exit_approach else p.distance_to(goal)<0.60) and not level.exit_open
			if goal!=previous_goal or (frame%36==0 and level.nearest_risk>0.03):
				path=risk_path(level,p,goal);previous_goal=goal
			if near:
				release();key(KEY_SHIFT,false);key(KEY_E,true)
			else:
				key(KEY_E,false)
				while path.size()>1 and p.distance_to(path[0])<0.24:path.pop_front()
				var target:Vector3=path[0] if not path.is_empty() else goal
				var velocity:Vector3=player.velocity;velocity.y=0
				var force:Vector3=(target-p)*5.5-velocity*0.35
				var right:Vector3=game.camera.global_basis.x;right.y=0;right=right.normalized()
				var forward:Vector3=-game.camera.global_basis.z;forward.y=0;forward=forward.normalized()
				var input:=Vector2(force.dot(right),-force.dot(forward)).limit_length(1)
				release();Input.action_press("gravity_right" if input.x>0 else "gravity_left",absf(input.x));Input.action_press("gravity_down" if input.y>0 else "gravity_up",absf(input.y))
				key(KEY_SHIFT,level.pursuit_count>0 or level.nearest_risk>0.2)
			if stage>1:
				for g in level.guards:
					if g.position.distance_to(p)<2.8 and (g.confidence>0.1 or g.mode==g.Mode.CHASE):level.use_slot(1,p)
			if level.nearest_risk>0.3 and not level.sight_is_blocked(p,p):level.use_slot(0,p)
			await physics_frame;frame+=1
		key(KEY_E,false);key(KEY_SHIFT,false);release()
		var won:bool=game.state==game.State.WON;all_pass=all_pass and won
		print("TACTICAL ROUTE stage=",stage," won=",won," snapshot=",JSON.stringify(game.snapshot()))
	game.queue_free();await process_frame;quit(0 if all_pass else 1)

