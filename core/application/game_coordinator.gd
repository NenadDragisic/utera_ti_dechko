class_name GameCoordinator
extends RefCounted


signal state_changed
signal notice_requested(message: String)
signal confirmation_requested


const MODES := [1, 2, 4, 8]


var bundle: GameBundle
var settings: Settings
var statistics: Statistics
var active_mode: int = 1

var _progress: ProgressService
var _factory: SessionFactory
var _share: ShareService
var _pool: WordPool


func _init(
	progress: ProgressService,
	factory: SessionFactory,
	share: ShareService,
	pool: WordPool,
) -> void:
	_progress = progress
	_factory = factory
	_share = share
	_pool = pool


func launch() -> bool:
	var result := _progress.load_or_create()
	bundle = result.bundle
	settings = result.settings
	statistics = result.statistics
	active_mode = 1
	if not result.warning.is_empty():
		notice_requested.emit(result.warning)
	state_changed.emit()
	return result.restored


func active_session() -> GameSession:
	if bundle == null or not bundle.is_valid() or not bundle.sessions.has(active_mode):
		return null
	return bundle.sessions[active_mode]


func type_letter(letter: String) -> bool:
	var session := active_session()
	if session == null or session.status != GameSession.Status.ACTIVE:
		return false
	if not session.type_letter(letter, _pool):
		return false
	_progress.mark_dirty()
	state_changed.emit()
	return true


func erase() -> bool:
	var session := active_session()
	if session == null or session.status != GameSession.Status.ACTIVE:
		return false
	if not session.erase_letter():
		return false
	_progress.mark_dirty()
	state_changed.emit()
	return true


func submit() -> bool:
	var session := active_session()
	if session == null or session.status != GameSession.Status.ACTIVE:
		return false
	if not session.submit(_pool):
		return false
	if session.status != GameSession.Status.ACTIVE and not session.statistics_recorded:
		var session_id := "bundle-%d-mode-%d" % [bundle.sequence, active_mode]
		if statistics.record(active_mode, session.score(), session_id):
			session.statistics_recorded = true
	_flush_with_notice()
	state_changed.emit()
	return true


func switch_mode(mode: int) -> bool:
	if bundle == null or not bundle.is_valid() or not MODES.has(mode) or mode == active_mode:
		return false
	active_mode = mode
	state_changed.emit()
	return true


func request_new_bundle() -> bool:
	if bundle == null or not bundle.is_valid():
		return false
	if _has_unfinished_progress():
		confirmation_requested.emit()
		return false
	return confirm_new_bundle()


func confirm_new_bundle() -> bool:
	if bundle == null or not bundle.is_valid():
		return false
	var replacement := _factory.create_bundle(bundle.sequence + 1, _pool, _progress.bag)
	if not replacement.is_valid():
		notice_requested.emit(
			"Нова игра није направљена: потребно је 15 одговора, доступно је %d."
			% replacement.available_answer_count
		)
		return false
	bundle = replacement
	_progress.bundle = replacement
	active_mode = 1
	_flush_with_notice()
	state_changed.emit()
	return true


func set_settings(
	theme: Settings.ThemePreference,
	reduced_motion: bool,
	onscreen_keyboard: bool,
) -> bool:
	if settings == null or not [
		Settings.ThemePreference.SYSTEM,
		Settings.ThemePreference.DARK,
		Settings.ThemePreference.LIGHT,
	].has(theme):
		return false
	if (
		settings.theme == theme
		and settings.reduced_motion == reduced_motion
		and settings.onscreen_keyboard == onscreen_keyboard
	):
		return false
	settings.theme = theme
	settings.reduced_motion = reduced_motion
	settings.onscreen_keyboard = onscreen_keyboard
	_flush_with_notice()
	state_changed.emit()
	return true


func _has_unfinished_progress() -> bool:
	for mode in MODES:
		var session: GameSession = bundle.sessions[mode]
		if (
			session.status == GameSession.Status.ACTIVE
			and (session.attempt_index > 0 or not session.current_input.is_empty())
		):
			return true
	return false


func _flush_with_notice() -> void:
	var save_error := _progress.flush_now()
	if save_error != OK:
		notice_requested.emit("Напредак није сачуван: %s" % error_string(save_error))
