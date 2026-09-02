class_name HomeScreen
extends Control


signal mode_selected(mode: int)
signal statistics_requested
signal settings_requested
signal combined_share_requested


const MODES := [1, 2, 4, 8]


@onready var _share_fallback: PanelContainer = $Center/Content/ShareFallback


func _ready() -> void:
	for mode in MODES:
		_mode_button(mode).pressed.connect(_on_mode_pressed.bind(mode))
	$Center/Content/Actions/StatisticsButton.pressed.connect(statistics_requested.emit)
	$Center/Content/Actions/ShareButton.pressed.connect(combined_share_requested.emit)
	$Center/Content/Actions/SettingsButton.pressed.connect(settings_requested.emit)


func render(active_mode: int, summaries: Dictionary) -> void:
	for mode in MODES:
		var button := _mode_button(mode)
		button.button_pressed = mode == active_mode
		button.tooltip_text = _summary_text(summaries.get(mode, {}))
	$Center/Content/Status.text = "ИЗАБРАН РЕЖИМ · %d" % active_mode


func show_share_fallback(text: String) -> void:
	var share_text: TextEdit = _share_fallback.get_node("FallbackLayout/ShareText")
	share_text.text = text
	_share_fallback.visible = true
	share_text.select_all()
	get_tree().process_frame.connect(
		_reveal_share_fallback.bind(share_text),
		CONNECT_ONE_SHOT,
	)


func show_copy_success() -> void:
	_share_fallback.visible = false


func _reveal_share_fallback(share_text: TextEdit) -> void:
	if is_instance_valid(share_text):
		($Center as ScrollContainer).ensure_control_visible(share_text)


func _on_mode_pressed(mode: int) -> void:
	mode_selected.emit(mode)


func _mode_button(mode: int) -> Button:
	return get_node("Center/Content/ModeCards/Mode%d" % mode) as Button


func _summary_text(summary: Dictionary) -> String:
	if summary.is_empty() or not summary.has("status"):
		return "Режим није доступан"
	if summary["status"] == GameSession.Status.ACTIVE:
		return "Игра је у току"
	return "Резултат: %d/6" % int(summary.get("score", 0))
