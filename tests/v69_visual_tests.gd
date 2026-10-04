extends "res://tests/v68_audio_tests.gd"
func extra_checks(game:Node3D)->void:
	await super.extra_checks(game)
	game.stage=1;game.load_level()
	check(game.hud.chrome.ready_screen,"ready uses dedicated industrial preparation layout")
	check(game.hud.chrome.showcase.active,"preparation displays actual worker model")
	check(not game.hud.readout_block.visible and not game.hud.endurance_block.visible,"ready hides gameplay telemetry instead of overlapping the briefing")
	check(game.hud.settings.z_index>game.hud.backpack.z_index,"settings remain above ready equipment cells")
	check(game.hud.catalog_tiles.size()==4 and game.hud.inventory_tiles.size()==2,"new preparation layout retains four model cards and two equipment slots")
	var decor:Node3D=game.level.get_node("IndustrialDetail")
	var batches:int=0
	for child in decor.get_children():
		if child is MeshInstance3D:batches+=1
	check(batches>0 and batches<=16,"new static industrial geometry is material-batched")
	check(decor.find_children("*","CollisionObject3D",true,false).is_empty(),"new sector decoration never adds hidden collision")
	var g:Node3D=game.level.guards[0];var meshes:int=0
	for child in g.visual.get_children():
		if child is MeshInstance3D:meshes+=1
	check(meshes>0 and meshes<=8,"patrol chassis retains compact material batches")
	check(game.level.player.rig.get_node_or_null("TorsoPivot/Head")!=null,"new worker keeps animation-compatible head pivot")
	game._primary()
	check(not game.hud.chrome.showcase.active and game.hud.chrome.showcase.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"worker showcase stops rendering during gameplay")
	check(game.hud.readout_block.visible and game.hud.endurance_block.visible,"starting restores gameplay HUD")

