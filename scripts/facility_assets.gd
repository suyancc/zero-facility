extends RefCounted
const V:=preload("res://scripts/visual_factory.gd")
const B:=preload("res://scripts/industrial_batch.gd")
static func palette()->Dictionary:
	return {"dark":V.material(Color("15222c"),0.25),"steel":V.material(Color("465965"),0.55),"ivory":V.material(Color("a0aaa9"),0.3),"orange":V.material(Color("b8763d"),0.2),"blue":V.material(Color("438aab"),0.1,true),"red":V.material(Color("bd5145"),0.1,true),"screen":V.material(Color("142f43"),0.1)}
static func screen(parent:Node3D,at:Vector3,size:Vector2,p:Dictionary,alarm:bool=false)->void:
	V.rounded(parent,Vector3(size.x+0.06,size.y+0.06,0.10),at,p.dark,0.025)
	V.box(parent,Vector3(size.x,size.y,0.013),at+Vector3(0,0,0.06),p.screen)
	var ink:Material=p.red if alarm else p.blue
	V.box(parent,Vector3(size.x*0.88,size.y*0.065,0.009),at+Vector3(0,size.y*0.38,0.07),ink)
	for row in range(4):
		V.box(parent,Vector3(size.x*(0.42+0.09*(row%3)),size.y*0.025,0.009),at+Vector3(-size.x*0.17,size.y*(0.20-row*0.12),0.07),ink)
	for i in range(5):V.box(parent,Vector3(size.x*0.047,size.y*(0.12+i*0.035),0.009),at+Vector3(size.x*(0.19+i*0.05),-size.y*0.14,0.07),ink)
static func crate(parent:Node3D,at:Vector3,size:Vector3,p:Dictionary)->void:
	V.rounded(parent,size,at,p.steel,0.035)
	for side in [-1,1]:
		V.box(parent,Vector3(size.x*0.075,size.y*1.015,size.z*1.015),at+Vector3(side*size.x*0.36,0,0),p.dark)
		V.box(parent,Vector3(size.x*0.1,size.y*0.17,0.025),at+Vector3(side*size.x*0.36,0,size.z*0.51),p.orange)
	V.box(parent,Vector3(size.x*0.23,size.y*0.045,0.03),at+Vector3(0,size.y*0.22,size.z*0.51),p.dark)
	V.box(parent,Vector3(size.x*0.19,size.y*0.11,0.015),at+Vector3(size.x*0.1,-size.y*0.16,size.z*0.51),p.ivory)
static func server(parent:Node3D,at:Vector3,width:float,height:float,p:Dictionary)->void:
	V.rounded(parent,Vector3(width,height,0.77),at+Vector3.UP*height/2,p.dark,0.035)
	for side in [-1,1]:V.box(parent,Vector3(0.055,height,0.08),at+Vector3(side*(width/2-0.055),height/2,0.405),p.steel)
	for row in range(7):
		var y:float=0.15+row*(height-0.23)/7
		V.box(parent,Vector3(width*0.80,(height-0.23)/8,0.06),at+Vector3(0,y,0.405),p.steel)
		for i in range(4):V.box(parent,Vector3(width*0.44,0.013,0.009),at+Vector3(-width*0.12,y+i*0.025-0.035,0.444),p.dark)
		V.box(parent,Vector3(0.035,0.026,0.01),at+Vector3(width*0.29,y,0.445),p.blue)
static func reactor(parent:Node3D,at:Vector3,radius:float,height:float,p:Dictionary)->void:
	V.cylinder(parent,radius*0.23,height*0.72,at+Vector3.UP*height*0.49,p.dark)
	V.cylinder(parent,radius*0.34,height*0.68,at+Vector3.UP*height*0.5,p.red)
	for y in [0.10,height*0.90]:
		V.cylinder(parent,radius,height*0.12,at+Vector3.UP*y,p.steel)
		V.cylinder(parent,radius*1.01,0.045,at+Vector3.UP*(y+0.04),p.orange)
	for i in range(6):
		var a:float=i*TAU/6
		V.box(parent,Vector3(0.075,height*0.74,0.075),at+Vector3(cos(a)*radius*0.8,height*0.5,sin(a)*radius*0.8),p.ivory)
	for y in [height*0.28,height*0.5,height*0.72]:V.cylinder(parent,radius*0.51,0.055,at+Vector3.UP*y,p.red)
static func furniture(parent:Node3D,kind:int,at:Vector3)->void:
	var p:=palette();var zone:int=(0 if at.x<0 else 1)+(0 if at.z<0 else 2)
	match kind:
		0:crate(parent,Vector3(0,0.39,0),Vector3(1.08,0.70,1.08),p)
		1:
			if zone==3:reactor(parent,Vector3.ZERO,0.52,1.83,p)
			else:
				V.cylinder(parent,0.50,1.64,Vector3(0,0.87,0),p.steel)
				for y in [0.15,0.78,1.62]:V.cylinder(parent,0.53,0.08,Vector3(0,y,0),p.dark)
				screen(parent,Vector3(0,1.07,0.49),Vector2(0.23,0.23),p)
		2:
			if zone==0:
				V.box(parent,Vector3(1.06,1.85,0.72),Vector3(0,0.975,-0.15),p.dark)
				for y in [0.64,1.22,1.73]:screen(parent,Vector3(0,y,0.24),Vector2(0.87,0.43),p)
				V.box(parent,Vector3(1.06,0.07,0.40),Vector3(0,0.87,0.33),p.steel)
			else:server(parent,Vector3(0,0.08,0),1.04,1.83,p)
		3:
			for x in [-0.49,0.49]:
				for z in [-0.49,0.49]:V.box(parent,Vector3(0.075,1.69,0.075),Vector3(x,0.89,z),p.orange)
			for y in [0.18,0.76,1.33]:
				V.box(parent,Vector3(1.1,0.075,1.10),Vector3(0,y,0),p.steel)
				crate(parent,Vector3(-0.21,y+0.23,0),Vector3(0.48,0.38,0.81),p)
				crate(parent,Vector3(0.29,y+0.18,0.05),Vector3(0.33,0.27,0.70),p)
		4:
			V.box(parent,Vector3(1.08,0.67,0.95),Vector3(0,0.36,0),p.dark)
			V.box(parent,Vector3(1.10,0.075,1.10),Vector3(0,0.73,0),p.steel)
			screen(parent,Vector3(-0.14,1.01,-0.05),Vector2(0.53,0.35),p,zone==3)
			for x in [-0.34,-0.20,-0.06,0.08]:V.box(parent,Vector3(0.09,0.025,0.12),Vector3(x,0.785,0.31),p.ivory)
	B.bake(parent)
static func signatures(root:Node3D)->void:
	var p:=palette()
	for zone in range(4):
		var n:=Node3D.new();n.name="DistrictSignature%d"%zone;root.add_child(n)
		# Outside the collision board; never cover a playable cell or exit approach.
		n.position=Vector3(-15.0 if zone%2==0 else 15.0,-0.70,-5.2 if zone<2 else 5.2)
		n.rotation.y=PI/2 if zone%2==0 else -PI/2
		V.box(n,Vector3(5.4,0.22,2.1),Vector3(0,0,0),p.dark)
		match zone:
			0:
				V.box(n,Vector3(5.1,2.65,0.20),Vector3(0,1.43,-0.69),p.steel)
				for x in [-1.65,-0.55,0.55,1.65]:
					for y in [1.05,1.83,2.48]:screen(n,Vector3(x,y,-0.51),Vector2(0.97,0.52),p)
				V.box(n,Vector3(4.9,0.15,0.83),Vector3(0,0.83,0.37),p.steel)
			1:
				for x in [-1.9,-0.95,0,0.95,1.9]:server(n,Vector3(x,0.12,0),0.86,2.85,p)
				V.box(n,Vector3(5.1,0.15,0.95),Vector3(0,3.08,0),p.steel)
			2:
				for x in [-2.1,0,2.1]:
					for z in [-0.65,0.65]:V.box(n,Vector3(0.10,3.1,0.1),Vector3(x,1.6,z),p.orange)
				for y in [0.18,1.1,2.03]:
					V.box(n,Vector3(4.4,0.10,1.4),Vector3(0,y,0),p.steel)
					for x in [-1.5,-0.5,0.5,1.5]:crate(n,Vector3(x,y+0.40,0),Vector3(0.85,0.70,1.16),p)
			3:
				reactor(n,Vector3(0,0.12,0),0.94,3.2,p)
				for x in [-1.72,1.72]:
					server(n,Vector3(x,0.12,0),0.80,1.7,p)
					var pipe:=V.cylinder(n,0.11,1.05,Vector3(x*0.63,0.52,0),p.steel);pipe.rotation.z=PI/2
		B.bake(n)

