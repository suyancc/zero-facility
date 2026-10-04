extends "res://tests/v67_mix_tests.gd"
func extra_checks(game:Node3D)->void:
	await super.extra_checks(game)
	var a=game.audio
	a.clear_tasks();a.reset_tension_audio();a.music.play()
	var d:=preload("res://scripts/tension_director.gd").new()
	var calm:Dictionary=d.tick(0.1,1,0,false,false,false)
	a.mix_state(0,1,0);a.mix_tension(0,calm,1)
	var pauses:int=a.audio_pause_writes;var gains:int=a.audio_gain_writes
	for i in range(120):a.mix_state(0,1,0);a.mix_tension(0,calm,1)
	check(a.audio_pause_writes==pauses,"unchanged unpaused state never resubmits a WebAudio resume")
	check(a.audio_gain_writes==gains,"unchanged gains do not resubmit audio updates")
	a.mix_tension(0,calm,2);check(a.music.stream_paused,"actual pause still reaches music player")
	a.mix_tension(0,calm,1);check(not a.music.stream_paused,"resume still reaches music player")
	a.reset_tension_audio();a.unlock()
	for i in range(20):
		var mode:String="suspect" if i%2==0 else "recovery"
		a.mix_tension(0.05,{"mode":mode,"intensity":0.5,"beat":false,"entered":false},1)
	check(a.detection_count==1,"rapid recognition/recovery alternation retains four-second cue cooldown")
	var saved:float=a.music_level;a.music_level=0;a.mix_tension(0,calm,1)
	check(a.music.volume_db< -90,"music slider zero remains effectively silent after gain debounce")
	a.music_level=saved;a.stop_effects()
