extends "res://tests/v69_visual_tests.gd"
func extra_checks(game:Node3D)->void:
	await super.extra_checks(game)
	var mesh_root:=Node3D.new()
	var shaped:=preload("res://scripts/surface_geometry.gd").loft(mesh_root,[Vector3(0,0.2,0.1),Vector3(0.3,0.24,0.13)],Vector3.ZERO,preload("res://scripts/visual_factory.gd").material(Color.WHITE))
	var arrays:Array=shaped.mesh.surface_get_arrays(0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	check((vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).dot(normals[0])<0,"cloth uses Godot clockwise outward-facing triangles")
	mesh_root.free()
	game.stage=1;game.load_level()
	for zone in range(4):
		var n:Node3D=game.level.get_node_or_null("DistrictSignature%d"%zone)
		check(n!=null and n.get_child_count()>0,"distinct constructed district signature %d"%zone)
		check(n.find_children("*","CollisionObject3D",true,false).is_empty(),"district background never blocks a route %d"%zone)
	check(game.level.get_node("Workshop").belt_boxes.is_empty(),"old moving parcel factory replaced with static facility service gantry")
	var guard=game.level.guards[0]
	check(guard.visual.has_method("animate") and guard.visual.legs.size()==2 and guard.visual.knees.size()==2,"patrol has two articulated legs and knees")
	guard.visual.animate(0.1,0.2)
	check(absf(guard.visual.legs[0].rotation.x-guard.visual.legs[1].rotation.x)>0.1,"actual robot travel drives alternating gait")
	var phase:float=guard.visual.phase;guard.visual.animate(0.1,0)
	check(guard.visual.phase==phase,"stationary robot never continues locomotion phase")
	check(not game.level.security_cameras[0].visual.has_method("animate"),"camera replaces patrol body and never animates humanoid limbs")
	var player=game.level.player
	check(player.head.scale.y<0.8,"worker head uses adult proportions rather than oversized block silhouette")
	player.carrying=false;player.interacting=true;player._process(0.1)
	check(player.forearms[0].rotation.x>0.9 and player.upper_arms[0].rotation.x>0.4,"held interaction has a distinct hand operation pose")
	player.interacting=false
	game.level.pursuit_count=1;game.level.update_labels(false)
	var labels:Array=game.level.item_nodes[0].find_children("*","Label3D",true,false)
	check(not labels[0].visible,"chase prioritizes danger labels over overlapping item captions")
	game.level.update_labels(true)
	check(labels[0].visible,"overview still exposes item names during chase")
	game.level.pursuit_count=0
	for kind in Models.KINDS:
		var model:=Models.spawn(kind)
		check(model.get_node_or_null("ManufacturedDetail")!=null,"finished model retains manufacturer detail assembly: "+kind)
		check(model.find_children("*","CollisionObject3D",true,false).is_empty(),"item render geometry does not alter collision: "+kind)
		model.free()

