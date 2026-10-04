extends "res://tests/v66_tension_tests.gd"
func extra_checks(game:Node3D)->void:
	await super.extra_checks(game)
	var a=game.audio;game._primary();AudioServer.set_bus_mute(0,false);a.unlock()
	var d:=preload("res://scripts/tension_director.gd").new()
	a.clear_tasks();a.reset_tension_audio();a.mix_tension(1,d.tick(.1,1,0,false,false,false),1)
	check(a.music.volume_db> -36,"calm music no longer stacks excessive player attenuation")
	a.mix_tension(.1,d.tick(.1,1,.4,false,false,false),1)
	check(a.detection_count==1 and a.detection_player.playing,"initial recognition immediately starts distinct audible warning")
	for i in range(10):a.mix_tension(.1,d.tick(.1,1,.4,false,false,false),1)
	check(a.detection_count==1,"sustained recognition does not spam warning")
	a.mix_tension(.1,d.tick(.1,2,.4,false,false,false),2)
	check(a.detection_player.stream_paused or not a.detection_player.playing,"pause freezes or finishes detection accent safely")
	a.stop_effects();check(a.detection_count==0 and not a.detection_player.playing,"retry clears detection warning and cooldown")
