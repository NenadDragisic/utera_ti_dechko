class_name HomeScreen
extends Control


signal mode_selected(mode: int)
signal statistics_requested
signal settings_requested
signal combined_share_requested


const MODES := [1, 2, 4, 8]


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
