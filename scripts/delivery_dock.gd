extends Area3D
signal delivered(parcel: RigidBody3D)
@export var stable_seconds: float = 0.55
@export var max_speed: float = 0.65
@export var max_spin: float = 0.6
@export var half_extent: Vector2 = Vector2(1.1, 1.1)
var stable_time: float = 0.0
var completed: bool = false
var candidate: RigidBody3D

func _ready() -> void:
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)

func _on_entered(body: Node3D) -> void:
	if body is RigidBody3D and body.is_in_group("parcels"):
		candidate = body

func _on_exited(body: Node3D) -> void:
	if body == candidate:
		candidate = null
		stable_time = 0.0

func fits(parcel: RigidBody3D) -> bool:
	if not is_instance_valid(parcel) or parcel.lost_emitted:
		return false
	# Test all bottom box corners in dock space; center-only tests accept overhangs.
	for x in [-parcel.half_size, parcel.half_size]:
		for z in [-parcel.half_size, parcel.half_size]:
			var corner: Vector3 = to_local(parcel.to_global(Vector3(x, -parcel.half_size, z)))
			if absf(corner.x) > half_extent.x or absf(corner.z) > half_extent.y:
				return false
			if absf(corner.y) > 0.35:
				return false
	var speed := Vector2(parcel.linear_velocity.x, parcel.linear_velocity.z).length()
	return speed <= max_speed and parcel.angular_velocity.length() <= max_spin

func tick(delta: float, enabled: bool) -> void:
	if completed:
		return
	if enabled and is_instance_valid(candidate) and fits(candidate):
		stable_time += delta
		if stable_time >= stable_seconds:
			completed = true
			delivered.emit(candidate)
	else:
		stable_time = 0.0
