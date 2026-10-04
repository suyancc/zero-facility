extends "res://tests/v64_thumbnail_tests.gd"
var op_events:Array[String]=[]
func index_of(level:Node3D,kind:String,last:bool=false)->int:
	var result:int=-1
	for i in range(level.data.items.size()):
		if level.data.items[i].kind==kind:
			result=i
			if not last:return i
	return result
func fixture(game:Node3D,number:int)->Node3D:
	game.stage=number;game.load_level();game._primary();game.level.set_physics_process(false)
	return game.level
func act(level:Node3D,index:int,time:float=10)->void:
	level.player.position=level.data.items[index].at;level._tick_interaction(time,true,false)
func extra_checks(game:Node3D)->void:
	await super.extra_checks(game)
	var signatures:Dictionary={};var stable:bool=true;var connected:bool=true
	for number in range(1,121):
		var d:Dictionary=Gen.generate(number);var again:Dictionary=Gen.generate(number)
		signatures[str(d.mission)+":"+str(d.variant)]=true
		stable=stable and d.variant==again.variant and d.items==again.items
		connected=connected and Gen.objectives_connected(d)
	check(signatures.size()==9,"120 generated stages cover all nine objective variants")
	check(stable,"retry seed preserves exact variant and objective placement")
	check(connected,"all added terminals/interfaces reachable with maintenance doors locked")
	var level=fixture(game,4);var card:int=index_of(level,"card");var control:int=index_of(level,"control");var override:int=index_of(level,"override")
	check(level.data.variant==1 and game.hud.heading.text.contains(level.data.variant_title) and game.hud.body.text.contains("出口"),"READY uses this run's variant, steps and exit location")
	act(level,card);check(not level.requirements_met() and level.tracked_target().id=="control","alert lockdown card requires disabling controller")
	act(level,control);check(level.requirements_met(),"controller plus card completes alert lockdown without consumables")
	level=fixture(game,4);override=index_of(level,"override");level.player.position=level.data.items[override].at
	check(level._nearest_interaction().duration==8,"loud bypass takes eight seconds without controller")
	act(level,override,8.1);check(level.requirements_met(),"loud bypass remains an equipment-free alternative")
	level=fixture(game,7);act(level,index_of(level,"override"));check(not level.requirements_met(),"dual authorization cannot finish with manual release alone")
	act(level,index_of(level,"card"));check(level.requirements_met(),"dual authorization completes with both permissions")
	level=fixture(game,5);var first:int=index_of(level,"download");var second:int=index_of(level,"download",true)
	act(level,first);act(level,second)
	check(level.transfers.size()==2 and level.download_running(),"split terminals can download concurrently")
	level._tick_transfers(5);check(not level.download_running() and not level.requirements_met(),"finished downloads still require retrieving both fragments")
	act(level,first);check(level.fragments==1 and not level.requirements_met(),"one fragment cannot complete two-part objective")
	act(level,second);check(level.fragments==2 and level.requirements_met(),"two retrieved fragments complete split objective")
	level=fixture(game,8);first=index_of(level,"download");level.player.position=level.data.items[first].at
	var task:Dictionary=level._nearest_interaction();check(task.is_empty() or task.kind!="download","uncalibrated terminal cannot start download")
	check(level.tracked_target().id=="control","uncalibrated mission guides to prerequisite controller")
	act(level,index_of(level,"control"));act(level,first);check(level.download_started,"calibration unlocks actual download interaction")
	level=fixture(game,6);var core:int=index_of(level,"core");level.player.position=level.data.items[core].at
	task=level._nearest_interaction();check(task.is_empty() or task.kind!="core","unstable core cannot be lifted before stabilization")
	act(level,index_of(level,"control"));act(level,core);check(level.player.carrying,"stabilization enables carrying without consuming gear")
	level=fixture(game,9);act(level,index_of(level,"core"));var options:Array=level.Guidance.choices(level)
	var alternate:bool=false
	for item in options:
		if item.id=="deliver_silent":alternate=true
	check(alternate,"carried core offers second real delivery destination")
	act(level,index_of(level,"override"),4.1);check(level.core_delivered and not level.player.carrying,"remote silent interface accepts core and unlocks extraction objective")
	level=fixture(game,1);level.operation_audio.connect(func(kind:String,_progress:float):op_events.append(kind))
	override=index_of(level,"override");act(level,override,0.1)
	check(level.active_operation=="override" and game.audio.operation_kind=="override" and not level.manual_override,"holding E starts corresponding sound before completion")
	level._tick_interaction(0.1,false,false)
	check(game.audio.operation_kind=="" and level.interact_progress==0 and not level.manual_override,"releasing E stops work sound and resets incomplete progress")
	act(level,override,0.1);level._tick_interaction(0.1,true,true)
	check(game.audio.operation_kind=="" and level.interact_progress==0,"movement interrupts work audio and progress")
	act(level,override,0.1);game.toggle_pause();check(game.audio.operation_kind=="","pause clears active work loop without completing task");game.toggle_pause()
	act(level,override,4.1);check(game.audio.operation_kind=="" and level.manual_override,"completion stops work loop before success cue")
	var hashes:Dictionary={}
	for wav in game.audio.operation_cache.values():hashes[hash(wav.data)]=true
	check(hashes.size()==8,"eight types of sustained operation sound have different PCM")
	check(game.audio.operation_player not in game.audio.players and game.audio.operation_player!=game.audio.task_player,"work loop has its own channel separate from footsteps and completion cues")
	game.audio.set_operation("intel",0.1);AudioServer.set_bus_mute(0,true);game.audio.set_operation("intel",0.2)
	check(game.audio.operation_kind=="","muted progress does not start audible or stale work loop");AudioServer.set_bus_mute(0,false)
	game.load_level();check(game.audio.operation_kind=="" and not game.audio.operation_player.playing,"retry clears work audio")
