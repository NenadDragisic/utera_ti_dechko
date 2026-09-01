class_name AppRoot
extends Control


signal game_requested(mode: int)
signal statistics_requested
signal settings_requested
signal new_game_confirmation_requested


const HOME_SCREEN_SCENE := preload("res://features/home/home_screen.tscn")
const GAME_SCREEN_SCENE := preload("res://features/gameplay/game_screen.tscn")
const RESULTS_VIEW_SCENE := preload("res://features/results/results_view.tscn")
const STATISTICS_VIEW_SCENE := preload("res://features/results/statistics_view.tscn")
const SETTINGS_VIEW_SCENE := preload("res://features/settings/settings_view.tscn")
const CONFIRM_NEW_GAME_DIALOG_SCENE := preload(
	"res://features/settings/confirm_new_game_dialog.tscn"
)
const DARK_THEME := preload("res://app/app_theme.tres")
const LIGHT_THEME := preload("res://app/app_theme_light.tres")
const REQUIRED_ANSWER_COUNT := SessionFactory.BUNDLE_ANSWER_COUNT


var word_repository: BazaWordRepository
var save_repository: SaveRepositoryPort
var save_repository_override: SaveRepositoryPort
var random_source: GodotRandomSource
var clipboard: ClipboardPort
var clipboard_override: ClipboardPort
var platform_capabilities: PlatformCapabilities
var platform_capabilities_override: PlatformCapabilities
var session_factory: SessionFactory
var progress_service: ProgressService
var share_service: ShareService
var coordinator: GameCoordinator
var current_screen: Control
var _statistics_filter: int = 0
var _confirmation_dialog: ConfirmNewGameDialog

@onready var _screen_container: Control = $SafeArea/Layout/ScreenContainer
@onready var _new_game_button: Button = $SafeArea/Layout/Footer/NewGameButton
@onready var _notice_banner: NoticeBanner = $NoticeBanner


func _ready() -> void:
	set_process_unhandled_key_input(true)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	word_repository = BazaWordRepository.new()
	var pool := word_repository.load_pool()
	start(pool, word_repository.last_error)


func _process(delta: float) -> void:
	if progress_service != null and progress_service.dirty:
		progress_service.tick(delta)


func start(pool: WordPool, pool_error: String = "") -> void:
	coordinator = null
	progress_service = null
	share_service = null
	if pool == null or pool.answers().size() < REQUIRED_ANSWER_COUNT:
		_show_fatal_startup(pool, pool_error)
		return

	save_repository = (
		save_repository_override
		if save_repository_override != null
		else UserSaveRepository.new()
	)
	random_source = GodotRandomSource.new()
	clipboard = (
		clipboard_override
		if clipboard_override != null
		else GodotClipboardAdapter.new()
	)
	platform_capabilities = PlatformCapabilities.new()
	if platform_capabilities_override != null:
		platform_capabilities = platform_capabilities_override
	session_factory = SessionFactory.new(random_source)
	progress_service = ProgressService.new(save_repository, pool, session_factory)
	share_service = ShareService.new(clipboard)
	coordinator = GameCoordinator.new(progress_service, session_factory, share_service, pool)
	coordinator.state_changed.connect(_on_state_changed)
	coordinator.notice_requested.connect(_notice_banner.show_message)
	coordinator.confirmation_requested.connect(_on_confirmation_requested)

	_show_home()
	coordinator.launch()
	if coordinator.bundle == null or not coordinator.bundle.is_valid():
		_show_fatal_startup(pool, "Није могуће направити почетни сноп игара.")
		coordinator = null
		progress_service = null
		return
	var platform_warning := platform_capabilities.persistence_warning()
	if not platform_warning.is_empty():
		_notice_banner.show_message(platform_warning)


func set_screen(screen: Control, defer_previous_free: bool = false) -> void:
	if current_screen != null:
		_screen_container.remove_child(current_screen)
		if defer_previous_free:
			current_screen.queue_free()
		else:
			current_screen.free()
	current_screen = screen
	_screen_container.add_child(current_screen)
	current_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _show_home(defer_previous_free: bool = false) -> void:
	var home: HomeScreen = HOME_SCREEN_SCENE.instantiate()
	home.mode_selected.connect(_on_mode_selected)
	home.statistics_requested.connect(_on_statistics_requested)
	home.settings_requested.connect(_on_settings_requested)
	home.combined_share_requested.connect(_on_combined_share_requested)
	set_screen(home, defer_previous_free)


func _show_game() -> void:
	var game: GameScreen = GAME_SCREEN_SCENE.instantiate()
	game.letter_typed.connect(_on_game_letter_typed)
	game.erase_requested.connect(_on_game_erase_requested)
	game.submit_requested.connect(_on_game_submit_requested)
	game.mode_selected.connect(_on_game_mode_selected)
	# A HomeScreen button signal is still executing while this route changes.
	# Queueing only that outgoing screen avoids freeing a signal-locked object.
	set_screen(game, true)
	var onscreen_keyboard := coordinator != null and coordinator.settings.onscreen_keyboard
	game.set_mobile_layout(
		platform_capabilities.is_mobile_layout(get_viewport_rect().size) or onscreen_keyboard
	)


func _show_results() -> void:
	var results: ResultsView = RESULTS_VIEW_SCENE.instantiate()
	results.copy_requested.connect(_on_result_copy_requested)
	results.mode_selected.connect(_on_result_mode_selected)
	results.home_requested.connect(_on_result_home_requested)
	set_screen(results, true)
	_render_results_screen()


func _show_statistics() -> void:
	var statistics_view: StatisticsView = STATISTICS_VIEW_SCENE.instantiate()
	statistics_view.filter_selected.connect(_on_statistics_filter_selected)
	statistics_view.home_requested.connect(_on_statistics_home_requested)
	set_screen(statistics_view, true)
	_render_statistics_screen()


func _show_settings() -> void:
	var settings_view: SettingsView = SETTINGS_VIEW_SCENE.instantiate()
	settings_view.settings_changed.connect(_on_settings_changed)
	settings_view.home_requested.connect(_on_settings_home_requested)
	set_screen(settings_view, true)
	_render_settings_screen()


func _show_fatal_startup(pool: WordPool, detail: String) -> void:
	var available := 0 if pool == null else pool.answers().size()
	var fatal := CenterContainer.new()
	fatal.name = "FatalStartup"
	var message := Label.new()
	message.name = "Message"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.text = (
		"Покретање није могуће: потребно је најмање %d исправних речи, доступно је %d."
		% [REQUIRED_ANSWER_COUNT, available]
	)
	if not detail.is_empty():
		message.text += "\n" + detail
	fatal.add_child(message)
	set_screen(fatal)


func _on_state_changed() -> void:
	if coordinator == null:
		return
	_apply_settings_preferences()
	if current_screen is HomeScreen:
		var home := current_screen as HomeScreen
		home.render(coordinator.active_mode, _mode_summaries())
	elif current_screen is GameScreen:
		var session := coordinator.active_session()
		if session != null and session.status != GameSession.Status.ACTIVE:
			_show_results()
		else:
			_render_game_screen()
	elif current_screen is ResultsView:
		_render_results_screen()
	elif current_screen is StatisticsView:
		_render_statistics_screen()
	elif current_screen is SettingsView:
		_render_settings_screen()


func _render_game_screen() -> void:
	if coordinator == null or not current_screen is GameScreen:
		return
	var game := current_screen as GameScreen
	var reduced_motion := coordinator.settings != null and coordinator.settings.reduced_motion
	game.render(coordinator.active_session(), coordinator.active_mode, reduced_motion)


func _render_results_screen() -> void:
	if coordinator == null or share_service == null or not current_screen is ResultsView:
		return
	var session := coordinator.active_session()
	var share_text := share_service.mode_text(coordinator.bundle, coordinator.active_mode)
	(current_screen as ResultsView).render(session, coordinator.active_mode, share_text)


func _render_statistics_screen() -> void:
	if coordinator == null or not current_screen is StatisticsView:
		return
	(current_screen as StatisticsView).render(coordinator.statistics, _statistics_filter)


func _render_settings_screen() -> void:
	if coordinator == null or not current_screen is SettingsView:
		return
	(current_screen as SettingsView).render(coordinator.settings)


func _apply_settings_preferences() -> void:
	if coordinator == null or coordinator.settings == null:
		return
	theme = _theme_for_preference(coordinator.settings.theme)
	if current_screen is GameScreen and platform_capabilities != null:
		var game := current_screen as GameScreen
		game.set_mobile_layout(
			platform_capabilities.is_mobile_layout(get_viewport_rect().size)
			or coordinator.settings.onscreen_keyboard
		)


func _theme_for_preference(preference: Settings.ThemePreference) -> Theme:
	match preference:
		Settings.ThemePreference.DARK:
			return DARK_THEME
		Settings.ThemePreference.LIGHT:
			return LIGHT_THEME
		_:
			if DisplayServer.is_dark_mode_supported() and not DisplayServer.is_dark_mode():
				return LIGHT_THEME
			return DARK_THEME


func _mode_summaries() -> Dictionary:
	var summaries := {}
	if coordinator == null or coordinator.bundle == null:
		return summaries
	for mode in GameCoordinator.MODES:
		var session: GameSession = coordinator.bundle.sessions.get(mode)
		if session == null:
			continue
		summaries[mode] = {
			"status": session.status,
			"score": -1 if session.status == GameSession.Status.ACTIVE else session.score(),
		}
	return summaries


func _on_mode_selected(mode: int) -> void:
	if coordinator == null:
		return
	_show_game()
	if coordinator.active_mode != mode:
		if not coordinator.switch_mode(mode):
			_show_home()
			_on_state_changed()
			return
	else:
		_render_game_screen()
	game_requested.emit(mode)


func _on_game_letter_typed(letter: String) -> void:
	if coordinator != null:
		coordinator.type_letter(letter)


func _on_game_erase_requested() -> void:
	if coordinator != null:
		coordinator.erase()


func _on_game_submit_requested() -> void:
	if coordinator != null:
		coordinator.submit()


func _on_game_mode_selected(mode: int) -> void:
	if coordinator != null:
		coordinator.switch_mode(mode)


func _on_result_copy_requested(text: String) -> void:
	if share_service == null or not current_screen is ResultsView:
		return
	var results := current_screen as ResultsView
	if share_service.copy(text):
		results.show_copy_success()
		_notice_banner.show_message("Резултат је копиран.")
	else:
		results.show_share_fallback(text)


func _on_result_mode_selected(mode: int) -> void:
	if coordinator == null or not coordinator.switch_mode(mode):
		return
	var session := coordinator.active_session()
	if session != null and session.status == GameSession.Status.ACTIVE:
		_show_game()
	else:
		_show_results()


func _on_result_home_requested() -> void:
	_show_home(true)
	_on_state_changed()


func _on_statistics_requested() -> void:
	statistics_requested.emit()
	_statistics_filter = 0
	_show_statistics()


func _on_statistics_filter_selected(mode: int) -> void:
	_statistics_filter = mode
	_render_statistics_screen()


func _on_statistics_home_requested() -> void:
	_show_home(true)
	_on_state_changed()


func _on_settings_requested() -> void:
	settings_requested.emit()
	_show_settings()


func _on_settings_changed(value: Settings) -> void:
	if coordinator == null or value == null:
		return
	coordinator.set_settings(value.theme, value.reduced_motion, value.onscreen_keyboard)


func _on_settings_home_requested() -> void:
	_show_home(true)
	_on_state_changed()


func _on_combined_share_requested() -> void:
	if coordinator == null or share_service == null:
		return
	var share_text := share_service.combined_text(coordinator.bundle)
	if share_service.copy(share_text):
		_notice_banner.show_message("Резултат је копиран.")
	else:
		_show_manual_share(share_text)


func _show_manual_share(text: String) -> void:
	var results: ResultsView = RESULTS_VIEW_SCENE.instantiate()
	results.copy_requested.connect(_on_result_copy_requested)
	results.mode_selected.connect(_on_result_mode_selected)
	results.home_requested.connect(_on_result_home_requested)
	set_screen(results, true)
	results.render(null, coordinator.active_mode, "")
	results.show_share_fallback(text)


func _on_new_game_pressed() -> void:
	if coordinator != null and coordinator.request_new_bundle():
		_show_home()
		_on_state_changed()


func _on_confirmation_requested() -> void:
	new_game_confirmation_requested.emit()
	if _confirmation_dialog != null:
		return
	_confirmation_dialog = CONFIRM_NEW_GAME_DIALOG_SCENE.instantiate()
	_confirmation_dialog.confirmed.connect(_on_new_game_confirmed)
	_confirmation_dialog.cancelled.connect(_on_new_game_cancelled)
	add_child(_confirmation_dialog)
	_confirmation_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(_confirmation_dialog, get_child_count() - 1)


func _on_new_game_cancelled() -> void:
	_close_confirmation_dialog()


func _on_new_game_confirmed() -> void:
	_close_confirmation_dialog()
	if coordinator != null and coordinator.confirm_new_bundle():
		_show_home()
		_on_state_changed()


func _close_confirmation_dialog() -> void:
	if _confirmation_dialog == null:
		return
	_confirmation_dialog.queue_free()
	_confirmation_dialog = null


func _on_viewport_size_changed() -> void:
	if platform_capabilities == null or not current_screen is GameScreen:
		return
	var game := current_screen as GameScreen
	var onscreen_keyboard := coordinator != null and coordinator.settings.onscreen_keyboard
	game.set_mobile_layout(
		platform_capabilities.is_mobile_layout(get_viewport_rect().size) or onscreen_keyboard
	)
