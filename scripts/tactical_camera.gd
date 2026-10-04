extends "res://scripts/guard.gd"
var clock:float=0
var base_heading:float=PI
var report_cooldown:float=0
func setup(spec:Dictionary)->void:
	position=spec.at;base_heading=spec.heading;vision_range=spec.range;fov_degrees=62
	heading=base_heading;forward=Vector3.FORWARD.rotated(Vector3.UP,heading)
func _ready()->void:
	super._ready()
	visual.queue_free();visual=Node3D.new();add_child(visual)
	var steel:=Visual.material(Color("a2acab"),0.4)
	var dark:=Visual.material(Color("25343e"),0.3)
	Visual.cylinder(visual,0.16,0.10,Vector3(0,0.05,0),dark)
	Visual.cylinder(visual,0.055,1.61,Vector3(0,0.82,0),dark)
	Visual.box(visual,Vector3(0.08,0.10,0.37),Vector3(0,1.66,0.10),steel)
	Visual.rounded(visual,Vector3(0.38,0.26,0.48),Vector3(0,1.75,-0.08),steel,0.055)
	Visual.box(visual,Vector3(0.40,0.035,0.56),Vector3(0,1.895,-0.12),dark)
	var bezel:=Visual.cylinder(visual,0.10,0.075,Vector3(0,1.75,-0.34),dark);bezel.rotation.x=PI/2
	var lens:=Visual.cylinder(visual,0.075,0.025,Vector3(0,1.75,-0.392),eye_material);lens.rotation.x=PI/2
	for side in [-1,1]:
		Visual.box(visual,Vector3(0.016,0.10,0.19),Vector3(side*0.198,1.75,-0.07),dark)
	preload("res://scripts/industrial_batch.gd").bake(visual)
	intent.position.y=2.14;intent.text="监控"
func update_ai(delta:float,parcel:Node3D,observable:bool)->void:
	report_cooldown=maxf(0,report_cooldown-delta)
	if jammed>0:
		jammed=maxf(0,jammed-delta);confidence=0;show_jammed_visual();return
	cone.show();rim.show();clock+=delta
	heading=base_heading+sin(clock*0.6)*0.7
	forward=Vector3.FORWARD.rotated(Vector3.UP,heading)
	var visible:bool=observable and sees(parcel)
	confidence=clampf(confidence+delta*(1.0/0.9 if visible else -0.8),0,1)
	if confidence>=1 and report_cooldown<=0:
		report_cooldown=8;contact_reported.emit(self,parcel.global_position)
	step(delta,true)
	intent.text="监控确认" if confidence>0.05 else "监控"
func state_name()->String:return "监控"

