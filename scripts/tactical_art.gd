extends RefCounted
const V:=preload("res://scripts/visual_factory.gd")
const Gen:=preload("res://scripts/level_generator.gd")
const Cam:=preload("res://scripts/tactical_camera.gd")
static func build(root:Node3D,d:Dictionary)->void:
	var steel:=V.material(Color("405866"),0.3)
	var dark:=V.material(Color("182d3a"),0.2)
	var cyan:=V.material(Color("52c3cf"),0,true)
	for room in d.rooms:
		V.box(root,Vector3(10.2,0.016,7.2),room.at+Vector3(0,0.018,0),V.material(room.color))
		root.room_labels.append(V.label(root,room.name,room.at+Vector3(0,0.08,-2.9),Color("99b3be")))
	for c in d.walls:
		var at:Vector3=Gen.world(c)
		var size:=Vector3(0.25,1.75,1.31) if c.x==9 else Vector3(1.31,1.75,0.25)
		V.box(root,size,at+Vector3.UP*0.875,dark,true,4)
		V.box(root,Vector3(size.x,0.035,size.z),at+Vector3.UP*1.77,cyan)
	for spec in d.doors:
		var node:=Node3D.new();root.add_child(node);node.position=spec.at
		var body:=V.box(node,Vector3(0.27,1.72,1.25),Vector3(0,0.86,0),steel,true,4)
		var label:=V.label(node,"维修门 · 卡 / 撬锁",Vector3(0,2,0),Color("ffc087"))
		root.doors.append({"node":node,"body":body,"label":label,"at":spec.at,"cell":spec.cell,"open":false})
	var cameras:=Node3D.new();cameras.name="SecurityCameras";root.add_child(cameras)
	for spec in d.cameras:
		var camera:=Node3D.new();camera.set_script(Cam);camera.setup(spec);cameras.add_child(camera);root.security_cameras.append(camera)

	preload("res://scripts/industrial_sector.gd").build(root,d)

