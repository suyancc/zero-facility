extends SceneTree
const Gen:=preload("res://scripts/tactical_generator.gd")
const Nav:=preload("res://scripts/navigation.gd")
const Main:=preload("res://scenes/main.tscn")
var checks:int=0
var failures:int=0
func check(ok:bool,text:String)->void:
	checks+=1
	if ok:print("PASS: ",text)
	else:failures+=1;printerr("FAIL: ",text)
func _initialize()->void:call_deferred("run")
func run()->void:
	var connected:bool=true;var peripheral:bool=true;var varied:bool=true;var alternate:bool=true
	var goals:Dictionary={}
	for stage in range(1,121):
		var d:=Gen.generate(stage);var start:Vector2i=Nav.nearest(d,d.start)
		connected=connected and Gen.objectives_connected(d) and Nav.reachable(d,start).size()==285-d.blocked.size()
		var edge:int=0;var kinds:Dictionary={}
		for c in d.cover:
			kinds[c.kind]=true
			if c.cell.x<=1 or c.cell.x>=17 or c.cell.y<=1 or c.cell.y>=13:edge+=1
		peripheral=peripheral and edge>=12;varied=varied and kinds.size()==5
		var at:Vector2i=d.doors[0].cell;var before:int=Nav.cells(d,at+Vector2i.LEFT,at+Vector2i.RIGHT).size()
		d.blocked.erase(at)
		alternate=alternate and before>3 and Nav.cells(d,at+Vector2i.LEFT,at+Vector2i.RIGHT).size()==3
		goals[str(d.goal)]=true
	check(connected,"120 tactical maps connect every objective and exit with maintenance door LOCKED")
	check(peripheral and varied,"120 maps retain perimeter furniture and five cover silhouettes")
	check(alternate,"every maintenance door creates a measurable alternate shortcut")
	check(goals.size()>12,"tactical exits still vary across perimeter")
	var d:=Gen.generate(14);check(d.blocked==Gen.generate(14).blocked and d.items==Gen.generate(14).items,"retries reproduce tactical map and task locations")
	check(Gen.generate(1).title!=Gen.generate(2).title and Gen.generate(2).title!=Gen.generate(3).title,"three distinct objective loops rotate")
	var game=Main.instantiate();game.test_mode=true;root.add_child(game);await process_frame
	var level=game.level;var p=level.player
	check(level.loadout.size()==2 and level.decoys_left==0,"exactly two equipped gadgets, no free third decoy")
	var equipment:Array[String]=["smoke","jammer"];level.set_loadout(equipment)
	game._primary();level.set_physics_process(false)
	check(level.use_slot(0,p.position),"smoke can be deployed from equipped slot")
	check(level.charges.smoke==1 and level.projectiles.size()==1 and level.smoke_clouds.is_empty(),"smoke spends one finite charge and launches a real projectile")
	level._tick_projectiles(0.6)
	check(level.projectiles.is_empty() and level.smoke_clouds.size()==1,"smoke activates only after projectile lands")
	check(level.sight_is_blocked(p.position-Vector3.RIGHT*3,p.position+Vector3.RIGHT*3),"smoke intersects vision segment, not merely target center")
	check(not level.use_slot(0,p.position),"gadget cooldown prevents double use")
	check(not level.throw_decoy(p.position),"unequipped decoy unavailable")
	var g=level.guards[0];g.position=p.position+Vector3.RIGHT;g._set_mode(g.Mode.CHASE);g.last_seen=p.position
	level.gear_cooldown=0;check(level.use_slot(1,p.position),"EMP affects nearby guard")
	var where:Vector3=g.position;g.update_ai(0.1,p,true)
	check(g.jammed>3 and g.position==where and not g.caught,"jammed guard cannot move or capture during pulse")
	check(g.mode==g.Mode.CHASE,"EMP preserves pursuit state rather than clearing alert")
	g.jammed=0;g.update_ai(0.01,p,true);check(g.jammed==0 and g.cone.visible,"guard resumes after EMP")
	var smoke_life:float=level.smoke_clouds[0].life;game.toggle_pause();await process_frame
	check(level.smoke_clouds[0].life==smoke_life,"pause does not expire smoke")
	game.toggle_pause()
	level.smoke_clouds[0].life=0.01;level._physics_process(0.02)
	check(level.smoke_clouds.is_empty(),"smoke expires and restores visibility")
	# Controlled component fixtures below are not input-driven route evidence.
	game.load_level();game._primary();level=game.level;level.set_physics_process(false);p=level.player
	p.position=level.doors[0].at+Vector3.LEFT*0.8
	level.use_slot(1,p.position);level._tick_interaction(0.5,true,false)
	check(not level.doors[0].open and level.charges.pick==2,"lockpick requires sustained interaction and does not spend early")
	level._tick_interaction(0.1,false,false);check(level.interact_progress==0,"releasing E cancels lockpick")
	level._tick_interaction(2.3,true,false);await physics_frame
	check(level.doors[0].open and level.charges.pick==1,"lockpick opens maintenance door and consumes one charge")
	check(Nav.is_walkable(level.data,level.doors[0].cell),"opened door updates shared navigation")
	var disabled:bool=false
	for c in level.doors[0].body.get_children():
		if c is CollisionShape3D:disabled=c.disabled
	check(disabled,"opened door removes actual collision")
	p.position=level.data.items[1].at;level._tick_interaction(4.1,true,false)
	check(level.manual_override and level.requirements_met(),"manual override provides tool-free breakout solution")
	p.position=level.data.goal-level.data.exit_direction*0.7;level._tick_interaction(1.2,true,false)
	check(level.exit_open,"completed breakout unlocks physical exit")
	game.load_level();game._primary();level=game.level;level.set_physics_process(false);p=level.player
	p.position=level.data.goal-level.data.exit_direction*0.7;level.use_slot(1,p.position);level._tick_interaction(3.1,true,false)
	check(level.exit_open and level.charges.pick==1,"breakout offers direct lockpick solution distinct from item collection")
	game.stage=2;game.load_level();game._primary();level=game.level;level.set_physics_process(false);p=level.player
	p.position=level.data.items[0].at;level._tick_interaction(0.7,true,false)
	check(level.download_started and not level.download_taken and not level.requirements_met(),"download starts without immediately satisfying task")
	level._tick_interaction(1.0,true,false);check(not level.download_taken,"cannot collect unfinished download")
	p.position=level.data.start;level._physics_process(5)
	check(level.download_time==5 and not level.requirements_met(),"download advances while player leaves terminal")
	level._physics_process(5);check(level.download_time==10 and not level.requirements_met(),"completed download still requires physical retrieval")
	p.position=level.data.items[0].at;level._tick_interaction(0.7,true,false)
	check(level.download_taken and level.requirements_met(),"returning to terminal retrieves completed data")
	p.position=level.data.items[1].at;level._tick_interaction(1.6,true,false)
	check(level.control_used and level.doors[0].open and level.security_cameras[0].jammed==45,"optional control panel changes cameras AND route topology")
	game.stage=3;game.load_level();game._primary();level=game.level;level.set_physics_process(false);p=level.player
	p.position=level.core_at;level._tick_interaction(0.7,true,false)
	check(p.carrying and not level.requirements_met(),"lifting core is not equivalent to delivering it")
	p.drive(0.1,Vector2.RIGHT,game.camera,false,true)
	check(not p.running and Vector2(p.velocity.x,p.velocity.z).length()<=1.81,"carrying disables sprint and limits movement speed")
	var location:Vector3=p.position;check(level.drop_core(),"carried core can be deliberately placed down")
	check(not p.carrying and level.core_at.distance_to(Vector3(location.x,0,location.z))<0.01,"dropped core remains at actual player position")
	p.position=level.core_at;level._tick_interaction(0.7,true,false)
	check(p.carrying,"dropped core can be picked up again")
	p.position=level.data.goal-level.data.exit_direction*0.7;level._tick_interaction(1.1,true,false)
	check(level.core_delivered and not p.carrying and level.requirements_met() and not level.exit_open,"core delivery is separate from exit opening")
	level._tick_interaction(1.2,true,false);check(level.exit_open,"core task permits final door opening")

	game.load_level();game._primary();level=game.level;level.set_physics_process(false);p=level.player
	var camera=level.security_cameras[0];camera.position=p.position+Vector3(0,0,1.2);camera.base_heading=0;camera.clock=0
	await physics_frame
	camera.update_ai(0.3,p,true)
	check(camera.confidence>0 and level.alert_count==0,"camera gives a confirmation window before alarm")
	camera.update_ai(0.7,p,true)
	check(level.alert_count==1 and game.state==game.State.PLAYING,"confirmed camera reports position instead of instantly failing player")
	camera.update_ai(1.0,p,true);check(level.alert_count==1,"camera radio cooldown prevents repeated alarm spam")
	camera.jammed=0.5;camera.update_ai(0.2,p,true)
	check(camera.confidence==0 and not camera.cone.visible,"jammed camera stops confirming and hides active vision")
	camera.update_ai(0.4,p,true);camera.update_ai(0.01,p,true)
	check(camera.cone.visible and camera.jammed==0,"camera automatically resumes after interference expires")
	var font=load("res://assets/fonts/TacticalSansSC.ttf");var glyphs:bool=true
	for letter in "烟雾罐撬锁干扰器监控下载核心搬运维修门方案装备":glyphs=glyphs and font.has_char(letter.unicode_at(0))
	check(glyphs,"new tactical Chinese UI glyphs bundled")

	game.load_level()
	game.hud.inventory_tiles[1].pressed.emit();game.hud.catalog_tiles[0].pressed.emit()
	check(game.selected_gear==game.level.loadout and game.level.loadout[0]=="pick" and game.level.loadout[1]=="smoke","ready-screen equipment selection reaches game state and prevents duplicate slots")
	game._primary()
	var before:Array=game.level.loadout.duplicate();var changed:Array[String]=["pick","decoy"]
	game.level.set_loadout(changed)
	check(game.level.loadout==before,"equipment cannot be replaced or refilled after mission starts")

	check(game.hud.inventory_tiles.size()==2 and game.hud.catalog_tiles.size()==4,"two square inventory slots and four icon equipment choices replace dropdowns")
	var textures:bool=true
	for kind in ["smoke","jammer","pick","decoy"]:textures=textures and preload("res://scripts/gear_tile.gd").icon_for(kind).get_width()==128
	check(textures,"all four original model thumbnails render as 128px textures")
	var signatures:Dictionary={}
	for kind in ["smoke","jammer","pick","decoy"]:
		var wav=preload("res://scripts/audio_feedback.gd").make_gadget(kind);signatures[hash(wav.data)]=true
	check(signatures.size()==4,"four item sounds have distinct generated PCM data")
	check(game.aim.mesh is ArrayMesh and game.aim.material_override.albedo_color.a<0.3,"range preview is a translucent thin mesh rather than solid torus")
	await extra_checks(game)
	game.queue_free();await process_frame
	print("TACTICAL RESULT: ",checks," checks, ",failures," failures");quit(1 if failures else 0)

func extra_checks(_game:Node3D)->void:pass

