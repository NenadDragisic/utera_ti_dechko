class_name GameScreen
extends Control


signal letter_typed(letter: String)
signal erase_requested
signal submit_requested
signal mode_selected(mode: int)
signal board_selected(index: int)


const BOARD_VIEW_SCENE := preload("res://features/gameplay/board_view.tscn")
const KEYBOARD_VIEW_SCENE := preload("res://features/gameplay/keyboard_view.tscn")
const MODES := [1, 2, 4, 8]
const BOARD_GAP := 12
const MINIMUM_BOARD_WIDTH := 280
const SWIPE_THRESHOLD := 48.0


var board_columns: int = 1
var selected_board_index: int = 0
var mobile_layout: bool = false

var _session: GameSession
var _reduced_motion: bool = false
var _keyboard_view: KeyboardView
var _touch_start := Vector2.ZERO
var _tracked_touch_index: int = -1
var _active_row_reveal_queued: bool = false

@onready var _board_center: CenterContainer = $Layout/BoardsScroll/BoardCenter
@onready var _boards_grid: GridContainer = $Layout/BoardsScroll/BoardCenter/BoardsGrid
@onready var _boards_scroll: ScrollContainer = $Layout/BoardsScroll
@onready var _navigator: HBoxContainer = $Layout/Navigator


func _ready() -> void:
	set_process_unhandled_key_input(true)
	for mode in MODES:
		_mode_button(mode).pressed.connect(mode_selected.emit.bind(mode))
	_boards_scroll.gui_input.connect(_on_focus_gui_input)
	_boards_scroll.resized.connect(_on_board_viewport_resized)
	resized.connect(_on_resized)


func render(session: GameSession, active_mode: int, reduced_motion: bool = false) -> void:
	if session == null or not MODES.has(active_mode):
		return
	_session = session
	_reduced_motion = reduced_motion
	_ensure_board_views(session.boards.size())
	selected_board_index = clampi(selected_board_index, 0, maxi(0, session.boards.size() - 1))
	for mode in MODES:
		_mode_button(mode).button_pressed = mode == active_mode
	for index in range(session.boards.size()):
		var board_view := _boards_grid.get_child(index) as BoardView
		board_view.set_reduced_motion(reduced_motion)
		board_view.render(session.boards[index], session, index)
	if _keyboard_view != null:
		_keyboard_view.set_reduced_motion(reduced_motion)
		_keyboard_view.render(session)
	_refresh_mobile_presentation()
	layout_for_width(size.x if size.x > 0.0 else 1440.0)
	if mobile_layout:
		call_deferred("_reveal_active_row")


func set_mobile_layout(value: bool) -> void:
	if mobile_layout == value and (_keyboard_view != null) == value:
		return
	mobile_layout = value
	if mobile_layout:
		if _keyboard_view == null:
			_keyboard_view = KEYBOARD_VIEW_SCENE.instantiate() as KeyboardView
			_keyboard_view.name = "KeyboardView"
			_keyboard_view.set_reduced_motion(_reduced_motion)
			_keyboard_view.set_collapsed(true)
			_keyboard_view.letter_pressed.connect(letter_typed.emit)
			_keyboard_view.erase_pressed.connect(erase_requested.emit)
			_keyboard_view.submit_pressed.connect(submit_requested.emit)
			_keyboard_view.collapsed_changed.connect(_on_keyboard_collapsed_changed)
			$Layout.add_child(_keyboard_view)
			if _session != null:
				_keyboard_view.render(_session)
	else:
		if _keyboard_view != null:
			$Layout.remove_child(_keyboard_view)
			_keyboard_view.free()
			_keyboard_view = null
	_refresh_mobile_presentation()
	layout_for_width(size.x if size.x > 0.0 else 1440.0)


func select_board(index: int) -> void:
	if _session == null or _session.boards.is_empty():
		return
	var clamped := clampi(index, 0, _session.boards.size() - 1)
	selected_board_index = clamped
	_refresh_mobile_presentation()
	board_selected.emit(selected_board_index)
	call_deferred("_reveal_active_row")


func layout_for_width(viewport_width: float) -> void:
	var safe_width := maxf(viewport_width, float(MINIMUM_BOARD_WIDTH))
	var capacity := maxi(1, floori((safe_width + BOARD_GAP) / (MINIMUM_BOARD_WIDTH + BOARD_GAP)))
	var board_count := _boards_grid.get_child_count()
	board_columns = 1 if mobile_layout else maxi(1, _preferred_columns(board_count, capacity))
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


func _ensure_navigator(count: int) -> void:
	if _navigator.get_child_count() == count:
		return
	for child in _navigator.get_children():
		_navigator.remove_child(child)
		child.free()
	for index in range(count):
		var button := Button.new()
		button.name = "Board%d" % index
		button.custom_minimum_size = Vector2(44, 44)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(select_board.bind(index))
		_navigator.add_child(button)


func _refresh_mobile_presentation() -> void:
	_navigator.visible = mobile_layout and _session != null and _session.boards.size() >= 4
	if _session == null:
		return
	for index in range(_boards_grid.get_child_count()):
		_boards_grid.get_child(index).visible = not mobile_layout or index == selected_board_index
	if not mobile_layout:
		return
	_ensure_navigator(_session.boards.size())
	for index in range(_navigator.get_child_count()):
		var button := _navigator.get_child(index) as Button
		var board: BoardState = _session.boards[index]
		var state := "unfinished"
		if board.is_solved:
			state = "solved"
		elif _session.status == GameSession.Status.LOST:
			state = "failed"
		button.text = "✓" if state == "solved" else str(index + 1)
		button.set_meta("navigator_state", state)
		button.set_meta("selected", index == selected_board_index)
		button.tooltip_text = "РЕЧ %d · %s" % [index + 1, _navigator_state_label(state)]
		button.modulate = _navigator_color(state, index == selected_board_index)


func _navigator_color(state: String, selected: bool) -> Color:
	if selected:
		return DesignTokens.MINT_ACTION
	match state:
		"solved":
			return DesignTokens.MINT_SUCCESS
		"failed":
			return DesignTokens.RED_INVALID
		_:
			return Color.WHITE


func _navigator_state_label(state: String) -> String:
	match state:
		"solved":
			return "решена"
		"failed":
			return "неуспешна"
		_:
			return "у току"


func _navigate_focus(direction: int) -> void:
	if _session == null or _session.boards.size() < 2:
		return
	var count := _session.boards.size()
	var has_unsolved := false
	for board in _session.boards:
		if not board.is_solved:
			has_unsolved = true
			break
	for offset in range(1, count + 1):
		var candidate := posmod(selected_board_index + direction * offset, count)
		if not has_unsolved or not _session.boards[candidate].is_solved:
			select_board(candidate)
			return


func _on_focus_gui_input(event: InputEvent) -> void:
	if not mobile_layout or not event is InputEventScreenTouch:
		return
	var touch := event as InputEventScreenTouch
	if touch.pressed:
		if _tracked_touch_index == -1:
			_tracked_touch_index = touch.index
			_touch_start = touch.position
		return
	if touch.index != _tracked_touch_index:
		return
	_tracked_touch_index = -1
	var travel := touch.position - _touch_start
	if absf(travel.x) <= SWIPE_THRESHOLD or absf(travel.x) <= absf(travel.y):
		return
	_navigate_focus(1 if travel.x < 0.0 else -1)


func _reveal_active_row() -> void:
	if not mobile_layout or _session == null or _boards_grid.get_child_count() == 0:
		return
	var board := _boards_grid.get_child(selected_board_index) as BoardView
	var row := mini(_session.attempt_index, _session.attempt_limit - 1)
	var cell := board.get_node("Content/Cells/Cell_%d_0" % row) as Control
	_boards_scroll.ensure_control_visible(cell)


func _on_keyboard_collapsed_changed(_collapsed: bool) -> void:
	call_deferred("_reveal_active_row")


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
		select_board(index)


func _on_resized() -> void:
	if _boards_grid != null:
		layout_for_width(size.x)


func _on_board_viewport_resized() -> void:
	if not mobile_layout or _active_row_reveal_queued:
		return
	_active_row_reveal_queued = true
	get_tree().process_frame.connect(_reveal_active_row_after_layout, CONNECT_ONE_SHOT)


func _reveal_active_row_after_layout() -> void:
	_active_row_reveal_queued = false
	_reveal_active_row()
