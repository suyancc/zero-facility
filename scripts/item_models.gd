extends RefCounted
const V:=preload("res://scripts/visual_factory.gd")
const KINDS:Array[String]=["smoke","jammer","pick","decoy","card","intel","power","core","download","control","override"]
const COLORS:Dictionary={"smoke":"7cdbcb","jammer":"78baff","pick":"ffbc72","decoy":"ffd36e","card":"f2ce79","intel":"bd96ff","power":"71e5dd","core":"78ecc3","download":"77b9ff","control":"90ddbf","override":"ef9f72"}
static var scenes:Dictionary={}
static func spawn(kind:String)->Node3D:
	if kind=="terminal":kind="download"
	var path:String="res://scenes/items/"+kind+".scn"
	if ResourceLoader.exists(path):
		if not scenes.has(kind):scenes[kind]=load(path)
		return scenes[kind].instantiate()
	return build(kind)
static func part(parent:Node3D,title:String)->Node3D:
	var n:=Node3D.new();n.name=title;parent.add_child(n);return n
static func ring(parent:Node3D,radius:float,width:float,at:Vector3,mat:Material)->MeshInstance3D:
	var n:=MeshInstance3D.new();var mesh:=TorusMesh.new();mesh.inner_radius=radius-width;mesh.outer_radius=radius+width;mesh.rings=32;mesh.ring_segments=8
	n.mesh=mesh;n.material_override=mat;parent.add_child(n);n.position=at;return n
static func build(kind:String)->Node3D:
	var root:=Node3D.new();root.name=kind.to_pascal_case()+"Model";root.set_meta("item_kind",kind)
	var dark:=V.material(Color("142734"),0.25)
	var rubber:=V.material(Color("203540"),0.05)
	var steel:=V.material(Color("8195a0"),0.55)
	var ivory:=V.material(Color("c8d4d6"),0.2)
	var accent:=V.material(Color(COLORS.get(kind,"7cdbcb")),0.18,true)
	var gold:=V.material(Color("d8ac5b"),0.45)
	match kind:
		"smoke":
			var body:=part(root,"PressureCanister")
			V.cylinder(body,0.185,0.53,Vector3(0,0.33,0),steel)
			for y in [0.09,0.56]:V.cylinder(body,0.198,0.065,Vector3(0,y,0),dark)
			V.cylinder(body,0.188,0.18,Vector3(0,0.34,0),accent)
			for z in [-0.19,0.19]:V.box(body,Vector3(0.085,0.13,0.015),Vector3(0,0.34,z),dark)
			var safety:=part(root,"LeverAndPullRing")
			V.cylinder(safety,0.115,0.09,Vector3(0,0.64,0),dark)
			var lever:=V.box(safety,Vector3(0.065,0.38,0.045),Vector3(0.16,0.53,0),gold);lever.rotation.z=0.18
			var pin:=ring(safety,0.082,0.012,Vector3(0,0.76,0),gold);pin.rotation.x=PI/2
		"jammer":
			var body:=part(root,"ShieldedHandset")
			V.rounded(body,Vector3(0.52,0.62,0.27),Vector3(0,0.38,0),dark,0.065)
			for x in [-0.25,0.25]:V.rounded(body,Vector3(0.10,0.50,0.31),Vector3(x,0.35,0),rubber,0.025)
			var screen:=part(root,"StatusScreen")
			V.box(screen,Vector3(0.35,0.21,0.025),Vector3(0,0.50,0.15),accent)
			for i in range(3):V.box(screen,Vector3(0.05,0.04+i*0.04,0.013),Vector3(-0.09+i*0.09,0.46+i*0.02,0.17),dark)
			for x in [-0.13,0.13]:
				V.cylinder(root,0.026,0.34,Vector3(x,0.85,0),steel)
				V.cylinder(root,0.043,0.07,Vector3(x,1.04,0),dark)
			for x in [-0.1,0,0.1]:V.rounded(root,Vector3(0.065,0.06,0.04),Vector3(x,0.26,0.16),ivory,0.014)
		"pick":
			var case:=part(root,"FoldingToolCase")
			V.rounded(case,Vector3(0.70,0.12,0.38),Vector3(0,0.10,0),dark,0.035)
			V.rounded(case,Vector3(0.66,0.58,0.08),Vector3(0,0.41,-0.16),rubber,0.025)
			for i in range(3):
				var tool:=part(root,"PickTool%d"%i);tool.position.x=(i-1)*0.19
				V.rounded(tool,Vector3(0.105,0.22,0.065),Vector3(0,0.28,0.07),accent,0.022)
				V.box(tool,Vector3(0.026,0.39-i*0.045,0.026),Vector3(0,0.57-i*0.025,0.07),steel)
				var tip:=V.box(tool,Vector3(0.09,0.022,0.026),Vector3(0.025,0.76-i*0.047,0.07),steel);tip.rotation.z=0.25*i
			V.box(root,Vector3(0.26,0.045,0.025),Vector3(0,0.16,0.205),gold)
		"decoy":
			var shell:=part(root,"ResonatorShell")
			V.rounded(shell,Vector3(0.52,0.48,0.32),Vector3(0,0.30,0),dark,0.10)
			var speaker:=part(root,"SpeakerGrille")
			for i in range(3):
				var grille:=ring(speaker,0.075+i*0.04,0.011,Vector3(0,0.32,0.18),steel if i<2 else accent);grille.rotation.x=PI/2
			for x in [-0.18,0.18]:V.box(root,Vector3(0.05,0.23,0.035),Vector3(x,0.31,0.19),rubber)
			V.cylinder(root,0.09,0.07,Vector3(0,0.57,0),accent)
			V.cylinder(root,0.018,0.20,Vector3(0.19,0.66,0),steel)
		"card":
			var stand:=part(root,"CardRest")
			V.box(stand,Vector3(0.32,0.06,0.25),Vector3(0,0.05,0),dark)
			V.box(stand,Vector3(0.045,0.23,0.045),Vector3(0,0.19,-0.025),steel)
			var card:=part(root,"AccessCard");card.position.y=0.39;card.rotation.z=-0.10
			V.rounded(card,Vector3(0.49,0.31,0.042),Vector3.ZERO,ivory,0.025)
			V.box(card,Vector3(0.15,0.12,0.012),Vector3(-0.1,0.015,0.029),gold)
			for y in [-0.035,0.02,0.075]:V.box(card,Vector3(0.1,0.012,0.009),Vector3(-0.1,y,0.038),dark)
			V.box(card,Vector3(0.055,0.24,0.012),Vector3(0.16,0,0.03),dark)
			V.box(card,Vector3(0.055,0.055,0.014),Vector3(0.04,-0.07,0.031),accent)
		"intel":
			var case:=part(root,"ArchiveCase")
			V.rounded(case,Vector3(0.55,0.14,0.42),Vector3(0,0.13,0),dark,0.045)
			for i in range(3):V.box(case,Vector3(0.46,0.028,0.33),Vector3(0,0.23+i*0.045,0),ivory)
			var cover:=V.rounded(case,Vector3(0.54,0.045,0.4),Vector3(0,0.36,-0.01),V.material(Color("766194"),0.2),0.015);cover.rotation.x=-0.16
			var module:=part(root,"DataCrystal")
			var crystal:=V.box(module,Vector3(0.13,0.19,0.13),Vector3(0.10,0.48,0.015),accent);crystal.rotation.y=PI/4
			for x in [-0.19,-0.08]:V.box(root,Vector3(0.035,0.20,0.075),Vector3(x,0.29,0.19),steel)
		"power","core":
			var large:bool=kind=="core";var radius:float=0.27 if large else 0.19
			var cell:=part(root,"ReactorCell" if large else "ReserveBattery")
			V.cylinder(cell,radius*0.66,0.57,Vector3(0,0.42,0),accent)
			for y in [0.10,0.76]:V.cylinder(cell,radius,0.12,Vector3(0,y,0),steel)
			for i in range(4):
				var a:float=i*TAU/4
				V.box(cell,Vector3(0.07,0.64,0.07),Vector3(cos(a)*radius*0.85,0.43,sin(a)*radius*0.85),dark)
			if large:
				var cage:=part(root,"CarryingHandle")
				for x in [-0.15,0.15]:V.box(cage,Vector3(0.045,0.18,0.045),Vector3(x,0.89,0),gold)
				V.box(cage,Vector3(0.34,0.045,0.07),Vector3(0,0.985,0),gold)
			else:V.cylinder(root,0.085,0.10,Vector3(0,0.88,0),gold)
		"download":
			var station:=part(root,"DataWorkstation")
			V.box(station,Vector3(0.56,0.12,0.44),Vector3(0,0.08,0),dark)
			V.box(station,Vector3(0.13,0.68,0.15),Vector3(0,0.40,-0.07),steel)
			V.rounded(station,Vector3(0.66,0.46,0.15),Vector3(0,0.91,-0.045),dark,0.045)
			var screen:=part(root,"StatusScreen")
			V.box(screen,Vector3(0.55,0.33,0.023),Vector3(0,0.93,0.045),accent)
			for i in range(4):V.box(screen,Vector3(0.35-i*0.055,0.035,0.009),Vector3(-i*0.027,0.82+i*0.07,0.062),dark)
			V.box(station,Vector3(0.55,0.065,0.29),Vector3(0,0.65,0.14),steel)
			for x in [-0.18,-0.09,0,0.09,0.18]:V.box(station,Vector3(0.06,0.025,0.16),Vector3(x,0.695,0.15),dark)
		"control":
			var cabinet:=part(root,"CircuitBreakerCabinet")
			V.rounded(cabinet,Vector3(0.56,0.94,0.30),Vector3(0,0.52,0),dark,0.045)
			V.box(cabinet,Vector3(0.45,0.78,0.035),Vector3(0,0.55,0.17),steel)
			for x in [-0.14,0,0.14]:V.box(cabinet,Vector3(0.07,0.09,0.025),Vector3(x,0.83,0.20),accent)
			var breaker:=part(root,"IsolationLever")
			for x in [-0.15,0.15]:V.box(breaker,Vector3(0.04,0.3,0.06),Vector3(x,0.50,0.23),dark)
			V.box(breaker,Vector3(0.36,0.065,0.07),Vector3(0,0.56,0.27),gold)
			for y in [0.21,0.27]:V.box(root,Vector3(0.32,0.022,0.014),Vector3(0,y,0.20),dark)
		"override":
			var console:=part(root,"ManualReleasePedestal")
			V.box(console,Vector3(0.52,0.12,0.44),Vector3(0,0.08,0),dark)
			V.rounded(console,Vector3(0.30,0.83,0.28),Vector3(0,0.52,-0.08),steel,0.04)
			var valve:=part(root,"MechanicalReleaseWheel")
			var wheel:=ring(valve,0.25,0.035,Vector3(0,0.86,0.16),accent);wheel.rotation.x=PI/2
			for i in range(3):
				var spoke:=V.box(valve,Vector3(0.44,0.035,0.035),Vector3(0,0.86,0.16),gold);spoke.rotation.z=i*PI/3
			var handle:=V.cylinder(valve,0.04,0.18,Vector3(0.19,0.98,0.24),dark);handle.rotation.x=PI/2
	return root
