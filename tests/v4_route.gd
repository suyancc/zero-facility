extends SceneTree
const Gen:=preload("res://scripts/level_generator.gd")
func _initialize()->void:call_deferred("run")
func shift(pressed:bool)->void:
	var event:=InputEventKey.new()
	event.physical_keycode=KEY_SHIFT
	event.pressed=pressed
	Input.parse_input_event(event)
func run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	await process_frame
	var overall:bool=true
	for stage in [1,3]:
		game.stage=stage;game.load_level();game._primary()
		var cells:Array[Vector2i]=[Vector2i(0,11),Vector2i(0,3),Vector2i(2,3),Vector2i(0,3)]
		if game.level.data.objectives.size()>1:
			cells.append_array([Vector2i(0,0),Vector2i(16,0),Vector2i(16,9),Vector2i(13,9),Vector2i(16,9),Vector2i(16,0)])
			cells.append_array([Vector2i(15,0),Vector2i(15,1)])
		else:cells.append_array([Vector2i(0,12),Vector2i(16,12),Vector2i(16,1),Vector2i(15,1)])
		var next:int=0
		var frames:int=0
		var thrown:bool=false
		var right:Vector3=game.camera.global_basis.x;right.y=0;right=right.normalized()
		var forward:Vector3=-game.camera.global_basis.z;forward.y=0;forward=forward.normalized()
		while frames<12000 and game.state==game.State.PLAYING:
			var p:Vector3=game.level.parcel.position;p.y=0
			var velocity:Vector3=game.level.parcel.linear_velocity;velocity.y=0
			var target:Vector3=Gen.world(cells[next])
			var is_station:bool=cells[next]==Vector2i(2,3) or cells[next]==Vector2i(13,9)
			var expected:int=1 if cells[next]==Vector2i(2,3) else 2
			if next<cells.size()-1 and p.distance_to(target)<0.58 and velocity.length()<0.6:
				if not is_station or game.level.objective_index>=expected:
					next+=1;thrown=false;target=Gen.world(cells[next])
			is_station=cells[next]==Vector2i(2,3) or cells[next]==Vector2i(13,9)
			# Use the normal finite-charge decoy mechanic, not a guard-state override.
			if is_station and not thrown and p.distance_to(target)<2.8:
				thrown=game.level.throw_decoy(target+Vector3(4,0,0))
			shift(is_station and p.distance_to(target)<3.0 and game.level.pursuit_count==0)
			var force:Vector3=(target-p)*3.0-velocity*2.8
			var input:=Vector2(force.dot(right),-force.dot(forward))/4.4
			input=input.limit_length(1)
			for action in ["gravity_left","gravity_right","gravity_up","gravity_down"]:Input.action_release(action)
			Input.action_press("gravity_right" if input.x>0 else "gravity_left",absf(input.x))
			Input.action_press("gravity_down" if input.y>0 else "gravity_up",absf(input.y))
			await physics_frame
			frames+=1
		var won:bool=game.state==game.State.WON
		overall=overall and won
		print("ROUTE stage=",stage," won=",won," time=",game.level.elapsed," stations=",game.level.objective_index," waypoint=",next," snapshot=",JSON.stringify(game.snapshot()))
	shift(false)
	game.queue_free();await process_frame
	quit(0 if overall else 1)

