extends "res://tests/v63_items_tests.gd"
func extra_checks(game:Node3D)->void:
	await super.extra_checks(game)
	var Tile:=preload("res://scripts/gear_tile.gd")
	for kind in ["smoke","jammer","pick","decoy"]:
		var texture:Texture2D=Tile.icon_for(kind)
		check(texture.resource_path.ends_with(kind+"-model.png") and texture.get_width()==128,"tile uses baked corresponding model PNG: "+kind)
		check(texture.get_image().detect_alpha()!=Image.ALPHA_NONE,"model thumbnail has transparent background: "+kind)
	game.hud.editing_slot=0;game.selected_gear.assign(["smoke","pick"]);game.load_level()
	game.hud.catalog_tiles[1].pressed.emit()
	check(game.hud.inventory_tiles[0].icon_for(game.hud.inventory_tiles[0].kind)==game.hud.catalog_tiles[1].icon_for("jammer"),"inventory and catalog use identical cached model texture after equip")
	check(game.hud.model_preview.visible and game.hud.model_preview.kind=="jammer","large live preview remains alongside model thumbnail tiles")
	game._primary();game.level.set_physics_process(false)
	game.level.charges.jammer=0;game.hud.update_inventory(game.level.loadout,game.level.charges,0,0,false)
	check(game.hud.inventory_tiles[0].count==0 and game.hud.inventory_tiles[0].kind=="jammer","empty stock keeps correct model and zero count")
