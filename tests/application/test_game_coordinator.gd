extends GutTest


const MODES := [1, 2, 4, 8]


func test_launch_without_save_creates_a_fresh_bundle_and_announces_state() -> void:
	var context := _context()
	var states: Array[int] = []
	context.coordinator.state_changed.connect(func() -> void: states.append(1))

	var restored: bool = context.coordinator.launch()

	assert_false(restored)
	assert_eq(context.coordinator.active_mode, 1)
	assert_eq(context.coordinator.bundle.sequence, 1)
	assert_eq(context.coordinator.bundle.sessions.keys(), MODES)
	assert_eq(states.size(), 1)


func test_launch_with_save_restores_bundle_settings_statistics_and_active_sessions() -> void:
	var repository := MemorySaveRepository.new()
	var first := _context(repository)
	first.coordinator.launch()
	var completed: GameSession = first.coordinator.active_session()
	_type_word(first.coordinator, completed.boards[0].answer)
	assert_true(first.coordinator.submit())
	assert_true(first.coordinator.switch_mode(2))
	assert_true(first.coordinator.type_letter("А"))
	first.coordinator.set_settings(Settings.ThemePreference.LIGHT, true, true)
	var saved_bundle: GameBundle = first.coordinator.bundle

	var second := _context(repository)
	var restored: bool = second.coordinator.launch()

	assert_true(restored)
	assert_eq(second.coordinator.bundle.sessions[1].status, GameSession.Status.WON)
	assert_true(second.coordinator.bundle.sessions[1].statistics_recorded)
	assert_eq(second.coordinator.bundle.sessions[2].current_input, "А")
	assert_eq(second.coordinator.settings.theme, Settings.ThemePreference.LIGHT)
	assert_true(second.coordinator.settings.reduced_motion)
	assert_true(second.coordinator.settings.onscreen_keyboard)
	assert_eq(second.coordinator.statistics.score_counts, PackedInt32Array([0, 0, 0, 0, 0, 0, 1]))
	assert_eq(second.coordinator.statistics.score_counts_by_mode[1], PackedInt32Array([0, 0, 0, 0, 0, 0, 1]))
	assert_eq(second.coordinator.statistics.score_counts_by_mode[2], PackedInt32Array([0, 0, 0, 0, 0, 0, 0]))
	assert_eq(second.coordinator.statistics.score_counts_by_mode[4], PackedInt32Array([0, 0, 0, 0, 0, 0, 0]))
	assert_eq(second.coordinator.statistics.score_counts_by_mode[8], PackedInt32Array([0, 0, 0, 0, 0, 0, 0]))
	assert_eq(second.coordinator.statistics.recorded_session_ids, {"bundle-1-mode-1": true})
	assert_ne(second.coordinator.bundle, saved_bundle)


func test_launch_forwards_recovery_warning_as_a_notice() -> void:
	var context := _context(MemorySaveRepository.new("not json"))
	var notices: Array[String] = []
	context.coordinator.notice_requested.connect(func(message: String) -> void: notices.append(message))

	context.coordinator.launch()

	assert_eq(notices.size(), 1)
	assert_string_contains(notices[0], "Сачувани напредак")


func test_mode_switch_preserves_each_sessions_input_and_only_mutates_the_selected_session() -> void:
	var context := _launched_context()

	assert_true(context.coordinator.type_letter("А"))
	assert_true(context.coordinator.type_letter("Б"))
	assert_true(context.coordinator.switch_mode(2))
	assert_true(context.coordinator.type_letter("В"))
	assert_true(context.coordinator.switch_mode(1))

	assert_eq(context.coordinator.bundle.sessions[1].current_input, "АБ")
	assert_eq(context.coordinator.bundle.sessions[2].current_input, "В")
	assert_false(context.coordinator.switch_mode(3))
	assert_eq(context.coordinator.active_mode, 1)


func test_typing_and_erasing_mark_progress_dirty_without_synchronous_saves() -> void:
	var repository := MemorySaveRepository.new()
	var context := _launched_context(repository)
	repository.reset_tracking()

	assert_true(context.coordinator.type_letter("А"))
	assert_true(context.progress.dirty)
	assert_eq(repository.save_calls, 0)
	assert_eq(context.progress.flush_now(), OK)
	repository.reset_tracking()
	assert_true(context.coordinator.erase())

	assert_true(context.progress.dirty)
	assert_eq(repository.save_calls, 0)


func test_valid_submission_is_mirrored_and_saved_immediately() -> void:
	var repository := MemorySaveRepository.new()
	var context := _launched_context(repository)
	assert_true(context.coordinator.switch_mode(2))
	var session: GameSession = context.coordinator.active_session()
	var guess: String = session.boards[0].answer
	_type_word(context.coordinator, guess)
	var states: Array[int] = []
	context.coordinator.state_changed.connect(func() -> void: states.append(1))
	repository.reset_tracking()

	assert_true(context.coordinator.submit())

	assert_eq(session.attempt_index, 1)
	assert_eq(session.boards[0].rows[0].guess(), guess)
	assert_eq(session.boards[1].rows[0].guess(), guess)
	assert_eq(repository.save_calls, 1)
	assert_false(context.progress.dirty)
	assert_eq(states.size(), 1)


func test_invalid_submission_is_blocked_without_state_change_or_immediate_save() -> void:
	var repository := MemorySaveRepository.new()
	var context := _launched_context(repository)
	var states: Array[int] = []
	context.coordinator.state_changed.connect(func() -> void: states.append(1))
	_type_word(context.coordinator, "ШШШШШ")
	repository.reset_tracking()
	states.clear()

	assert_false(context.coordinator.submit())

	assert_eq(context.coordinator.active_session().attempt_index, 0)
	assert_eq(context.coordinator.active_session().current_input, "ШШШШШ")
	assert_true(context.coordinator.active_session().input_is_invalid)
	assert_eq(repository.save_calls, 0)
	assert_eq(states.size(), 0)


func test_terminal_submission_records_statistics_and_saves_exactly_once() -> void:
	var repository := MemorySaveRepository.new()
	var context := _launched_context(repository)
	var session: GameSession = context.coordinator.active_session()
	_type_word(context.coordinator, session.boards[0].answer)
	repository.reset_tracking()

	assert_true(context.coordinator.submit())
	assert_eq(session.status, GameSession.Status.WON)
	assert_true(session.statistics_recorded)
	assert_eq(context.coordinator.statistics.score_counts[6], 1)
	assert_eq(context.coordinator.statistics.score_counts_by_mode[1][6], 1)
	assert_eq(repository.save_calls, 1)

	assert_false(context.coordinator.submit())
	assert_false(context.coordinator.type_letter("А"))
	assert_false(context.coordinator.erase())
	assert_eq(context.coordinator.statistics.score_counts[6], 1)
	assert_eq(repository.save_calls, 1)


func test_settings_change_updates_existing_settings_and_saves_immediately() -> void:
	var repository := MemorySaveRepository.new()
	var context := _launched_context(repository)
	var original_settings: Settings = context.coordinator.settings
	var states: Array[int] = []
	context.coordinator.state_changed.connect(func() -> void: states.append(1))
	repository.reset_tracking()

	assert_true(context.coordinator.set_settings(Settings.ThemePreference.DARK, true, true))

	assert_same(context.coordinator.settings, original_settings)
	assert_eq(original_settings.theme, Settings.ThemePreference.DARK)
	assert_true(original_settings.reduced_motion)
	assert_true(original_settings.onscreen_keyboard)
	assert_eq(repository.save_calls, 1)
	assert_eq(states.size(), 1)
	assert_false(context.coordinator.set_settings(Settings.ThemePreference.DARK, true, true))
	assert_eq(repository.save_calls, 1)
	assert_eq(states.size(), 1)


func test_request_new_bundle_asks_for_confirmation_when_any_mode_has_unfinished_progress() -> void:
	var repository := MemorySaveRepository.new()
	var context := _launched_context(repository)
	assert_true(context.coordinator.switch_mode(8))
	assert_true(context.coordinator.type_letter("А"))
	assert_true(context.coordinator.switch_mode(1))
	var confirmations: Array[int] = []
	var states: Array[int] = []
	context.coordinator.confirmation_requested.connect(func() -> void: confirmations.append(1))
	context.coordinator.state_changed.connect(func() -> void: states.append(1))
	repository.reset_tracking()

	assert_false(context.coordinator.request_new_bundle())

	assert_eq(confirmations.size(), 1)
	assert_eq(states.size(), 0)
	assert_eq(context.coordinator.bundle.sequence, 1)
	assert_eq(repository.save_calls, 0)


func test_confirmed_bundle_reset_replaces_all_sessions_and_preserves_long_lived_state() -> void:
	var repository := MemorySaveRepository.new()
	var context := _launched_context(repository)
	var completed: GameSession = context.coordinator.active_session()
	_type_word(context.coordinator, completed.boards[0].answer)
	assert_true(context.coordinator.submit())
	context.coordinator.set_settings(Settings.ThemePreference.LIGHT, true, false)
	var settings: Settings = context.coordinator.settings
	var statistics: Statistics = context.coordinator.statistics
	var bag: AnswerShuffleBag = context.progress.bag
	var old_sessions: Dictionary = context.coordinator.bundle.sessions.duplicate()
	var states: Array[int] = []
	context.coordinator.state_changed.connect(func() -> void: states.append(1))
	repository.reset_tracking()

	assert_true(context.coordinator.confirm_new_bundle())

	assert_eq(context.coordinator.bundle.sequence, 2)
	assert_eq(context.coordinator.active_mode, 1)
	for mode in MODES:
		assert_ne(context.coordinator.bundle.sessions[mode], old_sessions[mode])
		assert_eq(context.coordinator.bundle.sessions[mode].attempt_index, 0)
		assert_eq(context.coordinator.bundle.sessions[mode].current_input, "")
	assert_same(context.coordinator.settings, settings)
	assert_same(context.coordinator.statistics, statistics)
	assert_same(context.progress.bag, bag)
	assert_eq(statistics.score_counts[6], 1)
	assert_eq(repository.save_calls, 1)
	assert_eq(states.size(), 1)


func test_confirmed_reset_does_not_record_abandoned_unfinished_progress_as_a_loss() -> void:
	var context := _launched_context()
	var completed: GameSession = context.coordinator.active_session()
	_type_word(context.coordinator, completed.boards[0].answer)
	assert_true(context.coordinator.submit())
	assert_true(context.coordinator.switch_mode(2))
	var abandoned: GameSession = context.coordinator.active_session()
	_type_word(context.coordinator, abandoned.boards[0].answer)
	assert_true(context.coordinator.submit())
	assert_eq(abandoned.status, GameSession.Status.ACTIVE)
	assert_eq(abandoned.attempt_index, 1)
	var old_sessions: Dictionary = context.coordinator.bundle.sessions.duplicate()
	var pre_score_counts: PackedInt32Array = context.coordinator.statistics.score_counts.duplicate()
	var pre_mode_counts: Dictionary = {}
	for mode in MODES:
		pre_mode_counts[mode] = context.coordinator.statistics.score_counts_by_mode[mode].duplicate()
	var pre_recorded_ids: Dictionary = context.coordinator.statistics.recorded_session_ids.duplicate()
	var confirmations: Array[int] = []
	context.coordinator.confirmation_requested.connect(func() -> void: confirmations.append(1))

	assert_false(context.coordinator.request_new_bundle())
	assert_eq(confirmations.size(), 1)
	assert_true(context.coordinator.confirm_new_bundle())

	assert_eq(context.coordinator.bundle.sequence, 2)
	for mode in MODES:
		var fresh: GameSession = context.coordinator.bundle.sessions[mode]
		assert_ne(fresh, old_sessions[mode])
		assert_eq(fresh.status, GameSession.Status.ACTIVE)
		assert_eq(fresh.attempt_index, 0)
		assert_eq(fresh.current_input, "")
	assert_eq(abandoned.status, GameSession.Status.ACTIVE)
	assert_false(abandoned.statistics_recorded)
	assert_eq(context.coordinator.statistics.score_counts, pre_score_counts)
	for mode in MODES:
		assert_eq(context.coordinator.statistics.score_counts_by_mode[mode], pre_mode_counts[mode])
	assert_eq(context.coordinator.statistics.recorded_session_ids, pre_recorded_ids)
	assert_eq(context.coordinator.statistics.score_counts[0], 0)
	assert_eq(context.coordinator.statistics.recorded_session_ids.size(), 1)
	assert_false(context.coordinator.statistics.recorded_session_ids.has("bundle-1-mode-2"))


func test_request_new_bundle_resets_without_confirmation_when_no_unfinished_progress_exists() -> void:
	var repository := MemorySaveRepository.new()
	var context := _launched_context(repository)
	var completed: GameSession = context.coordinator.active_session()
	_type_word(context.coordinator, completed.boards[0].answer)
	assert_true(context.coordinator.submit())
	var confirmations: Array[int] = []
	var states: Array[int] = []
	context.coordinator.confirmation_requested.connect(func() -> void: confirmations.append(1))
	context.coordinator.state_changed.connect(func() -> void: states.append(1))
	repository.reset_tracking()

	assert_true(context.coordinator.request_new_bundle())

	assert_eq(confirmations.size(), 0)
	assert_eq(context.coordinator.bundle.sequence, 2)
	assert_eq(context.coordinator.statistics.score_counts[6], 1)
	assert_eq(repository.save_calls, 1)
	assert_eq(states.size(), 1)


func _type_word(coordinator: GameCoordinator, word: String) -> void:
	for letter in word:
		assert_true(coordinator.type_letter(letter))


func _launched_context(repository: MemorySaveRepository = MemorySaveRepository.new()) -> Dictionary:
	var context := _context(repository)
	context.coordinator.launch()
	return context


func _context(repository: MemorySaveRepository = MemorySaveRepository.new()) -> Dictionary:
	var pool := WordPool.from_entries(PackedStringArray([
		"ААААА", "БББББ", "ВВВВВ", "ГГГГГ", "ДДДДД", "ЂЂЂЂЂ", "ЕЕЕЕЕ", "ЖЖЖЖЖ", "ЗЗЗЗЗ", "ИИИИИ",
		"ЈЈЈЈЈ", "ККККК", "ЛЛЛЛЛ", "ЉЉЉЉЉ", "МММММ", "ННННН", "ЊЊЊЊЊ", "ООООО", "ППППП", "РРРРР",
	]))
	var factory := SessionFactory.new(FakeRandomSource.new())
	var progress := ProgressService.new(repository, pool, factory)
	var coordinator := GameCoordinator.new(progress, factory, ShareService.new(FakeClipboard.new()), pool)
	return {
		"repository": repository,
		"pool": pool,
		"factory": factory,
		"progress": progress,
		"coordinator": coordinator,
	}
