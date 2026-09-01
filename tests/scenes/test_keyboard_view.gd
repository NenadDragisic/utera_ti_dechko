extends GutTest


const KEYBOARD_SCENE_PATH := "res://features/gameplay/keyboard_view.tscn"


func test_keyboard_has_every_serbian_letter_once_and_accessible_actions() -> void:
	var keyboard := _keyboard()
	if keyboard == null:
		return

	var letters := ""
	var letter_buttons := keyboard.get_tree().get_nodes_in_group("keyboard_letters")
	assert_eq(letter_buttons.size(), WordPool.ALPHABET.length())
	for button in letter_buttons:
		letters += button.text
		assert_gte(button.custom_minimum_size.x, 44.0)
		assert_gte(button.custom_minimum_size.y, 44.0)
	for letter in WordPool.ALPHABET:
		assert_eq(letters.count(letter), 1, "%s appears exactly once" % letter)

	for path in [
		"SheetContent/Content/Header/Actions/EraseButton",
		"SheetContent/Content/Header/Actions/SubmitButton",
		"ReopenButton",
	]:
		var target: Button = keyboard.get_node(path)
		assert_gte(target.custom_minimum_size.x, 44.0)
		assert_gte(target.custom_minimum_size.y, 44.0)


func test_keyboard_buttons_emit_intents_without_mutating_a_session() -> void:
	var keyboard := _keyboard()
	if keyboard == null:
		return
	var session := GameSession.create(PackedStringArray(["ЖИВОТ"]))
	keyboard.render(session)
	watch_signals(keyboard)

	var first_letter: Button = keyboard.get_tree().get_nodes_in_group("keyboard_letters")[0]
	first_letter.pressed.emit()
	keyboard.get_node("SheetContent/Content/Header/Actions/EraseButton").pressed.emit()

	assert_signal_emitted_with_parameters(keyboard, "letter_pressed", [first_letter.text])
	assert_signal_emitted(keyboard, "erase_pressed")
	assert_eq(session.current_input, "")
	assert_eq(session.attempt_index, 0)


func test_touch_drag_starting_over_a_key_reaches_each_final_key_without_typing() -> void:
	var keyboard := _keyboard()
	if keyboard == null:
		return
	keyboard.size = Vector2(390, 300)
	await get_tree().process_frame
	watch_signals(keyboard)
	var final_letters := ["Ш", "Ч", "М"]

	for row_index in range(3):
		var row: ScrollContainer = keyboard.get_node(
			"SheetContent/Content/Rows/Row%d" % (row_index + 1)
		)
		var keys: HBoxContainer = row.get_node("Keys")
		var first_key := keys.get_child(0) as Button
		var start := Vector2(first_key.position.x + first_key.size.x * 0.5, 22.0)
		_emit_row_touch(row, start, true)
		_emit_row_drag(row, start - Vector2(300.0, 0.0), Vector2(-300.0, 0.0))
		_emit_row_touch(row, start - Vector2(300.0, 0.0), false)
		assert_gt(row.scroll_horizontal, 0, "row %d scrolls" % (row_index + 1))
		assert_signal_emit_count(keyboard, "letter_pressed", row_index)

		var final_key := keys.get_child(keys.get_child_count() - 1) as Button
		var final_position := Vector2(
			final_key.position.x + final_key.size.x * 0.5 - row.scroll_horizontal,
			22.0,
		)
		assert_between(final_position.x, 0.0, row.size.x)
		_emit_row_touch(row, final_position, true)
		_emit_row_touch(row, final_position, false)
		assert_signal_emitted_with_parameters(
			keyboard,
			"letter_pressed",
			[final_letters[row_index]],
		)
		assert_signal_emit_count(keyboard, "letter_pressed", row_index + 1)


func test_collapse_leaves_only_reopen_handle_and_submit_collapses_sheet() -> void:
	var keyboard := _keyboard()
	if keyboard == null:
		return
	watch_signals(keyboard)

	keyboard.set_collapsed(true)
	assert_true(keyboard.collapsed)
	assert_false(keyboard.get_node("SheetContent").visible)
	assert_true(keyboard.get_node("ReopenButton").visible)
	assert_signal_emitted_with_parameters(keyboard, "collapsed_changed", [true])

	keyboard.get_node("ReopenButton").pressed.emit()
	assert_false(keyboard.collapsed)
	assert_true(keyboard.get_node("SheetContent").visible)
	assert_false(keyboard.get_node("ReopenButton").visible)

	var valid := GameSession.create(PackedStringArray(["ЖИВОТ"]))
	valid.current_input = "АВАЛА"
	keyboard.render(valid)
	keyboard.get_node("SheetContent/Content/Header/Actions/SubmitButton").pressed.emit()
	assert_signal_emitted(keyboard, "submit_pressed")
	assert_true(keyboard.collapsed)


func test_submit_is_disabled_for_incomplete_invalid_and_completed_sessions() -> void:
	var keyboard := _keyboard()
	if keyboard == null:
		return
	var submit: Button = keyboard.get_node("SheetContent/Content/Header/Actions/SubmitButton")
	var session := GameSession.create(PackedStringArray(["ЖИВОТ"]))

	keyboard.render(session)
	assert_true(submit.disabled)
	session.current_input = "БББББ"
	session.input_is_invalid = true
	keyboard.render(session)
	assert_true(submit.disabled)
	session.input_is_invalid = false
	keyboard.render(session)
	assert_false(submit.disabled)
	session.status = GameSession.Status.WON
	keyboard.render(session)
	assert_true(submit.disabled)


func test_reduced_motion_suppresses_collapse_tween_hook() -> void:
	var keyboard := _keyboard()
	if keyboard == null:
		return
	keyboard.set_reduced_motion(true)
	keyboard.set_collapsed(true)
	var browse_height: float = keyboard.custom_minimum_size.y
	assert_false(keyboard.collapse_animation_enabled)
	keyboard.set_collapsed(false)
	var compose_height: float = keyboard.custom_minimum_size.y
	assert_gt(compose_height, browse_height)
	keyboard.set_collapsed(true)
	assert_eq(keyboard.custom_minimum_size.y, browse_height)

	keyboard.set_reduced_motion(false)
	keyboard.set_collapsed(false)
	assert_true(keyboard.collapse_animation_enabled)
	assert_eq(keyboard.custom_minimum_size.y, browse_height)
	await get_tree().create_timer(KeyboardView.COLLAPSE_TWEEN_SECONDS + 0.05).timeout
	assert_eq(keyboard.custom_minimum_size.y, compose_height)


func _keyboard() -> Control:
	var scene: PackedScene = load(KEYBOARD_SCENE_PATH)
	assert_not_null(scene)
	if scene == null:
		return null
	var keyboard: Control = scene.instantiate()
	add_child_autofree(keyboard)
	return keyboard


func _emit_row_touch(row: ScrollContainer, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = pressed
	row.gui_input.emit(event)


func _emit_row_drag(row: ScrollContainer, position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = position
	event.relative = relative
	row.gui_input.emit(event)
