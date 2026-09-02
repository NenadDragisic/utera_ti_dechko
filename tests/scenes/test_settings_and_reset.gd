extends GutTest


const SETTINGS_SCENE_PATH := "res://features/settings/settings_view.tscn"
const SETTINGS_SCRIPT_PATH := "res://features/settings/settings_view.gd"
const DIALOG_SCENE_PATH := "res://features/settings/confirm_new_game_dialog.tscn"
const DARK_THEME_PATH := "res://app/app_theme.tres"
const LIGHT_THEME_PATH := "res://app/app_theme_light.tres"


func test_settings_emits_a_fresh_typed_value_without_mutating_rendered_settings() -> void:
	var view := _instantiate_scene(SETTINGS_SCENE_PATH)
	if view == null:
		return
	var original := Settings.new()
	view.render(original)
	var emitted: Array[Settings] = []
	view.settings_changed.connect(func(value: Settings) -> void: emitted.append(value))
	var signal_info := _signal_named(view, "settings_changed")

	assert_eq(signal_info.args.size(), 1)
	assert_eq(signal_info.args[0].class_name, &"Settings")
	var theme_option: OptionButton = view.get_node("Center/Content/ThemeOption")
	assert_eq(theme_option.item_count, 3)
	assert_eq(theme_option.get_item_id(0), Settings.ThemePreference.SYSTEM)
	assert_eq(theme_option.get_item_id(1), Settings.ThemePreference.DARK)
	assert_eq(theme_option.get_item_id(2), Settings.ThemePreference.LIGHT)
	theme_option.select(Settings.ThemePreference.LIGHT)
	theme_option.item_selected.emit(Settings.ThemePreference.LIGHT)

	assert_eq(emitted.size(), 1)
	assert_ne(emitted[0], original)
	assert_eq(emitted[0].theme, Settings.ThemePreference.LIGHT)
	assert_false(emitted[0].reduced_motion)
	assert_false(emitted[0].onscreen_keyboard)
	assert_eq(original.theme, Settings.ThemePreference.SYSTEM)


func test_settings_controls_are_touch_sized_and_emit_all_preferences_together() -> void:
	var view := _instantiate_scene(SETTINGS_SCENE_PATH)
	if view == null:
		return
	var initial := Settings.new()
	initial.theme = Settings.ThemePreference.DARK
	initial.reduced_motion = true
	view.render(initial)
	var emitted: Array[Settings] = []
	view.settings_changed.connect(func(value: Settings) -> void: emitted.append(value))

	for control_name in ["ThemeOption", "ReducedMotion", "OnscreenKeyboard", "HomeButton"]:
		var control: Control = view.get_node("Center/Content/%s" % control_name)
		assert_gte(control.custom_minimum_size.y, 44.0)
	var keyboard: CheckButton = view.get_node("Center/Content/OnscreenKeyboard")
	keyboard.set_pressed_no_signal(true)
	keyboard.toggled.emit(true)

	assert_eq(emitted.size(), 1)
	assert_eq(emitted[0].theme, Settings.ThemePreference.DARK)
	assert_true(emitted[0].reduced_motion)
	assert_true(emitted[0].onscreen_keyboard)


func test_app_root_applies_system_dark_light_reduced_motion_and_keyboard_immediately() -> void:
	var root: Control = load("res://app/app_root.tscn").instantiate()
	var saves := MemorySaveRepository.new()
	root.save_repository_override = saves
	add_child_autofree(root)
	root.current_screen.get_node("Center/Content/Actions/SettingsButton").pressed.emit()
	await get_tree().process_frame
	assert_eq(root.current_screen.get_script().resource_path, SETTINGS_SCRIPT_PATH)
	saves.reset_tracking()
	var option: OptionButton = root.current_screen.get_node("Center/Content/ThemeOption")

	_select_theme(option, Settings.ThemePreference.LIGHT)
	assert_eq(root.theme.resource_path, LIGHT_THEME_PATH)
	_select_theme(option, Settings.ThemePreference.SYSTEM)
	assert_true([DARK_THEME_PATH, LIGHT_THEME_PATH].has(root.theme.resource_path))
	_select_theme(option, Settings.ThemePreference.DARK)
	assert_eq(root.theme.resource_path, DARK_THEME_PATH)
	var reduced: CheckButton = root.current_screen.get_node("Center/Content/ReducedMotion")
	reduced.set_pressed_no_signal(true)
	reduced.toggled.emit(true)
	var keyboard: CheckButton = root.current_screen.get_node("Center/Content/OnscreenKeyboard")
	keyboard.set_pressed_no_signal(true)
	keyboard.toggled.emit(true)

	assert_eq(saves.save_calls, 5)
	assert_true(root.coordinator.settings.reduced_motion)
	assert_true(root.coordinator.settings.onscreen_keyboard)
	root.current_screen.get_node("Center/Content/HomeButton").pressed.emit()
	await get_tree().process_frame
	root.current_screen.get_node("Center/Content/ModeCards/Mode8").pressed.emit()
	await get_tree().process_frame
	assert_true(root.current_screen._reduced_motion)
	assert_false(root.current_screen.mobile_layout)
	assert_true(root.current_screen.has_node("Layout/KeyboardView"))
	assert_false(root.current_screen.get_node("Layout/Navigator").visible)
	assert_eq(root.current_screen.board_columns, 4)
	var visible_boards := 0
	for board in root.current_screen.get_node(
		"Layout/BoardsScroll/BoardCenter/BoardsGrid"
	).get_children():
		if board.visible:
			visible_boards += 1
	assert_eq(visible_boards, 8)


func test_reset_dialog_copy_and_signals_make_cancel_and_confirm_explicit() -> void:
	var dialog := _instantiate_scene(DIALOG_SCENE_PATH)
	if dialog == null:
		return
	var copy := _collect_text(dialog).to_lower()
	assert_string_contains(copy, "свим недовршеним режимима")
	assert_string_contains(copy, "статистика остаје")
	for button_name in ["CancelButton", "ConfirmButton"]:
		var button: Button = dialog.get_node("Center/Panel/Content/Actions/%s" % button_name)
		assert_gte(button.custom_minimum_size.x, 44.0)
		assert_gte(button.custom_minimum_size.y, 44.0)
	watch_signals(dialog)
	dialog.get_node("Center/Panel/Content/Actions/CancelButton").pressed.emit()
	dialog.get_node("Center/Panel/Content/Actions/ConfirmButton").pressed.emit()
	assert_signal_emitted(dialog, "cancelled")
	assert_signal_emitted(dialog, "confirmed")


func test_reset_cancel_is_a_no_op_for_progress_and_persistence() -> void:
	var root: Control = load("res://app/app_root.tscn").instantiate()
	var saves := MemorySaveRepository.new()
	root.save_repository_override = saves
	add_child_autofree(root)
	root.current_screen.get_node("Center/Content/ModeCards/Mode2").pressed.emit()
	await get_tree().process_frame
	root.current_screen.letter_typed.emit("А")
	var sequence: int = root.coordinator.bundle.sequence
	saves.reset_tracking()

	root.get_node("SafeArea/Layout/Footer/NewGameButton").pressed.emit()
	assert_true(root.has_node("ConfirmNewGameDialog"))
	root.get_node(
		"ConfirmNewGameDialog/Center/Panel/Content/Actions/CancelButton"
	).pressed.emit()
	await get_tree().process_frame

	assert_false(root.has_node("ConfirmNewGameDialog"))
	assert_eq(root.coordinator.bundle.sequence, sequence)
	assert_eq(root.coordinator.active_session().current_input, "А")
	assert_eq(saves.save_calls, 0)
	assert_true(root.current_screen is GameScreen)


func test_reset_dialog_traps_focus_and_restores_it_after_accessibility_cancel() -> void:
	var root: Control = load("res://app/app_root.tscn").instantiate()
	root.save_repository_override = MemorySaveRepository.new()
	add_child_autofree(root)
	root.current_screen.get_node("Center/Content/ModeCards/Mode2").pressed.emit()
	await get_tree().process_frame
	var game := root.current_screen as GameScreen
	var focused_mode := game.get_node("Layout/ModeBar/Mode2") as Button
	focused_mode.grab_focus()
	await get_tree().process_frame
	game.letter_typed.emit("А")
	root.get_node("SafeArea/Layout/Footer/NewGameButton").pressed.emit()
	await get_tree().process_frame
	var dialog := root.get_node("ConfirmNewGameDialog") as ConfirmNewGameDialog
	var cancel := dialog.get_node("Center/Panel/Content/Actions/CancelButton") as Button
	var confirm := dialog.get_node("Center/Panel/Content/Actions/ConfirmButton") as Button
	assert_same(get_viewport().gui_get_focus_owner(), cancel)
	assert_eq(cancel.get_node_or_null(cancel.focus_next), confirm)
	assert_eq(confirm.get_node_or_null(confirm.focus_next), cancel)
	assert_eq(cancel.get_node_or_null(cancel.focus_previous), confirm)
	assert_eq(confirm.get_node_or_null(confirm.focus_previous), cancel)

	cancel.pressed.emit()
	await get_tree().process_frame
	assert_false(root.has_node("ConfirmNewGameDialog"))
	assert_same(get_viewport().gui_get_focus_owner(), focused_mode)
	assert_eq(game.process_mode, Node.PROCESS_MODE_INHERIT)


func test_reset_dialog_blocks_keyboard_gameplay_and_escape_cancels() -> void:
	var root: Control = load("res://app/app_root.tscn").instantiate()
	root.save_repository_override = MemorySaveRepository.new()
	add_child_autofree(root)
	root.current_screen.get_node("Center/Content/ModeCards/Mode2").pressed.emit()
	await get_tree().process_frame
	root.current_screen.letter_typed.emit("А")
	var input_before: String = root.coordinator.active_session().current_input

	root.get_node("SafeArea/Layout/Footer/NewGameButton").pressed.emit()
	await get_tree().process_frame
	var letter_event := InputEventKey.new()
	letter_event.pressed = true
	letter_event.unicode = "Б".unicode_at(0)
	Input.parse_input_event(letter_event)
	await get_tree().process_frame
	var input_after: String = root.coordinator.active_session().current_input
	assert_eq(input_after, input_before)
	if input_after != input_before:
		root.get_node(
			"ConfirmNewGameDialog/Center/Panel/Content/Actions/CancelButton"
		).pressed.emit()
		return

	var escape_event := InputEventKey.new()
	escape_event.pressed = true
	escape_event.keycode = KEY_ESCAPE
	Input.parse_input_event(escape_event)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(root.has_node("ConfirmNewGameDialog"))
	assert_eq(root.coordinator.active_session().current_input, input_before)


func test_reset_dialog_blocks_pointer_gameplay_until_accessibility_cancel() -> void:
	var root: Control = load("res://app/app_root.tscn").instantiate()
	root.save_repository_override = MemorySaveRepository.new()
	add_child_autofree(root)
	root.current_screen.get_node("Center/Content/ModeCards/Mode2").pressed.emit()
	await get_tree().process_frame
	var game := root.current_screen as GameScreen
	var mode_four := game.get_node("Layout/ModeBar/Mode4") as Button
	game.letter_typed.emit("А")

	root.get_node("SafeArea/Layout/Footer/NewGameButton").pressed.emit()
	await get_tree().process_frame
	var dialog := root.get_node("ConfirmNewGameDialog") as ConfirmNewGameDialog
	assert_eq(dialog.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(dialog.get_node("Backdrop").mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(dialog.get_node("Center").mouse_filter, Control.MOUSE_FILTER_STOP)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = mode_four.global_position + mode_four.size * 0.5
	click.pressed = true
	Input.parse_input_event(click)
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	await get_tree().process_frame
	assert_eq(root.coordinator.active_mode, 2)

	dialog.get_node(
		"Center/Panel/Content/Actions/CancelButton"
	).pressed.emit()
	await get_tree().process_frame
	assert_false(root.has_node("ConfirmNewGameDialog"))
	assert_eq(game.process_mode, Node.PROCESS_MODE_INHERIT)


func test_reset_confirm_replaces_once_closes_overlays_and_preserves_statistics_and_settings() -> void:
	var root: Control = load("res://app/app_root.tscn").instantiate()
	var saves := MemorySaveRepository.new()
	root.save_repository_override = saves
	add_child_autofree(root)
	assert_true(
		root.coordinator.set_settings(Settings.ThemePreference.LIGHT, true, true)
	)
	root.current_screen.get_node("Center/Content/ModeCards/Mode1").pressed.emit()
	await get_tree().process_frame
	var answer: String = root.coordinator.active_session().boards[0].answer
	for letter in answer:
		root.current_screen.letter_typed.emit(letter)
	root.current_screen.submit_requested.emit()
	await get_tree().process_frame
	assert_true(root.current_screen is ResultsView)
	assert_eq(root.coordinator.statistics.score_counts[6], 1)

	root.current_screen.get_node("Center/Content/ContinueModes/Mode2").pressed.emit()
	await get_tree().process_frame
	root.current_screen.letter_typed.emit("А")
	root.current_screen.mode_selected.emit(1)
	await get_tree().process_frame
	assert_true(root.current_screen is ResultsView)
	var sequence: int = root.coordinator.bundle.sequence
	saves.reset_tracking()

	root.get_node("SafeArea/Layout/Footer/NewGameButton").pressed.emit()
	assert_true(root.has_node("ConfirmNewGameDialog"))
	root.get_node(
		"ConfirmNewGameDialog/Center/Panel/Content/Actions/ConfirmButton"
	).pressed.emit()
	await get_tree().process_frame

	assert_eq(root.coordinator.bundle.sequence, sequence + 1)
	assert_eq(saves.save_calls, 1)
	assert_false(root.has_node("ConfirmNewGameDialog"))
	assert_true(root.current_screen is HomeScreen)
	assert_eq(root.coordinator.statistics.score_counts[6], 1)
	assert_eq(root.coordinator.settings.theme, Settings.ThemePreference.LIGHT)
	assert_true(root.coordinator.settings.reduced_motion)
	assert_true(root.coordinator.settings.onscreen_keyboard)
	for mode in GameCoordinator.MODES:
		var session: GameSession = root.coordinator.bundle.sessions[mode]
		assert_eq(session.status, GameSession.Status.ACTIVE)
		assert_eq(session.attempt_index, 0)
		assert_eq(session.current_input, "")


func _instantiate_scene(path: String) -> Control:
	var scene: PackedScene = load(path)
	assert_not_null(scene)
	if scene == null:
		return null
	var instance := scene.instantiate()
	add_child_autofree(instance)
	return instance


func _select_theme(option: OptionButton, preference: Settings.ThemePreference) -> void:
	option.select(preference)
	option.item_selected.emit(preference)


func _signal_named(object: Object, signal_name: String) -> Dictionary:
	for signal_info in object.get_signal_list():
		if signal_info.name == signal_name:
			return signal_info
	return {}


func _collect_text(node: Node) -> String:
	var result := ""
	if node is Label or node is Button:
		result += str(node.text) + "\n"
	for child in node.get_children():
		result += _collect_text(child)
	return result
