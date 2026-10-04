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
	var steel:=Visual.material(Color("637e8b"),0.4)
	Visual.cylinder(visual,0.065,1.85,Vector3(0,0.92,0),steel)
	Visual.rounded(visual,Vector3(0.48,0.3,0.55),Vector3(0,1.75,0),steel,0.05)
	Visual.box(visual,Vector3(0.29,0.13,0.04),Vector3(0,1.75,-0.29),eye_material)
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

