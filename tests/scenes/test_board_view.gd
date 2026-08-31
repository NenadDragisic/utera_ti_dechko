extends GutTest


const BOARD_SCENE_PATH := "res://features/gameplay/board_view.tscn"


func test_render_builds_one_fixed_five_cell_row_per_attempt_without_node_churn() -> void:
	var view: Control = _instantiate_board_view()
	if view == null:
		return
	var session := GameSession.create(PackedStringArray(["ЖИВОТ"]))

	view.render(session.boards[0], session)
	var cells_before: Array[Node] = _cells(view)
	var ids_before: Array[int] = []
	for cell in cells_before:
		ids_before.append(cell.get_instance_id())

	session.current_input = "ЖИ"
	view.render(session.boards[0], session)
	var cells_after: Array[Node] = _cells(view)
	var ids_after: Array[int] = []
	for cell in cells_after:
		ids_after.append(cell.get_instance_id())

	assert_eq(cells_after.size(), session.attempt_limit * 5)
	assert_eq(ids_after, ids_before)
	for row in range(session.attempt_limit):
		assert_eq(_row_cells(view, row).size(), 5)
	assert_eq(_glyph(view, 0, 0).text, "Ж")
	assert_eq(_glyph(view, 0, 1).text, "И")
	assert_eq(_glyph(view, 0, 2).text, "")


func test_evaluated_marks_use_absent_present_and_correct_semantic_styles() -> void:
	var view: Control = _instantiate_board_view()
	if view == null:
		return
	var pool := WordPool.from_entries(PackedStringArray(["АВАЛА", "ЛАААА"]))
	var session := GameSession.create(PackedStringArray(["АВАЛА"]))
	_type_word(session, "ЛАААА", pool)
	assert_true(session.submit(pool))

	view.render(session.boards[0], session)

	assert_eq(_cell(view, 0, 0).get_meta("render_state"), "present")
	assert_eq(_cell(view, 0, 2).get_meta("render_state"), "correct")
	assert_eq(_cell(view, 0, 3).get_meta("render_state"), "absent")
	assert_eq(_cell_style(view, 0, 0).bg_color, DesignTokens.GOLD_PRESENT)
	assert_eq(_cell_style(view, 0, 2).bg_color, DesignTokens.MINT_SUCCESS)
	assert_eq(_cell_style(view, 0, 3).bg_color, DesignTokens.DARK_SURFACE_RAISED)


func test_invalid_current_row_is_red_only_on_unsolved_boards_and_erase_clears_it() -> void:
	var first: Control = _instantiate_board_view()
	var second: Control = _instantiate_board_view()
	if first == null or second == null:
		return
	var pool := WordPool.from_entries(PackedStringArray(["ЖИВОТ", "АВАЛА"]))
	var session := GameSession.create(PackedStringArray(["ЖИВОТ", "АВАЛА"]))
	_type_word(session, "ЖИВОТ", pool)
	assert_true(session.submit(pool))
	_type_word(session, "БББББ", pool)
	assert_true(session.input_is_invalid)

	first.render(session.boards[0], session)
	second.render(session.boards[1], session)

	for column in range(5):
		assert_eq(_glyph(first, 1, column).text, "")
		assert_ne(_cell(first, 1, column).get_meta("render_state"), "invalid")
		assert_eq(_glyph(second, 1, column).text, "Б")
		assert_eq(_cell(second, 1, column).get_meta("render_state"), "invalid")
		assert_eq(_cell_style(second, 1, column).border_color, DesignTokens.RED_INVALID)
		assert_gt(_cell_style(second, 1, column).bg_color.r, DesignTokens.DARK_SURFACE_RAISED.r)

	assert_true(session.erase_letter())
	second.render(session.boards[1], session)
	for column in range(4):
		assert_eq(_cell(second, 1, column).get_meta("render_state"), "current")
		assert_ne(_cell_style(second, 1, column).border_color, DesignTokens.RED_INVALID)


func test_valid_five_letter_current_row_stays_neutral() -> void:
	var view: Control = _instantiate_board_view()
	if view == null:
		return
	var pool := WordPool.from_entries(PackedStringArray(["ЖИВОТ", "АВАЛА"]))
	var session := GameSession.create(PackedStringArray(["ЖИВОТ"]))
	_type_word(session, "АВАЛА", pool)
	assert_false(session.input_is_invalid)

	view.render(session.boards[0], session)

	for column in range(5):
		assert_eq(_cell(view, 0, column).get_meta("render_state"), "current")
		assert_ne(_cell_style(view, 0, column).border_color, DesignTokens.RED_INVALID)


func test_active_board_never_displays_its_answer_outside_submitted_rows() -> void:
	var view: Control = _instantiate_board_view()
	if view == null:
		return
	var pool := WordPool.from_entries(PackedStringArray(["ЖИВОТ", "АВАЛА"]))
	var session := GameSession.create(PackedStringArray(["ЖИВОТ"]))
	_type_word(session, "АВАЛА", pool)
	assert_true(session.submit(pool))

	view.render(session.boards[0], session)

	assert_false(_collect_text(view).contains("ЖИВОТ"))
	assert_eq(_row_text(view, 0), "АВАЛА")


func test_animation_hooks_are_reduced_motion_aware_and_disabled_for_now() -> void:
	var view: Control = _instantiate_board_view()
	if view == null:
		return

	view.set_reduced_motion(false)
	assert_false(view.flip_animation_enabled)
	assert_false(view.shake_animation_enabled)
	view.set_reduced_motion(true)
	assert_true(view.reduced_motion)
	assert_false(view.flip_animation_enabled)
	assert_false(view.shake_animation_enabled)


func _instantiate_board_view() -> Control:
	var scene: PackedScene = load(BOARD_SCENE_PATH)
	assert_not_null(scene)
	if scene == null:
		return null
	var view := scene.instantiate()
	add_child_autofree(view)
	return view


func _cells(view: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in view.get_node("Content/Cells").get_children():
		result.append(child)
	return result


func _row_cells(view: Node, row: int) -> Array[Node]:
	var result: Array[Node] = []
	for column in range(5):
		result.append(_cell(view, row, column))
	return result


func _cell(view: Node, row: int, column: int) -> PanelContainer:
	return view.get_node("Content/Cells/Cell_%d_%d" % [row, column]) as PanelContainer


func _glyph(view: Node, row: int, column: int) -> Label:
	return _cell(view, row, column).get_node("Glyph") as Label


func _cell_style(view: Node, row: int, column: int) -> StyleBoxFlat:
	return _cell(view, row, column).get_theme_stylebox("panel") as StyleBoxFlat


func _row_text(view: Node, row: int) -> String:
	var result := ""
	for column in range(5):
		result += _glyph(view, row, column).text
	return result


func _collect_text(node: Node) -> String:
	var result := ""
	if node is Label or node is Button:
		result += str(node.text)
	for child in node.get_children():
		result += _collect_text(child)
	return result


func _type_word(session: GameSession, word: String, pool: WordPool) -> void:
	for letter in word:
		assert_true(session.type_letter(letter, pool))
