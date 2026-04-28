extends Node2D

const PARAMS: Array[String] = ["omega_0", "zeta", "mass", "sat_x", "sat_v"]
const PARAM_DEFAULTS := {
	"omega_0": 8.0, "zeta": 0.35, "mass": 1.0, "sat_x": 40.0, "sat_v": 300.0,
}
const PARAM_RANGES := {
	"omega_0": [1.0,    20.0,   0.1],
	"zeta":    [0.0,     3.0,   0.01],
	"mass":    [0.1,     5.0,   0.05],
	"sat_x":   [10.0,  200.0,   1.0],
	"sat_v":   [50.0, 1000.0,   5.0],
}
const ROW_COLORS := [
	Color(0.65, 0.55, 0.95),
	Color(0.30, 0.65, 1.00),
	Color(0.30, 0.85, 0.55),
	Color(1.00, 0.55, 0.30),
	Color(0.95, 0.40, 0.65),
]
const MAX_AXIS := 5
const PANEL_W  := 320.0
const ROW_HEAD_W := 90.0
const COL_HEAD_H := 50.0

var _row_param := "zeta"
var _col_param := "omega_0"
var _row_values: Array[float] = [0.1, 0.4, 1.0, 2.5]
var _col_values: Array[float] = [3.0, 8.0, 15.0]
var _values: Dictionary = PARAM_DEFAULTS.duplicate()

var _trigger_mode    := 0      # 0 = impulse, 1 = drop
var _impulse_force   := 300.0
var _drop_height     := 100.0
var _auto_loop       := false
var _auto_interval   := 1.5
var _auto_t          := 0.0

var _grid_root: Control
var _cells: Array = []   # 2D array of SpringCell

# UI refs
var _row_option: OptionButton
var _col_option: OptionButton
var _row_start: SpinBox
var _row_end:   SpinBox
var _row_count: SpinBox
var _col_start: SpinBox
var _col_end:   SpinBox
var _col_count: SpinBox
var _shared_box: VBoxContainer

# ── lifecycle ──────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()
	await get_tree().process_frame
	_rebuild_grid()

func _process(delta: float) -> void:
	for row in _cells:
		for cell in row:
			cell.tick(delta)
	if _auto_loop and _cells.size() > 0:
		_auto_t += delta
		if _auto_t >= _auto_interval:
			_auto_t = 0.0
			_fire_all()

# ── UI build ───────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var vp := get_viewport_rect().size
	var cl := CanvasLayer.new()
	add_child(cl)

	# ── left control panel ────────────────────────────────────────────────
	var panel := Panel.new()
	panel.position = Vector2.ZERO
	panel.size     = Vector2(PANEL_W, vp.y)
	cl.add_child(panel)

	var margin := MarginContainer.new()
	panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    14)
	margin.add_theme_constant_override("margin_bottom", 14)

	var sc := ScrollContainer.new()
	margin.add_child(sc)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)

	_add_title(box, "Spring Grid")
	box.add_child(HSeparator.new())

	_add_subtitle(box, "Row axis")
	_row_option = _add_option(box, _row_param)
	_row_option.item_selected.connect(_on_row_param_selected)
	var row_rng = PARAM_RANGES[_row_param]
	_row_start = _add_range_row(box, "From:", 0.1,  row_rng[0], row_rng[1], row_rng[2])
	_row_end   = _add_range_row(box, "To:",   2.5,  row_rng[0], row_rng[1], row_rng[2])
	_row_count = _add_range_row(box, "Steps:", 4.0, 1.0, 5.0, 1.0)

	_add_subtitle(box, "Column axis")
	_col_option = _add_option(box, _col_param)
	_col_option.item_selected.connect(_on_col_param_selected)
	var col_rng = PARAM_RANGES[_col_param]
	_col_start = _add_range_row(box, "From:", 3.0,   col_rng[0], col_rng[1], col_rng[2])
	_col_end   = _add_range_row(box, "To:",   15.0,  col_rng[0], col_rng[1], col_rng[2])
	_col_count = _add_range_row(box, "Steps:", 3.0,  1.0, 5.0, 1.0)

	box.add_child(HSeparator.new())

	_add_subtitle(box, "Shared parameters")
	_shared_box = VBoxContainer.new()
	_shared_box.add_theme_constant_override("separation", 6)
	box.add_child(_shared_box)
	_rebuild_shared()

	box.add_child(HSeparator.new())

	_add_subtitle(box, "Trigger")
	var mode_opt := OptionButton.new()
	mode_opt.add_item("Impulse")
	mode_opt.add_item("Drop")
	mode_opt.selected = _trigger_mode
	mode_opt.item_selected.connect(func(i: int) -> void: _trigger_mode = i)
	box.add_child(mode_opt)

	var imp_spin := _add_labeled_spin(box, "Impulse:", _impulse_force, 50.0, 2000.0, 10.0)
	imp_spin.value_changed.connect(func(v: float) -> void: _impulse_force = v)

	var drop_spin := _add_labeled_spin(box, "Drop ht:", _drop_height, 20.0, 300.0, 5.0)
	drop_spin.value_changed.connect(func(v: float) -> void: _drop_height = v)

	var btn_fire := Button.new()
	btn_fire.text = "Fire all  (Space)"
	btn_fire.custom_minimum_size = Vector2(0, 36)
	btn_fire.add_theme_font_size_override("font_size", 14)
	btn_fire.pressed.connect(_fire_all)
	box.add_child(btn_fire)

	var auto_check := CheckBox.new()
	auto_check.text = "Auto-loop"
	auto_check.toggled.connect(func(p: bool) -> void:
		_auto_loop = p
		_auto_t = 0.0
	)
	box.add_child(auto_check)

	var int_spin := _add_labeled_spin(box, "Interval:", _auto_interval, 0.3, 10.0, 0.1)
	int_spin.value_changed.connect(func(v: float) -> void: _auto_interval = v)

	box.add_child(HSeparator.new())

	var btn_rebuild := Button.new()
	btn_rebuild.text = "Apply axes / Rebuild"
	btn_rebuild.custom_minimum_size = Vector2(0, 36)
	btn_rebuild.pressed.connect(_apply_and_rebuild)
	box.add_child(btn_rebuild)

	# ── right grid area ───────────────────────────────────────────────────
	_grid_root = Control.new()
	_grid_root.position = Vector2(PANEL_W, 0.0)
	_grid_root.size     = Vector2(vp.x - PANEL_W, vp.y)
	cl.add_child(_grid_root)

# ── UI helpers ─────────────────────────────────────────────────────────────

func _add_title(parent: Node, t: String) -> void:
	var lbl := Label.new()
	lbl.text = t
	lbl.add_theme_font_size_override("font_size", 18)
	parent.add_child(lbl)

func _add_subtitle(parent: Node, t: String) -> void:
	var lbl := Label.new()
	lbl.text = t
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.modulate = Color(0.78, 0.78, 0.85)
	parent.add_child(lbl)

func _add_option(parent: Node, selected: String) -> OptionButton:
	var opt := OptionButton.new()
	for i in PARAMS.size():
		opt.add_item(PARAMS[i])
		if PARAMS[i] == selected:
			opt.selected = i
	parent.add_child(opt)
	return opt

func _add_labeled_spin(parent: Node, lbl_text: String, init: float,
		mn: float, mx: float, step: float) -> SpinBox:
	var hb := HBoxContainer.new()
	parent.add_child(hb)
	var lbl := Label.new()
	lbl.text = lbl_text
	lbl.custom_minimum_size = Vector2(72, 0)
	hb.add_child(lbl)
	var sp := SpinBox.new()
	sp.min_value = mn
	sp.max_value = mx
	sp.step      = step
	sp.value     = init
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	return sp

func _rebuild_shared() -> void:
	for c in _shared_box.get_children():
		c.queue_free()
	for p in PARAMS:
		if p == _row_param or p == _col_param:
			continue
		var rng = PARAM_RANGES[p]
		var sp := _add_labeled_spin(_shared_box, p + ":",
				_values[p], rng[0], rng[1], rng[2])
		var pname: String = p
		sp.value_changed.connect(func(v: float) -> void:
			_values[pname] = v
			_update_all_cell_params()
		)

# ── axis handling ──────────────────────────────────────────────────────────

func _on_row_param_selected(idx: int) -> void:
	var p: String = PARAMS[idx]
	if p == _col_param:
		_col_param = _row_param
		_col_option.selected = PARAMS.find(_col_param)
		_update_axis_spins(_col_start, _col_end, _col_param)
	_row_param = p
	_update_axis_spins(_row_start, _row_end, _row_param)
	_rebuild_shared()

func _on_col_param_selected(idx: int) -> void:
	var p: String = PARAMS[idx]
	if p == _row_param:
		_row_param = _col_param
		_row_option.selected = PARAMS.find(_row_param)
		_update_axis_spins(_row_start, _row_end, _row_param)
	_col_param = p
	_update_axis_spins(_col_start, _col_end, _col_param)
	_rebuild_shared()

func _update_axis_spins(start_spin: SpinBox, end_spin: SpinBox, param: String) -> void:
	var rng = PARAM_RANGES[param]
	start_spin.min_value = rng[0]; start_spin.max_value = rng[1]; start_spin.step = rng[2]
	end_spin.min_value   = rng[0]; end_spin.max_value   = rng[1]; end_spin.step   = rng[2]
	start_spin.value = clampf(start_spin.value, rng[0], rng[1])
	end_spin.value   = clampf(end_spin.value,   rng[0], rng[1])

# ── grid build ─────────────────────────────────────────────────────────────

func _apply_and_rebuild() -> void:
	_row_values = _gen_values(_row_start.value, _row_end.value, int(_row_count.value))
	_col_values = _gen_values(_col_start.value, _col_end.value, int(_col_count.value))
	_rebuild_grid()

func _rebuild_grid() -> void:
	for c in _grid_root.get_children():
		c.queue_free()
	_cells.clear()

	var rows: int = _row_values.size()
	var cols: int = _col_values.size()
	if rows == 0 or cols == 0:
		return

	var area := _grid_root.size
	var avail_w := area.x - ROW_HEAD_W - 16.0
	var avail_h := area.y - COL_HEAD_H - 16.0
	var cell_w: float = clamp(avail_w / float(cols), 160.0, 400.0)
	var cell_h: float = clamp(avail_h / float(rows), 140.0, 320.0)

	var grid := GridContainer.new()
	grid.position = Vector2(8.0, 8.0)
	grid.columns = cols + 1
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_grid_root.add_child(grid)

	# top-left corner spacer
	var corner := Control.new()
	corner.custom_minimum_size = Vector2(ROW_HEAD_W, COL_HEAD_H)
	grid.add_child(corner)

	# column headers
	for c in cols:
		var lbl := Label.new()
		lbl.text = "%s\n%s" % [_col_param, _fmt(_col_values[c])]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size  = Vector2(cell_w, COL_HEAD_H)
		lbl.add_theme_font_size_override("font_size", 13)
		grid.add_child(lbl)

	# rows
	for r in rows:
		var col: Color = ROW_COLORS[r % ROW_COLORS.size()]

		var rlbl := Label.new()
		rlbl.text = "%s\n%s" % [_row_param, _fmt(_row_values[r])]
		rlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rlbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		rlbl.custom_minimum_size  = Vector2(ROW_HEAD_W, cell_h)
		rlbl.add_theme_font_size_override("font_size", 13)
		rlbl.modulate = col
		grid.add_child(rlbl)

		var row_cells: Array = []
		for c in cols:
			var cell := SpringCell.new()
			cell.custom_minimum_size = Vector2(cell_w, cell_h)
			cell.color  = col
			cell.spring = _make_spring(_row_values[r], _col_values[c])
			grid.add_child(cell)
			row_cells.append(cell)
		_cells.append(row_cells)

func _make_spring(rv: float, cv: float) -> SpringBody:
	var sb := SpringBody.new()
	sb.omega_0 = _resolve("omega_0", rv, cv)
	sb.zeta    = _resolve("zeta",    rv, cv)
	sb.mass    = _resolve("mass",    rv, cv)
	sb.sat_x   = _resolve("sat_x",   rv, cv)
	sb.sat_v   = _resolve("sat_v",   rv, cv)
	sb.setup()
	return sb

func _resolve(p: String, rv: float, cv: float) -> float:
	if p == _row_param: return rv
	if p == _col_param: return cv
	return _values[p]

func _update_all_cell_params() -> void:
	for r in _cells.size():
		for c in _cells[r].size():
			var sb: SpringBody = _cells[r][c].spring
			sb.omega_0 = _resolve("omega_0", _row_values[r], _col_values[c])
			sb.zeta    = _resolve("zeta",    _row_values[r], _col_values[c])
			sb.mass    = _resolve("mass",    _row_values[r], _col_values[c])
			sb.sat_x   = _resolve("sat_x",   _row_values[r], _col_values[c])
			sb.sat_v   = _resolve("sat_v",   _row_values[r], _col_values[c])
			sb.setup()

# ── triggers ───────────────────────────────────────────────────────────────

func _fire_all() -> void:
	for row in _cells:
		for cell in row:
			if _trigger_mode == 0:
				cell.fire_impulse(_impulse_force)
			else:
				cell.fire_drop(_drop_height)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.keycode == KEY_SPACE and ke.pressed and not ke.echo:
			_fire_all()

# ── helpers ────────────────────────────────────────────────────────────────

func _add_range_row(parent: Node, lbl_text: String, init: float,
		mn: float, mx: float, step: float) -> SpinBox:
	var hb := HBoxContainer.new()
	parent.add_child(hb)
	var lbl := Label.new()
	lbl.text = lbl_text
	lbl.custom_minimum_size = Vector2(52, 0)
	hb.add_child(lbl)
	var sp := SpinBox.new()
	sp.min_value = mn
	sp.max_value = mx
	sp.step      = step
	sp.value     = clampf(init, mn, mx)
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	return sp

func _gen_values(start: float, end: float, count: int) -> Array[float]:
	var out: Array[float] = []
	if count <= 1:
		out.append(start)
		return out
	for i in count:
		out.append(lerp(start, end, float(i) / float(count - 1)))
	return out

func _fmt(v: float) -> String:
	if abs(v - round(v)) < 0.001:
		return "%d" % int(v)
	return "%.2f" % v
