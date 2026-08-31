class_name GameScreen
extends Control


signal letter_typed(letter: String)
signal erase_requested
signal submit_requested
signal mode_selected(mode: int)
signal board_selected(index: int)


const BOARD_VIEW_SCENE := preload("res://features/gameplay/board_view.tscn")
const MODES := [1, 2, 4, 8]
const BOARD_GAP := 12
const MINIMUM_BOARD_WIDTH := 280


var board_columns: int = 1

@onready var _board_center: CenterContainer = $Layout/BoardsScroll/BoardCenter
@onready var _boards_grid: GridContainer = $Layout/BoardsScroll/BoardCenter/BoardsGrid
@onready var _boards_scroll: ScrollContainer = $Layout/BoardsScroll


func _ready() -> void:
	set_process_unhandled_key_input(true)
	for mode in MODES:
		_mode_button(mode).pressed.connect(mode_selected.emit.bind(mode))
	resized.connect(_on_resized)


func render(session: GameSession, active_mode: int, reduced_motion: bool = false) -> void:
	if session == null or not MODES.has(active_mode):
		return
	_ensure_board_views(session.boards.size())
	for mode in MODES:
		_mode_button(mode).button_pressed = mode == active_mode
	for index in range(session.boards.size()):
		var board_view := _boards_grid.get_child(index) as BoardView
		board_view.set_reduced_motion(reduced_motion)
		board_view.render(session.boards[index], session, index)
	layout_for_width(size.x if size.x > 0.0 else 1440.0)


func layout_for_width(viewport_width: float) -> void:
	var safe_width := maxf(viewport_width, float(MINIMUM_BOARD_WIDTH))
	var capacity := maxi(1, floori((safe_width + BOARD_GAP) / (MINIMUM_BOARD_WIDTH + BOARD_GAP)))
	var board_count := _boards_grid.get_child_count()
	board_columns = _preferred_columns(board_count, capacity)
	_boards_grid.columns = board_columns
	_board_center.custom_minimum_size.x = maxf(viewport_width, float(MINIMUM_BOARD_WIDTH))
	_boards_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
		if viewport_width < MINIMUM_BOARD_WIDTH
		else ScrollContainer.SCROLL_MODE_DISABLED
	)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed:
		return
	if key_event.keycode == KEY_BACKSPACE or key_event.physical_keycode == KEY_BACKSPACE:
		erase_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_ENTER or key_event.physical_keycode == KEY_ENTER:
		submit_requested.emit()
		get_viewport().set_input_as_handled()
		return
	var letter := InputMapper.map_event(key_event)
	if letter.is_empty():
		return
	letter_typed.emit(letter)
	get_viewport().set_input_as_handled()


func _ensure_board_views(count: int) -> void:
	if _boards_grid.get_child_count() == count:
		return
	for child in _boards_grid.get_children():
		_boards_grid.remove_child(child)
		child.free()
	for index in range(count):
		var board_view := BOARD_VIEW_SCENE.instantiate() as BoardView
		board_view.name = "Board%d" % index
		board_view.gui_input.connect(_on_board_gui_input.bind(index))
		_boards_grid.add_child(board_view)


func _preferred_columns(board_count: int, capacity: int) -> int:
	if board_count <= 2:
		return mini(board_count, capacity)
	if board_count == 4:
		if capacity >= 4:
			return 4
		return 2 if capacity >= 2 else 1
	if board_count == 8:
		if capacity >= 8:
			return 8
		if capacity >= 4:
			return 4
		return 2 if capacity >= 2 else 1
	return maxi(1, mini(board_count, capacity))


func _mode_button(mode: int) -> Button:
	return get_node("Layout/ModeBar/Mode%d" % mode) as Button


func _on_board_gui_input(event: InputEvent, index: int) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		board_selected.emit(index)


func _on_resized() -> void:
	if _boards_grid != null:
		layout_for_width(size.x)
