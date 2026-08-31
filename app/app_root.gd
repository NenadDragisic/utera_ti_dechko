class_name AppRoot
extends Control


signal game_requested(mode: int)
signal statistics_requested
signal settings_requested
signal new_game_confirmation_requested


const HOME_SCREEN_SCENE := preload("res://features/home/home_screen.tscn")
const REQUIRED_ANSWER_COUNT := SessionFactory.BUNDLE_ANSWER_COUNT


var word_repository: BazaWordRepository
var save_repository: SaveRepositoryPort
var save_repository_override: SaveRepositoryPort
var random_source: GodotRandomSource
var clipboard: GodotClipboardAdapter
var platform_capabilities: PlatformCapabilities
var session_factory: SessionFactory
var progress_service: ProgressService
var share_service: ShareService
var coordinator: GameCoordinator
var current_screen: Control

@onready var _screen_container: Control = $SafeArea/Layout/ScreenContainer
@onready var _new_game_button: Button = $SafeArea/Layout/Footer/NewGameButton
@onready var _notice_banner: NoticeBanner = $NoticeBanner


func _ready() -> void:
	set_process_unhandled_key_input(true)
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
	clipboard = GodotClipboardAdapter.new()
	platform_capabilities = PlatformCapabilities.new()
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


func set_screen(screen: Control) -> void:
	if current_screen != null:
		_screen_container.remove_child(current_screen)
		current_screen.free()
	current_screen = screen
	_screen_container.add_child(current_screen)
	current_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _show_home() -> void:
	var home: HomeScreen = HOME_SCREEN_SCENE.instantiate()
	home.mode_selected.connect(_on_mode_selected)
	home.statistics_requested.connect(_on_statistics_requested)
	home.settings_requested.connect(_on_settings_requested)
	home.combined_share_requested.connect(_on_combined_share_requested)
	set_screen(home)


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
	if coordinator == null or not current_screen is HomeScreen:
		return
	var home := current_screen as HomeScreen
	home.render(coordinator.active_mode, _mode_summaries())


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
	if coordinator.active_mode != mode and not coordinator.switch_mode(mode):
		return
	game_requested.emit(mode)


func _on_statistics_requested() -> void:
	statistics_requested.emit()


func _on_settings_requested() -> void:
	settings_requested.emit()


func _on_combined_share_requested() -> void:
	if coordinator == null or share_service == null:
		return
	var share_text := share_service.combined_text(coordinator.bundle)
	if share_service.copy(share_text):
		_notice_banner.show_message("Резултат је копиран.")
	else:
		_notice_banner.show_message("Резултат није могао да се копира.")


func _on_new_game_pressed() -> void:
	if coordinator != null:
		coordinator.request_new_bundle()


func _on_confirmation_requested() -> void:
	new_game_confirmation_requested.emit()
