extends "res://tests/v610_assets_tests.gd"
func shoe_sole(rig:Node)->float:
	var shoe:MeshInstance3D
	for mesh in rig.visual.find_children("*","MeshInstance3D",true,false):
		if "shoes01" in str(mesh.name):shoe=mesh;break
	var arrays:Array=shoe.mesh.surface_get_arrays(0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
	var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	var width:int=bones.size()/vertices.size();var lowest:float=10
	var matrices:Array[Transform3D]=[]
	for bind in range(shoe.skin.get_bind_count()):
		var bone:int=shoe.skin.get_bind_bone(bind)
		if shoe.skin.get_bind_name(bind)!=&"":bone=rig.skeleton.find_bone(shoe.skin.get_bind_name(bind))
		matrices.append(rig.skeleton.get_bone_global_pose(bone)*shoe.skin.get_bind_pose(bind))
	for i in range(vertices.size()):
		var at:=Vector3.ZERO
		for j in range(width):at+=(matrices[bones[i*width+j]]*vertices[i])*weights[i*width+j]
		lowest=minf(lowest,at.y)
	return lowest
func extra_checks(game:Node3D)->void:
	await super.extra_checks(game)
	game.stage=1;game.load_level()
	var player=game.level.player;var rig=player.rig
	check(rig.skeleton.get_bone_count()==53,"approved human uses 53 real skeleton bones")
	check(rig.mesh_count==6,"human is six skinned meshes, not dozens of rigid limb parts")
	check(rig.visual.find_children("*","CollisionObject3D",true,false).is_empty(),"human visual adds no gameplay collision objects")
	for mesh in rig.visual.find_children("*","MeshInstance3D",true,false):
		check(mesh.skin!=null and mesh.skin.get_bind_count()>0,"visible mesh is genuinely skinned: "+str(mesh.name))
	check(rig.visual.find_children("Human","MeshInstance3D",true,false)[0].mesh.get_blend_shape_count()==0,"approved body shape is baked; no lost import morphs or skin protrusions")
	var maximum_error:float=0
	for style in ["idle","walk","run","sneak"]:
		for step in range(12):
			rig.apply_pose(float(step)*TAU/12.0,0 if style=="idle" else 4.8 if style=="run" else 1.4 if style=="sneak" else 2.8,style=="run",style=="sneak",false,false,"",0)
			var sole:float=shoe_sole(rig);maximum_error=maxf(maximum_error,absf(sole))
			check(absf(sole)<0.045,"CPU-skinned shoe remains on floor: %s phase %d y %.4f"%[style,step,sole])
	print("HUMAN_MAX_SOLE_ERROR ",maximum_error)
	rig.apply_pose(0,0,false,false,false,false,"",0)
	var idle_hand:Vector3=rig.bone_at("hand_l");var idle_head:Vector3=rig.bone_at("head")
	rig.apply_pose(0,0,false,false,false,true,"",0)
	check(rig.bone_at("hand_l").distance_to(idle_hand)>0.2,"held interaction deforms actual hand bones forward")
	rig.apply_pose(0,0,false,false,true,false,"",0)
	check(rig.bone_at("hand_l").z>0.27,"carrying raises actual human hands toward core")
	rig.apply_pose(0,0,false,true,false,false,"",0)
	check(rig.bone_at("head").y<idle_head.y-0.12,"sneaking lowers the actual head, not only an invisible control")
	rig.apply_pose(0,0,false,false,false,false,"caught",0)
	check(rig.bone_at("hand_l").y>1.3,"caught pose raises human arms")
	rig.apply_pose(0,0,false,false,false,false,"escaped",0)
	check(rig.bone_at("hand_l").y>1.5,"escape pose has distinct raised hands")
	var a=game.audio;a.set_operation("door",0.1);var writes:int=a.audio_pause_writes
	for i in range(120):a.set_operation("door",float(i)/120)
	check(a.audio_pause_writes==writes,"held E never repeatedly resumes operation WebAudio")
	a.set_operation("",0)

