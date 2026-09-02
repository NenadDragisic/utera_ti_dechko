extends GutTest


func test_mode_text_formats_a_completed_grid_without_answers_or_guesses() -> void:
	var bundle := _bundle_with_completed_modes([1])
	var text := ShareService.new(FakeClipboard.new()).mode_text(bundle, 1)

	assert_eq(text, "УТЕРА ТИ ДЕЧКО #42\nРежим: 1 · Резултат: 6/6\n🟩🟨⬛🟩🟨")
	assert_false(text.contains("ТАЈНА"))
	assert_false(text.contains("СЛОВО"))


func test_combined_text_orders_completed_modes_and_omits_unfinished_grids() -> void:
	var bundle := _bundle_with_completed_modes([1, 2, 4])
	var text := ShareService.new(FakeClipboard.new()).combined_text(bundle)

	assert_eq(text.get_slice("\n", 0), "УТЕРА ТИ ДЕЧКО #42")
	assert_lt(text.find("Режим: 1"), text.find("Режим: 2"))
	assert_lt(text.find("Режим: 2"), text.find("Режим: 4"))
	assert_false(text.contains("Режим: 8"))
	assert_true(text.contains("🟩"))
	assert_true(text.contains("🟨"))
	assert_true(text.contains("⬛"))
	assert_false(text.contains("ТАЈНА"))
	assert_false(text.contains("СЛОВО"))


func test_copy_returns_success_and_forwards_share_text_to_clipboard() -> void:
	var clipboard := FakeClipboard.new()
	var service := ShareService.new(clipboard)

	assert_true(service.copy("само емоџи"))
	assert_eq(clipboard.copied_text, "само емоџи")


func test_copy_returns_false_when_clipboard_port_is_unavailable() -> void:
	var clipboard := FakeClipboard.new()
	clipboard.next_result = false

	assert_false(ShareService.new(clipboard).copy("само емоџи"))


func _bundle_with_completed_modes(completed_modes: Array[int]) -> GameBundle:
	var sessions: Dictionary[int, GameSession] = {}
	for mode in [1, 2, 4, 8]:
		sessions[mode] = _session(mode, completed_modes.has(mode))
	return GameBundle.new(42, sessions)


func _session(mode: int, completed: bool) -> GameSession:
	var session := GameSession.new()
	session.attempt_index = mode
	for board_index in mode:
		var board := BoardState.new("ТАЈНА")
		board.rows.append(GuessRow.new("СЛОВО", [
			LetterMark.Value.CORRECT,
			LetterMark.Value.PRESENT,
			LetterMark.Value.ABSENT,
			LetterMark.Value.CORRECT,
			LetterMark.Value.PRESENT,
		]))
		session.boards.append(board)
	if completed:
		session.status = GameSession.Status.WON
	return session
