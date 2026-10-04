extends Node3D
# Real CC0 MakeHuman skinned mesh. The small control nodes preserve the existing
# gameplay animation interface; they are NOT render geometry or collision shapes.
const MODEL=preload("res://assets/characters/maintenance_human.glb")
var skeleton:Skeleton3D
var visual:Node3D
var rest:Array[Transform3D]=[]
var posed:Array[Transform3D]=[]
var descendants:Array=[]
var bone_ids:Dictionary={}
var sole_heights:Vector2=Vector2.ZERO
var mesh_count:int=0
var animated_ids:Array[int]=[]
var finger_ids:Array[int]=[]
var curl_state:int=-1
var idle_key:String=""
var idle_head:Transform3D
var pose_cpu_mean_usec:float=0
func _is_finger(name:String)->bool:
	return name.begins_with("thumb") or name.begins_with("index") or name.begins_with("middle") or name.begins_with("ring") or name.begins_with("pinky")
func _write_bone(id:int,target:Transform3D)->void:
	var parent:int=skeleton.get_bone_parent(id)
	var parent_global:Transform3D=posed[parent] if parent>=0 else Transform3D.IDENTITY
	var local_pose:Transform3D=parent_global.affine_inverse()*target
	skeleton.set_bone_pose_position(id,local_pose.origin)
	skeleton.set_bone_pose_rotation(id,local_pose.basis.orthonormalized().get_rotation_quaternion())
func _ready()->void:
	name="HumanRig"
	visual=MODEL.instantiate();visual.name="SkinnedVisual";visual.rotation.y=PI;add_child(visual)
	for anim in visual.find_children("*","AnimationPlayer",true,false):anim.stop();anim.active=false
	skeleton=visual.find_children("*","Skeleton3D",true,false)[0]
	for i in range(skeleton.get_bone_count()):
		rest.append(skeleton.get_bone_global_rest(i));bone_ids[skeleton.get_bone_name(i)]=i
		var children:Array[int]=[i]
		for j in range(i+1,skeleton.get_bone_count()):
			if skeleton.get_bone_parent(j) in children:children.append(j)
		# Finger bones inherit the hand transform. Never recompute their global chains per frame.
		descendants.append(children.filter(func(id:int)->bool:return not _is_finger(skeleton.get_bone_name(id))))
	for name in ["pelvis","spine_01","head","upperarm_l","lowerarm_l","upperarm_r","lowerarm_r","thigh_l","calf_l","foot_l","thigh_r","calf_r","foot_r"]:animated_ids.append(bone_ids[name])
	for side in ["l","r"]:
		for finger in ["index","middle","ring","pinky"]:
			for joint in ["02","03"]:finger_ids.append(bone_ids[finger+"_"+joint+"_"+side])
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		mesh_count+=1
		# Imported alpha hair uses cutout depth, not expensive sorted translucency.
		for s in range(mesh.mesh.get_surface_count()):
			var material:StandardMaterial3D=mesh.get_active_material(s).duplicate()
			material.roughness=maxf(material.roughness,0.65)
			if "short04" in str(mesh.name) or "eyebrow" in str(mesh.name):
				material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				material.alpha_scissor_threshold=0.35;material.cull_mode=BaseMaterial3D.CULL_DISABLED
			mesh.set_surface_override_material(s,material)
	# Stable controls used by player logic and showcase. All visible limbs are skinned.
	var torso=_control(self,"TorsoPivot");_control(torso,"Head")
	for prefix in ["Left","Right"]:
		var arm=_control(torso,prefix+"UpperArm");_control(arm,prefix+"Forearm")
		var thigh=_control(self,prefix+"Thigh");var calf=_control(thigh,prefix+"Shin");_control(calf,prefix+"Foot")
	apply_pose(0,0,false,false,false,false,"",0)
func _control(parent:Node,node_name:String)->Node3D:
	var n:=Node3D.new();n.name=node_name;parent.add_child(n);return n
func _move_tree(id:int,change:Transform3D)->void:
	for child in descendants[id]:posed[child]=change*posed[child]
func _rotate_to(id:int,basis:Basis)->void:
	var rot:Basis=basis*posed[id].basis.inverse()
	var origin:Vector3=posed[id].origin
	_move_tree(id,Transform3D(rot,origin-rot*origin))
func _aim(id:int,child:int,target:Vector3)->void:
	var from:Vector3=(posed[child].origin-posed[id].origin).normalized()
	var to:Vector3=(target-posed[id].origin).normalized()
	_rotate_to(id,Basis(Quaternion(from,to))*posed[id].basis)
func _two_bone(a:int,b:int,c:int,target:Vector3,pole:Vector3)->void:
	var origin:Vector3=posed[a].origin
	var length_a:float=rest[a].origin.distance_to(rest[b].origin)
	var length_b:float=rest[b].origin.distance_to(rest[c].origin)
	var direction:Vector3=target-origin
	var distance:float=clampf(direction.length(),0.01,length_a+length_b-0.001)
	direction=direction.normalized();target=origin+direction*distance
	var along:float=(length_a*length_a-length_b*length_b+distance*distance)/(2*distance)
	var height:float=sqrt(maxf(0,length_a*length_a-along*along))
	var bend:Vector3=(pole-direction*direction.dot(pole)).normalized()
	var middle:Vector3=origin+direction*along+bend*height
	_aim(a,b,middle);_aim(b,c,target)
func apply_pose(gait:float,speed:float,running:bool,sneaking:bool,carrying:bool,interacting:bool,outcome:String,clock:float)->void:
	if skeleton==null:return
	var began:int=Time.get_ticks_usec()
	var wanted_key:String=(str(sneaking)+str(carrying)+outcome) if speed==0 and not interacting else ""
	if wanted_key!="" and wanted_key==idle_key:
		var look:Transform3D=idle_head;look.basis=Basis(Vector3.UP,sin(clock*0.75)*0.035)*look.basis
		_write_bone(bone_ids.head,look)
		pose_cpu_mean_usec=lerpf(pose_cpu_mean_usec,float(Time.get_ticks_usec()-began),0.08)
		return
	posed.assign(rest)
	var amount:float=clampf(speed/2.8,0,1)
	var moving:bool=speed>0.12
	var pelvis:int=bone_ids.pelvis
	var lower:float=-0.19 if sneaking else -0.035
	var bob:float=absf(sin(gait))*0.015*amount
	_move_tree(pelvis,Transform3D(Basis.IDENTITY,Vector3(0,lower+bob,0)))
	# Lean only the upper body; planted-foot IK remains independent of torso pitch.
	var spine:int=bone_ids.spine_01
	var lean:float=0.23 if sneaking else 0.13 if running else 0.025
	var lean_basis:=Basis(Vector3.RIGHT,lean)*Basis(Vector3.UP,sin(gait)*0.025*amount)
	_rotate_to(spine,lean_basis*posed[spine].basis)
	for side in ["l","r"]:
		var sign_x:float=1.0 if side=="l" else -1.0
		var phase:float=fposmod(gait/TAU+(0.0 if side=="l" else 0.5),1.0)
		var swing:float=0.0
		var stride:float=(0.26 if running else 0.10 if sneaking else 0.17)*amount
		var foot_z:float=0.0
		if moving:
			if phase<0.60:foot_z=lerpf(stride,-stride,phase/0.60)
			else:
				var t:float=(phase-0.60)/0.40
				foot_z=lerpf(-stride,stride,t*t*(3-2*t));swing=sin(PI*t)
		var thigh:int=bone_ids["thigh_"+side];var calf:int=bone_ids["calf_"+side];var foot:int=bone_ids["foot_"+side]
		var lift:float=swing*(0.13 if running else 0.055 if sneaking else 0.085)*amount
		var target:=Vector3(sign_x*0.105,rest[foot].origin.y+0.004+lift,rest[foot].origin.z+foot_z)
		_two_bone(thigh,calf,foot,target,Vector3(0,0,1))
		_rotate_to(foot,Basis(Vector3.RIGHT,-0.08*swing)*rest[foot].basis)
		sole_heights[0 if side=="l" else 1]=posed[foot].origin.y-rest[foot].origin.y-0.0024
		var upper:int=bone_ids["upperarm_"+side];var elbow:int=bone_ids["lowerarm_"+side];var hand:int=bone_ids["hand_"+side]
		var wave:float=sin(gait+(0 if side=="l" else PI))*amount
		var hand_at:=Vector3(sign_x*0.235,0.79+lower,0.06-wave*(0.13 if running else 0.065))
		if running:hand_at.y=1.05+lower;hand_at.z=0.14-wave*0.14
		if sneaking:hand_at.y=0.93+lower;hand_at.z=0.14-wave*0.07
		if carrying:hand_at=Vector3(sign_x*0.19,1.05+lower,0.34)
		elif interacting:hand_at=Vector3(sign_x*0.19,1.11+lower+sin(clock*5+sign_x)*0.012,0.30)
		if outcome=="caught":hand_at=Vector3(sign_x*0.40,1.46,0.04)
		elif outcome=="escaped":hand_at=Vector3(sign_x*0.30,1.68,0.03)
		_two_bone(upper,elbow,hand,hand_at,Vector3(sign_x*0.15,-1,-0.15))

	# Finger curls are parent-local and only change when entering/leaving carry.
	var desired_curl:int=1 if carrying else 0
	if curl_state!=desired_curl:
		curl_state=desired_curl
		for id in finger_ids:
			var basis:Basis=skeleton.get_bone_rest(id).basis*Basis(Vector3.RIGHT,0.34 if carrying else 0.14)
			skeleton.set_bone_pose_rotation(id,basis.get_rotation_quaternion())
	var head_id:int=bone_ids.head
	idle_head=posed[head_id];idle_key=wanted_key
	_rotate_to(head_id,Basis(Vector3.UP,(sin(clock*0.75)*0.035 if not moving else 0.0))*posed[head_id].basis)
	# Other local bones are unchanged from rest; the renderer inherits their parents.
	for id in animated_ids:_write_bone(id,posed[id])
	pose_cpu_mean_usec=lerpf(pose_cpu_mean_usec,float(Time.get_ticks_usec()-began),0.08)

func bone_at(name:String)->Vector3:
	return skeleton.get_bone_global_pose(bone_ids[name]).origin

