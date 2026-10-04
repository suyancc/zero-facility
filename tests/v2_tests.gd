extends SceneTree
const Gen := preload("res://scripts/level_generator.gd")
const Guard := preload("res://scripts/guard.gd")
const V := preload("res://scripts/visual_factory.gd")
const Gravity := preload("res://scripts/gravity_controller.gd")
const Main := preload("res://scenes/main.tscn")
var checks:int=0
var failures:int=0
func check(ok:bool,label:String)->void:
	checks+=1
	if ok: print("PASS: ",label)
	else: failures+=1; printerr("FAIL: ",label)
func _initialize()->void: call_deferred("run")
func run()->void:
	var assets_ok:bool=true
	for asset in ["machine", "machine-window", "robot-arm-a", "pipe-large-bend", "conveyor-long", "box-small"]:
		var packed=load("res://assets/models/factory/"+asset+".glb")
		assets_ok=assets_ok and packed is PackedScene
	check(assets_ok,"all six used third-party models import as scenes")
	var font=load("res://assets/fonts/GravitySansSC.ttf")
	var glyphs_ok:bool=true
	for character in "重力快递夜班潜行管理员下一关设置声音":
		glyphs_ok=glyphs_ok and font.has_char(character.unicode_at(0))
	check(glyphs_ok,"key Chinese UI glyphs present in bundled font")
	var all_routes:=true
	var safe_distances:=true
	for stage in range(1,501):
		var d:=Gen.generate(stage)
		all_routes=all_routes and Gen.safe_route_valid(d)
		for spec in d.guards:
			for point in spec.route:
				for cell in d.safe_route:
					safe_distances=safe_distances and Gen.world(cell).distance_to(point)>spec.range+0.54
	check(all_routes,"500 stages preserve connected unobstructed outer route")
	check(safe_distances,"500 stages safe route clears every patrol envelope plus parcel radius")
	var a:=Gen.generate(17)
	var b:=Gen.generate(17)
	check(a.blocked==b.blocked and a.guards==b.guards,"deterministic retry seed")
	check(Gen.generate(18).blocked!=a.blocked,"next stage changes layout")
	var high:=Gen.generate(1000000000)
	check(high.guards.size()==3 and high.difficulty==23,"high stage difficulty capped")
	check(Gen.safe_route_valid(high),"high stage safe route valid")
	check(Guard.in_sector(Vector3.ZERO,Vector3.FORWARD,Vector3(0,0,-2),3,60),"target ahead in sector")
	check(not Guard.in_sector(Vector3.ZERO,Vector3.FORWARD,Vector3(0,0,2),3,60),"target behind invisible")
	check(not Guard.in_sector(Vector3.ZERO,Vector3.FORWARD,Vector3(0,0,-4),3,60),"target outside range invisible")
	check(not Guard.in_sector(Vector3.ZERO,Vector3.FORWARD,Vector3(2,0,-1),3,60),"target outside angle invisible")
	var axial:=Gravity.target_acceleration(Vector2.RIGHT,Vector3.RIGHT,Vector3.FORWARD,12,22)
	var diagonal:=Gravity.target_acceleration(Vector2(1,1),Vector3.RIGHT,Vector3.FORWARD,12,22)
	check(absf(axial.length()-diagonal.length())<0.001,"approved gravity magnitude unchanged")
	var fixture:=Node3D.new()
	root.add_child(fixture)
	var guard:=Node3D.new()
	guard.set_script(Guard)
	guard.configure({"route":[Vector3.ZERO,Vector3(0,0,-1)],"range":3.0,"fov":70.0,"speed":0.6,"pause":1.0})
	fixture.add_child(guard)
	var blocker:=V.box(fixture,Vector3(1.0,1.4,0.3),Vector3(0,0.7,-1),V.material(Color.WHITE),true,4)
	await physics_frame
	await physics_frame
	check(not guard.sees_point(Vector3(0,0,-2)),"physical occluder blocks vision")
	blocker.queue_free()
	await physics_frame
	await physics_frame
	check(guard.sees_point(Vector3(0,0,-2)),"removing occluder reveals target")
	fixture.queue_free()
	await process_frame
	var game:=Main.instantiate()
	game.test_mode=true
	root.add_child(game)
	await process_frame
	check(game.state==game.State.READY and game.stage==1,"fresh test game begins at stage one READY")
	check(game.level.guards.size()==1,"first stage has one moving administrator")
	game._primary()
	await create_timer(0.25).timeout
	check(game.level.parcel.position.y>0.2,"parcel stays on new floor")
	check(game.impact_count==0,"stationary ground contact does not trigger collision sounds")
	var t:float=game.level.elapsed
	var guard_at:Vector3=game.level.guards[0].position
	game.toggle_pause()
	await create_timer(0.12,true).timeout
	check(game.level.elapsed==t and game.level.guards[0].position==guard_at,"pause freezes clock and patrol")
	game.toggle_pause()
	var target_guard=game.level.guards[0]
	game.level.parcel.position=target_guard.position+target_guard.forward*0.7+Vector3.UP*0.38
	game.level.protection=0.8
	game.level._physics_process(0.016)
	check(game.state==game.State.PLAYING,"explicit start protection prevents instant spawn loss")
	game.level.protection=0
	game.level._physics_process(0.016)
	check(game.state==game.State.LOST,"unobstructed sight causes immediate failure")
	game.level._win(game.level.parcel)
	check(game.state==game.State.LOST,"detection failure cannot be reversed by delivery")
	game.retry()
	game._primary()
	var dock=game.level.dock
	var parcel=game.level.parcel
	parcel.set_active(false)
	parcel.position=dock.position+Vector3.UP*0.38
	parcel.linear_velocity=Vector3.ZERO
	parcel.angular_velocity=Vector3.ZERO
	check(dock.fits(parcel),"centered parcel fits destination")
	parcel.position.x+=1.0
	check(not dock.fits(parcel),"dock rejects overhang")
	parcel.position.x-=1.0
	parcel.linear_velocity=Vector3(2,0,0)
	check(not dock.fits(parcel),"dock rejects excessive speed")
	parcel.linear_velocity=Vector3.ZERO
	dock.candidate=parcel
	dock.tick(0.1,true)
	check(not dock.completed,"dock requires dwell")
	dock.tick(0.6,true)
	check(game.state==game.State.WON,"valid delivery wins")
	game._primary()
	check(game.stage==2 and game.state==game.State.READY,"success primary advances to next stage")
	var old_seed:int=game.level.data.seed
	game.retry()
	check(game.stage==2 and game.level.data.seed==old_seed,"retry preserves current stage and seed")
	for i in range(20):
		game.retry()
		await process_frame
	check(get_nodes_in_group("parcels").size()==1,"20 procedural restarts leave one parcel")
	game._primary()
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.state==game.State.PAUSED,"focus loss pauses new game")
	paused=false
	check(Gen.generate(1).mission==0 and Gen.generate(2).mission==1 and Gen.generate(3).mission==2,"three delivery mission types rotate")
	game.stage=2
	game.load_level()
	game._primary()
	game.level._on_impact(0.8)
	check(game.level.damage==0,"soft impacts do not damage fragile cargo")
	for i in range(3):game.level._on_impact(1.5)
	check(game.state==game.State.PLAYING and game.level.damage==3,"fragile cargo tolerates three hard impacts")
	game.level._on_impact(1.5)
	check(game.state==game.State.LOST,"fourth hard impact fails fragile mission")
	game.stage=3
	game.load_level()
	game._primary()
	game.level._win(game.level.parcel)
	check(game.state==game.State.PLAYING,"scan mission cannot finish before scanning")
	game.level.parcel.position=game.level.data.scan+Vector3.UP*0.4
	game.level._physics_process(0.016)
	check(game.level.scanned_cargo and not game.level.scan_marker.visible,"scan ring registers cargo and disappears")
	game.level._win(game.level.parcel)
	check(game.state==game.State.WON,"scan mission can finish after scanning")
	check(game.audio.music.stream!=null and game.audio.ambient.stream!=null,"music and room tone resources loaded")
	check(game.audio.music.stream.loop and game.audio.ambient.stream.loop,"background audio loops enabled")
	game.retry()
	check(not game.level.scanned_cargo and game.level.damage==0,"retry resets mission state")
	game.queue_free()
	await process_frame
	V.cache.clear()
	print("RESULT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
