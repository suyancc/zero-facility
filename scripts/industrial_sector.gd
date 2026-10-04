extends RefCounted
const V:=preload("res://scripts/visual_factory.gd")
const Gen:=preload("res://scripts/level_generator.gd")
static func build(level:Node3D,data:Dictionary)->void:
	var decor:=Node3D.new();decor.name="IndustrialDetail";level.add_child(decor)
	var dark:=V.material(Color("15222c"),0.25)
	var steel:=V.material(Color("465965"),0.55)
	var stripe:=V.material(Color("b8763d"),0.2)
	var light:=V.material(Color("80b7c2"),0.1)
	var colors:Array[Color]=[Color("20353f"),Color("253443"),Color("37332d"),Color("382a30")]
	for index in range(data.rooms.size()):
		var room:Dictionary=data.rooms[index]
		for x in range(4):
			for z in range(3):
				var mat:=V.material(colors[index].lightened(0.025 if (x+z)%2==0 else 0.0),0.28)
				V.box(decor,Vector3(2.46,0.012,2.32),room.at+Vector3((x-1.5)*2.52,0.031,(z-1)*2.39),mat)
		for x in range(7):
			var mark:=V.box(decor,Vector3(0.13,0.012,0.30),room.at+Vector3(x*0.29-0.85,0.045,-3.35),stripe);mark.rotation.y=-0.5
		var sign:=V.label(level,"%02d  %s"%[index+1,room.name],room.at+Vector3(-2.4,0.058,-2.4),Color("7e939c"))
		level.floor_labels.append(sign)
		sign.billboard=BaseMaterial3D.BILLBOARD_DISABLED;sign.no_depth_test=false;sign.rotation.x=-PI/2;sign.pixel_size=0.021;sign.outline_size=0;sign.font_size=44
	for cell in data.walls:
		var at:Vector3=Gen.world(cell)
		var vertical:bool=cell.x==9
		var along:=Vector3(0,0,1) if vertical else Vector3(1,0,0)
		var cross:=Vector3(1,0,0) if vertical else Vector3(0,0,1)
		var panel_size:=Vector3(0.018,0.94,1.04) if vertical else Vector3(1.04,0.94,0.018)
		for side in [-1,1]:
			V.box(decor,panel_size,at+cross*side*0.138+Vector3.UP*0.93,steel)
			V.box(decor,Vector3(0.026,0.032,0.87) if vertical else Vector3(0.87,0.032,0.026),at+cross*side*0.151+Vector3.UP*0.52,stripe)
			for end in [-1,1]:V.box(decor,Vector3(0.06,0.06,0.06),at+cross*side*0.16+along*end*0.46+Vector3.UP*1.29,dark)
		V.box(decor,Vector3(0.31,0.10,1.27) if vertical else Vector3(1.27,0.10,0.31),at+Vector3.UP*1.69,dark)
	# Services stay outside the playable board: no decorative collision or new light.
	for y in [0.8,1.25]:
		var pipe:=V.cylinder(decor,0.08,30,Vector3(0,y,-12.95),steel);pipe.rotation.z=PI/2
		for x in [-12,-6,0,6,12]:V.box(decor,Vector3(0.10,0.22,0.23),Vector3(x,y,-12.95),dark)
	for x in [-12,-6,0,6,12]:
		V.box(decor,Vector3(2.4,0.08,0.32),Vector3(x,2.5,-12.9),dark)
		V.box(decor,Vector3(2.15,0.025,0.22),Vector3(x,2.445,-12.9),light)
	preload("res://scripts/industrial_batch.gd").bake(decor)

