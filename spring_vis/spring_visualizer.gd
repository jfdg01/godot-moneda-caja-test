extends Node2D

const TRAIL_LEN := 300
const GRAPH_LEN := 300
const UI_W      := 320.0
const GRAPH_H   := 140.0
const BALL_R    := 14.0
const TARGET_R  := 18.0

var spring: SpringBody

var _sim: Node2D
var _trail: Line2D
var _graph_line: Line2D
var _graph_panel: Panel
var _target_pos: Vector2

var _trail_buf: Array[Vector2] = []
var _graph_buf: Array[float]   = []

# ── build ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	spring = SpringBody.new()
	spring.omega_0 = 8.0
	spring.zeta    = 0.35
	spring.mass    = 1.0
	spring.sat_x   = 40.0
	spring.sat_v   = 300.0
	spring.setup()

	var vp := get_viewport_rect().size
	_target_pos = vp / 2.0
	spring.teleport(_target_pos)

	_build_sim()
	_build_ui(vp)


func _build_sim() -> void:
	_sim = Node2D.new()
	add_child(_sim)
	_sim.draw.connect(_on_sim_draw)

	_trail = Line2D.new()
	_trail.width          = 2.0
	_trail.default_color  = Color(0.4, 0.9, 1.0, 0.25)
	_trail.joint_mode     = Line2D.LINE_JOINT_ROUND
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode   = Line2D.LINE_CAP_ROUND
	_sim.add_child(_trail)


func _build_ui(vp: Vector2) -> void:
	var cl := CanvasLayer.new()
	add_child(cl)

	# ── right panel ───────────────────────────────────────────────────────
	var panel := Panel.new()
	panel.position = Vector2(vp.x - UI_W, 0.0)
	panel.size     = Vector2(UI_W, vp.y - GRAPH_H)
	cl.add_child(panel)

	var margin := MarginContainer.new()
	panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    14)
	margin.add_theme_constant_override("margin_bottom", 14)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Spring Parameters"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_add_row(vbox, "omega_0", spring.omega_0,  1.0,   20.0, 0.1,  _on_omega)
	_add_row(vbox, "zeta",    spring.zeta,     0.0,    2.0, 0.01, _on_zeta)
	_add_row(vbox, "mass",    spring.mass,     0.1,    5.0, 0.05, _on_mass)
	_add_row(vbox, "sat_x",   spring.sat_x,   10.0,  200.0, 1.0,  _on_sat_x)
	_add_row(vbox, "sat_v",   spring.sat_v,   50.0, 1000.0, 5.0,  _on_sat_v)

	vbox.add_child(HSeparator.new())

	var hint := Label.new()
	hint.text = "Click sim → move target\nSpace / button → impulse\n\nmass only affects impulse\nresponse, not oscillation.\nHigher mass = less kick."
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(0.75, 0.75, 0.75)
	vbox.add_child(hint)

	var btn_impulse := Button.new()
	btn_impulse.text = "Impulse ↓  (Space)"
	btn_impulse.add_theme_font_size_override("font_size", 14)
	btn_impulse.custom_minimum_size = Vector2(0, 36)
	btn_impulse.pressed.connect(_apply_impulse)
	vbox.add_child(btn_impulse)

	var btn_reset := Button.new()
	btn_reset.text = "Reset"
	btn_reset.add_theme_font_size_override("font_size", 14)
	btn_reset.custom_minimum_size = Vector2(0, 36)
	btn_reset.pressed.connect(_reset)
	vbox.add_child(btn_reset)

	# ── graph panel ───────────────────────────────────────────────────────
	_graph_panel = Panel.new()
	_graph_panel.position = Vector2(0.0, vp.y - GRAPH_H)
	_graph_panel.size     = Vector2(vp.x, GRAPH_H)
	cl.add_child(_graph_panel)

	var glabel := Label.new()
	glabel.text = "Displacement"
	glabel.add_theme_font_size_override("font_size", 12)
	glabel.position = Vector2(8, 5)
	glabel.modulate = Color(0.75, 0.75, 0.75)
	_graph_panel.add_child(glabel)

	_graph_line = Line2D.new()
	_graph_line.width         = 1.5
	_graph_line.default_color = Color(1.0, 0.75, 0.2, 0.9)
	_graph_panel.add_child(_graph_line)


func _add_row(parent: VBoxContainer, label_text: String, init_val: float,
		min_v: float, max_v: float, step: float, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(66, 0)
	lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step      = step
	slider.value     = init_val
	slider.custom_minimum_size    = Vector2(0, 26)
	slider.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step      = step
	spin.value     = init_val
	spin.custom_minimum_size = Vector2(90, 0)
	spin.get_line_edit().add_theme_font_size_override("font_size", 13)
	row.add_child(spin)

	# keep slider and spinbox in sync without feedback loops
	slider.value_changed.connect(func(v: float) -> void:
		if not is_equal_approx(spin.value, v):
			spin.set_value_no_signal(v)
		callback.call(v)
	)
	spin.value_changed.connect(func(v: float) -> void:
		if not is_equal_approx(slider.value, v):
			slider.set_value_no_signal(v)
		callback.call(v)
	)

# ── simulation ─────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	spring.target = _target_pos
	spring.tick(delta)

	_trail_buf.append(spring.position)
	if _trail_buf.size() > TRAIL_LEN:
		_trail_buf.pop_front()
	_trail.points = PackedVector2Array(_trail_buf)

	var disp := (spring.position - spring.target).length()
	_graph_buf.append(disp)
	if _graph_buf.size() > GRAPH_LEN:
		_graph_buf.pop_front()
	_update_graph()

	_sim.queue_redraw()


func _update_graph() -> void:
	if _graph_buf.is_empty():
		return
	var w     := _graph_panel.size.x
	var h     := GRAPH_H - 26.0
	var top   := 22.0
	var max_d := 0.0
	for d in _graph_buf:
		if d > max_d:
			max_d = d
	max_d = max(max_d, 1.0)

	var pts := PackedVector2Array()
	var n   := _graph_buf.size()
	for i in n:
		var x := (float(i) / float(GRAPH_LEN - 1)) * w
		var y := top + (1.0 - _graph_buf[i] / max_d) * h
		pts.append(Vector2(x, y))
	_graph_line.points = pts

# ── drawing ────────────────────────────────────────────────────────────────

func _on_sim_draw() -> void:
	_sim.draw_line(spring.position, _target_pos, Color(1, 1, 1, 0.18), 1.5)

	_sim.draw_arc(_target_pos, TARGET_R, 0.0, TAU, 32, Color(1, 1, 1, 0.45), 2.0)
	_sim.draw_arc(_target_pos, 3.0,      0.0, TAU, 16, Color(1, 1, 1, 0.7),  2.0)

	var ball_r := BALL_R * sqrt(spring.mass)
	_sim.draw_circle(spring.position, ball_r, Color(0.25, 0.85, 1.0, 1.0))
	_sim.draw_arc(spring.position, ball_r, 0.0, TAU, 32, Color(1, 1, 1, 0.6), 1.5)

# ── input ──────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var vp    := get_viewport_rect().size
			var click := mb.position
			if click.x < vp.x - UI_W and click.y < vp.y - GRAPH_H:
				_target_pos = click

	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.keycode == KEY_SPACE and ke.pressed and not ke.echo:
			_apply_impulse()

# ── callbacks ──────────────────────────────────────────────────────────────

func _apply_impulse() -> void:
	spring.push(Vector2(0.0, 300.0))

func _reset() -> void:
	var vp := get_viewport_rect().size
	_target_pos = vp / 2.0
	spring.teleport(_target_pos)
	_trail_buf.clear()
	_graph_buf.clear()
	_trail.points      = PackedVector2Array()
	_graph_line.points = PackedVector2Array()

func _on_omega(v: float) -> void:
	spring.omega_0 = v
	spring.setup()

func _on_zeta(v: float) -> void:
	spring.zeta = v
	spring.setup()

func _on_mass(v: float) -> void:
	spring.mass = v
	spring.setup()

func _on_sat_x(v: float) -> void:
	spring.sat_x = v

func _on_sat_v(v: float) -> void:
	spring.sat_v = v
