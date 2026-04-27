extends CharacterBody2D

@export var coin_area: Area2D
@export var caja_body: AnimatableBody2D

var dragging := false
var drag_offset := Vector2.ZERO

func _ready():
	coin_area.input_event.connect(_on_coin_input)

func _on_coin_input(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging = true
		drag_offset = global_position - get_global_mouse_position()

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false

func _physics_process(delta):
	if dragging:
		var target = get_global_mouse_position() + drag_offset
		var smoothed = global_position.lerp(target, 20.0 * delta)
		velocity = (smoothed - global_position) / delta
	else:
		velocity = Vector2.ZERO

	var pre_slide_velocity := velocity
	move_and_slide()

	if dragging:
		for i in get_slide_collision_count():
			var col = get_slide_collision(i)
			if col.get_collider() == caja_body:
				var impact := pre_slide_velocity.dot(-col.get_normal())
				if impact > 0:
					caja_body.apply_push(-col.get_normal(), impact)
