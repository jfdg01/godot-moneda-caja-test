class_name SpringBody
extends RefCounted

var omega_0: float = 8.0
var zeta: float    = 0.35
var mass: float    = 1.0
var sat_x: float   = 40.0
var sat_v: float   = 300.0

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var target:   Vector2 = Vector2.ZERO

var _k: float
var _b: float

func setup() -> void:
	_k = omega_0 * omega_0 * mass
	_b = 2.0 * zeta * omega_0 * mass

func teleport(pos: Vector2) -> void:
	position = pos
	target   = pos
	velocity = Vector2.ZERO

func push(impulse: Vector2) -> void:
	velocity += impulse / mass

func tick(delta: float, substeps: int = 4) -> void:
	var dt: float = delta / substeps
	for _i in substeps:
		var disp: float = (target - position).length()
		var disp_dir: Vector2 = (target - position) / max(disp, 0.001)

		var f_spring: Vector2 = disp_dir * _k * sat_x * tanh(disp / sat_x)

		var speed: float = velocity.length()
		var vel_dir: Vector2 = velocity / max(speed, 0.001)
		var f_damp: Vector2 = vel_dir * _b * sat_v * tanh(speed / sat_v)

		var acceleration: Vector2 = (f_spring - f_damp) / mass
		velocity += acceleration * dt
		position += velocity * dt
