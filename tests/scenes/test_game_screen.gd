extends GutTest


const GAME_SCENE_PATH := "res://features/gameplay/game_screen.tscn"
const GAME_SCRIPT_PATH := "res://features/gameplay/game_screen.gd"


func test_wide_layout_centers_small_modes_and_reflows_large_modes_at_readable_size() -> void:
	var screen: Control = _instantiate_game_screen()
	if screen == null:
		return

	for mode in [1, 2]:
		var session := GameSession.create(_answers(mode))
		screen.render(session, mode)
		screen.layout_for_width(1440.0)
		assert_true(screen.get_node("Layout/BoardsScroll/BoardCenter") is CenterContainer)
		assert_eq(screen.board_columns, mode)

	var four_session := GameSession.create(_answers(4))
	screen.render(four_session, 4)
	screen.layout_for_width(1440.0)
	assert_eq(screen.board_columns, 4)
	screen.layout_for_width(1024.0)
	assert_eq(screen.board_columns, 2)

	var eight_session := GameSession.create(_answers(8))
	screen.render(eight_session, 8)
	screen.layout_for_width(1440.0)
	assert_eq(screen.board_columns, 4)
	screen.layout_for_width(1024.0)
	assert_eq(screen.board_columns, 2)
	screen.layout_for_width(2600.0)
	assert_eq(screen.board_columns, 8)
	assert_ne(
		screen.get_node("Layout/BoardsScroll").vertical_scroll_mode,
		ScrollContainer.SCROLL_MODE_DISABLED,
	)

	for board in screen.get_node("Layout/BoardsScroll/BoardCenter/BoardsGrid").get_children():
		for cell in board.get_node("Content/Cells").get_children():
			assert_gte(cell.custom_minimum_size.x, 48.0)
			assert_gte(cell.get_node("Glyph").get_theme_font_size("font_size"), 16)


func test_game_screen_emits_typed_intents_and_direct_input_does_not_mutate_rendered_state() -> void:
	var screen: Control = _instantiate_game_screen()
	if screen == null:
		return
	var session := GameSession.create(PackedStringArray(["ЖИВОТ"]))
	screen.render(session, 1)
	watch_signals(screen)

	var letter_event := _key_event(KEY_A, "a")
	screen._unhandled_key_input(letter_event)
	assert_signal_emitted_with_parameters(screen, "letter_typed", ["А"])
	assert_eq(_first_cell(screen).text, "")
	assert_true(screen.get_viewport().is_input_handled())

	screen._unhandled_key_input(_key_event(KEY_BACKSPACE))
	screen._unhandled_key_input(_key_event(KEY_ENTER))
	assert_signal_emitted(screen, "erase_requested")
	assert_signal_emitted(screen, "submit_requested")

	screen.get_node("Layout/ModeBar/Mode8").pressed.emit()
	assert_signal_emitted_with_parameters(screen, "mode_selected", [8])

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var first_board: Control = screen.get_node("Layout/BoardsScroll/BoardCenter/BoardsGrid").get_child(0)
	first_board.gui_input.emit(click)
	assert_signal_emitted_with_parameters(screen, "board_selected", [0])


func test_game_screen_has_no_text_field_or_permanent_keyboard() -> void:
	var screen: Control = _instantiate_game_screen()
	if screen == null:
		return

	assert_false(_tree_contains_type(screen, "LineEdit"))
	assert_false(_tree_contains_name(screen, "KeyboardView"))


func test_desktop_onscreen_keyboard_preserves_wide_eight_board_layout() -> void:
	var screen: Control = _instantiate_game_screen()
	if screen == null:
		return
	var session := GameSession.create(_answers(8))
	screen.render(session, 8)
	screen.set_mobile_layout(false)
	screen.set_onscreen_keyboard(true)
	screen.layout_for_width(1440.0)

	assert_false(screen.mobile_layout)
	assert_true(screen.get_node("Layout").has_node("KeyboardView"))
	assert_false(screen.get_node("Layout/Navigator").visible)
	assert_eq(screen.board_columns, 4)
	var visible_boards := 0
	for board in screen.get_node("Layout/BoardsScroll/BoardCenter/BoardsGrid").get_children():
		if board.visible:
			visible_boards += 1
	assert_eq(visible_boards, 8)


func test_app_root_routes_home_to_game_and_wires_coordinator_state_changes() -> void:
	var root: Control = load("res://app/app_root.tscn").instantiate()
	root.save_repository_override = MemorySaveRepository.new()
	add_child_autofree(root)
	root.current_screen.get_node("Center/Content/ModeCards/Mode1").pressed.emit()
	await get_tree().process_frame

	assert_eq(root.current_screen.get_script().resource_path, GAME_SCRIPT_PATH)
	var screen: Control = root.current_screen
	var first_cell: Label = _first_cell(screen)
	assert_eq(first_cell.text, "")

	for letter in "БББББ":
		screen.letter_typed.emit(letter)
	assert_true(root.coordinator.active_session().input_is_invalid)
	assert_eq(_cell_panel(screen, 0, 0).get_meta("render_state"), "invalid")

	screen.erase_requested.emit()
	assert_false(root.coordinator.active_session().input_is_invalid)
	assert_eq(_cell_panel(screen, 0, 0).get_meta("render_state"), "current")
	for _index in range(4):
		screen.erase_requested.emit()
	for letter in "АВАЛА":
		screen.letter_typed.emit(letter)
	assert_false(root.coordinator.active_session().input_is_invalid)
	assert_eq(_cell_panel(screen, 0, 0).get_meta("render_state"), "current")

	screen.submit_requested.emit()
	assert_eq(root.coordinator.active_session().attempt_index, 1)
	assert_eq(root.coordinator.active_session().current_input, "")

	screen.mode_selected.emit(8)
	assert_eq(root.coordinator.active_mode, 8)
	assert_eq(screen.get_node("Layout/BoardsScroll/BoardCenter/BoardsGrid").get_child_count(), 8)
	screen.letter_typed.emit("А")
	screen.mode_selected.emit(1)
	assert_eq(root.coordinator.active_session().attempt_index, 1)
	screen.mode_selected.emit(8)
	assert_eq(root.coordinator.active_session().current_input, "А")
	assert_eq(_first_cell(screen).text, "А")


func _instantiate_game_screen() -> Control:
	var scene: PackedScene = load(GAME_SCENE_PATH)
	assert_not_null(scene)
	if scene == null:
		return null
	var screen := scene.instantiate()
	add_child_autofree(screen)
	return screen


func _first_cell(screen: Node) -> Label:
	return _cell_panel(screen, 0, 0).get_node("Glyph") as Label


func _cell_panel(screen: Node, row: int, column: int) -> PanelContainer:
	return screen.get_node(
		"Layout/BoardsScroll/BoardCenter/BoardsGrid/Board0/Content/Cells/Cell_%d_%d"
		% [row, column]
	) as PanelContainer


func _answers(count: int) -> PackedStringArray:
	return PackedStringArray([
		"ААААА", "БББББ", "ВВВВВ", "ГГГГГ",
		"ДДДДД", "ЂЂЂЂЂ", "ЕЕЕЕЕ", "ЖЖЖЖЖ",
	]).slice(0, count)


func _key_event(keycode: Key, unicode_text: String = "") -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	if not unicode_text.is_empty():
		event.unicode = unicode_text.unicode_at(0)
	return event


func _tree_contains_type(node: Node, type_name: String) -> bool:
	if node.is_class(type_name):
		return true
	for child in node.get_children():
		if _tree_contains_type(child, type_name):
			return true
	return false


func _tree_contains_name(node: Node, node_name: String) -> bool:
	if node.name == node_name:
		return true
	for child in node.get_children():
		if _tree_contains_name(child, node_name):
			return true
	return false
