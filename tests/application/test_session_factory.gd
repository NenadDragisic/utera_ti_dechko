extends GutTest


func test_factory_allocates_reversed_draw_into_exact_mode_slices_and_limits() -> void:
	var bundle := SessionFactory.new(FakeRandomSource.new()).create_bundle(42, _pool(15), AnswerShuffleBag.new())

	assert_true(bundle.is_valid())
	assert_eq(bundle.sequence, 42)
	assert_eq(bundle.sessions.keys(), [1, 2, 4, 8])
	assert_eq(bundle.sessions[1].boards.map(func(board: BoardState) -> String: return board.answer), ["ННННН"])
	assert_eq(bundle.sessions[2].boards.map(func(board: BoardState) -> String: return board.answer), ["МММММ", "ЛЛЛЛЛ"])
	assert_eq(bundle.sessions[4].boards.map(func(board: BoardState) -> String: return board.answer), ["ККККК", "ЈЈЈЈЈ", "ИИИИИ", "ЗЗЗЗЗ"])
	assert_eq(bundle.sessions[8].boards.map(func(board: BoardState) -> String: return board.answer), ["ЖЖЖЖЖ", "ЕЕЕЕЕ", "ЂЂЂЂЂ", "ДДДДД", "ГГГГГ", "ВВВВВ", "БББББ", "ААААА"])
	assert_eq(bundle.sessions[1].attempt_limit, 6)
	assert_eq(bundle.sessions[2].attempt_limit, 7)
	assert_eq(bundle.sessions[4].attempt_limit, 9)
	assert_eq(bundle.sessions[8].attempt_limit, 13)


func test_factory_returns_typed_insufficient_answers_result_without_partial_sessions() -> void:
	var bundle := SessionFactory.new(FakeRandomSource.new()).create_bundle(1, _pool(14), AnswerShuffleBag.new())

	assert_false(bundle.is_valid())
	assert_eq(bundle.error, GameBundle.Error.INSUFFICIENT_ANSWERS)
	assert_eq(bundle.available_answer_count, 14)
	assert_eq(bundle.sessions, {})


func _pool(count: int) -> WordPool:
	return WordPool.from_entries(PackedStringArray([
		"ААААА", "БББББ", "ВВВВВ", "ГГГГГ", "ДДДДД", "ЂЂЂЂЂ", "ЕЕЕЕЕ", "ЖЖЖЖЖ", "ЗЗЗЗЗ", "ИИИИИ",
		"ЈЈЈЈЈ", "ККККК", "ЛЛЛЛЛ", "МММММ", "ННННН",
	]).slice(0, count))
