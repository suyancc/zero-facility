extends SceneTree
const Gen:=preload("res://scripts/level_generator.gd")
func _initialize()->void: call_deferred("run")
func run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	game.test_mode=true
	root.add_child(game)
	await process_frame
	var overall:bool=true
	for stage in [1,2,3,24,100]:
		game.stage=stage
		game.load_level()
		await process_frame
		game._primary()
		# Outer-route turning points; never teleport the parcel or bypass detection.
		var targets:Array[Vector3]=[Gen.world(Vector2i(0,7)),Gen.world(Vector2i(0,0)),Gen.world(Vector2i(9,0)),Gen.world(Vector2i(9,1))]
		var next:int=0
		var frames:int=0
		var right:Vector3=game.camera.global_basis.x
		right.y=0;right=right.normalized()
		var forward:Vector3=-game.camera.global_basis.z
		forward.y=0;forward=forward.normalized()
		while frames<6000 and game.state==game.State.PLAYING:
			var p:Vector3=game.level.parcel.position;p.y=0
			var velocity:Vector3=game.level.parcel.linear_velocity;velocity.y=0
			if next<targets.size()-1 and p.distance_to(targets[next])<0.6 and velocity.length()<0.65:next+=1
			var force:Vector3=(targets[next]-p)*3.0-velocity*2.8
			var input:=Vector2(force.dot(right),-force.dot(forward))/4.4
			input=input.limit_length(1.0)
			for action in ["gravity_left","gravity_right","gravity_up","gravity_down"]:Input.action_release(action)
			Input.action_press("gravity_right" if input.x>0 else "gravity_left",absf(input.x))
			Input.action_press("gravity_down" if input.y>0 else "gravity_up",absf(input.y))
			await physics_frame
			frames+=1
		var won:bool=game.state==game.State.WON
		overall=overall and won
		print("ROUTE stage=",stage," won=",won," time=",game.level.elapsed," position=",game.level.parcel.position)
	game.queue_free()
	await process_frame
	quit(0 if overall else 1)
