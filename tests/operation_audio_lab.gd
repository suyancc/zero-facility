extends Node
const Feedback=preload("res://scripts/audio_feedback.gd")
var audio:Node
var elapsed:float=0
var kind:String="door"
var active:bool=false
var paused:bool=false
var kinds:Array=["door","card","intel","download","control","override","pick","breach","core","deliver","exit"]
func _ready()->void:
	audio=Feedback.new();add_child(audio)
func _input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_SPACE:
			audio.unlock();audio.ambient.stop();audio.music.stop()
			for layer in audio.tension_layers.values():layer.stop()
		if event.keycode==KEY_N:kind=kinds[(kinds.find(kind)+1)%kinds.size()]
		if event.keycode==KEY_P:paused=not paused;audio.set_task_paused(paused)
func _process(delta:float)->void:
	active=Input.is_physical_key_pressed(KEY_E)
	elapsed=elapsed+delta if active else 0
	audio.set_operation(kind if active else "",fmod(elapsed,4.0)/4.0)
	audio.mix_state(delta,2 if paused else 1,0)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__operationLab="+JSON.stringify({"kind":kind,"elapsed":elapsed,"playing":audio.operation_player.playing,"paused":paused}))
