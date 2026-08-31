class_name BoardView
extends PanelContainer


const WORD_LENGTH := 5
const MINIMUM_CELL_SIZE := 48
const MINIMUM_GLYPH_SIZE := 16
const CELL_GAP := 4


var reduced_motion: bool = false
var flip_animation_enabled: bool = false
var shake_animation_enabled: bool = false

var _attempt_limit: int = 0
var _styles: Dictionary = {}

@onready var _board_name: Label = $Content/Header/BoardName
@onready var _attempt_status: Label = $Content/Header/AttemptStatus
@onready var _cells: GridContainer = $Content/Cells


func render(board: BoardState, session: GameSession, display_index: int = 0) -> void:
	if board == null or session == null:
		return
	_ensure_grid(session.attempt_limit)
	_board_name.text = "РЕЧ %d" % (display_index + 1)
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


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	# Task 13 enables the motion hooks. Keeping both flags false now prevents
	# state changes from animating in either motion preference.
	flip_animation_enabled = false
	shake_animation_enabled = false


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
	var border := DesignTokens.DARK_BORDER
	match state:
		"correct":
			surface = _semantic_color("success", DesignTokens.MINT_SUCCESS)
			border = surface
		"present":
			surface = _semantic_color("present", DesignTokens.GOLD_PRESENT)
			border = surface
		"absent":
			surface = DesignTokens.DARK_SURFACE_RAISED
			border = DesignTokens.DARK_SURFACE_RAISED
		"current":
			surface = DesignTokens.DARK_SURFACE_RAISED
			border = DesignTokens.DARK_MUTED_TEXT
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
