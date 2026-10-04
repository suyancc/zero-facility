extends SceneTree
const Player:=preload("res://scripts/escape_player.gd")
func own_children(node:Node,owner_node:Node)->void:
	for child in node.get_children():
		child.owner=owner_node
		own_children(child,owner_node)
func _initialize()->void:
	var author:=CharacterBody3D.new();author.set_script(Player);author._build_model()
	var model:Node3D=author.rig;author.remove_child(model)
	own_children(model,model)
	var scene:=PackedScene.new()
	var result:=scene.pack(model)
	if result==OK:result=ResourceSaver.save(scene,"res://scenes/characters/maintenance_worker.scn",ResourceSaver.FLAG_COMPRESS)
	print("CHARACTER_MODEL_SAVE ",result," nodes=",model.get_child_count())
	model.free();author.free()
	quit(0 if result==OK else 1)
