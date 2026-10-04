extends SceneTree
const Nav:=preload("res://scripts/navigation.gd")
func _initialize()->void:call_deferred("run")
func key(code:Key,pressed:bool)->void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=pressed;Input.parse_input_event(e)
func release()->void:
	for action in ["gravity_left","gravity_right","gravity_up","gravity_down"]:Input.action_release(action)
func run()->void:
	var game=load("res://scenes/main.tscn").instantiate();game.test_mode=true;game.tactical_mode=false;root.add_child(game);await process_frame
	var overall:bool=true
	for stage in [1,3]:
		game.stage=stage;game.load_level();game._primary()
		var path:Array[Vector3]=[];var destination:=Vector3(999,0,999);var signature:String=""
		var frames:int=0;var used_decoy:float=-10
		while frames<14400 and game.state==game.State.PLAYING:
			var level=game.level;var player=level.player
			var p:Vector3=player.position;p.y=0
			var current:String=JSON.stringify(level.found)+str(level.exit_open)
			if current!=signature:
				signature=current
				destination=level.target_position()
				if level.requirements_met():destination=level.data.goal+level.data.exit_direction*(0.55 if level.exit_open else -0.8)
				path=Nav.path(level.data,p,destination)
				if not path.is_empty():path[path.size()-1]=destination
			var distance:float=p.distance_to(destination)
			var near_interaction:bool=(p.distance_to(level.data.goal)<1.22 if level.requirements_met() else distance<0.72) and not level.exit_open
			if near_interaction:
				release();key(KEY_SHIFT,false);key(KEY_E,true)
			else:
				key(KEY_E,false)
				while path.size()>1 and p.distance_to(path[0])<0.22:path.pop_front()
				var target:Vector3=path[0] if not path.is_empty() else destination
				var velocity:Vector3=player.velocity;velocity.y=0
				var force:Vector3=(target-p)*2.6-velocity*0.7
				var right:Vector3=game.camera.global_basis.x;right.y=0;right=right.normalized()
				var forward:Vector3=-game.camera.global_basis.z;forward.y=0;forward=forward.normalized()
				var input:=Vector2(force.dot(right),-force.dot(forward)).limit_length(1)
				release()
				Input.action_press("gravity_right" if input.x>0 else "gravity_left",absf(input.x))
				Input.action_press("gravity_down" if input.y>0 else "gravity_up",absf(input.y))
				var nearest:Node3D=null;var danger:float=100
				for guard in level.guards:
					var d:float=p.distance_to(guard.position)
					if d<danger:danger=d;nearest=guard
				key(KEY_SHIFT,danger<5.5 or level.pursuit_count>0)
				if danger<5 and level.elapsed-used_decoy>4 and level.decoys_left>0:
					if level.throw_decoy(nearest.position+(nearest.position-p).normalized()*3):used_decoy=level.elapsed
			await physics_frame;frames+=1
		key(KEY_E,false);key(KEY_SHIFT,false);release()
		var won:bool=game.state==game.State.WON;overall=overall and won
		print("ESCAPE stage=",stage," won=",won," seconds=",game.level.elapsed," snapshot=",JSON.stringify(game.snapshot()))
	game.queue_free();await process_frame;quit(0 if overall else 1)

