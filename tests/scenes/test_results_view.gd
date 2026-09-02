extends GutTest


const RESULTS_SCENE_PATH := "res://features/results/results_view.tscn"
const RESULTS_SCRIPT_PATH := "res://features/results/results_view.gd"


func test_terminal_result_reveals_score_and_distinguishes_solved_and_missed_answers() -> void:
	var view := _instantiate_results_view()
	if view == null:
		return
	var session := _partially_solved_loss()

	view.render(session, 2, "УТЕРА ТИ ДЕЧКО #12\nРежим: 2 · Резултат: 0/6")

	assert_eq(view.get_node("Center/Content/Score").text, "0/6")
	var answers: VBoxContainer = view.get_node("Center/Content/Answers")
	assert_eq(answers.get_child_count(), 2)
	assert_eq(answers.get_child(0).get_meta("answer_state"), "solved")
	assert_eq(answers.get_child(1).get_meta("answer_state"), "missed")
	assert_string_contains(answers.get_child(0).get_node("Answer").text, "ЖИВОТ")
	assert_string_contains(answers.get_child(1).get_node("Answer").text, "АВАЛА")
	assert_ne(answers.get_child(0).modulate, answers.get_child(1).modulate)


func test_winning_result_displays_the_upper_score_boundary() -> void:
	var view := _instantiate_results_view()
	if view == null:
		return
	var session := GameSession.create(PackedStringArray(["ЖИВОТ"]))
	var pool := WordPool.from_entries(PackedStringArray(["ЖИВОТ"]))
	_type_and_submit(session, "ЖИВОТ", pool)

	view.render(session, 1, "share")

	assert_eq(session.score(), 6)
	assert_eq(view.get_node("Center/Content/Score").text, "6/6")


func test_active_session_creates_no_answer_nodes() -> void:
	var view := _instantiate_results_view()
	if view == null:
		return
	var active := GameSession.create(PackedStringArray(["ЖИВОТ", "АВАЛА"]))

	view.render(active, 2, "must not be available")

	assert_eq(view.get_node("Center/Content/Answers").get_child_count(), 0)
	assert_false(view.get_node("Center/Content/ShareButton").visible)


func test_copy_and_continuation_buttons_emit_typed_intents_without_mutating_session() -> void:
	var view := _instantiate_results_view()
	if view == null:
		return
	var session := GameSession.create(PackedStringArray(["ЖИВОТ"]))
	var pool := WordPool.from_entries(PackedStringArray(["ЖИВОТ"]))
	_type_and_submit(session, "ЖИВОТ", pool)
	view.render(session, 1, "share text")
	watch_signals(view)
	var before_status := session.status

	view.get_node("Center/Content/ShareButton").pressed.emit()
	view.get_node("Center/Content/ContinueModes/Mode8").pressed.emit()
	view.get_node("Center/Content/HomeButton").pressed.emit()

	var copy_signal := _signal_named(view, "copy_requested")
	var mode_signal := _signal_named(view, "mode_selected")
	assert_eq(copy_signal.args.size(), 1)
	assert_eq(copy_signal.args[0].type, TYPE_STRING)
	assert_eq(mode_signal.args.size(), 1)
	assert_eq(mode_signal.args[0].type, TYPE_INT)
	assert_signal_emitted_with_parameters(view, "copy_requested", ["share text"])
	assert_signal_emitted_with_parameters(view, "mode_selected", [8])
	assert_signal_emitted(view, "home_requested")
	assert_eq(session.status, before_status)


func test_clipboard_failure_keeps_selectable_share_text_and_manual_guidance_visible() -> void:
	var view := _instantiate_results_view()
	if view == null:
		return
	view.show_share_fallback("УТЕРА ТИ ДЕЧКО #5\n⬛⬛⬛⬛⬛")
	await get_tree().process_frame

	var panel: Control = view.get_node("Center/Content/ShareFallback")
	var layout: VBoxContainer = panel.get_node("FallbackLayout")
	var guidance: Label = layout.get_node("Guidance")
	var text: TextEdit = layout.get_node("ShareText")
	assert_true(panel.visible)
	assert_same(guidance.get_parent(), layout)
	assert_same(text.get_parent(), layout)
	assert_lte(guidance.global_position.y + guidance.size.y, text.global_position.y)
	assert_false(text.editable)
	assert_true(text.selecting_enabled)
	assert_eq(text.text, "УТЕРА ТИ ДЕЧКО #5\n⬛⬛⬛⬛⬛")
	assert_string_contains(guidance.text.to_lower(), "ручно")

	view.show_copy_success()
	assert_false(panel.visible)


func test_app_root_routes_terminal_session_to_results_and_failed_copy_to_fallback() -> void:
	var root: Control = load("res://app/app_root.tscn").instantiate()
	var clipboard := FakeClipboard.new()
	clipboard.next_result = false
	root.clipboard_override = clipboard
	root.save_repository_override = MemorySaveRepository.new()
	add_child_autofree(root)
	root.current_screen.get_node("Center/Content/ModeCards/Mode1").pressed.emit()
	await get_tree().process_frame

	root.coordinator.active_session().status = GameSession.Status.LOST
	root.coordinator.state_changed.emit()
	await get_tree().process_frame

	assert_eq(root.current_screen.get_script().resource_path, RESULTS_SCRIPT_PATH)
	root.current_screen.get_node("Center/Content/ShareButton").pressed.emit()
	assert_true(root.current_screen.get_node("Center/Content/ShareFallback").visible)
	assert_eq(
		root.current_screen.get_node(
			"Center/Content/ShareFallback/FallbackLayout/ShareText"
		).text,
		clipboard.copied_text,
	)


func test_physical_enter_on_final_non_winning_attempt_reaches_saved_results_in_every_mode() -> void:
	for mode in [1, 2, 4, 8]:
		var repository := MemorySaveRepository.new()
		var root: AppRoot = load("res://app/app_root.tscn").instantiate()
		root.save_repository_override = repository
		add_child_autofree(root)
		root.current_screen.get_node(
			"Center/Content/ModeCards/Mode%d" % mode
		).pressed.emit()
		await get_tree().process_frame
		var session: GameSession = root.coordinator.active_session()
		var pool := root.word_repository.load_pool()
		var loss_guess := _first_non_answer(pool, session)
		assert_false(loss_guess.is_empty())

		for attempt in range(session.attempt_limit):
			var game := root.current_screen as GameScreen
			for letter in loss_guess:
				game.letter_typed.emit(letter)
			if attempt < session.attempt_limit - 1:
				game.submit_requested.emit()
			else:
				var enter := InputEventKey.new()
				enter.pressed = true
				enter.keycode = KEY_ENTER
				game._unhandled_key_input(enter)
		await get_tree().process_frame

		assert_eq(session.status, GameSession.Status.LOST, "mode %d" % mode)
		assert_eq(session.attempt_index, session.attempt_limit, "mode %d" % mode)
		assert_true(session.statistics_recorded, "mode %d" % mode)
		assert_true(root.current_screen is ResultsView, "mode %d" % mode)
		assert_eq(
			root.current_screen.get_node("Center/Content/Score").text,
			"0/6",
			"mode %d" % mode,
		)
		assert_eq(root.coordinator.statistics.score_counts_by_mode[mode][0], 1)
		assert_eq(repository.save_calls, session.attempt_limit)
		var saved: Dictionary = JSON.parse_string(repository.text)
		assert_eq(
			int(saved["bundle"]["sessions"][str(mode)]["status"]),
			GameSession.Status.LOST,
		)
		assert_true(saved["bundle"]["sessions"][str(mode)]["statistics_recorded"])


func test_first_mode_switch_after_loss_renders_every_destination_immediately() -> void:
	for destination_mode in [1, 2, 4, 8]:
		var source_mode := 2 if destination_mode == 1 else 1
		var root: AppRoot = load("res://app/app_root.tscn").instantiate()
		root.save_repository_override = MemorySaveRepository.new()
		add_child_autofree(root)
		root.current_screen.get_node(
			"Center/Content/ModeCards/Mode%d" % source_mode
		).pressed.emit()
		await get_tree().process_frame
		var source_session := root.coordinator.active_session()
		var pool := root.word_repository.load_pool()
		var loss_guess := _first_non_answer(pool, source_session)
		for attempt in range(source_session.attempt_limit):
			var game := root.current_screen as GameScreen
			for letter in loss_guess:
				game.letter_typed.emit(letter)
			game.submit_requested.emit()
		await get_tree().process_frame

		assert_true(root.current_screen is ResultsView, "destination %d" % destination_mode)
		root.current_screen.get_node(
			"Center/Content/ContinueModes/Mode%d" % destination_mode
		).pressed.emit()
		await get_tree().process_frame

		assert_true(root.current_screen is GameScreen, "destination %d" % destination_mode)
		var destination_game := root.current_screen as GameScreen
		var destination_session := root.coordinator.active_session()
		assert_eq(root.coordinator.active_mode, destination_mode)
		assert_eq(destination_session.status, GameSession.Status.ACTIVE)
		assert_eq(
			destination_game.get_node("Layout/BoardsScroll/BoardCenter/BoardsGrid").get_child_count(),
			destination_mode,
			"destination %d must render on its first switch" % destination_mode,
		)
		destination_game.letter_typed.emit("А")
		assert_eq(destination_session.current_input, "А", "destination %d" % destination_mode)
		root.queue_free()
		await get_tree().process_frame


func test_combined_clipboard_failure_also_opens_selectable_manual_fallback() -> void:
	var root: Control = load("res://app/app_root.tscn").instantiate()
	var clipboard := FakeClipboard.new()
	clipboard.next_result = false
	root.clipboard_override = clipboard
	root.save_repository_override = MemorySaveRepository.new()
	add_child_autofree(root)

	root.current_screen.get_node("Center/Content/Actions/ShareButton").pressed.emit()
	await get_tree().process_frame

	assert_true(root.current_screen is HomeScreen)
	var fallback: Control = root.current_screen.get_node("Center/Content/ShareFallback")
	assert_true(fallback.visible)
	assert_eq(
		fallback.get_node("FallbackLayout/ShareText").text,
		clipboard.copied_text,
	)
	assert_string_contains(
		fallback.get_node("FallbackLayout/Guidance").text.to_lower(),
		"ручно",
	)
	assert_false(_tree_contains_name(root.current_screen, "Score"))
	assert_false(_tree_contains_name(root.current_screen, "Answers"))


func _instantiate_results_view() -> Control:
	var scene: PackedScene = load(RESULTS_SCENE_PATH)
	assert_not_null(scene)
	if scene == null:
		return null
	var view := scene.instantiate()
	add_child_autofree(view)
	return view


func _partially_solved_loss() -> GameSession:
	var session := GameSession.create(PackedStringArray(["ЖИВОТ", "АВАЛА"]))
	var guesses := PackedStringArray([
		"ЖИВОТ", "БББББ", "ВВВВВ", "ГГГГГ", "ДДДДД", "ЂЂЂЂЂ", "ЕЕЕЕЕ",
	])
	var entries := guesses.duplicate()
	entries.append("АВАЛА")
	var pool := WordPool.from_entries(entries)
	for guess in guesses:
		_type_and_submit(session, guess, pool)
	assert_eq(session.status, GameSession.Status.LOST)
	return session


func _type_and_submit(session: GameSession, word: String, pool: WordPool) -> void:
	for letter in word:
		assert_true(session.type_letter(letter, pool))
	assert_true(session.submit(pool))


func _first_non_answer(pool: WordPool, session: GameSession) -> String:
	var answers := PackedStringArray()
	for board in session.boards:
		answers.append(board.answer)
	for word in pool.answers():
		if not answers.has(word):
			return word
	return ""


func _signal_named(object: Object, signal_name: String) -> Dictionary:
	for signal_info in object.get_signal_list():
		if signal_info.name == signal_name:
			return signal_info
	return {}


func _tree_contains_name(node: Node, node_name: String) -> bool:
	if node.name == node_name:
		return true
	for child in node.get_children():
		if _tree_contains_name(child, node_name):
			return true
	return false
