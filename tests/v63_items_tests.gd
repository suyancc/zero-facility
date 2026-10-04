extends "res://tests/v62_feedback_tests.gd"
const Models:=preload("res://scripts/item_models.gd")
var heard:Array[String]=[]
func extra_checks(game:Node3D)->void:
	await super.extra_checks(game)
	var unique:Dictionary={}
	for kind in Models.KINDS:
		var model:=Models.spawn(kind)
		check(model.get_meta("item_kind")==kind and model.get_child_count()>=2,"baked item has structured editable model: "+kind)
		unique[model.get_child(0).name]=true;model.free()
	check(unique.size()==11,"eleven item models have distinct structures")
	game.hud.editing_slot=0;game.stage=1;game.selected_gear.assign(["smoke","pick"]);game.load_level()
	var preview=game.hud.model_preview
	check(preview.visible and preview.kind=="smoke" and preview.slot==0,"READY initially displays selected equipped model")
	game.hud.inventory_tiles[1].pressed.emit();game.hud.catalog_tiles[1].pressed.emit()
	check(preview.kind=="jammer" and preview.slot==1 and game.selected_gear[1]=="jammer","selection switches corresponding model and slot badge")
	check(game.hud.catalog_tiles[1].highlighted and game.hud.catalog_tiles[1].equipped_slot==2 and not game.hud.catalog_tiles[0].highlighted,"focused equipment highlight differs from other equipped item")
	preview.reduced=true;var angle:float=preview.model.rotation.y;preview._process(0.5)
	check(preview.model.rotation.y==angle,"reduced motion disables preview rotation")
	game._primary();game.level.set_physics_process(false)
	check(not preview.visible and preview.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"3D preview stops rendering after start")
	var audio=game.audio
	var hashes:Dictionary={}
	for event in audio.TASK_FILES:
		var wav:AudioStreamWAV=audio.task_cache[event];hashes[hash(wav.data)]=true
	check(hashes.size()==audio.TASK_FILES.size(),"all seventeen task cues have distinct PCM")
	check(audio.task_cache.card.get_length()<1 and audio.task_cache.intel.get_length()>1.5 and audio.task_cache.download_ready.get_length()>2.5 and audio.task_cache.mission.get_length()>3,"pickup, archive, download completion and mission use differentiated lengths")
	AudioServer.set_bus_mute(0,false);audio.unlock();audio.clear_tasks();audio.task_event("intel")
	check(audio.task_player not in audio.players and audio.task_current=="intel","long archive cue uses dedicated channel separate from footsteps")
	audio.task_event("card");audio.task_event("card");audio.task_event("door");audio.task_event("power");audio.task_event("download_ready")
	check(audio.task_queue.size()==3 and audio.task_queue.has("download_ready") and audio.task_queue.count("card")<=1,"bounded deduplicated queue preserves significant completion cues")
	audio.set_download_active(true);audio.set_task_paused(true)
	check(audio.task_player.stream_paused and audio.download_player.stream_paused,"pause freezes task cue and download loop")
	audio.set_task_paused(false);check(not audio.task_paused and not audio.task_player.stream_paused,"resume restores task channel")
	audio.task_event("mission");check(audio.task_current=="mission" and audio.task_queue.is_empty() and not audio.download_active,"mission completion replaces stale cues and stops download loop")
	audio.stop_effects();check(audio.task_current=="" and not audio.task_player.playing and not audio.download_player.playing,"retry cleanup stops every event channel")
	AudioServer.set_bus_mute(0,true);audio.task_event("intel");check(audio.task_current=="","mute does not queue inaudible stale events");AudioServer.set_bus_mute(0,false)
	game.stage=2;game.load_level();game._primary();var level=game.level;level.set_physics_process(false)
	level.task_event.connect(func(kind:String):heard.append(kind))
	var index:int=-1
	for i in range(level.data.items.size()):
		if level.data.items[i].kind=="download":index=i
	level.player.position=level.data.items[index].at;level._tick_interaction(5,true,false)
	check(heard==["download_start"] and audio.download_active,"download start emits semantic event and activates loop")
	level._physics_process(10);level._physics_process(0.1)
	check(heard.count("download_ready")==1 and not audio.download_active,"download readiness emits once and stops loop")
	level.player.position=level.data.items[index].at;level._tick_interaction(5,true,false)
	check(heard.has("download_collect") and level.download_taken,"retrieving downloaded data uses separate collection cue")
	game.load_level();check(audio.task_current=="" and audio.task_queue.is_empty(),"loading next level clears audio queue")

