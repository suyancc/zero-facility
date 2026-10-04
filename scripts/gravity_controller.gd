extends Node
## All forces are in world space; the board and its collisions remain static.
@export var strength: float = 12.0
@export_range(1.0, 35.0) var max_tilt_degrees: float = 22.0
@export var response_time: float = 0.16
var acceleration: Vector3 = Vector3.DOWN * 12.0
var input_vector: Vector2 = Vector2.ZERO

static func target_acceleration(input: Vector2, right: Vector3, forward: Vector3, g: float, tilt: float) -> Vector3:
	var bounded := input.limit_length(1.0)
	var direction := right * bounded.x + forward * -bounded.y
	var angle := deg_to_rad(tilt) * bounded.length()
	return g * (direction.normalized() * sin(angle) + Vector3.DOWN * cos(angle))

func step(delta: float, input: Vector2, camera: Camera3D) -> Vector3:
	input_vector = input.limit_length(1.0)
	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var target := target_acceleration(input_vector, right, forward, strength, max_tilt_degrees)
	acceleration = acceleration.lerp(target, 1.0 - exp(-delta / maxf(response_time, 0.01)))
	return acceleration

func reset() -> void:
	acceleration = Vector3.DOWN * strength
	input_vector = Vector2.ZERO
