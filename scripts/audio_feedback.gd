extends Node
const FOOT:=preload("res://assets/audio/footstep_concrete_000.ogg")
const CLICK := preload("res://assets/audio/click_001.ogg")
const SUCCESS := preload("res://assets/audio/confirmation_002.ogg")
const FAILURE := preload("res://assets/audio/error_004.ogg")
const IMPACTS := [preload("res://assets/audio/impactWood_light_000.ogg"),preload("res://assets/audio/impactWood_light_001.ogg"),preload("res://assets/audio/impactMetal_light_000.ogg")]
var players: Array[AudioStreamPlayer] = []
var next_player: int = 0
var unlocked: bool = false
var warning_cooldown: float = 0.0
var ambient: AudioStreamPlayer
var master: float = 0.65
var music: AudioStreamPlayer
var mix_level: float = -22.0

func _ready() -> void:
	for i in range(6):
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)
	ambient = AudioStreamPlayer.new()
	ambient.volume_db = -32.0
	add_child(ambient)
	ambient.stream=load("res://assets/audio/factory-room.ogg")
	ambient.stream.loop=true
	music=AudioStreamPlayer.new()
	music.stream=load("res://assets/audio/tension_mix/calm.ogg")
	music.stream.loop=true
	music.volume_db=-24
	add_child(music)
	_setup_task_audio()
	_setup_operation_audio()
	_setup_tension_audio()

func unlock() -> void:
	unlocked = true
	if DisplayServer.get_name()!="headless":
		if not ambient.playing:ambient.play()
		if not music.playing:
			music.play()
			for layer in tension_layers.values():layer.play()

func play_sample(stream: AudioStream, volume: float = -12.0, pitch: float = 1.0) -> void:
	if not unlocked or DisplayServer.get_name() == "headless": return
	var player := players[next_player]
	next_player = (next_player+1)%players.size()
	player.stop()
	player.stream = stream
	player.volume_db = volume + linear_to_db(maxf(master,0.00001))
	player.pitch_scale = pitch
	player.play()

func click() -> void: play_sample(CLICK,-14.0)
func success() -> void: play_sample(SUCCESS,-7.0)
func failure() -> void: play_sample(FAILURE,-8.0,0.82)
func collision(strength: float) -> void:
	play_sample(IMPACTS[next_player%IMPACTS.size()],lerpf(-22.0,-8.0,clampf(strength/3.0,0,1)),randf_range(0.94,1.08))

func proximity(delta: float, risk: float) -> void:
	warning_cooldown -= delta
	if risk > 0.42 and warning_cooldown <= 0.0:
		warning_cooldown = lerpf(1.1,0.4,risk)
		tone(520.0,0.045,-27.0)

func tone(frequency: float, duration: float = 0.14, volume: float = -17.0) -> void:
	if not unlocked or DisplayServer.get_name() == "headless": return
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var count := int(duration*22050)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	for i in range(count):
		var t := float(i)/22050.0
		var envelope := sin(PI*float(i)/float(count))
		var sound := sin(TAU*frequency*t)*0.7 + sin(TAU*frequency*1.5*t)*0.15
		bytes.encode_s16(i*2,int(sound*envelope*15000))
	wav.data = bytes
	play_sample(wav,volume)

func stop_effects() -> void:
	clear_tasks()
	reset_tension_audio()
	for player in players:
		player.stop()
		player.stream = null

func _exit_tree() -> void:
	stop_effects()
	for child in get_children():
		if child is AudioStreamPlayer:child.stop();child.stream=null
	task_cache.clear();operation_cache.clear();gadget_samples.clear();tension_layers.clear()

# Avoid forwarding unchanged controls to the WebAudio backend every rendered frame.
var audio_pause_writes:int=0
var audio_gain_writes:int=0
func _set_paused(player:AudioStreamPlayer,value:bool)->void:
	if player.stream_paused==value:return
	player.stream_paused=value;audio_pause_writes+=1
func _set_gain(player:AudioStreamPlayer,value:float)->void:
	# 0.05 dB is below a perceptible step, while retaining smooth music/duck fades.
	if absf(player.volume_db-value)<0.05:return
	player.volume_db=value;audio_gain_writes+=1
func _stop_active(player:AudioStreamPlayer)->void:
	if player.playing:player.stop()
func mix_state(delta:float,state:int,risk:float) -> void:
	var gain:=linear_to_db(maxf(master,0.00001))
	if operation_player!=null:_set_gain(operation_player,-14+gain)
	if task_player!=null:_set_gain(task_player,-7+gain)
	if download_player!=null:_set_gain(download_player,-17+gain)
	_set_gain(ambient,(-40.0 if state==2 else -31.0)+gain)
func step_sound(loudness:float)->void:
	play_sample(FOOT,-28.0 if loudness<1 else -17.0 if loudness>4 else -22.0,randf_range(0.93,1.08))

var gadget_samples:Dictionary={}
func gadget(kind:String)->void:
	if not gadget_samples.has(kind):gadget_samples[kind]=make_gadget(kind)
	play_sample(gadget_samples[kind],-17.0 if kind=="jammer" else -15.0)
static func make_gadget(kind:String)->AudioStreamWAV:
	var duration:float=0.24 if kind=="throw" else 0.85 if kind=="smoke" else 0.55 if kind=="jammer" else 0.4
	var rate:int=22050;var count:int=int(duration*rate);var bytes:=PackedByteArray();bytes.resize(count*2)
	var rng:=RandomNumberGenerator.new();rng.seed=67061
	var low:float=0
	for i in range(count):
		var t:float=float(i)/rate;var progress:float=t/duration;var n:float=rng.randf_range(-1,1);low=lerpf(low,n,0.16)
		var sample:float=0
		match kind:
			"throw":sample=low*2.0*sin(PI*progress)*exp(-progress*1.8)+n*exp(-t*110)*0.2
			"smoke":sample=low*1.9*sin(PI*progress)*exp(-progress*0.7)+n*exp(-t*110)*0.5
			"jammer":sample=(sin(TAU*(950*t-700*t*t))*0.4+sin(TAU*90*t)*0.2+low*0.25)*sin(PI*progress)*exp(-progress*1.3)
			"pick":
				for hit in [0.0,0.1,0.23]:
					if t>=hit:sample+=(n*0.5+sin(TAU*2400*t)*0.15)*exp(-(t-hit)*100)
			"decoy":sample=sin(TAU*(880 if t<0.17 else 1175)*t)*0.4*pow(sin(PI*fmod(t,0.2)/0.2),4)
			"unlock":sample=low*exp(-t*30)*1.3+sin(TAU*680*t)*0.2*sin(PI*progress)
			_:sample=n*exp(-t*100)*0.2
		bytes.encode_s16(i*2,int(clampf(sample,-0.9,0.9)*25000))
	var wav:=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=rate;wav.data=bytes
	return wav

const TASK_FILES:Dictionary={"card":"card","power":"power","intel":"intel","download_start":"download_start","download_ready":"download_ready","download_collect":"download_collect","control":"control","override":"override","core":"core","core_drop":"core_drop","deliver":"deliver","door":"door","pick":"pick","breach":"breach","mission":"mission","escape":"escape","captured":"captured"}
const TASK_PRIORITY:Dictionary={"mission":100,"captured":100,"deliver":80,"download_ready":70,"escape":60,"intel":40}
var task_player:AudioStreamPlayer
var download_player:AudioStreamPlayer
var task_queue:Array[String]=[]
var task_cache:Dictionary={}
var task_current:String=""
var download_active:bool=false
var task_paused:bool=false
func _setup_task_audio()->void:
	task_player=AudioStreamPlayer.new();task_player.volume_db=-7;add_child(task_player)
	task_player.finished.connect(_next_task)
	download_player=AudioStreamPlayer.new();download_player.volume_db=-17;add_child(download_player)
	for event in TASK_FILES:
		task_cache[event]=load("res://assets/audio/tasks/%s.wav"%TASK_FILES[event])
	var loop:AudioStreamWAV=load("res://assets/audio/tasks/download_loop.wav").duplicate()
	loop.loop_mode=AudioStreamWAV.LOOP_FORWARD;loop.loop_begin=0;loop.loop_end=int(loop.get_length()*loop.mix_rate)
	download_player.stream=loop
func task_event(event:String)->void:
	if not TASK_FILES.has(event) or AudioServer.is_bus_mute(0) or not unlocked:return
	if event in ["mission","captured"]:
		set_operation("",0)
		task_queue.clear();task_player.stop();task_current="";set_download_active(false)
	if event==task_current or task_queue.has(event):return
	if task_queue.size()<3:task_queue.append(event)
	else:
		var lowest:int=0
		for i in range(1,task_queue.size()):
			if int(TASK_PRIORITY.get(task_queue[i],10))<int(TASK_PRIORITY.get(task_queue[lowest],10)):lowest=i
		if int(TASK_PRIORITY.get(event,10))>int(TASK_PRIORITY.get(task_queue[lowest],10)):task_queue[lowest]=event
	if not task_player.playing:_next_task()
func _next_task()->void:
	task_current=""
	if AudioServer.is_bus_mute(0) or not unlocked or task_paused or task_queue.is_empty():return
	task_current=task_queue.pop_front();task_player.stream=task_cache[task_current];task_player.volume_db=-7+linear_to_db(maxf(master,0.00001));task_player.play()
func set_download_active(active:bool)->void:
	download_active=active
	if download_player==null:return
	if active and unlocked and not AudioServer.is_bus_mute(0):
		download_player.volume_db=-17+linear_to_db(maxf(master,0.00001))
		if not download_player.playing:download_player.play()
		download_player.stream_paused=task_paused
	else:download_player.stop()
func set_task_paused(value:bool)->void:
	task_paused=value
	if operation_player!=null:_set_paused(operation_player,value)
	if task_player!=null:task_player.stream_paused=value
	if download_player!=null:download_player.stream_paused=value
	if not value and task_player!=null and not task_player.playing:_next_task()
func clear_tasks()->void:
	set_operation("",0)
	task_queue.clear();task_current="";download_active=false;task_paused=false
	if task_player!=null:task_player.stop();task_player.stream_paused=false
	if download_player!=null:download_player.stop();download_player.stream_paused=false

const OPERATION_TYPES:Dictionary={"card":"card","door":"card","intel":"intel","download":"download","control":"control","override":"override","pick":"pick","breach":"pick","core":"core","deliver":"deliver","exit":"override"}
var operation_player:AudioStreamPlayer
var operation_cache:Dictionary={}
var operation_kind:String=""
func _setup_operation_audio()->void:
	operation_player=AudioStreamPlayer.new();add_child(operation_player)
	for kind in ["card","intel","download","control","override","pick","core","deliver"]:
		var wav:AudioStreamWAV=load("res://assets/audio/operations/"+kind+".wav").duplicate()
		wav.loop_mode=AudioStreamWAV.LOOP_FORWARD;wav.loop_begin=0;wav.loop_end=int(wav.get_length()*wav.mix_rate)
		operation_cache[kind]=wav
func set_operation(kind:String,_progress:float)->void:
	if operation_player==null:return
	var sound_kind:String=OPERATION_TYPES.get(kind,"")
	if sound_kind=="" or not unlocked or AudioServer.is_bus_mute(0):
		_stop_active(operation_player);operation_kind="";return
	if operation_kind!=kind or not operation_player.playing:
		operation_kind=kind;operation_player.stream=operation_cache[sound_kind]
		operation_player.volume_db=-14+linear_to_db(maxf(master,0.00001));operation_player.pitch_scale=1.0;operation_player.play()
	# Keep the loop continuous: repeated stream_paused writes restart WebAudio sources.
	# Progress is represented by the distinct source pattern and UI, not per-frame pitch writes.
	_set_paused(operation_player,task_paused)

var tension_layers:Dictionary={}
var heartbeat_player:AudioStreamPlayer
var exposure_player:AudioStreamPlayer
var detection_player:AudioStreamPlayer
var detection_cooldown:float=0
var previous_tension_mode:String="calm"
var detection_count:int=0
var music_level:float=0.8
var heartbeat_level:float=0.75
var tension_weights:Dictionary={"suspicion":0.0,"chase":0.0,"recovery":0.0}
var tension_duck:float=0
var exposure_cooldown:float=0
var heartbeat_count:int=0
func _setup_tension_audio()->void:
	for name in ["suspicion","chase","recovery"]:
		var layer:=AudioStreamPlayer.new();add_child(layer)
		layer.stream=load("res://assets/audio/tension_mix/"+name+".ogg");layer.stream.loop=true;layer.volume_db=-80
		tension_layers[name]=layer
	heartbeat_player=AudioStreamPlayer.new();add_child(heartbeat_player);heartbeat_player.stream=load("res://assets/audio/tension_mix/heartbeat.wav")
	exposure_player=AudioStreamPlayer.new();add_child(exposure_player);exposure_player.stream=load("res://assets/audio/tension_mix/exposed.wav")
	detection_player=AudioStreamPlayer.new();add_child(detection_player);detection_player.stream=load("res://assets/audio/tension_mix/detected.wav")
func reset_tension_audio()->void:
	if heartbeat_player==null:return
	heartbeat_player.stop();exposure_player.stop();detection_player.stop();detection_cooldown=0;detection_count=0;previous_tension_mode="calm";heartbeat_count=0;exposure_cooldown=0;tension_duck=0
	for name in tension_weights:tension_weights[name]=0.0
	_set_paused(music,false)
	for layer in tension_layers.values():_set_paused(layer,false);_set_gain(layer,-80)
func mix_tension(delta:float,data:Dictionary,state:int)->void:
	var paused:bool=state==2
	_set_paused(music,paused)
	for layer in tension_layers.values():_set_paused(layer,paused)
	_set_paused(heartbeat_player,paused);_set_paused(exposure_player,paused);_set_paused(detection_player,paused)
	if paused:return
	var gain:float=linear_to_db(maxf(master,0.00001))
	var busy:bool=(operation_player!=null and operation_player.playing) or (task_player!=null and task_player.playing)
	tension_duck=lerpf(tension_duck,7.0 if busy else 0.0,1-exp(-delta*(12 if busy else 1.8)))
	var mgain:float=linear_to_db(maxf(music_level,0.00001))+gain-tension_duck
	_set_gain(music,-9+mgain)
	for name in tension_layers:
		var target:float=0.0
		if state==1:
			if name=="suspicion" and data.mode in ["suspect","chase"]:target=float(data.intensity)
			if name=="chase" and data.mode=="chase":target=1.0
			if name=="recovery" and data.mode=="recovery":target=float(data.intensity)
		tension_weights[name]=lerpf(float(tension_weights[name]),target,1-exp(-delta*(2.5 if target>float(tension_weights[name]) else 0.8)))
		_set_gain(tension_layers[name],(-1 if name=="chase" else -7)+mgain+linear_to_db(maxf(float(tension_weights[name]),0.00001)))
	_set_gain(exposure_player,-5+mgain)
	exposure_cooldown=maxf(0,exposure_cooldown-delta)
	if state!=1:_stop_active(heartbeat_player);_stop_active(exposure_player);_stop_active(detection_player);previous_tension_mode="calm";detection_cooldown=0;return
	detection_cooldown=maxf(0,detection_cooldown-delta)
	var detected_now:bool=data.mode in ["suspect","chase"] and previous_tension_mode in ["calm","recovery"]
	previous_tension_mode=data.mode
	if not unlocked or AudioServer.is_bus_mute(0):_stop_active(heartbeat_player);_stop_active(exposure_player);_stop_active(detection_player);return
	_set_gain(detection_player,-8+gain)
	if detected_now and detection_cooldown<=0 and master>0:
		detection_player.play();detection_count+=1;detection_cooldown=4.0
	_set_gain(heartbeat_player,-10+8*float(data.intensity)+gain+linear_to_db(maxf(heartbeat_level,0.00001))+linear_to_db(maxf(sqrt(float(data.intensity)),0.00001))-tension_duck*0.7)
	if data.beat and heartbeat_level>0 and master>0:
		heartbeat_player.play();heartbeat_count+=1
	if data.entered and exposure_cooldown<=0 and music_level>0:
		_set_gain(exposure_player,-5+mgain);exposure_player.play();exposure_cooldown=6

