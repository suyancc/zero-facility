extends "res://tests/v65_variants_tests.gd"
func extra_checks(game:Node3D)->void:
	await super.extra_checks(game)
	var Director:=preload("res://scripts/tension_director.gd")
	var d:=Director.new();var mood:Dictionary=d.tick(0.1,1,0,false,false,false)
	check(d.mode=="calm" and d.intensity==0,"safe scene begins calm with no heartbeat pressure")
	for i in range(10):mood=d.tick(0.1,1,0.65,false,false,false)
	check(d.mode=="suspect" and d.intensity>0.3,"partial recognition builds suspicion before capture")
	mood=d.tick(0.1,1,0.07,false,false,false)
	check(d.mode=="suspect","recognition hysteresis prevents mode chatter")
	mood=d.tick(0.1,1,0,false,false,true)
	check(d.mode=="chase" and mood.entered,"camera alarm enters confirmed danger even without guard chase")
	var beats:int=0
	for i in range(20):
		mood=d.tick(0.1,1,0,true,false,false)
		if mood.beat:beats+=1
	check(beats>=3 and d.bpm>135,"chase accelerates shared heartbeat clock within bounded BPM")
	var phase:float=d.phase;var intensity:float=d.intensity;var age:float=d.beat_age
	for i in range(20):mood=d.tick(0.1,2,1,true,false,true)
	check(d.phase==phase and d.intensity==intensity and d.beat_age==age and not mood.beat,"pause freezes visual phase, intensity and beat events")
	for i in range(30):mood=d.tick(0.1,1,0,false,true,false)
	check(d.mode=="recovery" and d.intensity>0.3,"lost sight enters search aftermath rather than immediate calm")
	for i in range(200):mood=d.tick(0.1,1,0,false,false,false)
	check(d.mode=="calm" and d.intensity<0.01,"safe interval gradually releases residual tension")
	d.tick(0.1,1,1,true,false,false);mood=d.tick(0.1,3,0,false,false,false)
	check(d.intensity==0 and not mood.beat,"victory clears heartbeat clock")
	d.reset();check(d.phase==0 and d.alarm_hold==0 and d.recovery_hold==0,"retry resets tension timers and phase")
	game.stage=1;game.load_level();game._primary();var level=game.level;level.set_physics_process(false)
	for g in level.guards:g.confidence=0;g.mode=g.Mode.PATROL
	for c in level.security_cameras:c.confidence=0
	var camera=level.security_cameras[0];camera.confidence=0.7
	game._process(0.1);check(game.tension.mode=="suspect","actual camera confidence feeds shared director")
	camera.jammed=4;game.tension.reset();game._process(0.1)
	check(game.tension.mode=="calm","disabled camera cannot generate phantom visual tension")
	camera.confidence=0;camera.jammed=0;level.alert_count+=1;game._process(0.1)
	check(game.tension.mode=="chase","actual camera alert counter latches confirmed danger")
	game.audio.unlock();var a=game.audio
	check(a.tension_layers.size()==3 and a.heartbeat_player not in a.players,"music layers and heartbeat use independent dedicated players")
	for layer in a.tension_layers.values():check(absf(layer.stream.get_length()-a.music.stream.get_length())<0.01,"music stems share exact loop duration")
	for i in range(15):game._process(0.1)
	check(float(a.tension_weights.chase)>0.5 and a.heartbeat_count>0,"live danger fades in chase layer and triggers shared beats")
	a.set_operation("override",0.4);a.mix_tension(0.1,game.tension.last,1)
	check(a.tension_duck>0,"music ducks for important work and completion channels")
	a.music.play();a.heartbeat_player.play()
	for layer in a.tension_layers.values():layer.play()
	game.toggle_pause();game._process(0.1)
	check(a.music.stream_paused and a.heartbeat_player.stream_paused,"pause suspends music and heartbeat playback together")
	game.toggle_pause();game._process(0.1)
	check(not a.music.stream_paused,"resume unpauses existing music without restarting stems")
	game.settings_data.edge_heartbeat=false;game._process(0.1)
	check(not game.hud.tension_edge.visible,"edge effect can be disabled independently of sound")
	game.settings_data.edge_heartbeat=true;game.settings_data.reduced=true;game._process(0.1)
	check(game.hud.tension_edge.fx.get_shader_parameter("subtle")==1.0,"reduced motion removes beat modulation while retaining mild static warning")
	game.settings_data.reduced=false;a.heartbeat_level=0;var count:int=a.heartbeat_count
	for i in range(10):game._process(0.1)
	check(a.heartbeat_count==count,"zero heartbeat volume prevents new heartbeat playback")
	a.heartbeat_level=0.75;game.load_level();game._process(0.1)
	check(game.tension.intensity==0 and not a.heartbeat_player.playing,"loading new attempt clears audible heartbeat and visual tension")
	check(game.hud.music_slider!=null and game.hud.heartbeat_slider!=null and game.hud.edge_toggle!=null,"Chinese comfort settings expose independent music, heartbeat and edge controls")

