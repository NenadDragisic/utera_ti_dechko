class_name BoardView
extends PanelContainer


const WORD_LENGTH := 5
const MINIMUM_CELL_SIZE := 48
const MINIMUM_GLYPH_SIZE := 16
const CELL_GAP := 4
const MOTION_SECONDS := 0.15
const SHAKE_DISTANCE := 4.0


var reduced_motion: bool = false
var flip_animation_enabled: bool = false
var shake_animation_enabled: bool = false
var solved_emphasis_animation_enabled: bool = false

var _attempt_limit: int = 0
var _styles: Dictionary = {}
var _rendered_states: Dictionary = {}
var _was_solved: bool = false
var _has_rendered: bool = false
var _motion_tweens: Array[Tween] = []
var _base_panel_style: StyleBoxFlat

@onready var _board_name: Label = $Content/Header/BoardName
@onready var _attempt_status: Label = $Content/Header/AttemptStatus
@onready var _cells: GridContainer = $Content/Cells


func render(board: BoardState, session: GameSession, display_index: int = 0) -> void:
	if board == null or session == null:
		return
	_stop_motion()
	_ensure_grid(session.attempt_limit)
	_board_name.text = "РЕЧ %d" % (display_index + 1)
	accessibility_name = "Табла %d, %s" % [
		display_index + 1,
		"решена" if board.is_solved else "у току",
	]
	_attempt_status.text = "ПОКУШАЈ %d / %d" % [
		mini(session.attempt_index + 1, session.attempt_limit),
		session.attempt_limit,
	]
	_reset_cells()

	for row_index in range(board.rows.size()):
		var row: GuessRow = board.rows[row_index]
		var marks := row.marks()
		for column in range(WORD_LENGTH):
			_set_cell(row_index, column, row.guess()[column], _state_for_mark(marks[column]))

	if not board.is_solved and session.status == GameSession.Status.ACTIVE:
		var active_row := session.attempt_index
		if active_row < session.attempt_limit:
			var active_state := "invalid" if session.input_is_invalid else "current"
			for column in range(session.current_input.length()):
				_set_cell(active_row, column, session.current_input[column], active_state)

	_apply_solved_style(board.is_solved)
	var next_states := _current_states()
	if _has_rendered and not reduced_motion:
		_animate_state_changes(next_states, session, board.is_solved)
	_rendered_states = next_states
	_was_solved = board.is_solved
	_has_rendered = true


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	flip_animation_enabled = not reduced_motion
	shake_animation_enabled = not reduced_motion
	solved_emphasis_animation_enabled = not reduced_motion
	if reduced_motion:
		_stop_motion()


func _ensure_grid(attempt_limit: int) -> void:
	if _attempt_limit == attempt_limit:
		return
	assert(_attempt_limit == 0, "A BoardView has one fixed grid for its session mode.")
	_attempt_limit = attempt_limit
	_cells.columns = WORD_LENGTH
	_cells.add_theme_constant_override("h_separation", CELL_GAP)
	_cells.add_theme_constant_override("v_separation", CELL_GAP)
	for row in range(_attempt_limit):
		for column in range(WORD_LENGTH):
			var cell := PanelContainer.new()
			cell.name = "Cell_%d_%d" % [row, column]
			cell.custom_minimum_size = Vector2(MINIMUM_CELL_SIZE, MINIMUM_CELL_SIZE)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.pivot_offset = Vector2(
				MINIMUM_CELL_SIZE * 0.5,
				MINIMUM_CELL_SIZE * 0.5,
			)
			var glyph := Label.new()
			glyph.name = "Glyph"
			glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			glyph.add_theme_font_size_override("font_size", MINIMUM_GLYPH_SIZE)
			glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(glyph)
			_cells.add_child(cell)


func _reset_cells() -> void:
	for row in range(_attempt_limit):
		for column in range(WORD_LENGTH):
			_set_cell(row, column, "", "empty")


func _set_cell(row: int, column: int, letter: String, state: String) -> void:
	var cell := _cell(row, column)
	var glyph := cell.get_node("Glyph") as Label
	glyph.text = letter
	cell.set_meta("render_state", state)
	cell.accessibility_name = "Ред %d, слово %d, %s" % [
		row + 1,
		column + 1,
		_accessibility_state_label(state),
	]
	cell.add_theme_stylebox_override("panel", _style(state))
	glyph.add_theme_color_override("font_color", _font_color(state))


func _cell(row: int, column: int) -> PanelContainer:
	return _cells.get_node("Cell_%d_%d" % [row, column]) as PanelContainer


func _style(state: String) -> StyleBoxFlat:
	if _styles.has(state):
		return _styles[state]
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = DesignTokens.CELL_RADIUS
	style.corner_radius_top_right = DesignTokens.CELL_RADIUS
	style.corner_radius_bottom_left = DesignTokens.CELL_RADIUS
	style.corner_radius_bottom_right = DesignTokens.CELL_RADIUS
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	var surface := _semantic_color("surface", DesignTokens.DARK_SURFACE)
	var raised_surface := _semantic_color(
		"surface_raised", DesignTokens.DARK_SURFACE_RAISED
	)
	var border := _semantic_color("border", DesignTokens.DARK_BORDER)
	match state:
		"correct":
			surface = _semantic_color("success", DesignTokens.MINT_SUCCESS)
			border = surface
		"present":
			surface = _semantic_color("present", DesignTokens.GOLD_PRESENT)
			border = surface
		"absent":
			surface = raised_surface
			border = raised_surface
		"current":
			surface = raised_surface
			border = _semantic_color("muted_text", DesignTokens.DARK_MUTED_TEXT)
		"invalid":
			var invalid := _semantic_color("invalid", DesignTokens.RED_INVALID)
			surface = surface.lerp(invalid, 0.28)
			border = invalid
	style.bg_color = surface
	style.border_color = border
	_styles[state] = style
	return style


func _font_color(state: String) -> Color:
	if state == "absent" or state == "empty":
		return _semantic_color("muted_text", DesignTokens.DARK_MUTED_TEXT)
	return _semantic_color("text", DesignTokens.DARK_TEXT)


func _semantic_color(color_name: StringName, fallback: Color) -> Color:
	if has_theme_color(color_name, "DesignTokens"):
		return get_theme_color(color_name, "DesignTokens")
	return fallback


func _state_for_mark(mark: LetterMark.Value) -> String:
	match mark:
		LetterMark.Value.CORRECT:
			return "correct"
		LetterMark.Value.PRESENT:
			return "present"
		_:
			return "absent"


func _accessibility_state_label(state: String) -> String:
	match state:
		"correct":
			return "тачно"
		"present":
			return "присутно"
		"absent":
			return "није присутно"
		"current":
			return "унето"
		"invalid":
			return "неважеће"
		_:
			return "празно"


func _current_states() -> Dictionary:
	var states := {}
	for row in range(_attempt_limit):
		for column in range(WORD_LENGTH):
			states[Vector2i(row, column)] = _cell(row, column).get_meta("render_state")
	return states


func _animate_state_changes(
	next_states: Dictionary,
	session: GameSession,
	is_solved: bool,
) -> void:
	var invalid_row := -1
	for position: Vector2i in next_states:
		var state: String = next_states[position]
		var previous: String = _rendered_states.get(position, "empty")
		if ["correct", "present", "absent"].has(state) and state != previous:
			_animate_cell_reveal(_cell(position.x, position.y))
		if state == "invalid" and previous != "invalid":
			invalid_row = position.x
	if invalid_row >= 0 and invalid_row < session.attempt_limit:
		_animate_invalid_row(invalid_row)
	if is_solved and not _was_solved:
		_animate_solved_emphasis()


func _animate_cell_reveal(cell: Control) -> void:
	cell.pivot_offset = cell.size * 0.5
	cell.scale = Vector2(1.0, 0.82)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(cell, "scale", Vector2.ONE, MOTION_SECONDS)
	_motion_tweens.append(tween)


func _animate_invalid_row(row: int) -> void:
	for column in range(WORD_LENGTH):
		var glyph := _cell(row, column).get_node("Glyph") as Label
		var origin := glyph.position
		glyph.set_meta("motion_origin", origin)
		glyph.position.x = origin.x - SHAKE_DISTANCE
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(
			glyph,
			"position:x",
			origin.x + SHAKE_DISTANCE,
			MOTION_SECONDS / 3.0,
		)
		tween.tween_property(
			glyph,
			"position:x",
			origin.x - SHAKE_DISTANCE,
			MOTION_SECONDS / 3.0,
		)
		tween.tween_property(glyph, "position:x", origin.x, MOTION_SECONDS / 3.0)
		_motion_tweens.append(tween)


func _animate_solved_emphasis() -> void:
	pivot_offset = size * 0.5
	scale = Vector2(0.97, 0.97)
	modulate = _semantic_color("success", DesignTokens.MINT_SUCCESS).lerp(
		Color.WHITE,
		0.35,
	)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, MOTION_SECONDS)
	tween.tween_property(self, "modulate", Color.WHITE, MOTION_SECONDS)
	_motion_tweens.append(tween)


func _apply_solved_style(is_solved: bool) -> void:
	if _base_panel_style == null:
		_base_panel_style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if not is_solved:
		add_theme_stylebox_override("panel", _base_panel_style)
		return
	var solved := _base_panel_style.duplicate() as StyleBoxFlat
	var mint := _semantic_color("success", DesignTokens.MINT_SUCCESS)
	solved.border_color = mint
	solved.set_border_width_all(2)
	add_theme_stylebox_override("panel", solved)


func _stop_motion() -> void:
	for tween in _motion_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_motion_tweens.clear()
	scale = Vector2.ONE
	modulate = Color.WHITE
	if _attempt_limit == 0:
		return
	for row in range(_attempt_limit):
		for column in range(WORD_LENGTH):
			var cell := _cell(row, column)
			cell.scale = Vector2.ONE
			var glyph := cell.get_node("Glyph") as Label
			if glyph.has_meta("motion_origin"):
				glyph.position = glyph.get_meta("motion_origin")
				glyph.remove_meta("motion_origin")
