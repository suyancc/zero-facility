extends "res://tests/v6_route.gd"
func run()->void:
	var game=load("res://scenes/main.tscn").instantiate();game.test_mode=true;root.add_child(game);await process_frame
	var all_pass:bool=true
	for stage in range(1,10):
		game.stage=stage;game.load_level()
		game._primary()
		# Objective/navigation fixture, NOT a live-stealth success benchmark.
		# No consumables; hazards frozen so all nine mandatory paths are isolated.
		for g in game.level.guards+game.level.security_cameras:g.jammed=10000
		for kind in game.level.charges:game.level.charges[kind]=0
		var refuge:=Vector3.INF
		var path:Array[Vector3]=[];var frame:int=0;var previous_goal:=Vector3(999,0,999)
		while frame<18000 and game.state==game.State.PLAYING:
			var level=game.level;var player=level.player;var p:Vector3=player.position;p.y=0
			var goal:Vector3=level.data.goal-level.data.exit_direction*0.8
			if level.exit_open:goal=level.data.goal+level.data.exit_direction*0.55
			elif not level.requirements_met():
				var v:int=level.data.variant
				if level.data.mission==0:
					if v==1 and not level.control_used:goal=item_at(level,"control")
					elif level.found.card==0:goal=item_at(level,"card")
					else:goal=item_at(level,"override")
				elif level.data.mission==1:
					if v==2 and not level.control_used:goal=item_at(level,"control")
					elif v==1:
						goal=Vector3.INF
						for i in range(level.data.items.size()):
							if level.data.items[i].kind=="download" and not level.taken.has(i) and (not level.transfers.has(i) or float(level.transfers[i])>=5):goal=level.data.items[i].at;break
						if goal==Vector3.INF:
							if refuge==Vector3.INF:refuge=find_refuge(level,p)
							goal=refuge
					else:
						goal=item_at(level,"download")
						if level.download_started and level.download_time<9.5:
							if refuge==Vector3.INF:refuge=find_refuge(level,p)
							goal=refuge
				else:
					if v==1 and not level.control_used:goal=item_at(level,"control")
					elif not player.carrying:goal=level.core_at
					elif v==2:goal=item_at(level,"override")
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
			await physics_frame;frame+=1
		key(KEY_E,false);key(KEY_SHIFT,false);release()
		var won:bool=game.state==game.State.WON;all_pass=all_pass and won
		print("VARIANT OBJECTIVE ROUTE hazards=frozen charges=0 stage=",stage," won=",won," snapshot=",JSON.stringify(game.snapshot()))
	game.queue_free();await process_frame;quit(0 if all_pass else 1)

func item_at(level:Node3D,kind:String)->Vector3:
	for item in level.data.items:
		if item.kind==kind:return item.at
	return level.data.goal
