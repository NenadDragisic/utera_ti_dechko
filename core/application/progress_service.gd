class_name ProgressService
extends RefCounted


const SCHEMA_VERSION := 1
const DEBOUNCE_SECONDS := 0.35
const MODES := [1, 2, 4, 8]


class LoadResult extends RefCounted:
	var bundle: GameBundle
	var settings: Settings
	var statistics: Statistics
	var bag: AnswerShuffleBag
	var restored: bool
	var warning: String

	func _init(
		loaded_bundle: GameBundle,
		loaded_settings: Settings,
		loaded_statistics: Statistics,
		loaded_bag: AnswerShuffleBag,
		was_restored: bool,
		load_warning: String,
	) -> void:
		bundle = loaded_bundle
		settings = loaded_settings
		statistics = loaded_statistics
		bag = loaded_bag
		restored = was_restored
		warning = load_warning


var bundle: GameBundle
var settings: Settings = Settings.new()
var statistics: Statistics = Statistics.new()
var bag: AnswerShuffleBag = AnswerShuffleBag.new()
var dirty: bool = false
var last_error: Error = OK

var _repository: SaveRepositoryPort
var _pool: WordPool
var _factory: SessionFactory
var _debounce_elapsed: float = 0.0


func _init(repository: SaveRepositoryPort, pool: WordPool, factory: SessionFactory) -> void:
	_repository = repository
	_pool = pool
	_factory = factory


func load_or_create() -> LoadResult:
	var loaded := _repository.load_text()
	if not _valid_load_envelope(loaded):
		return _fresh_result("Чување није могло да се учита.")
	var load_error: Error = loaded["error"]
	if load_error != OK:
		last_error = load_error
		return _fresh_result("Чување није могло да се учита: %s" % error_string(load_error))
	if not loaded["found"]:
		return _fresh_result("")

	var raw: String = loaded["text"]
	var parser := JSON.new()
	if parser.parse(raw) != OK:
		return _recover(raw, "Сачувани напредак није исправан.")
	var document: Variant = parser.data
	if typeof(document) != TYPE_DICTIONARY:
		return _recover(raw, "Сачувани напредак није исправан.")
	var validation_error := _validate_document(document)
	if not validation_error.is_empty():
		return _recover(raw, validation_error)

	_hydrate_document(document)
	var saved_fingerprint: String = document["pool_fingerprint"]
	var needs_persist := false
	if saved_fingerprint != _pool.fingerprint():
		_reconcile_current_inputs()
		_factory.reconcile_bag(_pool, bag, _active_answers(bundle))
		needs_persist = true

	if _record_unrecorded_completed_sessions():
		needs_persist = true
	var result := _result(true, "")
	if needs_persist:
		dirty = true
		var save_error := flush_now()
		if save_error != OK:
			result.warning = "Напредак је учитан, али усклађено стање није сачувано: %s" % error_string(save_error)
	return result


func mark_dirty() -> void:
	dirty = true
	_debounce_elapsed = 0.0


func flush_now() -> Error:
	if bundle == null or not bundle.is_valid():
		dirty = true
		last_error = ERR_UNCONFIGURED
		return last_error
	var json := JSON.stringify(_encode_document())
	var save_error := _repository.save_text(json)
	last_error = save_error
	_debounce_elapsed = 0.0
	if save_error == OK:
		dirty = false
	else:
		dirty = true
	return save_error


func tick(delta: float) -> void:
	if not dirty or delta <= 0.0:
		return
	_debounce_elapsed += delta
	if _debounce_elapsed + 0.000001 >= DEBOUNCE_SECONDS:
		flush_now()


func _valid_load_envelope(loaded: Variant) -> bool:
	return (
		typeof(loaded) == TYPE_DICTIONARY
		and loaded.has("error")
		and _is_integer(loaded["error"])
		and loaded.has("found")
		and typeof(loaded["found"]) == TYPE_BOOL
		and loaded.has("text")
		and typeof(loaded["text"]) == TYPE_STRING
	)


func _validate_document(document: Dictionary) -> String:
	if not _has_keys(document, ["schema_version", "pool_fingerprint", "sequence", "bundle", "settings", "statistics", "bag"]):
		return "Сачуваном напретку недостају обавезна поља."
	if not _is_integer(document["schema_version"]) or int(document["schema_version"]) != SCHEMA_VERSION:
		return "Верзија сачуваног напретка није подржана."
	if typeof(document["pool_fingerprint"]) != TYPE_STRING or document["pool_fingerprint"].is_empty():
		return "Отисак речника није исправан."
	if not _is_integer(document["sequence"]) or int(document["sequence"]) < 1:
		return "Редни број игре није исправан."
	if typeof(document["bundle"]) != TYPE_DICTIONARY:
		return "Сноп игара није исправан."
	if typeof(document["settings"]) != TYPE_DICTIONARY:
		return "Подешавања нису исправна."
	if typeof(document["statistics"]) != TYPE_DICTIONARY:
		return "Статистика није исправна."
	if typeof(document["bag"]) != TYPE_DICTIONARY:
		return "Врећа одговора није исправна."

	var settings_error := _validate_settings(document["settings"])
	if not settings_error.is_empty():
		return settings_error
	var statistics_error := _validate_statistics(document["statistics"])
	if not statistics_error.is_empty():
		return statistics_error
	var active_answers := PackedStringArray()
	var bundle_error := _validate_bundle(
		document["bundle"],
		active_answers,
		document["pool_fingerprint"] == _pool.fingerprint(),
	)
	if not bundle_error.is_empty():
		return bundle_error
	var bag_error := _validate_bag(document["bag"], document["pool_fingerprint"], active_answers)
	if not bag_error.is_empty():
		return bag_error
	return _validate_statistics_coherence(document)


func _validate_settings(data: Dictionary) -> String:
	if not _has_keys(data, ["theme", "reduced_motion", "onscreen_keyboard"]):
		return "Подешавањима недостају обавезна поља."
	if not _is_integer(data["theme"]) or not [0, 1, 2].has(int(data["theme"])):
		return "Тема није исправна."
	if typeof(data["reduced_motion"]) != TYPE_BOOL or typeof(data["onscreen_keyboard"]) != TYPE_BOOL:
		return "Подешавања приступачности нису исправна."
	return ""


func _validate_statistics(data: Dictionary) -> String:
	if not _has_keys(data, ["score_counts", "score_counts_by_mode", "recorded_session_ids"]):
		return "Статистици недостају обавезна поља."
	if not _valid_count_array(data["score_counts"]):
		return "Укупни резултати нису исправни."
	if typeof(data["score_counts_by_mode"]) != TYPE_DICTIONARY:
		return "Резултати по режиму нису исправни."
	for mode in MODES:
		if not data["score_counts_by_mode"].has(str(mode)) or not _valid_count_array(data["score_counts_by_mode"][str(mode)]):
			return "Резултати режима %d нису исправни." % mode
	if typeof(data["recorded_session_ids"]) != TYPE_ARRAY:
		return "Списак забележених игара није исправан."
	var seen: Dictionary = {}
	for session_id in data["recorded_session_ids"]:
		if typeof(session_id) != TYPE_STRING or session_id.is_empty() or seen.has(session_id):
			return "Идентификатор забележене игре није исправан."
		seen[session_id] = true
	return ""


func _validate_bundle(
	data: Dictionary,
	active_answers: PackedStringArray,
	validate_current_input: bool,
) -> String:
	if not _has_keys(data, ["sessions"]) or typeof(data["sessions"]) != TYPE_DICTIONARY:
		return "Сесије нису исправне."
	var sessions: Dictionary = data["sessions"]
	if sessions.size() != MODES.size():
		return "Сачувани сноп нема сва четири режима."
	var seen_answers: Dictionary = {}
	for mode in MODES:
		var mode_key := str(mode)
		if not sessions.has(mode_key) or typeof(sessions[mode_key]) != TYPE_DICTIONARY:
			return "Сесија режима %d није исправна." % mode
		var session_error := _validate_session(
			sessions[mode_key],
			mode,
			seen_answers,
			active_answers,
			validate_current_input,
		)
		if not session_error.is_empty():
			return session_error
	return ""


func _validate_session(
	data: Dictionary,
	mode: int,
	seen_answers: Dictionary,
	active_answers: PackedStringArray,
	validate_current_input: bool,
) -> String:
	var required := ["current_input", "input_is_invalid", "attempt_index", "attempt_limit", "status", "statistics_recorded", "boards"]
	if not _has_keys(data, required):
		return "Сесији режима %d недостају обавезна поља." % mode
	if typeof(data["current_input"]) != TYPE_STRING or not _valid_input(data["current_input"]):
		return "Унос режима %d није исправан." % mode
	if typeof(data["input_is_invalid"]) != TYPE_BOOL or typeof(data["statistics_recorded"]) != TYPE_BOOL:
		return "Ознаке сесије режима %d нису исправне." % mode
	if validate_current_input:
		var expected_invalid: bool = (
			data["current_input"].length() == 5
			and not _pool.contains(data["current_input"])
		)
		if data["input_is_invalid"] != expected_invalid:
			return "Ознака исправности уноса режима %d није у складу са речником." % mode
	if not _is_integer(data["attempt_index"]) or not _is_integer(data["attempt_limit"]) or not _is_integer(data["status"]):
		return "Број покушаја режима %d није исправан." % mode
	var attempt_index := int(data["attempt_index"])
	var attempt_limit := int(data["attempt_limit"])
	var status := int(data["status"])
	if attempt_limit != GameSession.ATTEMPT_LIMITS[mode] or attempt_index < 0 or attempt_index > attempt_limit:
		return "Ограничење покушаја режима %d није исправно." % mode
	if not [GameSession.Status.ACTIVE, GameSession.Status.WON, GameSession.Status.LOST].has(status):
		return "Статус режима %d није исправан." % mode
	if typeof(data["boards"]) != TYPE_ARRAY or data["boards"].size() != mode:
		return "Број табли режима %d није исправан." % mode

	var all_solved := true
	for board_data in data["boards"]:
		var board_error := _validate_board(board_data, attempt_index, seen_answers, active_answers)
		if not board_error.is_empty():
			return board_error
		if not board_data["is_solved"]:
			all_solved = false
	var expected_status := GameSession.Status.ACTIVE
	if all_solved:
		expected_status = GameSession.Status.WON
	elif attempt_index >= attempt_limit:
		expected_status = GameSession.Status.LOST
	if status != expected_status:
		return "Статус режима %d није у складу са таблама." % mode
	if status != GameSession.Status.ACTIVE and (not data["current_input"].is_empty() or data["input_is_invalid"]):
		return "Завршена сесија режима %d садржи активан унос." % mode
	return ""


func _validate_board(
	data: Variant,
	attempt_index: int,
	seen_answers: Dictionary,
	active_answers: PackedStringArray,
) -> String:
	if typeof(data) != TYPE_DICTIONARY or not _has_keys(data, ["answer", "rows", "is_solved", "solved_attempt"]):
		return "Табла није исправна."
	var answer: Variant = data["answer"]
	if typeof(answer) != TYPE_STRING or not WordPool._is_valid_word(answer) or not _pool.contains(answer) or seen_answers.has(answer):
		return "Активни одговор није у тренутном речнику."
	seen_answers[answer] = true
	active_answers.append(answer)
	if typeof(data["rows"]) != TYPE_ARRAY or typeof(data["is_solved"]) != TYPE_BOOL or not _is_integer(data["solved_attempt"]):
		return "Стање табле није исправно."
	if data["rows"].size() > attempt_index:
		return "Табла има превише редова."
	for row_data in data["rows"]:
		var row_error := _validate_row(row_data, answer)
		if not row_error.is_empty():
			return row_error
	var solved_attempt := int(data["solved_attempt"])
	if data["is_solved"]:
		if data["rows"].is_empty() or solved_attempt != data["rows"].size() - 1 or data["rows"][-1]["guess"] != answer:
			return "Решена табла нема исправан завршни ред."
	else:
		if solved_attempt != -1 or data["rows"].size() != attempt_index:
			return "Нерешена табла има недоследно стање."
		for row_data in data["rows"]:
			if row_data["guess"] == answer:
				return "Нерешена табла садржи решење."
	return ""


func _validate_row(data: Variant, answer: String) -> String:
	if typeof(data) != TYPE_DICTIONARY or not _has_keys(data, ["guess", "marks"]):
		return "Ред покушаја није исправан."
	if typeof(data["guess"]) != TYPE_STRING or not WordPool._is_valid_word(data["guess"]):
		return "Реч у покушају није исправна."
	if typeof(data["marks"]) != TYPE_ARRAY or data["marks"].size() != 5:
		return "Оцене слова нису исправне."
	for mark in data["marks"]:
		if not _is_integer(mark) or not [LetterMark.Value.ABSENT, LetterMark.Value.PRESENT, LetterMark.Value.CORRECT].has(int(mark)):
			return "Оцена слова није исправна."
	var expected_marks := GuessEvaluator.marks_for(data["guess"], answer)
	for index in range(expected_marks.size()):
		if int(data["marks"][index]) != int(expected_marks[index]):
			return "Оцене слова нису у складу са покушајем и одговором."
	return ""


func _validate_bag(
	data: Dictionary,
	saved_fingerprint: String,
	active_answers: PackedStringArray,
) -> String:
	if not _has_keys(data, ["remaining_words", "pool_fingerprint"]):
		return "Врећи одговора недостају обавезна поља."
	if typeof(data["remaining_words"]) != TYPE_ARRAY or typeof(data["pool_fingerprint"]) != TYPE_STRING:
		return "Врећа одговора није исправна."
	if data["pool_fingerprint"] != saved_fingerprint:
		return "Отисци речника се не подударају."
	var seen: Dictionary = {}
	for word in data["remaining_words"]:
		if typeof(word) != TYPE_STRING or not WordPool._is_valid_word(word) or seen.has(word):
			return "Преостали одговор у врећи није исправан."
		if active_answers.has(word):
			return "Врећа одговора садржи активни одговор."
		if saved_fingerprint == _pool.fingerprint() and not _pool.contains(word):
			return "Преостали одговор није у тренутном речнику."
		seen[word] = true
	return ""


func _validate_statistics_coherence(document: Dictionary) -> String:
	var statistics_data: Dictionary = document["statistics"]
	var recorded_ids: Array = statistics_data["recorded_session_ids"]
	var total_records := 0
	for score in range(Statistics.SCORE_BUCKET_COUNT):
		var per_mode_total := 0
		for mode in MODES:
			per_mode_total += int(statistics_data["score_counts_by_mode"][str(mode)][score])
		if per_mode_total != int(statistics_data["score_counts"][score]):
			return "Укупна статистика није у складу са режимима."
		total_records += per_mode_total
	if total_records != recorded_ids.size():
		return "Број забележених игара није у складу са статистиком."

	for mode in MODES:
		var session_data: Dictionary = document["bundle"]["sessions"][str(mode)]
		var expected_id := _session_id(int(document["sequence"]), mode)
		var has_record: bool = recorded_ids.has(expected_id)
		if int(session_data["status"]) == GameSession.Status.ACTIVE and (session_data["statistics_recorded"] or has_record):
			return "Активна сесија режима %d не сме бити забележена у статистици." % mode
		if session_data["statistics_recorded"] != has_record:
			return "Ознака статистике режима %d није у складу са забележеним играма." % mode
		if has_record:
			var expected_score := 0
			if int(session_data["status"]) == GameSession.Status.WON:
				expected_score = 6 + mode - int(session_data["attempt_index"])
			if int(statistics_data["score_counts_by_mode"][str(mode)][expected_score]) < 1:
				return "Резултат режима %d није у одговарајућој статистичкој групи." % mode
	return ""


func _hydrate_document(document: Dictionary) -> void:
	settings = Settings.new()
	settings.theme = int(document["settings"]["theme"])
	settings.reduced_motion = document["settings"]["reduced_motion"]
	settings.onscreen_keyboard = document["settings"]["onscreen_keyboard"]

	statistics = Statistics.new()
	statistics.score_counts = _packed_counts(document["statistics"]["score_counts"])
	for mode in MODES:
		statistics.score_counts_by_mode[mode] = _packed_counts(document["statistics"]["score_counts_by_mode"][str(mode)])
	for session_id in document["statistics"]["recorded_session_ids"]:
		statistics.recorded_session_ids[session_id] = true

	bag = AnswerShuffleBag.new()
	bag.remaining_words = PackedStringArray(document["bag"]["remaining_words"])
	bag.pool_fingerprint = document["bag"]["pool_fingerprint"]

	var sessions: Dictionary[int, GameSession] = {}
	for mode in MODES:
		var session_data: Dictionary = document["bundle"]["sessions"][str(mode)]
		var answers := PackedStringArray()
		for board_data in session_data["boards"]:
			answers.append(board_data["answer"])
		var session := GameSession.create(answers)
		for board_index in range(session.boards.size()):
			var board: BoardState = session.boards[board_index]
			var board_data: Dictionary = session_data["boards"][board_index]
			for row_index in range(board_data["rows"].size()):
				var row_data: Dictionary = board_data["rows"][row_index]
				var marks: Array[LetterMark.Value] = []
				for mark in row_data["marks"]:
					marks.append(int(mark) as LetterMark.Value)
				board._append_row(GuessRow.new(row_data["guess"], marks), row_index)
		session.current_input = session_data["current_input"]
		session.input_is_invalid = session_data["input_is_invalid"]
		session.attempt_index = int(session_data["attempt_index"])
		session.status = int(session_data["status"])
		session.statistics_recorded = session_data["statistics_recorded"]
		sessions[mode] = session
	bundle = GameBundle.new(int(document["sequence"]), sessions)


func _record_unrecorded_completed_sessions() -> bool:
	var changed := false
	for mode in MODES:
		var session: GameSession = bundle.sessions[mode]
		if session.status == GameSession.Status.ACTIVE or session.statistics_recorded:
			continue
		statistics.record(mode, session.score(), _session_id(bundle.sequence, mode))
		session.statistics_recorded = true
		changed = true
	return changed


func _reconcile_current_inputs() -> void:
	for mode in MODES:
		var session: GameSession = bundle.sessions[mode]
		session.input_is_invalid = (
			session.current_input.length() == 5
			and not _pool.contains(session.current_input)
		)


func _encode_document() -> Dictionary:
	var session_documents: Dictionary = {}
	for mode in MODES:
		session_documents[str(mode)] = _encode_session(bundle.sessions[mode])
	var mode_counts: Dictionary = {}
	for mode in MODES:
		mode_counts[str(mode)] = _int_array(statistics.score_counts_by_mode[mode])
	var recorded_ids: Array = statistics.recorded_session_ids.keys()
	recorded_ids.sort()
	return {
		"schema_version": SCHEMA_VERSION,
		"pool_fingerprint": _pool.fingerprint(),
		"sequence": bundle.sequence,
		"bundle": {"sessions": session_documents},
		"settings": {
			"theme": settings.theme,
			"reduced_motion": settings.reduced_motion,
			"onscreen_keyboard": settings.onscreen_keyboard,
		},
		"statistics": {
			"score_counts": _int_array(statistics.score_counts),
			"score_counts_by_mode": mode_counts,
			"recorded_session_ids": recorded_ids,
		},
		"bag": {
			"remaining_words": Array(bag.remaining_words),
			"pool_fingerprint": bag.pool_fingerprint,
		},
	}


func _encode_session(session: GameSession) -> Dictionary:
	var boards: Array = []
	for board in session.boards:
		var rows: Array = []
		for row in board.rows:
			rows.append({"guess": row.guess(), "marks": _int_array(row.marks())})
		boards.append({
			"answer": board.answer,
			"rows": rows,
			"is_solved": board.is_solved,
			"solved_attempt": board.solved_attempt,
		})
	return {
		"current_input": session.current_input,
		"input_is_invalid": session.input_is_invalid,
		"attempt_index": session.attempt_index,
		"attempt_limit": session.attempt_limit,
		"status": session.status,
		"statistics_recorded": session.statistics_recorded,
		"boards": boards,
	}


func _recover(raw: String, warning: String) -> LoadResult:
	var preserve_error := _repository.preserve_corrupt(raw)
	if preserve_error != OK:
		last_error = preserve_error
		warning += " Резервна копија није направљена: %s" % error_string(preserve_error)
	return _fresh_result(warning)


func _fresh_result(warning: String) -> LoadResult:
	settings = Settings.new()
	statistics = Statistics.new()
	bag = AnswerShuffleBag.new()
	bundle = _factory.create_bundle(1, _pool, bag)
	dirty = false
	_debounce_elapsed = 0.0
	return _result(false, warning)


func _result(restored: bool, warning: String) -> LoadResult:
	return LoadResult.new(bundle, settings, statistics, bag, restored, warning)


func _active_answers(active_bundle: GameBundle) -> PackedStringArray:
	var answers := PackedStringArray()
	for mode in MODES:
		for board in active_bundle.sessions[mode].boards:
			answers.append(board.answer)
	return answers


func _session_id(sequence: int, mode: int) -> String:
	return "bundle-%d-mode-%d" % [sequence, mode]


func _valid_count_array(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY or value.size() != Statistics.SCORE_BUCKET_COUNT:
		return false
	for count in value:
		if not _is_integer(count) or int(count) < 0:
			return false
	return true


func _valid_input(value: String) -> bool:
	if value.length() > 5:
		return false
	for letter in value:
		if not WordPool.ALPHABET.contains(letter):
			return false
	return true


func _packed_counts(values: Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	for value in values:
		result.append(int(value))
	return result


func _int_array(values: Variant) -> Array:
	var result: Array = []
	for value in values:
		result.append(int(value))
	return result


func _has_keys(data: Dictionary, keys: Array) -> bool:
	for key in keys:
		if not data.has(key):
			return false
	return true


func _is_integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and value == floor(value))
