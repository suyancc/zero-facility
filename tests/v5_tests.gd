extends SceneTree
const Gen:=preload("res://scripts/level_generator.gd")
const Nav:=preload("res://scripts/navigation.gd")
const Guard:=preload("res://scripts/guard.gd")
const Main:=preload("res://scenes/main.tscn")
const Store:=preload("res://scripts/progress_store.gd")
const V:=preload("res://scripts/visual_factory.gd")
var checks:int=0
var failures:int=0
func check(ok:bool,text:String)->void:
	checks+=1
	if ok:print("PASS: ",text)
	else:failures+=1;printerr("FAIL: ",text)
func _initialize()->void:call_deferred("run")
func run()->void:
	var connected:bool=true;var varied:bool=true;var perimeter:bool=true
	var exits:Dictionary={};var starts:Dictionary={}
	for stage in range(1,81):
		var d:=Gen.generate(stage)
		connected=connected and Gen.objectives_connected(d) and Nav.reachable(d,Nav.nearest(d,d.start)).size()==d.width*d.height-d.blocked.size()
		var types:Dictionary={};var edge:int=0
		for spec in d.cover:
			types[spec.kind]=true
			if spec.cell.x<=1 or spec.cell.x>=17 or spec.cell.y<=1 or spec.cell.y>=13:edge+=1
		varied=varied and types.size()==5;perimeter=perimeter and edge>=20
		exits[str(d.goal)]=true;starts[str(d.start)]=true
	check(connected,"80 maps connect all walkable cells objectives and exit")
	check(varied,"all maps contain five cover types")
	check(perimeter,"all maps place at least 20 obstacles around perimeter")
	check(exits.size()>12 and starts.size()==4,"exits vary across edges and all four spawns are used")
	var a:=Gen.generate(17);var b:=Gen.generate(17)
	check(a.blocked==b.blocked and a.goal==b.goal and a.items==b.items,"same sector retry reproduces layout exit and items")
	check(Gen.generate(1).items.size()==3 and Gen.generate(1).needs.power==2,"power contract permits two of three choices")
	check(Gen.generate(2).needs.has("card") and Gen.generate(3).needs.has("terminal"),"card and terminal contracts rotate")
	var font=load("res://assets/fonts/EscapeSansSC.ttf");var glyphs:bool=true
	for c in "零号设施逃生奔跑潜行档案电源门禁终端体力出口警报练习首区":glyphs=glyphs and font.has_char(c.unicode_at(0))
	check(glyphs,"escape UI Chinese glyphs available")
	var game:=Main.instantiate();game.test_mode=true;game.tactical_mode=false;root.add_child(game);await process_frame
	check(game.state==game.State.READY and game.level.player is CharacterBody3D,"character body replaces rigid parcel")
	var p:CharacterBody3D=game.level.player
	var limbs:bool=true
	for name in ["upperarm_l","lowerarm_l","hand_l","hand_r","thigh_l","calf_l","foot_l","foot_r"]:limbs=limbs and p.rig.skeleton.find_bone(name)>=0
	check(limbs,"independent skinned arms forearms hands thighs shins and feet exist")
	var fingers:bool=true
	for name in ["hand_l","thumb_01_l","index_01_l","middle_01_l","ring_01_l","pinky_01_l"]:fingers=fingers and p.rig.skeleton.find_bone(name)>=0
	check(fingers,"skinned hand includes palm four fingers and thumb")
	p.set_active(true);p.velocity=Vector3(2,0,0);p.running=false;p.sneaking=false;p._process(0.15)
	check(p.pose=="walk" and absf(p.rig.bone_at("foot_l").z-p.rig.bone_at("foot_r").z)>0.05,"walk uses alternating leg joints")
	var sole:float=minf(p.rig.sole_heights.x,p.rig.sole_heights.y)
	check(absf(sole)<0.025,"walk plants at least one independent shoe near ground")
	p.running=true;p._process(0.2)
	check(p.pose=="run" and p.forearms[0].rotation.x > 0.8,"run changes arm bend and gait")
	p.running=false;p.sneaking=true;p._process(0.1)
	check(p.pose=="sneak","stealth has distinct slow pose")
	p.stamina=80;p.drive(0.05,Vector2.RIGHT,game.camera,false,true)
	check(p.stamina<80 and p.running,"sprinting drains stamina")
	p.stamina=0;p.drive(0.05,Vector2.RIGHT,game.camera,false,true)
	check(p.exhausted and not p.running,"empty stamina prevents sprint flicker")
	p.stamina=30;p.drive(0.05,Vector2.RIGHT,game.camera,false,true)
	check(p.running,"sprint resumes after sufficient recovery")
	p.stamina=50;p.drive(0.1,Vector2.ZERO,game.camera,false,false)
	check(p.stamina>50,"standing recovers stamina")
	game.retry();game._primary();await create_timer(0.2).timeout
	check(game.level.player.position.y> -0.15,"character capsule stands on facility floor")
	check(game.impact_count==0,"standing does not trigger impact effects")
	var t:float=game.level.elapsed;var at:Vector3=game.level.guards[0].position
	game.toggle_pause();await create_timer(0.12,true).timeout
	check(game.level.elapsed==t and game.level.guards[0].position==at,"pause freezes player AI and clock")
	game.toggle_pause()
	check(game.level.throw_decoy(game.level.player.position+Vector3(0,0,4)),"normal decoy action remains available")
	check(game.level.decoys_left==1 and not game.level.throw_decoy(Vector3.ZERO),"finite charges and cooldown remain")
	game.level._win();check(game.state==game.State.PLAYING,"closed exit cannot finish sector")
	game.level.player.set_active(false)
	for i in range(2):
		game.level.player.position=game.level.data.items[i].at+Vector3.UP*0.1
		game.level._tick_interaction(0.2,true,false)
		if i==0:
			check(game.level.found.power==0,"pickup requires held interaction")
			game.level._tick_interaction(0.1,false,false)
			check(game.level.interact_progress==0,"releasing interact cancels progress")
		game.level._tick_interaction(0.7,true,false)
	check(game.level.requirements_met() and game.level.taken.size()==2,"any two power pickups satisfy exit condition")
	for i in range(2):
		game.level.player.position=game.level.data.intel[i]+Vector3.UP*0.1
		game.level._tick_interaction(0.5,true,false)
	check(game.level.intel_count==2,"optional intel is collectible independently")
	game.level.player.position=game.level.data.goal-game.level.data.exit_direction*0.7+Vector3.UP*0.1
	game.level._tick_interaction(1.2,true,false);await process_frame
	check(game.level.exit_open and game.level.exit_collision.disabled,"held exit interaction opens physical door")
	game.level.elapsed=12.5;game.level._win()
	check(game.state==game.State.WON and game.settings_data.records["1"].stars==3,"escape grade includes clean run and optional intel")
	check(game.settings_data.records["1"].seconds==12.5,"best escape time recorded in memory")
	game._primary();check(game.stage==2 and game.state==game.State.READY,"escape continues to next sector")
	var saved:int=game.settings_data.stage;game._practice()
	check(game.stage==1 and game.settings_data.stage==saved,"practice preserves unlocked progression")
	var clean:=Store.clean_records({"1":{"seconds":15,"stars":9,"intel":9},"bad":{},"2":{"seconds":-1,"stars":1,"intel":0}})
	check(clean.size()==1 and clean["1"].stars==3,"record loader rejects invalid entries and clamps scores")
	var g:Node3D=game.level.guards[0]
	g.confidence=0.5;g.anim_clock=0;g.step(0.1,true)
	var alpha:float=g.cone_material.albedo_color.a
	check(g.cone_material.albedo_color.r>0.9 and g.cone_material.albedo_color.g<0.4,"detecting vision becomes red")
	g.step(0.2,true);check(absf(g.cone_material.albedo_color.a-alpha)>0.01,"red detection cone pulses")
	g.reduced_fx=true;g.step(0.1,true);alpha=g.cone_material.albedo_color.a;g.step(0.2,true)
	check(is_equal_approx(alpha,g.cone_material.albedo_color.a),"reduced effects disables flashing")
	check(game.audio.music.stream.loop and game.audio.ambient.stream.loop,"music and environment loops remain")
	game._primary();game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.state==game.State.PAUSED,"focus loss pauses escape")
	paused=false;game.queue_free();await process_frame;V.cache.clear();V.shapes.clear()
	var fixture:=Node3D.new();root.add_child(fixture)
	var watcher:=Node3D.new();watcher.set_script(Guard)
	watcher.configure({"route":[Vector3(-2.6,0,0),Vector3(-2.6,0,-2.6)],"nav":{"width":7,"height":7,"cell":1.3,"blocked":[]},"range":3.7,"fov":72.0,"speed":1.0,"chase_speed":2.65,"pause":0.6})
	fixture.add_child(watcher);watcher.heading=-PI/2;watcher.forward=Vector3.RIGHT
	var person=load("res://scenes/characters/escape_player.tscn").instantiate();fixture.add_child(person);person.position=Vector3(-0.6,0,0)
	var low:=V.box(fixture,Vector3(0.3,0.76,1.2),Vector3(-1.6,0.38,0),V.material(Color.WHITE),true,4)
	await physics_frame;await physics_frame
	check(watcher.sees(person),"low crate does not falsely conceal standing human")
	low.queue_free();await physics_frame
	var high:=V.box(fixture,Vector3(0.3,1.8,1.2),Vector3(-1.6,0.9,0),V.material(Color.WHITE),true,4)
	await physics_frame;await physics_frame
	check(not watcher.sees(person),"tall equipment occludes human vision samples")
	high.queue_free();await physics_frame;await physics_frame
	watcher.update_ai(0.2,person,true)
	check(watcher.mode!=Guard.Mode.CHASE,"brief human exposure is not instant capture")
	watcher.update_ai(0.2,person,true);watcher.update_ai(0.26,person,true)
	check(watcher.mode==Guard.Mode.CHASE and not watcher.caught,"confirmed distant human enters pursuit")
	var memory:Vector3=watcher.last_seen
	person.position=Vector3(15,0,15);watcher.update_ai(0.1,person,true)
	check(watcher.last_seen==memory,"unseen human does not update guard memory")
	watcher.update_ai(4.1,person,false);check(watcher.mode==Guard.Mode.SEARCH,"lost human triggers last-position search")
	watcher.update_ai(6.2,person,false);check(watcher.mode==Guard.Mode.RETURN,"search expires rather than omniscient pursuit")
	check(watcher.hear(watcher.position+Vector3.RIGHT,5,"调查诱饵"),"noise still redirects returning guard")
	watcher._set_mode(Guard.Mode.PATROL);watcher.alert();watcher.heading=-PI/2;watcher.forward=Vector3.RIGHT
	person.position=watcher.position+Vector3(0.5,0,0);watcher.update_ai(0.016,person,true)
	check(watcher.caught,"close pursuit captures human character")
	fixture.queue_free();await process_frame;V.cache.clear();V.shapes.clear()
	print("RESULT: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)

