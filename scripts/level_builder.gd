extends RefCounted
const V:=preload("res://scripts/visual_factory.gd")
const Gen:=preload("res://scripts/level_generator.gd")
const Guard:=preload("res://scripts/guard.gd")
const Player:=preload("res://scripts/escape_player.gd")
const Controller:=preload("res://scripts/level_controller.gd")
static func build(data:Dictionary)->Node3D:
	var root:=Node3D.new();root.name="Sector_%03d"%data.stage;root.set_script(load("res://scripts/tactical_controller.gd") if data.get("tactical",false) else Controller);root.data=data
	workshop(root)
	var floor_mat:=V.material(Color("253945"),0.2)
	var metal:=V.material(Color("172832"),0.3)
	var seam:=V.material(Color("3a505b"))
	var cyan:=V.material(Color("42aab8"),0,true)
	V.box(root,Vector3(25,0.58,19.8),Vector3(0,-0.32,0),floor_mat,true,1)
	V.box(root,Vector3(25.3,0.3,20.1),Vector3(0,-0.75,0),metal)
	for x in range(-9,10):V.box(root,Vector3(0.018,0.014,19.6),Vector3(x*1.3,0.005,0),seam)
	for z in range(-7,8):V.box(root,Vector3(24.8,0.014,0.018),Vector3(0,0.005,z*1.3),seam)
	for x in [-12.5,12.5]:
		V.box(root,Vector3(0.18,0.42,19.9),Vector3(x,0.21,0),metal,true)
		V.box(root,Vector3(0.035,0.02,19.8),Vector3(x,0.43,0),cyan)
	for z in [-9.9,9.9]:
		V.box(root,Vector3(25,0.42,0.18),Vector3(0,0.21,z),metal,true)
		V.box(root,Vector3(24.9,0.02,0.035),Vector3(0,0.43,z),cyan)
	for x in [-8,8]:
		for z in [-6,6]:
			var light:=OmniLight3D.new();root.add_child(light);light.position=Vector3(x,3.8,z)
			light.omni_range=9;light.light_energy=1.4;light.light_color=Color("80b8cd") if x<0 else Color("d0ae85")
	for spec in data.cover:_cover(root,Gen.world(spec.cell),spec.kind)
	var player:CharacterBody3D=load("res://scenes/characters/escape_player.tscn").instantiate()
	root.add_child(player);player.position=data.start
	var guards:=Node3D.new();guards.name="Guards";root.add_child(guards)
	for spec in data.guards:
		var guard:=Node3D.new();guard.set_script(Guard);guard.configure(spec);guards.add_child(guard)
	for item in data.items:
		var node:=_item(root,item.at,item.kind,item.name)
		root.item_nodes.append(node)
	for i in range(data.intel.size()):root.intel_nodes.append(_item(root,data.intel[i],"intel","可选档案"))
	_exit(root,data.goal,data.exit_direction)
	if data.get("tactical",false):preload("res://scripts/tactical_art.gd").build(root,data)
	return root
static func _cover(root:Node3D,at:Vector3,kind:int)->void:
	var heights:Array[float]=[0.76,1.85,1.95,1.72,1.25]
	var h:float=heights[kind]
	var dark:=V.material(Color("1b2b36"),0.3)
	var steel:=V.material(Color("506772"),0.4)
	var amber:=V.material(Color("94704c"))
	var cyan:=V.material(Color("3daaba"),0,true)
	var body:=V.box(root,Vector3(1.12,h,1.12),at+Vector3.UP*h*0.5,dark,true,4)
	body.get_child(0).hide()
	var art:=Node3D.new();body.add_child(art);art.position.y=-h*0.5
	V.box(art,Vector3(1.12,0.18,1.12),Vector3(0,0.09,0),dark)
	match kind:
		0:
			V.rounded(art,Vector3(1.1,0.69,1.1),Vector3(0,0.4,0),amber,0.08)
			for x in [-0.35,0.35]:V.box(art,Vector3(0.07,0.71,1.12),Vector3(x,0.4,0),steel)
		1:
			V.cylinder(art,0.53,1.60,Vector3(0,0.94,0),steel)
			for y in [0.28,1.1,1.66]:V.cylinder(art,0.55,0.085,Vector3(0,y,0),dark)
			V.cylinder(art,0.18,0.14,Vector3(0,1.8,0),amber)
		2:
			V.rounded(art,Vector3(1.09,1.85,1.09),Vector3(0,1.0,0),dark,0.07)
			V.box(art,Vector3(0.85,1.62,0.04),Vector3(0,1.0,0.558),steel)
			for y in [0.5,0.78,1.06,1.34,1.62]:
				V.box(art,Vector3(0.68,0.13,0.025),Vector3(0,y,0.59),dark)
				V.box(art,Vector3(0.045,0.045,0.02),Vector3(0.24,y,0.61),cyan)
		3:
			for x in [-0.48,0.48]:
				for z in [-0.48,0.48]:V.box(art,Vector3(0.12,1.7,0.12),Vector3(x,0.9,z),steel)
			for y in [0.2,0.85,1.52]:
				V.box(art,Vector3(1.1,0.09,1.1),Vector3(0,y,0),steel)
				V.rounded(art,Vector3(0.85,0.45,0.9),Vector3(0,y+0.25,0),amber,0.05)
		4:
			V.box(art,Vector3(1.1,0.65,1.1),Vector3(0,0.40,0),dark)
			for z in [-0.28,0.28]:
				var pipe:=V.cylinder(art,0.23,1.05,Vector3(0,0.98,z),steel);pipe.rotation.z=PI/2
			V.box(art,Vector3(0.36,0.12,0.24),Vector3(0,0.81,0.40),cyan)
static func _item(root:Node3D,at:Vector3,kind:String,title:String)->Node3D:
	var node:=Node3D.new();root.add_child(node);node.position=at
	var color:=Color("b68bff") if kind=="intel" else Color("80dfde") if kind=="power" else Color("f0c484")
	var Models:=preload("res://scripts/item_models.gd")
	color=Color(Models.COLORS.get(kind,"7cdbcb"))
	var art:=Models.spawn(kind);node.add_child(art)
	Models.ring(node,0.39,0.007,Vector3.UP*0.03,V.transparent_material(Color(color,0.38)))
	V.label(node,title,Vector3(0,1.35 if kind in ["terminal","download","control","override","core"] else 0.94,0),color)
	var light:=OmniLight3D.new();node.add_child(light);light.position.y=0.8;light.omni_range=2.4;light.light_energy=0.7;light.light_color=color
	return node
static func _exit(root:Node3D,at:Vector3,direction:Vector3)->void:
	var door:=Node3D.new();root.add_child(door);door.position=at;door.rotation.y=atan2(-direction.x,-direction.z)
	root.exit_node=door
	var steel:=V.material(Color("53717d"),0.35)
	var dark:=V.material(Color("192b37"),0.2)
	var red:=V.material(Color("ec7368"),0,true)
	for x in [-0.86,0.86]:V.box(door,Vector3(0.20,2.45,0.42),Vector3(x,1.225,0),steel)
	V.box(door,Vector3(1.92,0.18,0.42),Vector3(0,2.42,0),steel)
	V.box(door,Vector3(1.5,0.05,0.6),Vector3(0,0.02,0),dark)
	var gate:=V.box(door,Vector3(1.50,2.25,0.16),Vector3(0,1.15,0),dark,true,4)
	gate.get_child(0).hide();root.exit_collision=gate.get_child(1)
	for side in [-1,1]:
		var leaf:=V.box(door,Vector3(0.72,2.17,0.15),Vector3(side*0.365,1.13,0),dark)
		V.box(leaf,Vector3(0.045,1.85,0.025),Vector3(-side*0.30,0,0.09),red)
		root.exit_leaves.append(leaf)
	root.exit_label=V.label(door,"封锁出口",Vector3(0,2.80,0),Color("efaa92"))
static func workshop(root:Node3D) -> void:
	var life:=Node3D.new()
	life.set_script(preload("res://scripts/factory_life.gd"))
	life.name="Workshop"
	root.add_child(life)
	var floor:=V.material(Color("101c29"))
	var wall:=V.material(Color("233747"))
	var cream:=V.material(Color("6b8794"))
	var blue:=V.material(Color("172937"),0.2)
	var amber:=V.material(Color("806243"))
	V.box(life,Vector3(80,0.3,80),Vector3(0,-1.35,0),floor)
	# A cutaway warehouse: only distant walls, never hiding the playable board.
	V.box(life,Vector3(36,4.6,0.35),Vector3(0,0.95,-13.8),wall)
	V.box(life,Vector3(0.35,3.8,27),Vector3(-16.9,0.55,0),wall)
	for x in [-15,-10,-5,0,5,10,15]:
		V.box(life,Vector3(0.28,4.0,0.45),Vector3(x,0.6,-13.5),blue)
		V.box(life,Vector3(3.9,1.1,0.09),Vector3(x+0.3,1.35,-13.55),V.material(Color("4d9eaf"),0,true))
	V.box(life,Vector3(32,0.20,0.28),Vector3(0,2.25,-13.2),cream)
	# Conveyor and travelling boxes are background-only, with no invisible colliders.
	V.box(life,Vector3(10.4,0.3,1.15),Vector3(0,-0.36,-11.7),blue)
	for x in range(-10,11):
		var roller:=V.cylinder(life,0.11,1.12,Vector3(x*0.48,-0.13,-11.7),cream)
		roller.rotation.x=PI/2
	for i in range(5):
		var package:=V.asset(life,"box-small",Vector3(i*2.0-4.8,0,-11.7),0.65)
		life.belt_boxes.append(package)
	for x in [-15.1,15.1]:
		for z in [-4.0,0.0,4.0]:
			V.box(life,Vector3(1.4,0.18,1.3),Vector3(x,-0.95,z),amber)
			V.asset(life,"box-small",Vector3(x,-0.86,z),1.2)
			V.asset(life,"box-small",Vector3(x+0.12,0.05,z),0.85)
	for z in [-10.7,10.7]:
		for x in range(-9,10,2):
			V.box(life,Vector3(0.9,0.01,0.08),Vector3(x,-1.18,z),cream)


