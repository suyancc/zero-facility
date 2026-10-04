extends CharacterBody3D
const V:=preload("res://scripts/visual_factory.gd")
signal lost(reason:String)
signal footstep(loudness:float)
signal impacted(strength:float)
var active:bool=false
var stamina:float=100
var exhausted:bool=false
var sneaking:bool=false
var running:bool=false
var vision_height:float=1.28
var gait:float=0
var last_step:int=0
var anim_clock:float=0
var impact_cooldown:float=0
var rig:Node3D
var torso:Node3D
var head:Node3D
var upper_arms:Array[Node3D]=[]
var forearms:Array[Node3D]=[]
var thighs:Array[Node3D]=[]
var shins:Array[Node3D]=[]
var feet:Array[Node3D]=[]
var facing:float=0
var carrying:bool=false
var interacting:bool=false
var pose:String="idle"
var outcome:String=""
func _ready()->void:
	add_to_group("players")
	floor_snap_length=0.20
	floor_stop_on_slope=true
	rig=Node3D.new();rig.set_script(preload("res://scripts/human_rig.gd"));add_child(rig)
	torso=rig.get_node("TorsoPivot");head=torso.get_node("Head")
	for prefix in ["Left","Right"]:
		upper_arms.append(torso.get_node(prefix+"UpperArm"))
		forearms.append(upper_arms[-1].get_node(prefix+"Forearm"))
		thighs.append(rig.get_node(prefix+"Thigh"))
		shins.append(thighs[-1].get_node(prefix+"Shin"))
		feet.append(shins[-1].get_node(prefix+"Foot"))
	_accessories()
func _accessories()->void:
	V.label(self,"你",Vector3(0,1.97,0),Color("83e5ff"))
	var lamp:=OmniLight3D.new()
	lamp.light_color=Color("72bfe4");lamp.light_energy=0.55;lamp.omni_range=3.4;lamp.position=Vector3(0,1.5,0)
	add_child(lamp)
func set_active(value:bool)->void:
	active=value
	if not value:velocity=Vector3.ZERO
func drive(delta:float,input:Vector2,camera:Camera3D,quiet:bool,sprint:bool)->void:
	if not active:return
	sneaking=quiet
	if stamina<1:exhausted=true
	if stamina>24:exhausted=false
	running=sprint and not carrying and not quiet and not exhausted and input.length()>0.05
	if running:stamina=maxf(0,stamina-25*delta)
	else:stamina=minf(100,stamina+(11 if input.length()>0.1 else 22)*delta)
	var speed:float=1.2 if carrying and sneaking else 1.8 if carrying else 1.4 if sneaking else 4.8 if running else 2.8
	var right:Vector3=camera.global_basis.x;right.y=0;right=right.normalized()
	var forward:Vector3=-camera.global_basis.z;forward.y=0;forward=forward.normalized()
	var direction:Vector3=(right*input.x-forward*input.y).limit_length(1)
	var target:=direction*speed
	velocity.x=move_toward(velocity.x,target.x,delta*16)
	velocity.z=move_toward(velocity.z,target.z,delta*16)
	if is_on_floor():velocity.y=-0.5
	else:velocity.y-=22*delta
	var before:=Vector2(velocity.x,velocity.z).length()
	move_and_slide()
	impact_cooldown=maxf(0,impact_cooldown-delta)
	if get_slide_collision_count()>0 and impact_cooldown<=0:
		var change:float=before-Vector2(velocity.x,velocity.z).length()
		if change>1.4:impacted.emit(change);impact_cooldown=0.25
	if direction.length()>0.1:facing=atan2(-direction.x,-direction.z)
	vision_height=1.18 if sneaking else 1.28
	if position.y<-3:active=false;lost.emit("跌出了设施平台。")
func _process(delta:float)->void:
	anim_clock+=delta
	var speed:=Vector2(velocity.x,velocity.z).length() if active else 0.0
	var moving:bool=speed>0.12
	pose="run" if moving and running else "sneak" if moving and sneaking else "walk" if moving else "idle"
	if moving:gait+=delta*speed*(3.8 if sneaking else 3.4)
	var amount:float=clampf(speed/2.8,0,1)
	var stride:float=(0.90 if running else 0.56 if not sneaking else 0.36)*amount
	rig.rotation.y=lerp_angle(rig.rotation.y,facing,1-exp(-delta*13))
	rig.position.y=absf(sin(gait*2))*0.022*amount
	torso.rotation.x=lerpf(torso.rotation.x,-0.16 if running else -0.29 if sneaking else -0.02,1-exp(-delta*8))
	torso.rotation.z=sin(gait)*0.035*amount
	head.rotation.y=sin(anim_clock*0.9)*0.06 if not moving else 0.0
	var minimum_sole:float=10
	for i in range(2):
		var wave:float=sin(gait+i*PI)
		thighs[i].rotation.x=wave*stride+(0.22 if sneaking else 0.0)
		shins[i].rotation.x=(-0.44 if sneaking else -0.08)-maxf(0,-wave)*(1.1 if running else 0.7)*amount
		upper_arms[i].rotation.x=0.75 if carrying else -wave*stride*0.85
		forearms[i].rotation.x=0.85 if carrying else 1.1 if running else 0.25
		if interacting and not carrying:
			upper_arms[i].rotation.x=0.55+sin(anim_clock*5+i)*0.045;forearms[i].rotation.x=0.95
		var total:float=thighs[i].rotation.x+shins[i].rotation.x
		feet[i].rotation.x=-total
		var sole:float=0.80-0.36*cos(thighs[i].rotation.x)-0.35*cos(total)+0.055*sin(total)-0.09
		minimum_sole=minf(minimum_sole,sole)
	rig.position.y=-minimum_sole+(absf(sin(gait*2))*0.035 if running and moving else 0.0)
	if outcome=="caught":
		upper_arms[0].rotation.z=1.6;upper_arms[1].rotation.z=-1.6
	elif outcome=="escaped":
		upper_arms[0].rotation.z=2.2;upper_arms[1].rotation.z=-2.2
	rig.position.y=0
	rig.apply_pose(gait,speed,running,sneaking,carrying,interacting,outcome,anim_clock)
	var step_index:int=int(gait/PI)
	if moving and step_index!=last_step:
		last_step=step_index
		footstep.emit(0.8 if sneaking else 5.5 if running else 2.0)

