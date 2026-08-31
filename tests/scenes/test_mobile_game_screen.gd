extends GutTest


const GAME_SCENE_PATH := "res://features/gameplay/game_screen.tscn"
const FakePlatformCapabilities = preload("res://tests/doubles/fake_platform_capabilities.gd")


func test_mobile_four_and_eight_modes_show_one_focus_board_and_full_navigator() -> void:
	for mode in [4, 8]:
		var screen := _mobile_screen(Vector2(390, 844))
		if screen == null:
			return
		var session := GameSession.create(_answers(mode))
		screen.render(session, mode)
		await get_tree().process_frame

		var boards: GridContainer = screen.get_node("Layout/BoardsScroll/BoardCenter/BoardsGrid")
		assert_eq(_visible_child_count(boards), 1)
		assert_eq(screen.selected_board_index, 0)
		var navigator: HBoxContainer = screen.get_node("Layout/Navigator")
		assert_true(navigator.visible)
		assert_eq(navigator.get_child_count(), mode)
		assert_eq(navigator.get_child(0).get_meta("navigator_state"), "unfinished")
		assert_true(navigator.get_child(0).get_meta("selected"))


func test_navigator_reports_solved_unfinished_failed_and_allows_explicit_review() -> void:
	var screen := _mobile_screen(Vector2(390, 844))
	if screen == null:
		return
	var session := GameSession.create(_answers(4))
	_submit(session, "ААААА", _answers(4))
	screen.render(session, 4)

	var navigator: HBoxContainer = screen.get_node("Layout/Navigator")
	assert_eq(navigator.get_child(0).get_meta("navigator_state"), "solved")
	assert_eq(navigator.get_child(1).get_meta("navigator_state"), "unfinished")
	navigator.get_child(0).pressed.emit()
	assert_eq(screen.selected_board_index, 0)
	assert_true(screen.get_node("Layout/BoardsScroll/BoardCenter/BoardsGrid/Board0").visible)

	for board in session.boards:
		board.is_solved = false
	session.status = GameSession.Status.LOST
	screen.render(session, 4)
	assert_eq(navigator.get_child(1).get_meta("navigator_state"), "failed")


func test_horizontal_touch_swipe_skips_solved_boards_but_vertical_drag_does_not_navigate() -> void:
	var screen := _mobile_screen(Vector2(390, 844))
	if screen == null:
		return
	var session := GameSession.create(_answers(4))
	_submit(session, "БББББ", _answers(4))
	screen.render(session, 4)
	assert_true(session.boards[1].is_solved)

	screen.select_board(0)
	_touch(screen, Vector2(300, 100), true)
	_touch(screen, Vector2(250, 220), false)
	assert_eq(screen.selected_board_index, 0)

	_touch(screen, Vector2(300, 100), true)
	_touch(screen, Vector2(200, 105), false)
	assert_eq(screen.selected_board_index, 2)

	_touch(screen, Vector2(100, 100), true)
	_touch(screen, Vector2(200, 105), false)
	assert_eq(screen.selected_board_index, 0)


func test_selection_clamps_when_rendered_board_count_changes() -> void:
	var screen := _mobile_screen(Vector2(412, 915))
	if screen == null:
		return
	screen.render(GameSession.create(_answers(8)), 8)
	screen.select_board(7)
	screen.render(GameSession.create(_answers(4)), 4)
	assert_eq(screen.selected_board_index, 3)
	assert_eq(_visible_child_count(screen.get_node("Layout/BoardsScroll/BoardCenter/BoardsGrid")), 1)


func test_required_mobile_viewports_keep_focus_cells_readable_and_keyboard_outside_board_viewport() -> void:
	for viewport_size in [Vector2(390, 844), Vector2(412, 915), Vector2(844, 390)]:
		var screen := _mobile_screen(viewport_size)
		if screen == null:
			return
		screen.render(GameSession.create(_answers(8)), 8)
		await get_tree().process_frame

		var board: Control = screen.get_node("Layout/BoardsScroll/BoardCenter/BoardsGrid/Board0")
		var scroll: ScrollContainer = screen.get_node("Layout/BoardsScroll")
		var keyboard: Control = screen.get_node("Layout/KeyboardView")
		assert_true(board.visible, str(viewport_size))
		assert_lte(board.size.x, viewport_size.x, str(viewport_size))
		assert_gte(board.size.x, 280.0, str(viewport_size))
		assert_lte(scroll.position.y + scroll.size.y, keyboard.position.y + 0.5, str(viewport_size))
		for cell in board.get_node("Content/Cells").get_children():
			assert_gte(cell.size.x, 48.0, str(viewport_size))
			assert_gte(cell.size.y, 48.0, str(viewport_size))
			assert_lte(cell.position.x + cell.size.x, board.size.x, str(viewport_size))

		keyboard.set_collapsed(false)
		await get_tree().create_timer(KeyboardView.COLLAPSE_TWEEN_SECONDS + 0.05).timeout
		assert_gte(scroll.size.y, 48.0, "compose %s" % viewport_size)
		assert_lte(
			scroll.position.y + scroll.size.y,
			keyboard.position.y + 0.5,
			"compose %s" % viewport_size,
		)


func test_landscape_compose_state_keeps_one_active_cell_row_above_keyboard() -> void:
	var screen := _mobile_screen(Vector2(844, 390))
	if screen == null:
		return
	screen.render(GameSession.create(_answers(8)), 8)
	var keyboard: KeyboardView = screen.get_node("Layout/KeyboardView")
	keyboard.set_collapsed(false)
	await get_tree().create_timer(KeyboardView.COLLAPSE_TWEEN_SECONDS + 0.05).timeout

	var scroll: ScrollContainer = screen.get_node("Layout/BoardsScroll")
	assert_gte(scroll.size.y, 48.0)
	assert_lte(scroll.position.y + scroll.size.y, keyboard.position.y + 0.5)


func test_desktop_layout_has_no_keyboard_while_android_app_root_uses_mobile_scene() -> void:
	var desktop := _screen(Vector2(1440, 900))
	if desktop == null:
		return
	desktop.set_mobile_layout(false)
	desktop.render(GameSession.create(_answers(4)), 4)
	assert_false(desktop.get_node("Layout").has_node("KeyboardView"))
	assert_false(desktop.get_node("Layout/Navigator").visible)
	assert_eq(_visible_child_count(desktop.get_node("Layout/BoardsScroll/BoardCenter/BoardsGrid")), 4)

	var root: Control = load("res://app/app_root.tscn").instantiate()
	root.save_repository_override = MemorySaveRepository.new()
	root.platform_capabilities_override = FakePlatformCapabilities.new("Android", false)
	add_child_autofree(root)
	root.current_screen.get_node("Center/Content/ModeCards/Mode4").pressed.emit()
	await get_tree().process_frame
	assert_true(root.current_screen.mobile_layout)
	assert_true(root.current_screen.get_node("Layout/KeyboardView").visible)


func test_narrow_touch_web_reclassifies_layout_after_orientation_change() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(390, 844)
	add_child_autofree(viewport)
	var root: Control = load("res://app/app_root.tscn").instantiate()
	root.save_repository_override = MemorySaveRepository.new()
	root.platform_capabilities_override = FakePlatformCapabilities.new("Web", true)
	viewport.add_child(root)
	root.current_screen.get_node("Center/Content/ModeCards/Mode4").pressed.emit()
	await get_tree().process_frame
	assert_true(root.current_screen.mobile_layout)

	viewport.size = Vector2i(844, 390)
	await get_tree().process_frame
	assert_false(root.current_screen.mobile_layout)
	assert_false(root.current_screen.get_node("Layout").has_node("KeyboardView"))


func test_android_rotation_reveals_progressed_active_row_after_viewport_shrinks() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(390, 844)
	add_child_autofree(viewport)
	var root: Control = load("res://app/app_root.tscn").instantiate()
	root.save_repository_override = MemorySaveRepository.new()
	root.platform_capabilities_override = FakePlatformCapabilities.new("Android", false)
	viewport.add_child(root)
	var session := _progressed_session()
	root.coordinator.bundle.sessions[8] = session
	root.current_screen.get_node("Center/Content/ModeCards/Mode8").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var screen: GameScreen = root.current_screen
	assert_true(_active_row_is_visible(screen, session), "portrait setup")

	viewport.size = Vector2i(844, 390)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(_active_row_is_visible(screen, session), "landscape after rotation")


func _mobile_screen(viewport_size: Vector2) -> Control:
	var screen := _screen(viewport_size)
	if screen != null:
		screen.set_mobile_layout(true)
	return screen


func _screen(viewport_size: Vector2) -> Control:
	var scene: PackedScene = load(GAME_SCENE_PATH)
	assert_not_null(scene)
	if scene == null:
		return null
	var viewport := SubViewport.new()
	viewport.size = Vector2i(viewport_size)
	add_child_autofree(viewport)
	var screen: Control = scene.instantiate()
	viewport.add_child(screen)
	return screen


func _touch(screen: Control, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = pressed
	screen._on_focus_gui_input(event)


func _visible_child_count(parent: Node) -> int:
	var count := 0
	for child in parent.get_children():
		if child.visible:
			count += 1
	return count


func _submit(session: GameSession, guess: String, entries: PackedStringArray) -> void:
	var pool := WordPool.from_entries(entries)
	for letter in guess:
		session.type_letter(letter, pool)
	assert_true(session.submit(pool))


func _progressed_session() -> GameSession:
	var answers := _answers(8)
	var guesses := PackedStringArray([
		"ЗЗЗЗЗ", "ИИИИИ", "ЈЈЈЈЈ", "ККККК",
		"ЛЛЛЛЛ", "ЉЉЉЉЉ", "МММММ", "ННННН",
	])
	var entries := answers.duplicate()
	entries.append_array(guesses)
	var session := GameSession.create(answers)
	for guess in guesses:
		_submit(session, guess, entries)
	return session


func _active_row_is_visible(screen: GameScreen, session: GameSession) -> bool:
	var scroll: ScrollContainer = screen.get_node("Layout/BoardsScroll")
	var cell: Control = screen.get_node(
		"Layout/BoardsScroll/BoardCenter/BoardsGrid/Board%d/Content/Cells/Cell_%d_0"
		% [screen.selected_board_index, session.attempt_index]
	)
	var scroll_rect := scroll.get_global_rect()
	var cell_rect := cell.get_global_rect()
	return (
		cell_rect.position.y >= scroll_rect.position.y - 0.5
		and cell_rect.end.y <= scroll_rect.end.y + 0.5
	)


func _answers(count: int) -> PackedStringArray:
	return PackedStringArray([
		"ААААА", "БББББ", "ВВВВВ", "ГГГГГ",
		"ДДДДД", "ЂЂЂЂЂ", "ЕЕЕЕЕ", "ЖЖЖЖЖ",
	]).slice(0, count)
