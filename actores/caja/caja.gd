extends AnimatableBody2D

@export_range(0.0, 1.0) var sensitivity := 0.5:
	set(v): sensitivity = v; if is_node_ready(): _bake_params()
@export_range(0.0, 1.0) var bounciness := 0.3:
	set(v): bounciness = v; if is_node_ready(): _bake_params()
@export var max_travel := 300.0:
	set(v): max_travel = v; if is_node_ready(): _bake_params()
@export var statsON := false

var _rest_position: Vector2
var _spring_velocity := Vector2.ZERO
var _stats := Stats.new()

var _stiffness: float
var _damping: float
var _push_scale: float
var _max_impulse: float

func _ready():
	sync_to_physics = true
	_rest_position = position
	_bake_params()

func _bake_params():
	# Stiffness scales inversely with max_travel: more travel = softer spring = farther reach
	var travel_factor = 300.0 / max(max_travel, 10.0)
	_stiffness = lerp(30.0, 300.0, bounciness) * travel_factor
	_damping = 2.0 * sqrt(_stiffness) * lerp(3.0, 0.5, bounciness)
	_push_scale = lerp(50.0, 2000.0, sensitivity)
	# At full impulse, displacement reaches exactly max_travel
	_max_impulse = sqrt(_stiffness) * max_travel * lerp(0.3, 1.0, sensitivity)

func _physics_process(delta):
	var displacement = position - _rest_position
	var t = clamp(displacement.length() / max_travel, 0.0, 1.0)
	var effective_damping = _damping * (1.0 + t * t * 8.0)
	var spring_force = -_stiffness * displacement - effective_damping * _spring_velocity
	_spring_velocity += spring_force * delta
	position += _spring_velocity * delta
	var new_disp = position - _rest_position
	if new_disp.length() > max_travel:
		position = _rest_position + new_disp.normalized() * max_travel
		_spring_velocity = Vector2.ZERO

func apply_push(direction: Vector2, strength: float):
	if statsON:
		_stats.add(strength)
		print("hit: %.2f  mean: %.2f" % [strength, _stats.mean()])
		if _stats.count() % 10 == 0:
			_stats.report()
	_spring_velocity = (_spring_velocity + direction * strength * _push_scale).limit_length(_max_impulse)
