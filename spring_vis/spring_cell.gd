class_name SpringCell
extends Control

const TRACE_LEN  := 240
const ANCHOR_PAD := 22.0
const EQ_OFFSET  := 60.0
const COIL_TURNS := 9
const COIL_AMP   := 8.0
const BALL_R     := 11.0

var spring: SpringBody
var color: Color = Color(0.5, 0.7, 1.0)
var label_text: String = ""

var _anchor: Vector2
var _equilibrium: Vector2
var _spring_half_w: float
var _trace: Array[float] = []

func _ready() -> void:
	if spring == null:
		spring = SpringBody.new()
		spring.setup()
	resized.connect(_on_resized)
	_trace.resize(TRACE_LEN)
	_trace.fill(0.0)
	_on_resized()

func _on_resized() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	_spring_half_w = size.x * 0.5
	_anchor      = Vector2(_spring_half_w * 0.5, ANCHOR_PAD)
	_equilibrium = _anchor + Vector2(0, EQ_OFFSET)
	spring.target = _equilibrium
	if spring.position == Vector2.ZERO:
		spring.position = _equilibrium

func tick(delta: float) -> void:
	spring.target = _equilibrium
	spring.tick(delta)
	_trace.append(spring.position.y - _equilibrium.y)
	if _trace.size() > TRACE_LEN:
		_trace.pop_front()
	queue_redraw()

func fire_impulse(strength: float) -> void:
	spring.push(Vector2(0.0, strength))

func fire_drop(height: float) -> void:
	spring.position = _equilibrium - Vector2(0.0, height)
	spring.velocity = Vector2.ZERO

func _draw() -> void:
	# background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.09, 0.11), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.22, 0.22, 0.27), false, 1.0)

	# spring half — equilibrium dashed
	_draw_dashed_h(_equilibrium.y, 4.0, _spring_half_w - 4.0, Color(0.4, 0.4, 0.45))

	# anchor mount (gray bar)
	var mount_w := 32.0
	draw_rect(Rect2(_anchor - Vector2(mount_w * 0.5, 5), Vector2(mount_w, 5)),
			Color(0.5, 0.5, 0.55), true)

	# spring coil
	_draw_coil(_anchor, spring.position, color)

	# ball
	draw_circle(spring.position, BALL_R, color)

	# trace half
	_draw_trace()

func _draw_dashed_h(y: float, x0: float, x1: float, c: Color) -> void:
	var dash := 6.0
	var gap  := 4.0
	var x := x0
	while x < x1:
		var nx: float = minf(x + dash, x1)
		draw_line(Vector2(x, y), Vector2(nx, y), c, 1.0)
		x = nx + gap

func _draw_coil(a: Vector2, b: Vector2, c: Color) -> void:
	var diff := b - a
	var dist := diff.length()
	if dist < 1.0:
		draw_line(a, b, c, 2.0)
		return
	var dir  := diff / dist
	var perp := Vector2(-dir.y, dir.x)
	var n    := COIL_TURNS * 2
	var amp: float = minf(COIL_AMP, dist * 0.18)
	var pts  := PackedVector2Array()
	pts.append(a)
	for i in range(1, n):
		var t := float(i) / float(n)
		var p := a + diff * t
		var s := 1.0 if (i % 2 == 0) else -1.0
		pts.append(p + perp * amp * s)
	pts.append(b)
	draw_polyline(pts, c, 2.0, true)

func _draw_trace() -> void:
	var tx0    := _spring_half_w + 8.0
	var tx1    := size.x - 8.0
	var ty_top := ANCHOR_PAD
	var ty_bot := size.y - 10.0
	if tx1 - tx0 < 8.0 or ty_bot - ty_top < 8.0:
		return
	var tw   := tx1 - tx0
	var eq_y := ty_top + EQ_OFFSET

	# trace background
	draw_rect(Rect2(Vector2(tx0, ty_top), Vector2(tw, ty_bot - ty_top)),
			Color(0.06, 0.06, 0.08), true)

	# equilibrium dashed
	_draw_dashed_h(eq_y, tx0, tx1, Color(0.4, 0.4, 0.45))

	var n := _trace.size()
	if n < 2:
		return
	var pts := PackedVector2Array()
	for i in n:
		var x := tx0 + (float(i) / float(TRACE_LEN - 1)) * tw
		var y: float = clampf(eq_y + _trace[i], ty_top, ty_bot)
		pts.append(Vector2(x, y))
	draw_polyline(pts, color, 1.5, true)

	# head dot
	draw_circle(pts[pts.size() - 1], 4.0, color)
