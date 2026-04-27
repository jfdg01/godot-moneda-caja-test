extends CharacterBody2D

const INSIDE = 0
const OUTSIDE = 2

var dragging := false
var drag_offset := Vector2.ZERO
var inside := true

func _ready():
	z_index = OUTSIDE
	var slot = get_parent().get_node("SpineSprite/Area2D")
	slot.input_pickable = false
	slot.area_entered.connect(_on_slot_entered)
	# slot.area_exited.connect(_on_slot_exited)
	$Area2D.input_event.connect(_on_coin_input)

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
		move_and_slide()

func _on_slot_entered(_area):
	if (inside):
		z_index = INSIDE
	else:
		z_index = OUTSIDE
