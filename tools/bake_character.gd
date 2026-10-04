extends SceneTree
const HumanRig:=preload("res://scripts/human_rig.gd")
func _initialize()->void:
	# Store a scripted scene; the actual weighted GLB is instantiated in _ready.
	var model:=Node3D.new();model.name="HumanRig";model.set_script(HumanRig)
	var scene:=PackedScene.new();var result:=scene.pack(model)
	if result==OK:result=ResourceSaver.save(scene,"res://scenes/characters/maintenance_worker.scn",ResourceSaver.FLAG_COMPRESS)
	print("CHARACTER_MODEL_SAVE ",result," skinned MakeHuman")
	model.free();quit(0 if result==OK else 1)

