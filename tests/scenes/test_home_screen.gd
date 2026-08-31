extends GutTest


const HOME_SCENE_PATH := "res://features/home/home_screen.tscn"
const MODES := [1, 2, 4, 8]


func test_home_is_full_rect_container_driven_and_has_four_touch_sized_modes() -> void:
	var scene: PackedScene = load(HOME_SCENE_PATH)
	assert_not_null(scene)
	if scene == null:
		return
	var home: Control = scene.instantiate()
	add_child_autofree(home)

	assert_eq(home.anchor_left, 0.0)
	assert_eq(home.anchor_top, 0.0)
	assert_eq(home.anchor_right, 1.0)
	assert_eq(home.anchor_bottom, 1.0)
	assert_true(home.get_node("Center") is CenterContainer)
	assert_true(home.get_node("Center/Content") is VBoxContainer)
	assert_true(home.get_node("Center/Content/ModeCards") is HBoxContainer)
	assert_lte(home.get_node("Center/Content").get_combined_minimum_size().x, 280.0)

	var cards: HBoxContainer = home.get_node("Center/Content/ModeCards")
	assert_eq(cards.get_child_count(), 4)
	for index in range(MODES.size()):
		var button: Button = cards.get_child(index)
		assert_eq(button.text, str(MODES[index]))
		assert_eq(button.get_meta("mode"), MODES[index])
		assert_gte(button.custom_minimum_size.x, 44.0)
		assert_gte(button.custom_minimum_size.y, 44.0)


func test_home_exposes_typed_intents_and_buttons_emit_them() -> void:
	var scene: PackedScene = load(HOME_SCENE_PATH)
	assert_not_null(scene)
	if scene == null:
		return
	var home: Control = scene.instantiate()
	add_child_autofree(home)
	var mode_signal := _signal_named(home, "mode_selected")

	assert_eq(mode_signal.args.size(), 1)
	assert_eq(mode_signal.args[0].type, TYPE_INT)
	assert_true(home.has_signal("statistics_requested"))
	assert_true(home.has_signal("settings_requested"))
	assert_true(home.has_signal("combined_share_requested"))
	watch_signals(home)

	home.get_node("Center/Content/ModeCards/Mode8").pressed.emit()
	home.get_node("Center/Content/Actions/StatisticsButton").pressed.emit()
	home.get_node("Center/Content/Actions/ShareButton").pressed.emit()
	home.get_node("Center/Content/Actions/SettingsButton").pressed.emit()

	assert_signal_emitted_with_parameters(home, "mode_selected", [8])
	assert_signal_emitted(home, "statistics_requested")
	assert_signal_emitted(home, "combined_share_requested")
	assert_signal_emitted(home, "settings_requested")


func test_home_renders_active_mode_without_retaining_domain_state() -> void:
	var scene: PackedScene = load(HOME_SCENE_PATH)
	assert_not_null(scene)
	if scene == null:
		return
	var home: Control = scene.instantiate()
	add_child_autofree(home)
	var summaries := {
		1: {"status": GameSession.Status.ACTIVE, "score": -1},
		2: {"status": GameSession.Status.WON, "score": 5},
		4: {"status": GameSession.Status.ACTIVE, "score": -1},
		8: {"status": GameSession.Status.LOST, "score": 0},
	}

	home.render(4, summaries)
	summaries[4]["status"] = GameSession.Status.LOST

	assert_true(home.get_node("Center/Content/ModeCards/Mode4").button_pressed)
	assert_false(home.get_node("Center/Content/ModeCards/Mode1").button_pressed)
	assert_eq(home.get_node("Center/Content/Status").text, "ИЗАБРАН РЕЖИМ · 4")
	assert_false(_has_property(home, "mode_summaries"))


func _signal_named(object: Object, signal_name: String) -> Dictionary:
	for signal_info in object.get_signal_list():
		if signal_info.name == signal_name:
			return signal_info
	return {}


func _has_property(object: Object, property_name: String) -> bool:
	for property_info in object.get_property_list():
		if property_info.name == property_name:
			return true
	return false
