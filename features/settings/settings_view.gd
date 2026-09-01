class_name SettingsView
extends Control


signal settings_changed(value: Settings)
signal home_requested


var _rendering: bool = false

@onready var _theme_option: OptionButton = $Center/Content/ThemeOption
@onready var _reduced_motion: CheckButton = $Center/Content/ReducedMotion
@onready var _onscreen_keyboard: CheckButton = $Center/Content/OnscreenKeyboard


func _ready() -> void:
	_theme_option.add_item("СИСТЕМСКА", Settings.ThemePreference.SYSTEM)
	_theme_option.add_item("ТАМНА", Settings.ThemePreference.DARK)
	_theme_option.add_item("СВЕТЛА", Settings.ThemePreference.LIGHT)
	_theme_option.item_selected.connect(_on_theme_selected)
	_reduced_motion.toggled.connect(_on_toggle_changed)
	_onscreen_keyboard.toggled.connect(_on_toggle_changed)
	$Center/Content/HomeButton.pressed.connect(home_requested.emit)


func render(value: Settings) -> void:
	if value == null:
		return
	_rendering = true
	_theme_option.select(_theme_option.get_item_index(value.theme))
	_reduced_motion.set_pressed_no_signal(value.reduced_motion)
	_onscreen_keyboard.set_pressed_no_signal(value.onscreen_keyboard)
	_rendering = false


func _on_theme_selected(_index: int) -> void:
	_emit_settings()


func _on_toggle_changed(_pressed: bool) -> void:
	_emit_settings()


func _emit_settings() -> void:
	if _rendering:
		return
	var value := Settings.new()
	value.theme = _theme_option.get_selected_id()
	value.reduced_motion = _reduced_motion.button_pressed
	value.onscreen_keyboard = _onscreen_keyboard.button_pressed
	settings_changed.emit(value)
