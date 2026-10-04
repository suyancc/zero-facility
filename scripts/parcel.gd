extends RigidBody3D
signal lost(reason: String)
signal impacted(strength: float)
var impact_cooldown: float = 0.0
var previous_velocity: Vector3 = Vector3.ZERO
@export var horizontal_drag: float = 0.75
@export var max_horizontal_speed: float = 4.0
@export var fall_height: float = -4.0
var acceleration: Vector3 = Vector3.DOWN * 12.0
var active: bool = false
var lost_emitted: bool = false
var half_size: float = 0.38
var visual_kick: float = 0.0

func _ready() -> void:
	gravity_scale = 0.0
	contact_monitor = true
	max_contacts_reported = 6
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 2.0
	continuous_cd = true
	# M1 arcade choice: upright crate; free yaw, no rolling on X/Z.
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	add_to_group("parcels")

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not active:
		return
	impact_cooldown = maxf(0.0, impact_cooldown - state.step)
	var velocity := state.linear_velocity
	var current_flat := Vector3(velocity.x, 0, velocity.z)
	var old_flat := Vector3(previous_velocity.x, 0, previous_velocity.z)
	var impact_strength := (old_flat - current_flat).length()
	if state.get_contact_count() > 0 and impact_cooldown <= 0.0 and impact_strength > 0.45:
		impact_cooldown = 0.18
		call_deferred("_emit_impact", impact_strength)
	previous_velocity = velocity
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	state.apply_central_force(mass * (acceleration - horizontal * horizontal_drag))
	if horizontal.length() > max_horizontal_speed:
		horizontal = horizontal.limit_length(max_horizontal_speed)
		state.linear_velocity = Vector3(horizontal.x, velocity.y, horizontal.z)

func _physics_process(_delta: float) -> void:
	if active and not lost_emitted and global_position.y < fall_height:
		lost_emitted = true
		lost.emit("快递掉出了运输平台。试着缩短操作，提前反向减速。")

func set_active(value: bool) -> void:
	active = value
	freeze = not value
	if value:
		sleeping = false
func _emit_impact(strength: float) -> void:
	visual_kick = minf(strength*0.035,0.12)
	if active:
		impacted.emit(strength)

func _process(delta:float) -> void:
	if not has_node("Visual"):return
	visual_kick=move_toward(visual_kick,0,delta*0.5)
	var v:Node3D=$Visual
	var target:=Vector3(-linear_velocity.z*0.028,0,linear_velocity.x*0.028) if active else Vector3.ZERO
	v.rotation=v.rotation.lerp(target,1-exp(-delta*10))
	v.scale=Vector3(1+visual_kick,1-visual_kick,1+visual_kick)

