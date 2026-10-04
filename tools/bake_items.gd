extends SceneTree
const Models:=preload("res://scripts/item_models.gd")
func assign_owner(node:Node,owner_node:Node)->void:
	for child in node.get_children():child.owner=owner_node;assign_owner(child,owner_node)
func _initialize()->void:
	DirAccess.make_dir_recursive_absolute("res://scenes/items")
	var failures:int=0
	for kind in Models.KINDS:
		var model:=Models.build(kind);assign_owner(model,model)
		var packed:=PackedScene.new();var result:=packed.pack(model)
		if result==OK:result=ResourceSaver.save(packed,"res://scenes/items/%s.scn"%kind,ResourceSaver.FLAG_COMPRESS)
		print("ITEM_MODEL ",kind," result=",result," parts=",model.get_child_count())
		if result!=OK:failures+=1
		model.free()
	preload("res://scripts/visual_factory.gd").cache.clear();preload("res://scripts/visual_factory.gd").shapes.clear()
	quit(1 if failures else 0)
