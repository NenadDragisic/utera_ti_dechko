extends GutTest


const APP_ROOT_SCENE_PATH := "res://app/app_root.tscn"
const BOARD_SCENE_PATH := "res://features/gameplay/board_view.tscn"
const GAME_SCENE_PATH := "res://features/gameplay/game_screen.tscn"
const FakePlatformCapabilities = preload(
	"res://tests/doubles/fake_platform_capabilities.gd"
)


func test_empty_and_insufficient_word_pools_replace_playable_content_with_safe_fatal_diagnostic() -> void:
	var cases := [
		{
			"pool": null,
			"detail": "SECRET ANSWER\nSTACK TRACE",
			"diagnostic": "није доступан",
		},
		{
			"pool": WordPool.from_entries(PackedStringArray()),
			"detail": "SECRET ANSWER\nSTACK TRACE",
			"diagnostic": "није доступан",
		},
		{
			"pool": WordPool.from_entries(PackedStringArray()),
			"detail": "",
			"diagnostic": "не садржи",
		},
		{
			"pool": WordPool.from_entries(_answers(14)),
			"detail": "SECRET ANSWER\nSTACK TRACE",
			"diagnostic": "довољно",
		},
	]
	for test_case in cases:
		var root := _root(MemorySaveRepository.new())
		if root == null:
			return
		root.start(test_case["pool"], test_case["detail"])

		assert_null(root.coordinator)
		assert_eq(root.current_screen.name, "FatalStartup")
		assert_eq(root.get_node("SafeArea/Layout/ScreenContainer").get_child_count(), 1)
		var message: String = root.current_screen.get_node("Message").text
		assert_string_contains(message, "15")
		assert_string_contains(message.to_lower(), test_case["diagnostic"])
		assert_false(message.contains("SECRET ANSWER"))
		assert_false(message.contains("STACK TRACE"))


func test_corrupt_save_is_preserved_while_a_fresh_playable_bundle_shows_a_dismissible_notice() -> void:
	var raw := "{\"answer\":\"SECRET ANSWER\",\"stack\":\"STACK TRACE\""
	var repository := MemorySaveRepository.new(raw)
	var root := _root(repository)
	if root == null:
		return

	assert_not_null(root.coordinator)
	assert_true(root.coordinator.bundle.is_valid())
	assert_true(root.current_screen is HomeScreen)
	assert_eq(repository.preserved_texts, [raw])
	assert_true(root.get_node("NoticeBanner").visible)
	assert_false(_visible_text(root).contains("SECRET ANSWER"))
	assert_false(_visible_text(root).contains("STACK TRACE"))

	root.get_node("NoticeBanner/TopMargin/Panel/Layout/DismissButton").pressed.emit()
	assert_false(root.get_node("NoticeBanner").visible)
	assert_true(root.current_screen is HomeScreen)


func test_save_web_persistence_and_clipboard_failures_preserve_playable_state_with_fallbacks() -> void:
	var saves := MemorySaveRepository.new()
	var web_root := _root(
		saves,
		FakePlatformCapabilities.new("Web", true),
	)
	if web_root == null:
		return
	assert_true(web_root.current_screen is HomeScreen)
	assert_true(web_root.get_node("NoticeBanner").visible)
	assert_string_contains(_notice_text(web_root).to_lower(), "напредак")

	web_root.get_node("NoticeBanner").dismiss()
	saves.next_save_error = ERR_CANT_CREATE
	assert_true(web_root.coordinator.set_settings(Settings.ThemePreference.DARK, true, false))
	assert_true(web_root.current_screen is HomeScreen)
	assert_true(web_root.get_node("NoticeBanner").visible)
	assert_string_contains(_notice_text(web_root).to_lower(), "није сачуван")
	web_root.get_node("NoticeBanner").dismiss()
	saves.next_save_error = ERR_FILE_CANT_WRITE
	assert_true(web_root.coordinator.type_letter("А"))
	web_root._process(ProgressService.DEBOUNCE_SECONDS)
	assert_true(web_root.current_screen is HomeScreen)
	assert_true(web_root.get_node("NoticeBanner").visible)
	assert_string_contains(_notice_text(web_root).to_lower(), "није сачуван")

	var clipboard := FakeClipboard.new()
	clipboard.next_result = false
	var clipboard_root := _root(MemorySaveRepository.new(), null, clipboard)
	if clipboard_root == null:
		return
	clipboard_root.current_screen.get_node("Center/Content/Actions/ShareButton").pressed.emit()
	await get_tree().process_frame
	assert_true(clipboard_root.current_screen is HomeScreen)
	assert_true(
		clipboard_root.current_screen.get_node("Center/Content/ShareFallback").visible
	)
	assert_true(clipboard_root.get_node("NoticeBanner").visible)
	assert_string_contains(_notice_text(clipboard_root).to_lower(), "ручно")


func test_board_motion_is_restrained_visual_only_and_reduced_motion_is_synchronous() -> void:
	var animated: BoardView = _board()
	if animated == null:
		return
	var pool := WordPool.from_entries(PackedStringArray(["ЖИВОТ", "АВАЛА"]))
	var session := GameSession.create(PackedStringArray(["ЖИВОТ"]))
	animated.set_reduced_motion(false)
	animated.render(session.boards[0], session)
	await get_tree().process_frame
	var original_cell_minimum: Vector2 = animated.get_node(
		"Content/Cells/Cell_0_0"
	).custom_minimum_size
	var original_glyph_x: float = animated.get_node(
		"Content/Cells/Cell_0_0/Glyph"
	).position.x

	_type_word(session, "БББББ", pool)
	animated.render(session.boards[0], session)
	var invalid_glyph: Label = animated.get_node("Content/Cells/Cell_0_0/Glyph")
	assert_ne(invalid_glyph.position.x, original_glyph_x)
	assert_eq(
		animated.get_node("Content/Cells/Cell_0_0").custom_minimum_size,
		original_cell_minimum,
	)
	await get_tree().create_timer(0.20).timeout
	assert_almost_eq(invalid_glyph.position.x, original_glyph_x, 0.01)

	assert_true(session.erase_letter())
	for _index in range(4):
		assert_true(session.erase_letter())
	_type_word(session, "ЖИВОТ", pool)
	assert_true(session.submit(pool))
	animated.render(session.boards[0], session)
	var revealed_cell: Control = animated.get_node("Content/Cells/Cell_0_0")
	assert_lt(revealed_cell.scale.y, 1.0)
	assert_lt(animated.scale.x, 1.0)
	await get_tree().create_timer(0.20).timeout
	assert_almost_eq(revealed_cell.scale.y, 1.0, 0.01)
	assert_almost_eq(animated.scale.x, 1.0, 0.01)

	var reduced: BoardView = _board()
	var reduced_session := GameSession.create(PackedStringArray(["ЖИВОТ"]))
	reduced.set_reduced_motion(true)
	reduced.render(reduced_session.boards[0], reduced_session)
	await get_tree().process_frame
	var reduced_glyph_x: float = reduced.get_node(
		"Content/Cells/Cell_0_0/Glyph"
	).position.x
	_type_word(reduced_session, "ЖИВОТ", pool)
	assert_true(reduced_session.submit(pool))
	reduced.render(reduced_session.boards[0], reduced_session)
	assert_eq(reduced.get_node("Content/Cells/Cell_0_0").scale, Vector2.ONE)
	assert_eq(reduced.scale, Vector2.ONE)
	assert_eq(
		reduced.get_node("Content/Cells/Cell_0_0/Glyph").position.x,
		reduced_glyph_x,
	)


func test_cells_modes_navigator_and_icon_controls_have_safe_accessible_names_and_focus_paths() -> void:
	var screen: GameScreen = _game_screen()
	if screen == null:
		return
	var pool := WordPool.from_entries(PackedStringArray(["АВАЛА", "ЛАААА", "БББББ", "ВВВВВ"]))
	var session := GameSession.create(PackedStringArray(["АВАЛА", "БББББ", "ВВВВВ", "ГГГГГ"]))
	_type_word(session, "ЛАААА", pool)
	assert_true(session.submit(pool))
	screen.set_mobile_layout(true)
	screen.render(session, 4)

	var present_cell: Control = screen.get_node(
		"Layout/BoardsScroll/BoardCenter/BoardsGrid/Board0/Content/Cells/Cell_0_0"
	)
	assert_eq(present_cell.accessibility_name, "Ред 1, слово 1, присутно")
	assert_false(_all_accessibility_names(screen).contains("АВАЛА"))
	for mode in [1, 2, 4, 8]:
		var mode_button: Button = screen.get_node("Layout/ModeBar/Mode%d" % mode)
		assert_string_contains(mode_button.accessibility_name, "Режим %d" % mode)
		assert_false(mode_button.focus_neighbor_left.is_empty())
		assert_false(mode_button.focus_neighbor_right.is_empty())
		assert_gte(mode_button.custom_minimum_size.x, 44.0)
		assert_gte(mode_button.custom_minimum_size.y, 44.0)

	var navigator: HBoxContainer = screen.get_node("Layout/Navigator")
	for button in navigator.get_children():
		assert_string_contains(button.accessibility_name, "Табла")
		assert_false(button.focus_neighbor_left.is_empty())
		assert_false(button.focus_neighbor_right.is_empty())
		assert_gte(button.custom_minimum_size.x, 44.0)
		assert_gte(button.custom_minimum_size.y, 44.0)

	var keyboard: Control = screen.get_node("Layout/KeyboardView")
	for path in [
		"ReopenButton",
		"SheetContent/Content/Header/Actions/EraseButton",
		"SheetContent/Content/Header/CollapseButton",
	]:
		var icon_button: Button = keyboard.get_node(path)
		assert_false(icon_button.accessibility_name.is_empty(), path)
		assert_gte(icon_button.custom_minimum_size.x, 44.0)
		assert_gte(icon_button.custom_minimum_size.y, 44.0)

	var focus_style: StyleBox = screen.get_node(
		"Layout/ModeBar/Mode1"
	).get_theme_stylebox("focus")
	assert_not_null(focus_style)
	assert_gt(focus_style.get_minimum_size().x, 0.0)


func test_escape_collapses_the_keyboard_then_requests_back_without_typing() -> void:
	var screen: GameScreen = _game_screen()
	if screen == null:
		return
	screen.set_mobile_layout(true)
	screen.render(GameSession.create(_answers(4)), 4)
	var keyboard: KeyboardView = screen.get_node("Layout/KeyboardView")
	keyboard.set_collapsed(false)
	watch_signals(screen)

	screen._unhandled_key_input(_key_event(KEY_ESCAPE))
	assert_true(keyboard.collapsed)
	assert_signal_not_emitted(screen, "back_requested")
	screen._unhandled_key_input(_key_event(KEY_ESCAPE))
	assert_signal_emitted(screen, "back_requested")
	assert_signal_not_emitted(screen, "letter_typed")


func test_home_icon_controls_are_named_and_app_back_returns_secondary_screens_home() -> void:
	var root := _root(MemorySaveRepository.new())
	if root == null:
		return
	for path in [
		"Center/Content/Actions/StatisticsButton",
		"Center/Content/Actions/ShareButton",
		"Center/Content/Actions/SettingsButton",
	]:
		var icon_button: Button = root.current_screen.get_node(path)
		assert_false(icon_button.accessibility_name.is_empty(), path)
		assert_gte(icon_button.custom_minimum_size.x, 44.0)
		assert_gte(icon_button.custom_minimum_size.y, 44.0)

	root.current_screen.get_node("Center/Content/Actions/SettingsButton").pressed.emit()
	assert_true(root.current_screen is SettingsView)
	root._unhandled_key_input(_key_event(KEY_ESCAPE))
	assert_true(root.current_screen is HomeScreen)
	await get_tree().process_frame


func test_platform_back_collapses_mobile_keyboard_before_returning_home() -> void:
	var root := _root(
		MemorySaveRepository.new(),
		FakePlatformCapabilities.new("Android", false),
	)
	if root == null:
		return
	root.current_screen.get_node("Center/Content/ModeCards/Mode4").pressed.emit()
	await get_tree().process_frame
	var game: GameScreen = root.current_screen
	var keyboard: KeyboardView = game.get_node("Layout/KeyboardView")
	keyboard.set_collapsed(false)

	root._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_same(root.current_screen, game)
	assert_true(keyboard.collapsed)
	root._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_true(root.current_screen is HomeScreen)
	await get_tree().process_frame


func _root(
	saves: SaveRepositoryPort,
	capabilities: PlatformCapabilities = null,
	clipboard: ClipboardPort = null,
) -> AppRoot:
	var scene: PackedScene = load(APP_ROOT_SCENE_PATH)
	assert_not_null(scene)
	if scene == null:
		return null
	var root: AppRoot = scene.instantiate()
	root.save_repository_override = saves
	root.platform_capabilities_override = capabilities
	root.clipboard_override = clipboard
	add_child_autofree(root)
	return root


func _board() -> BoardView:
	var scene: PackedScene = load(BOARD_SCENE_PATH)
	assert_not_null(scene)
	if scene == null:
		return null
	var board: BoardView = scene.instantiate()
	add_child_autofree(board)
	return board


func _game_screen() -> GameScreen:
	var scene: PackedScene = load(GAME_SCENE_PATH)
	assert_not_null(scene)
	if scene == null:
		return null
	var screen: GameScreen = scene.instantiate()
	add_child_autofree(screen)
	return screen


func _notice_text(root: AppRoot) -> String:
	return root.get_node("NoticeBanner/TopMargin/Panel/Layout/Message").text


func _visible_text(node: Node) -> String:
	var result := ""
	if node is CanvasItem and not node.visible:
		return result
	if node is Label or node is Button:
		result += str(node.text) + "\n"
	for child in node.get_children():
		result += _visible_text(child)
	return result


func _all_accessibility_names(node: Node) -> String:
	var result := ""
	if node is Control:
		result += node.accessibility_name + "\n"
	for child in node.get_children():
		result += _all_accessibility_names(child)
	return result


func _type_word(session: GameSession, word: String, pool: WordPool) -> void:
	for letter in word:
		assert_true(session.type_letter(letter, pool))


func _answers(count: int) -> PackedStringArray:
	return PackedStringArray([
		"ААААА", "БББББ", "ВВВВВ", "ГГГГГ",
		"ДДДДД", "ЂЂЂЂЂ", "ЕЕЕЕЕ", "ЖЖЖЖЖ",
		"ЗЗЗЗЗ", "ИИИИИ", "ЈЈЈЈЈ", "ККККК",
		"ЛЛЛЛЛ", "ЉЉЉЉЉ", "МММММ",
	]).slice(0, count)


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	return event
