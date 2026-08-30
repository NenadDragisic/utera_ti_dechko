extends GutTest


func test_mode_sizes_assign_their_attempt_limits() -> void:
	assert_eq(GameSession.create(_answers(1)).attempt_limit, 6)
	assert_eq(GameSession.create(_answers(2)).attempt_limit, 7)
	assert_eq(GameSession.create(_answers(4)).attempt_limit, 9)
	assert_eq(GameSession.create(_answers(8)).attempt_limit, 13)


func test_input_stops_after_five_letters() -> void:
	var session := GameSession.create(PackedStringArray(["ЖИВОТ"]))
	for letter in "ЖИВОТ":
		assert_true(session.type_letter(letter, _pool()))

	assert_false(session.type_letter("А", _pool()))
	assert_eq(session.current_input, "ЖИВОТ")


func test_invalid_five_letter_guess_is_red_and_blocked() -> void:
	var session := GameSession.create(PackedStringArray(["ЖИВОТ", "АВАЛА"]))
	_type_word(session, "БББББ", _pool())

	assert_true(session.input_is_invalid)
	assert_false(session.submit(_pool()))
	assert_eq(session.attempt_index, 0)
	assert_eq(session.current_input, "БББББ")


func test_erase_clears_invalid_input_state() -> void:
	var session := GameSession.create(PackedStringArray(["ЖИВОТ", "АВАЛА"]))
	_type_word(session, "БББББ", _pool())

	assert_true(session.erase_letter())
	assert_eq(session.current_input, "ББББ")
	assert_false(session.input_is_invalid)


func test_valid_submit_mirrors_evaluated_rows_to_unsolved_boards() -> void:
	var session := GameSession.create(PackedStringArray(["ЖИВОТ", "АВАЛА"]))
	_submit(session, "ЖИВОТ", _pool())

	assert_eq(session.attempt_index, 1)
	assert_eq(session.boards[0].rows.size(), 1)
	assert_eq(session.boards[1].rows.size(), 1)
	assert_eq(session.boards[0].rows[0].guess(), "ЖИВОТ")
	assert_eq(session.boards[0].rows[0].marks(), [2, 2, 2, 2, 2])
	assert_eq(session.boards[1].rows[0].guess(), "ЖИВОТ")
	assert_eq(session.current_input, "")


func test_solved_board_freezes_while_other_board_continues() -> void:
	var session := GameSession.create(PackedStringArray(["ЖИВОТ", "АВАЛА"]))
	_submit(session, "ЖИВОТ", _pool())
	_submit(session, "АВАЛА", _pool())

	assert_eq(session.boards[0].rows.size(), 1)
	assert_eq(session.boards[1].rows.size(), 2)
	assert_true(session.boards[0].is_solved)
	assert_eq(session.boards[0].solved_attempt, 0)
	assert_eq(session.status, GameSession.Status.WON)


func test_all_solved_boards_wins_the_session() -> void:
	var session := GameSession.create(PackedStringArray(["ЖИВОТ"]))
	_submit(session, "ЖИВОТ", _pool())

	assert_eq(session.status, GameSession.Status.WON)
	assert_eq(session.score(), 6)


func test_final_unsolved_attempt_loses_the_session() -> void:
	var session := GameSession.create(PackedStringArray(["ЖИВОТ"]))
	for _attempt in range(session.attempt_limit):
		_submit(session, "АВАЛА", _pool())

	assert_eq(session.attempt_index, 6)
	assert_eq(session.status, GameSession.Status.LOST)
	assert_eq(session.score(), 0)
	assert_false(session.type_letter("Ж", _pool()))


func test_last_possible_multi_board_win_scores_one() -> void:
	var answers := _answers(8)
	var session := GameSession.create(answers)
	var pool := WordPool.from_entries(PackedStringArray(["ЗЗЗЗЗ"]) + answers)
	for _attempt in range(5):
		_submit(session, "ЗЗЗЗЗ", pool)
	for answer in answers:
		_submit(session, answer, pool)

	assert_eq(session.attempt_index, 13)
	assert_eq(session.status, GameSession.Status.WON)
	assert_eq(session.score(), 1)


func test_score_does_not_record_statistics() -> void:
	var session := GameSession.create(PackedStringArray(["ЖИВОТ"]))
	_submit(session, "ЖИВОТ", _pool())

	assert_false(session.statistics_recorded)
	assert_eq(session.score(), 6)
	assert_false(session.statistics_recorded)


func _type_word(session: GameSession, word: String, pool: WordPool) -> void:
	for letter in word:
		assert_true(session.type_letter(letter, pool))


func _submit(session: GameSession, word: String, pool: WordPool) -> void:
	_type_word(session, word, pool)
	assert_true(session.submit(pool))


func _pool() -> WordPool:
	return WordPool.from_entries(PackedStringArray(["ЖИВОТ", "АВАЛА"]))


func _answers(count: int) -> PackedStringArray:
	return PackedStringArray(["ААААА", "БББББ", "ВВВВВ", "ГГГГГ", "ДДДДД", "ЂЂЂЂЂ", "ЕЕЕЕЕ", "ЖЖЖЖЖ"]).slice(0, count)
