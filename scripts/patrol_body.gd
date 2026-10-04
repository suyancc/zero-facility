extends Node3D
const V:=preload("res://scripts/visual_factory.gd")
const G:=preload("res://scripts/surface_geometry.gd")
const Batch:=preload("res://scripts/industrial_batch.gd")
var legs:Array[Node3D]=[]
var knees:Array[Node3D]=[]
var soles:Array[Node3D]=[]
var arms:Array[Node3D]=[]
var phase:float=0
var blend:float=0
func pivot(at:Vector3,title:String,parent:Node3D=null)->Node3D:
	if parent==null:parent=self
	var n:=Node3D.new();n.name=title;parent.add_child(n);n.position=at;return n
func construct(eye:Material)->void:
	name="ArticulatedPatrol"
	var shell:=V.material(Color("bcc5c2"),0.32)
	var dark:=V.material(Color("17232a"),0.4)
	var steel:=V.material(Color("62777c"),0.7)
	var orange:=V.material(Color("c58140"),0.2)
	G.loft(self,[Vector3(0.89,0.14,0.10),Vector3(1.03,0.17,0.13),Vector3(1.24,0.24,0.14),Vector3(1.32,0.19,0.12),Vector3(1.35,0.08,0.075)],Vector3.ZERO,shell)
	V.cylinder(self,0.095,0.13,Vector3(0,1.37,0),dark)
	G.ellipsoid(self,Vector3(0,1.54,0),Vector3(0.145,0.17,0.14),shell)
	var optic:=V.cylinder(self,0.078,0.08,Vector3(0,1.55,-0.13),dark);optic.rotation.x=PI/2
	var lens:=V.cylinder(self,0.059,0.015,Vector3(0,1.55,-0.178),eye);lens.rotation.x=PI/2
	for side in [-1,1]:
		var ear:=V.cylinder(self,0.078,0.06,Vector3(side*0.14,1.54,0),steel);ear.rotation.z=PI/2
		V.box(self,Vector3(0.056,0.19,0.03),Vector3(side*0.17,1.18,-0.133),orange)
	V.rounded(self,Vector3(0.22,0.27,0.16),Vector3(0,1.16,0.18),dark,0.025)
	for y in [1.08,1.14,1.20]:V.box(self,Vector3(0.16,0.027,0.025),Vector3(0,y,0.267),steel)
	V.box(self,Vector3(0.085,0.033,0.02),Vector3(0,1.28,-0.147),eye)
	V.cylinder(self,0.12,0.15,Vector3(0,0.86,0),dark)
	V.rounded(self,Vector3(0.32,0.13,0.22),Vector3(0,0.78,0),shell,0.025)
	Batch.bake(self)
	for side in [-1,1]:
		var hip:=pivot(Vector3(side*0.115,0.75,0),"Leg%d"%side);legs.append(hip)
		G.ellipsoid(hip,Vector3.ZERO,Vector3(0.095,0.095,0.095),dark)
		V.cylinder(hip,0.046,0.28,Vector3(0,-0.16,0),steel)
		G.loft(hip,[Vector3(-0.29,0.065,0.07),Vector3(-0.20,0.081,0.086),Vector3(-0.05,0.083,0.087)],Vector3.ZERO,shell)
		V.box(hip,Vector3(0.028,0.17,0.026),Vector3(side*0.068,-0.16,-0.081),orange)
		Batch.bake(hip)
		var knee:=pivot(Vector3(0,-0.30,0),"Knee",hip);knees.append(knee)
		var joint:=V.cylinder(knee,0.08,0.19,Vector3.ZERO,dark);joint.rotation.z=PI/2
		V.cylinder(knee,0.04,0.29,Vector3(0,-0.17,0),steel)
		G.loft(knee,[Vector3(-0.30,0.061,0.069),Vector3(-0.17,0.067,0.069),Vector3(-0.055,0.08,0.087)],Vector3.ZERO,shell)
		V.cylinder(knee,0.019,0.25,Vector3(side*0.057,-0.15,0.06),steel)
		Batch.bake(knee)
		var sole:=pivot(Vector3(0,-0.32,0),"Foot",knee);soles.append(sole)
		V.rounded(sole,Vector3(0.19,0.12,0.31),Vector3(0,-0.065,-0.055),dark,0.025)
		V.rounded(sole,Vector3(0.17,0.05,0.15),Vector3(0,-0.015,-0.12),shell,0.015)
		Batch.bake(sole)
		var arm:=pivot(Vector3(side*0.25,1.23,0),"Arm%d"%side);arms.append(arm)
		G.ellipsoid(arm,Vector3.ZERO,Vector3(0.092,0.095,0.10),dark)
		V.rounded(arm,Vector3(0.12,0.14,0.19),Vector3(side*0.045,0.0,0),shell,0.03)
		V.cylinder(arm,0.04,0.23,Vector3(0,-0.15,0),steel)
		V.rounded(arm,Vector3(0.115,0.20,0.12),Vector3(0,-0.14,-0.022),shell,0.022)
		G.ellipsoid(arm,Vector3(0,-0.29,0),Vector3(0.065,0.065,0.067),dark)
		V.rounded(arm,Vector3(0.12,0.22,0.13),Vector3(0,-0.40,-0.045),shell,0.025)
		V.box(arm,Vector3(0.10,0.10,0.07),Vector3(0,-0.55,-0.05),dark)
		for i in range(3):V.box(arm,Vector3(0.023,0.07,0.03),Vector3((i-1)*0.034,-0.62,-0.05),steel)
		Batch.bake(arm)
func animate(delta:float,distance:float)->void:
	blend=lerpf(blend,clampf(distance/maxf(delta,0.001)/1.6,0,1),minf(delta*12,1))
	phase+=distance*5.0
	var low:float=10
	for i in range(2):
		var wave:float=sin(phase+i*PI)
		legs[i].rotation.x=wave*0.40*blend
		knees[i].rotation.x=-maxf(0,-wave)*0.55*blend
		var total:float=legs[i].rotation.x+knees[i].rotation.x
		soles[i].rotation.x=-total;arms[i].rotation.x=-wave*0.28*blend+0.08
		low=minf(low,0.75-0.30*cos(legs[i].rotation.x)-0.32*cos(total)-0.125)
	position.y=-low
