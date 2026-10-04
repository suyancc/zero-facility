extends SceneTree
const Gen:=preload("res://scripts/level_generator.gd")
const Nav:=preload("res://scripts/navigation.gd")
const Guard:=preload("res://scripts/guard.gd")
const V:=preload("res://scripts/visual_factory.gd")
const Main:=preload("res://scenes/main.tscn")
const Gravity:=preload("res://scripts/gravity_controller.gd")
var checks:int=0
var failures:int=0
func check(ok:bool,text:String)->void:
	checks+=1
	if ok:print("PASS: ",text)
	else:failures+=1;printerr("FAIL: ",text)
func _initialize()->void:call_deferred("run")
func run()->void:
	var all_connected:bool=true
	var paths_valid:bool=true
	for stage in range(1,151):
		var d:=Gen.generate(stage)
		all_connected=all_connected and Gen.objectives_connected(d)
		for spec in d.guards:
			for i in range(spec.route.size()):
				var points:=Nav.cells(d,Nav.nearest(d,spec.route[i]),Nav.nearest(d,spec.route[(i+1)%spec.route.size()]))
				paths_valid=paths_valid and not points.is_empty()
				for j in range(points.size()):
					paths_valid=paths_valid and Nav.is_walkable(d,points[j])
					if j>0:paths_valid=paths_valid and absi(points[j].x-points[j-1].x)+absi(points[j].y-points[j-1].y)==1
	check(all_connected,"150 larger maps connect spawn, every objective and delivery")
	check(paths_valid,"all patrol paths use free orthogonal cells without cabinet shortcuts")
	var a:=Gen.generate(23)
	var b:=Gen.generate(23)
	check(a.blocked==b.blocked and a.guards==b.guards,"deterministic layouts and patrols")
	check(a.width==17 and a.height==13,"larger 17 by 13 playable grid")
	check(Gen.generate(1000000000).guards.size()==4,"guard population capped at four")
	check(Gen.generate(1).objectives.size()==1 and Gen.generate(3).objectives.size()==2,"one and two station contracts")
	var font=load("res://assets/fonts/ShiftSansSC.ttf")
	var glyphs:bool=true
	for c in "巡逻调查追捕搜索返回确认诱饵轻运通行标记无线电支援西区扫描站东区中转站练习首关原进度保留":glyphs=glyphs and font.has_char(c.unicode_at(0))
	check(glyphs,"new Chinese intent and tactics glyphs present")
	check(absf(Gravity.target_acceleration(Vector2.RIGHT,Vector3.RIGHT,Vector3.FORWARD,12,22).length()-12)<0.001,"default gravity magnitude unchanged")
	var nav:Dictionary={"width":7,"height":7,"cell":1.3,"blocked":[Vector2i(3,3)]}
	var fixture:=Node3D.new()
	root.add_child(fixture)
	var guard:=Node3D.new()
	guard.set_script(Guard)
	guard.configure({"route":[Vector3(-2.6,0,0),Vector3(-2.6,0,-2.6)],"nav":nav,"range":3.5,"fov":72.0,"speed":1.0,"chase_speed":2.1,"pause":0.8})
	fixture.add_child(guard)
	guard.heading=-PI/2;guard.forward=Vector3.RIGHT
	var p:=RigidBody3D.new()
	p.freeze=true;p.collision_layer=0;p.collision_mask=0
	fixture.add_child(p)
	p.position=guard.position+Vector3(2,0.38,0)
	var wall:=V.box(fixture,Vector3(0.25,1.5,1.2),guard.position+Vector3(1,0.75,0),V.material(Color.WHITE),true,4)
	await physics_frame
	await physics_frame
	check(not guard.sees(p),"cabinet physically occludes vision")
	wall.queue_free()
	await physics_frame
	await physics_frame
	check(guard.sees(p),"unobstructed forward target visible")
	guard.update_ai(0.2,p,true)
	check(guard.mode!=Guard.Mode.CHASE and guard.confidence>0,"brief exposure raises confirmation without instant failure")
	guard.update_ai(0.2,p,true)
	guard.update_ai(0.3,p,true)
	check(guard.mode==Guard.Mode.CHASE,"sustained visibility confirms chase")
	check(not guard.caught,"distant confirmed target is not instantly captured")
	check(not guard.hear(Vector3.ZERO,100,"诱饵"),"direct visual chase ignores a competing noise")
	var memory:Vector3=guard.last_seen
	p.position=Vector3(20,0.38,20)
	guard.update_ai(0.2,p,true)
	check(guard.last_seen==memory,"unseen parcel does not update last known position")
	guard.update_ai(4.1,p,false)
	check(guard.mode==Guard.Mode.SEARCH,"lost target transitions to finite search")
	guard.update_ai(6.2,p,false)
	check(guard.mode==Guard.Mode.RETURN,"search expires and returns to patrol")
	check(not guard.hear(Vector3(100,0,100),2),"noise outside hearing radius ignored")
	check(guard.hear(Vector3(-2.6,0,1.3),7,"调查诱饵") and guard.mode==Guard.Mode.INVESTIGATE,"audible decoy redirects investigation")
	check(guard.last_heard==Vector3(-2.6,0,1.3),"investigation remembers sound location")
	guard.position=Vector3(-2.6,0,0);guard.heading=-PI/2;guard.forward=Vector3.RIGHT
	guard._set_mode(Guard.Mode.PATROL);guard.alert()
	p.position=guard.position+Vector3(0.5,0.38,0)
	guard.update_ai(0.016,p,true)
	check(guard.caught,"confirmed close contact captures parcel")
	fixture.queue_free()
	await process_frame
	var game:=Main.instantiate()
	game.test_mode=true
	root.add_child(game)
	await process_frame
	check(game.state==game.State.READY and game.level.guards.size()==2,"fresh game starts with two navigated patrols")
	game._primary()
	await create_timer(0.2).timeout
	check(game.level.parcel.position.y>0.2,"larger floor supports original parcel")
	check(game.impact_count==0,"stationary parcel does not make collision noise")
	var time:float=game.level.elapsed
	var at:Vector3=game.level.guards[0].position
	game.toggle_pause()
	await create_timer(0.15,true).timeout
	check(game.level.elapsed==time and game.level.guards[0].position==at,"pause freezes AI and mission clock")
	game.toggle_pause()
	check(game.level.throw_decoy(game.level.parcel.position+Vector3(0,0,-4)),"playing can deploy a decoy")
	check(game.level.decoys[0].target.distance_to(game.level.decoys[0].from)<=5.0,"snapped decoy target stays within five meters")
	check(game.level.decoys_left==1 and game.level.decoys.size()==1,"decoy consumes one charge")
	check(not game.level.throw_decoy(Vector3.ZERO),"decoy cooldown prevents spam")
	game.level._win(game.level.parcel)
	check(game.state==game.State.PLAYING,"delivery gated until required stations complete")
	game.level.parcel.set_active(false)
	game.level.parcel.position=game.level.data.objectives[0].at+Vector3.UP*0.38
	game.level.parcel.linear_velocity=Vector3.ZERO
	game.level.pursuit_count=0
	game.level._tick_objectives(0.2,0)
	check(game.level.objective_index==0,"station requires a short stable dwell")
	game.level._tick_objectives(0.6,0)
	check(game.level.objective_index==1 and game.level.decoys_left==2,"station completes and refills one decoy")
	game.level.pursuit_count=1
	game.level._win(game.level.parcel)
	check(game.state==game.State.PLAYING,"active pursuit blocks final delivery")
	game.level.pursuit_count=0
	game.level._win(game.level.parcel)
	check(game.state==game.State.WON,"escaped parcel with clearance may deliver")
	game._primary()
	check(game.stage==2 and game.state==game.State.READY,"success continues to next procedural contract")
	game._primary()
	game.level._on_impact(0.7)
	check(game.level.damage==0,"soft impacts do not damage fragile cargo")
	for i in range(4):game.level._on_impact(1.3)
	check(game.state==game.State.LOST,"four hard impacts fail fragile contract")
	game.stage=3;game.load_level();game._primary()
	var first:Node3D=game.level.guards[0]
	game.level._report(first,Vector3.ZERO)
	check(game.level.guards[1].mode==Guard.Mode.INVESTIGATE and game.level.radio_cooldown>0,"contact report sends one helper with radio cooldown")
	game.retry()
	check(game.level.objective_index==0 and game.level.decoys_left==2 and game.level.decoys.is_empty(),"retry resets objectives charges and deployed decoys")
	for i in range(8):game.retry();await process_frame
	check(get_nodes_in_group("parcels").size()==1,"restarts leave one parcel")
	check(game.audio.music.stream.loop and game.audio.ambient.stream.loop,"music and environment loops retained")
	var saved:int=game.settings_data.stage
	game._practice()
	check(game.stage==1 and game.settings_data.stage==saved,"first-stage practice preserves saved progression")
	game._primary();game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.state==game.State.PAUSED,"focus loss still pauses game")
	paused=false
	game.queue_free()
	await process_frame
	V.cache.clear();V.shapes.clear()
	print("RESULT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

