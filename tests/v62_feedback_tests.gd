extends "res://tests/v6_tests.gd"
const V:=preload("res://scripts/visual_factory.gd")
func extra_checks(game:Node3D)->void:
	game.selected_gear.assign(["smoke","pick"]);game.stage=1;game.load_level()
	var level=game.level;var p=level.player
	check(level.tracked_target().id=="card","default breakout guidance points to card solution")
	game.hud.tracking_button.pressed.emit()
	check(level.tracked_target().id=="override" and level.target_position()==level.data.items[1].at,"tracking button switches both name and actual target to override")
	var event:=InputEventKey.new();event.physical_keycode=KEY_T;event.pressed=true;game._unhandled_key_input(event)
	check(level.tracked_target().id=="exit_pick" and level.target_position()==level.data.goal,"T cycles to direct lockpick exit guidance")
	check(not level.requirements_met(),"changing tracking does not grant objective completion")
	level.charges.pick=0
	check(level.tracked_target().id=="card","spent lockpick invalidates shortcut guidance and falls back safely")
	level.found.card=1
	check(level.tracked_target().id=="exit","completed main goal updates guidance to extraction")
	game.load_level();level=game.level;p=level.player;game._primary();level.set_physics_process(false)
	level.use_slot(1,p.position)
	check(level.tracked_target().id=="exit_pick","arming lockpick proactively guides breakout player to exit")
	level.tracked_goal="intel"
	var target_before:Vector3=level.target_position()
	for i in range(level.data.intel.size()):
		if level.data.intel[i]==target_before:level.intel_taken[i]=true
	check(level.target_position()!=target_before,"optional archive tracker skips already-collected intel")
	level.tracked_goal="control";level.control_used=true
	check(level.tracked_target().id=="card","completed optional control returns guidance to main objective")
	level.set_physics_process(false)
	var target:Vector3=p.position+Vector3(0,0,1.3)
	var plan:Dictionary=level.throw_solution(target)
	check(plan.valid and plan.points.size()==25,"throw preview samples full arc with clearance checks")
	check(plan.points[0]==plan.from and plan.points[24].distance_to(plan.target)<0.001,"preview trajectory includes exact launch and landing points")
	check(plan.points[12].y>plan.from.y,"throw arc rises above release point")
	var released:Array[String]=[];level.gear_sound.connect(func(kind:String):released.append(kind))
	check(level.use_slot(0,target),"smoke throw accepted along clear preview")
	check(released==["throw"] and level.smoke_clouds.is_empty(),"release emits throw sound without premature smoke or hiss")
	level._tick_projectiles(0.20)
	var flight:Dictionary=level.projectiles[0]
	check(flight.node.position.distance_to(level.FX.throw_point(plan.from,plan.target,0.20/level.FLIGHT_TIME))<0.001,"actual canister follows the same equation as preview")
	check(level.smoke_clouds.is_empty(),"midair projectile does not block vision")
	var frozen:Vector3=flight.node.position
	game.toggle_pause();await process_frame
	check(flight.node.position==frozen,"pause freezes thrown canister")
	game.toggle_pause();level._tick_projectiles(0.40)
	check(level.projectiles.is_empty() and level.smoke_clouds.size()==1 and is_equal_approx(level.smoke_clouds[0].life,6.0),"landing begins full six-second smoke lifetime")
	check(released==["throw","smoke"],"landing triggers smoke release audio separately from throw")
	# Solid wall fixture in the reserved spawn area, no persistence or AI route claim.
	var wall=V.box(level,Vector3(3.0,3.0,0.20),p.position+Vector3(0,1.5,0.65),V.material(Color.WHITE),true,4)
	await physics_frame;await physics_frame
	var before:int=level.charges.smoke;level.gear_cooldown=0
	check(not level.valid_throw(target),"solid barrier invalidates preview arc")
	check(not level.use_slot(0,target) and level.charges.smoke==before,"blocked throw neither launches nor consumes inventory")
	wall.queue_free();await physics_frame;await physics_frame
	game.selected_gear.assign(["jammer","smoke"]);game.load_level();game._primary();level=game.level;p=level.player;level.set_physics_process(false)
	for guard in level.guards:guard.position=p.position+Vector3(8,0,0)
	for camera in level.security_cameras:camera.position=p.position+Vector3(8,0,0)
	check(not level.use_slot(0,p.position) and level.charges.jammer==1 and level.jam_hits_last==0,"EMP with no nearby device stays silent and keeps charge")
	level.guards[0].position=p.position+Vector3.RIGHT
	level.security_cameras[0].position=p.position+Vector3(0,0,1.4)
	level.guards[0]._set_mode(level.guards[0].Mode.CHASE)
	check(level.use_slot(0,p.position) and level.jam_hits_last==2,"EMP reports exact number of affected devices")
	check(level.guards[0].has_node("InterferenceFeedback") and level.security_cameras[0].has_node("InterferenceFeedback"),"both hit guard and camera receive device-attached offline indicators")
	check(not level.guards[1].has_node("InterferenceFeedback"),"out-of-range devices are not decorated as hits")
	var feedback=level.guards[0].get_node("InterferenceFeedback")
	level.guards[0].update_ai(0.5,p,true);feedback.update_feedback(0.1)
	check(feedback.bar.scale.x<1 and level.guards[0].intent.text.begins_with("离线"),"offline countdown and progress bar track actual remaining disable time")
	feedback.reduced=true;feedback.update_feedback(0)
	check(not feedback.circuit.visible and feedback.badge.visible,"reduced effects suppress sparks while preserving readable offline icon")
	check(level.guards[0].mode==level.guards[0].Mode.CHASE,"hit feedback does not erase pursuit state")
	level.guards[0].jammed=0;feedback.update_feedback(0)
	check(feedback.is_queued_for_deletion(),"expired interference removes attached effects")
	game.stage=2;game.load_level();level=game.level
	level.download_started=true;level.download_time=10
	check(level.tracked_target().name=="取回下载数据","download tracker changes instruction when data is ready")
	game.stage=3;game.load_level();level=game.level
	level.player.carrying=true
	check(level.target_position()==level.data.goal and level.tracked_target().id=="deliver","carrying core automatically tracks delivery destination")
	level.player.carrying=false;level.core_at+=Vector3.RIGHT
	check(level.target_position()==level.core_at and level.tracked_target().id=="core","dropping core restores guidance to actual dropped location")

