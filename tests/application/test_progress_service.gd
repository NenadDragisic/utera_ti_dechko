extends GutTest


const LIGHT_THEME := 2


func test_schema_one_round_trip_restores_every_persisted_field() -> void:
	var repository := MemorySaveRepository.new()
	var pool := _pool()
	var service := _service(repository, pool)
	var loaded := service.load_or_create()
	service.bundle.sequence = 17

	var solved: GameSession = service.bundle.sessions[1]
	_submit(solved, solved.boards[0].answer, pool)
	solved.statistics_recorded = true
	assert_true(service.statistics.record(1, solved.score(), "bundle-17-mode-1"))
	var partial: GameSession = service.bundle.sessions[2]
	_type(partial, "АБ", pool)
	var submitted: GameSession = service.bundle.sessions[4]
	_submit(submitted, "ААААА", pool)
	var invalid: GameSession = service.bundle.sessions[8]
	_type(invalid, "ЏЏЏЏЏ", pool)
	service.settings.set("theme", LIGHT_THEME)
	service.settings.set("reduced_motion", true)
	service.settings.set("onscreen_keyboard", true)
	assert_true(service.statistics.record(4, 3, "older-session"))
	service.bag.remaining_words = PackedStringArray(["БББББ", "ВВВВВ"])
	service.bag.pool_fingerprint = pool.fingerprint()

	assert_eq(service.flush_now(), OK)
	var restored_service := _service(repository, pool)
	var restored := restored_service.load_or_create()

	assert_true(loaded.bundle.is_valid())
	assert_true(restored.restored)
	assert_eq(restored.bundle.sequence, 17)
	assert_eq(restored.bundle.sessions.keys(), [1, 2, 4, 8])
	assert_eq(restored.bundle.sessions[1].status, GameSession.Status.WON)
	assert_eq(restored.bundle.sessions[1].attempt_index, 1)
	assert_true(restored.bundle.sessions[1].statistics_recorded)
	assert_true(restored.bundle.sessions[1].boards[0].is_solved)
	assert_eq(restored.bundle.sessions[1].boards[0].solved_attempt, 0)
	assert_eq(restored.bundle.sessions[1].boards[0].rows[0].guess(), solved.boards[0].answer)
	assert_eq(restored.bundle.sessions[1].boards[0].rows[0].marks(), [2, 2, 2, 2, 2])
	assert_eq(restored.bundle.sessions[2].current_input, "АБ")
	assert_false(restored.bundle.sessions[2].input_is_invalid)
	assert_eq(restored.bundle.sessions[4].attempt_index, 1)
	assert_eq(restored.bundle.sessions[4].boards[0].rows[0].guess(), "ААААА")
	assert_eq(restored.bundle.sessions[4].boards[0].rows[0].marks(), submitted.boards[0].rows[0].marks())
	assert_eq(restored.bundle.sessions[8].current_input, "ЏЏЏЏЏ")
	assert_true(restored.bundle.sessions[8].input_is_invalid)
	assert_eq(restored.settings.get("theme"), LIGHT_THEME)
	assert_true(restored.settings.get("reduced_motion"))
	assert_true(restored.settings.get("onscreen_keyboard"))
	assert_eq(restored.statistics.score_counts, PackedInt32Array([0, 0, 0, 1, 0, 0, 1]))
	assert_eq(restored.statistics.score_counts_by_mode[1], PackedInt32Array([0, 0, 0, 0, 0, 0, 1]))
	assert_eq(restored.statistics.score_counts_by_mode[4], PackedInt32Array([0, 0, 0, 1, 0, 0, 0]))
	assert_true(restored.statistics.recorded_session_ids.has("older-session"))
	assert_true(restored.statistics.recorded_session_ids.has("bundle-17-mode-1"))
	assert_eq(restored.bag.remaining_words, PackedStringArray(["БББББ", "ВВВВВ"]))
	assert_eq(restored.bag.pool_fingerprint, pool.fingerprint())


func test_malformed_json_is_preserved_before_a_fresh_bundle_is_created() -> void:
	_assert_recovers_from("{not-json")


func test_missing_required_keys_are_preserved_before_recovery() -> void:
	_assert_recovers_from(JSON.stringify({"schema_version": 1}))


func test_wrong_field_types_are_preserved_before_recovery() -> void:
	var document := _valid_document()
	document["settings"]["reduced_motion"] = "yes"
	_assert_recovers_from(JSON.stringify(document))


func test_unknown_schema_is_preserved_before_recovery() -> void:
	var document := _valid_document()
	document["schema_version"] = 2
	_assert_recovers_from(JSON.stringify(document))


func test_active_answer_missing_from_current_pool_is_preserved_before_recovery() -> void:
	var old_pool := _pool()
	var repository := MemorySaveRepository.new()
	var old_service := _service(repository, old_pool)
	old_service.load_or_create()
	assert_eq(old_service.flush_now(), OK)
	var removed_answer: String = old_service.bundle.sessions[1].boards[0].answer
	var current_entries := old_pool.answers()
	current_entries.remove_at(current_entries.find(removed_answer))
	current_entries.append("ЏЏЏЏЏ")
	var current_pool := WordPool.from_entries(current_entries)
	repository.reset_tracking()

	var restored := _service(repository, current_pool).load_or_create()

	assert_false(restored.restored)
	assert_ne(restored.warning, "")
	assert_eq(repository.preserved_texts.size(), 1)
	assert_true(restored.bundle.is_valid())
	assert_false(_active_answers(restored.bundle).has(removed_answer))


func test_changed_fingerprint_reconciles_bag_without_reintroducing_active_answers() -> void:
	var repository := MemorySaveRepository.new()
	var old_pool := _pool()
	var old_service := _service(repository, old_pool)
	old_service.load_or_create()
	var active_answers := _active_answers(old_service.bundle)
	old_service.bag.remaining_words = PackedStringArray(["ААААА", "БББББ"])
	assert_eq(old_service.flush_now(), OK)
	repository.reset_tracking()
	var changed_entries := old_pool.answers()
	changed_entries.append("ЏЏЏЏЏ")
	var changed_pool := WordPool.from_entries(changed_entries)

	var restored := _service(repository, changed_pool).load_or_create()

	assert_true(restored.restored)
	assert_eq(restored.bag.pool_fingerprint, changed_pool.fingerprint())
	assert_eq(restored.bag.remaining_words.size(), changed_pool.answers().size() - active_answers.size())
	for answer in active_answers:
		assert_false(restored.bag.remaining_words.has(answer))
	assert_true(restored.bag.remaining_words.has("ААААА"))
	assert_eq(repository.save_calls, 1)


func test_matching_fingerprint_rejects_semantically_inconsistent_input_flags() -> void:
	var cases := [
		{"input": "А", "flag": true},
		{"input": "ААААА", "flag": true},
		{"input": "ЏЏЏЏЏ", "flag": false},
	]
	for case: Dictionary in cases:
		var document := _valid_document()
		document["bundle"]["sessions"]["1"]["current_input"] = case["input"]
		document["bundle"]["sessions"]["1"]["input_is_invalid"] = case["flag"]
		_assert_recovers_from(JSON.stringify(document))


func test_changed_fingerprint_marks_a_removed_current_guess_invalid() -> void:
	var repository := MemorySaveRepository.new()
	var old_pool := _pool()
	var old_service := _service(repository, old_pool)
	old_service.load_or_create()
	_type(old_service.bundle.sessions[1], "ААААА", old_pool)
	assert_false(old_service.bundle.sessions[1].input_is_invalid)
	assert_eq(old_service.flush_now(), OK)
	repository.reset_tracking()
	var changed_entries := old_pool.answers()
	changed_entries.remove_at(changed_entries.find("ААААА"))
	changed_entries.append("ЏЏЏЏЏ")
	var changed_pool := WordPool.from_entries(changed_entries)

	var restored := _service(repository, changed_pool).load_or_create()

	assert_true(restored.restored)
	assert_eq(restored.bundle.sessions[1].current_input, "ААААА")
	assert_true(restored.bundle.sessions[1].input_is_invalid)
	assert_eq(repository.save_calls, 1)


func test_changed_fingerprint_marks_a_newly_added_current_guess_valid() -> void:
	var repository := MemorySaveRepository.new()
	var old_pool := _pool()
	var old_service := _service(repository, old_pool)
	old_service.load_or_create()
	_type(old_service.bundle.sessions[1], "ЏЏЏЏЏ", old_pool)
	assert_true(old_service.bundle.sessions[1].input_is_invalid)
	assert_eq(old_service.flush_now(), OK)
	repository.reset_tracking()
	var changed_entries := old_pool.answers()
	changed_entries.append("ЏЏЏЏЏ")
	var changed_pool := WordPool.from_entries(changed_entries)

	var restored := _service(repository, changed_pool).load_or_create()

	assert_true(restored.restored)
	assert_eq(restored.bundle.sessions[1].current_input, "ЏЏЏЏЏ")
	assert_false(restored.bundle.sessions[1].input_is_invalid)
	assert_eq(repository.save_calls, 1)


func test_unrecorded_completed_restored_session_is_recorded_and_saved_once() -> void:
	var repository := MemorySaveRepository.new()
	var pool := _pool()
	var original := _service(repository, pool)
	original.load_or_create()
	var session: GameSession = original.bundle.sessions[1]
	_submit(session, session.boards[0].answer, pool)
	assert_false(session.statistics_recorded)
	assert_eq(original.flush_now(), OK)
	repository.reset_tracking()

	var first_restore := _service(repository, pool).load_or_create()

	assert_true(first_restore.bundle.sessions[1].statistics_recorded)
	assert_eq(first_restore.statistics.score_counts[6], 1)
	assert_eq(repository.save_calls, 1)

	var second_restore := _service(repository, pool).load_or_create()

	assert_true(second_restore.bundle.sessions[1].statistics_recorded)
	assert_eq(second_restore.statistics.score_counts[6], 1)
	assert_eq(repository.save_calls, 1)


func test_recorded_terminal_session_without_matching_statistics_is_preserved_as_corrupt() -> void:
	var repository := MemorySaveRepository.new()
	var pool := _pool()
	var service := _service(repository, pool)
	service.load_or_create()
	var session: GameSession = service.bundle.sessions[1]
	_submit(session, session.boards[0].answer, pool)
	session.statistics_recorded = true
	assert_eq(service.flush_now(), OK)
	var raw := repository.text
	repository.reset_tracking()

	var restored := _service(repository, pool).load_or_create()

	assert_false(restored.restored)
	assert_eq(repository.preserved_texts, [raw])
	assert_eq(restored.statistics.score_counts, PackedInt32Array([0, 0, 0, 0, 0, 0, 0]))


func test_statistics_counts_without_a_recorded_id_are_preserved_as_corrupt() -> void:
	var document := _valid_document()
	document["statistics"]["score_counts"][0] = 1
	document["statistics"]["score_counts_by_mode"]["1"][0] = 1

	_assert_recovers_from(JSON.stringify(document))


func test_active_session_cannot_claim_a_coherent_statistics_record() -> void:
	var document := _valid_document()
	var session_id := "bundle-1-mode-1"
	document["bundle"]["sessions"]["1"]["statistics_recorded"] = true
	document["statistics"]["recorded_session_ids"].append(session_id)
	document["statistics"]["score_counts"][0] = 1
	document["statistics"]["score_counts_by_mode"]["1"][0] = 1

	_assert_recovers_from(JSON.stringify(document))


func test_recorded_terminal_session_score_bucket_must_match_its_score() -> void:
	var repository := MemorySaveRepository.new()
	var pool := _pool()
	var service := _service(repository, pool)
	service.load_or_create()
	var session: GameSession = service.bundle.sessions[1]
	_submit(session, session.boards[0].answer, pool)
	session.statistics_recorded = true
	assert_true(service.statistics.record(1, 0, "bundle-1-mode-1"))
	assert_eq(service.flush_now(), OK)

	_assert_recovers_from(repository.text)


func test_semantically_false_row_marks_are_preserved_as_corrupt() -> void:
	var repository := MemorySaveRepository.new()
	var pool := _pool()
	var service := _service(repository, pool)
	service.load_or_create()
	_submit(service.bundle.sessions[4], "ААААА", pool)
	assert_eq(service.flush_now(), OK)
	var document: Dictionary = JSON.parse_string(repository.text)
	document["bundle"]["sessions"]["4"]["boards"][0]["rows"][0]["marks"] = [2, 2, 2, 2, 2]

	_assert_recovers_from(JSON.stringify(document))


func test_bag_overlap_with_active_answer_is_preserved_for_all_fingerprints() -> void:
	for changed_fingerprint in [false, true]:
		var document := _valid_document()
		var active_answer: String = document["bundle"]["sessions"]["1"]["boards"][0]["answer"]
		document["bag"]["remaining_words"].append(active_answer)
		if changed_fingerprint:
			document["pool_fingerprint"] = "changed-fingerprint"
			document["bag"]["pool_fingerprint"] = "changed-fingerprint"

		_assert_recovers_from(JSON.stringify(document))


func test_typing_debounce_waits_for_point_three_five_seconds_after_latest_mutation() -> void:
	var repository := MemorySaveRepository.new()
	var service := _service(repository, _pool())
	service.load_or_create()
	repository.reset_tracking()

	service.mark_dirty()
	service.tick(0.30)
	service.mark_dirty()
	service.tick(0.34)
	assert_eq(repository.save_calls, 0)
	service.tick(0.01)

	assert_eq(repository.save_calls, 1)
	assert_false(service.dirty)


func test_flush_now_is_the_synchronous_application_entry_point_even_when_not_dirty() -> void:
	var repository := MemorySaveRepository.new()
	var service := _service(repository, _pool())
	service.load_or_create()
	repository.reset_tracking()

	assert_false(service.dirty)
	service.settings.set("theme", LIGHT_THEME)
	assert_eq(service.flush_now(), OK)

	assert_eq(repository.save_calls, 1)
	assert_eq(int(JSON.parse_string(repository.text)["settings"]["theme"]), LIGHT_THEME)
	assert_false(service.dirty)


func test_failed_debounced_save_stays_dirty_and_retries_after_next_mutation() -> void:
	var repository := MemorySaveRepository.new()
	var service := _service(repository, _pool())
	service.load_or_create()
	repository.reset_tracking()
	repository.next_save_error = ERR_CANT_CREATE

	service.mark_dirty()
	service.tick(0.35)
	assert_true(service.dirty)
	assert_eq(repository.save_calls, 1)

	service.mark_dirty()
	service.tick(0.35)
	assert_eq(repository.save_calls, 2)
	assert_false(service.dirty)


func _assert_recovers_from(raw: String) -> void:
	var repository := MemorySaveRepository.new(raw)
	var restored := _service(repository, _pool()).load_or_create()

	assert_false(restored.restored)
	assert_ne(restored.warning, "")
	assert_eq(repository.preserved_texts, [raw])
	assert_true(restored.bundle.is_valid())
	assert_eq(restored.bundle.sessions.keys(), [1, 2, 4, 8])


func _valid_document() -> Dictionary:
	var repository := MemorySaveRepository.new()
	var service := _service(repository, _pool())
	service.load_or_create()
	assert_eq(service.flush_now(), OK)
	return JSON.parse_string(repository.text)


func _service(repository: SaveRepositoryPort, pool: WordPool) -> ProgressService:
	return ProgressService.new(repository, pool, SessionFactory.new(FakeRandomSource.new()))


func _active_answers(bundle: GameBundle) -> PackedStringArray:
	var answers := PackedStringArray()
	for mode in [1, 2, 4, 8]:
		for board in bundle.sessions[mode].boards:
			answers.append(board.answer)
	return answers


func _type(session: GameSession, text: String, pool: WordPool) -> void:
	for letter in text:
		assert_true(session.type_letter(letter, pool))


func _submit(session: GameSession, word: String, pool: WordPool) -> void:
	_type(session, word, pool)
	assert_true(session.submit(pool))


func _pool() -> WordPool:
	return WordPool.from_entries(PackedStringArray([
		"ААААА", "БББББ", "ВВВВВ", "ГГГГГ", "ДДДДД", "ЂЂЂЂЂ", "ЕЕЕЕЕ", "ЖЖЖЖЖ", "ЗЗЗЗЗ", "ИИИИИ",
		"ЈЈЈЈЈ", "ККККК", "ЛЛЛЛЛ", "ЉЉЉЉЉ", "МММММ", "ННННН", "ЊЊЊЊЊ", "ООООО", "ППППП", "РРРРР",
		"ССССС", "ТТТТТ", "ЋЋЋЋЋ", "УУУУУ", "ФФФФФ", "ХХХХХ", "ЦЦЦЦЦ", "ЧЧЧЧЧ", "ШШШШШ",
	]))
