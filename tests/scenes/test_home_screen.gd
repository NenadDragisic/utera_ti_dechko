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
	assert_true(home.get_node("Center") is ScrollContainer)
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


func test_home_content_is_centered_in_the_desktop_root() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	add_child_autofree(viewport)
	var root: AppRoot = load("res://app/app_root.tscn").instantiate()
	root.save_repository_override = MemorySaveRepository.new()
	viewport.add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	var home := root.current_screen as HomeScreen
	var usable_area := home.get_node("Center") as Control
	var content := home.get_node("Center/Content") as Control
	assert_almost_eq(
		content.get_global_rect().get_center().x,
		usable_area.get_global_rect().get_center().x,
		1.0,
		"The menu content must be horizontally centered in the usable area.",
	)
	assert_almost_eq(
		content.get_global_rect().get_center().y,
		usable_area.get_global_rect().get_center().y,
		1.0,
		"The menu content must be vertically centered in the usable area.",
	)
	assert_almost_eq(
		home.get_node("Center/Content/ModeCards").get_global_rect().get_center().x,
		usable_area.get_global_rect().get_center().x,
		1.0,
		"The visible mode row must be centered, not only its parent bounds.",
	)


func test_home_manual_share_fallback_is_selectable_stacked_and_result_neutral() -> void:
	var scene: PackedScene = load(HOME_SCENE_PATH)
	assert_not_null(scene)
	if scene == null:
		return
	var home: Control = scene.instantiate()
	add_child_autofree(home)
	home.show_share_fallback("УТЕРА ТИ ДЕЧКО #3")
	await get_tree().process_frame

	var fallback: PanelContainer = home.get_node("Center/Content/ShareFallback")
	var layout: VBoxContainer = fallback.get_node("FallbackLayout")
	var guidance: Label = layout.get_node("Guidance")
	var share_text: TextEdit = layout.get_node("ShareText")
	assert_true(fallback.visible)
	assert_same(guidance.get_parent(), layout)
	assert_same(share_text.get_parent(), layout)
	assert_lte(guidance.global_position.y + guidance.size.y, share_text.global_position.y)
	assert_false(share_text.editable)
	assert_true(share_text.selecting_enabled)
	assert_eq(share_text.text, "УТЕРА ТИ ДЕЧКО #3")
	assert_false(_tree_contains_name(home, "Score"))
	assert_false(_tree_contains_name(home, "Answers"))


func test_home_manual_share_fallback_is_visible_and_selectable_at_844_by_390() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(844, 390)
	add_child_autofree(viewport)
	var root: AppRoot = load("res://app/app_root.tscn").instantiate()
	root.save_repository_override = MemorySaveRepository.new()
	viewport.add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame
	var home := root.current_screen as HomeScreen
	home.show_share_fallback("УТЕРА ТИ ДЕЧКО #3\n1: ⬛⬛⬛⬛⬛")
	await get_tree().process_frame
	await get_tree().process_frame

	var content_viewport := home.get_node("Center") as Control
	var content := home.get_node("Center/Content") as Control
	var share_text := home.get_node(
		"Center/Content/ShareFallback/FallbackLayout/ShareText"
	) as TextEdit
	var viewport_rect := content_viewport.get_global_rect()
	var share_rect := share_text.get_global_rect()
	var physical_rect := Rect2(Vector2.ZERO, Vector2(viewport.size))
	assert_almost_eq(
		content.get_global_rect().get_center().x,
		content_viewport.get_global_rect().get_center().x,
		8.0,
	)
	assert_gte(share_rect.position.y, viewport_rect.position.y)
	assert_lte(share_rect.end.y, viewport_rect.end.y)
	assert_gte(share_rect.position.y, physical_rect.position.y)
	assert_lte(share_rect.end.y, physical_rect.end.y)
	assert_true(share_text.has_selection())
	assert_true(share_text.selecting_enabled)
	assert_true(content_viewport is ScrollContainer)
	assert_gt((content_viewport as ScrollContainer).scroll_vertical, 0)


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


func _tree_contains_name(node: Node, node_name: String) -> bool:
	if node.name == node_name:
		return true
	for child in node.get_children():
		if _tree_contains_name(child, node_name):
			return true
	return false
