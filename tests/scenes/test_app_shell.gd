extends GutTest


const APP_ROOT_SCENE_PATH := "res://app/app_root.tscn"
const NOTICE_BANNER_SCENE_PATH := "res://features/common/notice_banner.tscn"
const DARK_THEME_PATH := "res://app/app_theme.tres"
const LIGHT_THEME_PATH := "res://app/app_theme_light.tres"
const ICON_PATH := "res://icon.svg"


func test_shell_uses_full_rect_container_layout_and_exact_brand_copy() -> void:
	var scene: PackedScene = load(APP_ROOT_SCENE_PATH)
	assert_not_null(scene)
	if scene == null:
		return
	var root: Control = autofree(scene.instantiate())

	assert_eq(root.anchor_left, 0.0)
	assert_eq(root.anchor_top, 0.0)
	assert_eq(root.anchor_right, 1.0)
	assert_eq(root.anchor_bottom, 1.0)
	assert_true(root.get_node("SafeArea") is MarginContainer)
	assert_true(root.get_node("SafeArea/Layout") is VBoxContainer)
	assert_eq(root.get_node("SafeArea/Layout/Header/Title").text, "УТЕРА ТИ ДЕЧКО")
	assert_eq(
		root.get_node("SafeArea/Layout/Footer/Attribution").text,
		"Ставља у погон: ПрслаФабрика",
	)
	assert_eq(root.get_node("SafeArea/Layout/Footer/NewGameButton").text, "НОВА ИГРА")
	assert_true(root.get_node("SafeArea/Layout/ScreenContainer") is Control)

	var visible_copy := _collect_text(root)
	assert_false(visible_copy.contains("Физичка тастатура активна"))
	assert_false(visible_copy.contains("Куцајте на физичкој тастатури"))
	assert_false(visible_copy.contains("Valid five-letter word"))
	assert_false(visible_copy.contains("Invalid five-letter word"))


func test_shell_starts_real_dependencies_and_routes_home_mode_intent() -> void:
	var scene: PackedScene = load(APP_ROOT_SCENE_PATH)
	assert_not_null(scene)
	if scene == null:
		return
	var root: Control = scene.instantiate()
	var save_repository := MemorySaveRepository.new()
	root.save_repository_override = save_repository
	add_child_autofree(root)

	assert_not_null(root.word_repository)
	assert_same(root.save_repository, save_repository)
	assert_not_null(root.progress_service)
	assert_not_null(root.share_service)
	assert_not_null(root.platform_capabilities)
	assert_not_null(root.coordinator)
	assert_not_null(root.current_screen)
	assert_eq(root.get_node("SafeArea/Layout/ScreenContainer").get_child_count(), 1)

	watch_signals(root)
	root.current_screen.get_node("Center/Content/ModeCards/Mode4").pressed.emit()
	await get_tree().process_frame
	assert_eq(root.coordinator.active_mode, 4)
	assert_signal_emitted_with_parameters(root, "game_requested", [4])


func test_shell_ticks_dirty_progress_and_rejects_an_unusable_pool() -> void:
	var scene: PackedScene = load(APP_ROOT_SCENE_PATH)
	assert_not_null(scene)
	if scene == null:
		return
	var root: Control = scene.instantiate()
	root.save_repository_override = MemorySaveRepository.new()
	add_child_autofree(root)

	root.progress_service.mark_dirty()
	root._process(ProgressService.DEBOUNCE_SECONDS)
	assert_false(root.progress_service.dirty)

	var replaced_home: Control = root.current_screen
	root.start(WordPool.from_entries(PackedStringArray()), "missing test data")
	assert_null(root.coordinator)
	assert_false(is_instance_valid(replaced_home))
	assert_eq(root.get_node("SafeArea/Layout/ScreenContainer").get_child_count(), 1)
	assert_true(root.get_node("SafeArea/Layout/ScreenContainer/FatalStartup").visible)
	assert_string_contains(
		root.get_node("SafeArea/Layout/ScreenContainer/FatalStartup/Message").text,
		"15",
	)


func test_notice_banner_reports_copy_without_blocking_pointer_input() -> void:
	var scene: PackedScene = load(NOTICE_BANNER_SCENE_PATH)
	assert_not_null(scene)
	if scene == null:
		return
	var banner: Control = autofree(scene.instantiate())

	assert_eq(banner.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(banner.anchor_right, 1.0)
	assert_eq(banner.anchor_bottom, 1.0)
	banner.show_message("Напредак није сачуван.")
	assert_true(banner.visible)
	assert_eq(
		banner.get_node("TopMargin/Panel/Layout/Message").text,
		"Напредак није сачуван.",
	)
	var dismiss: Button = banner.get_node("TopMargin/Panel/Layout/DismissButton")
	assert_gte(dismiss.custom_minimum_size.x, 44.0)
	assert_gte(dismiss.custom_minimum_size.y, 44.0)
	banner.show_message("Трајно чување није доступно.")
	banner.show_message("Трајно чување није доступно.")
	assert_eq(
		banner.get_node("TopMargin/Panel/Layout/Message").text,
		"Напредак није сачуван.",
	)
	dismiss.pressed.emit()
	assert_true(banner.visible)
	assert_eq(
		banner.get_node("TopMargin/Panel/Layout/Message").text,
		"Трајно чување није доступно.",
	)
	dismiss.pressed.emit()
	assert_false(banner.visible)


func test_themes_expose_semantic_colors_spacing_and_accessible_text_contrast() -> void:
	var dark: Theme = load(DARK_THEME_PATH)
	var light: Theme = load(LIGHT_THEME_PATH)
	assert_not_null(dark)
	assert_not_null(light)
	if dark == null or light == null:
		return

	for semantic_name in ["background", "surface", "action", "success", "present", "invalid", "text", "muted_text"]:
		assert_true(dark.has_color(semantic_name, "DesignTokens"), semantic_name)
		assert_true(light.has_color(semantic_name, "DesignTokens"), semantic_name)
	assert_gte(dark.get_constant("minimum_touch_target", "DesignTokens"), 44)
	assert_gt(dark.get_constant("cell_radius", "DesignTokens"), 0)
	assert_gt(dark.get_constant("space_1", "DesignTokens"), 0)
	assert_gt(dark.get_constant("space_4", "DesignTokens"), dark.get_constant("space_1", "DesignTokens"))
	assert_gte(
		_contrast_ratio(dark.get_color("text", "DesignTokens"), dark.get_color("background", "DesignTokens")),
		4.5,
	)
	assert_gte(
		_contrast_ratio(light.get_color("text", "DesignTokens"), light.get_color("background", "DesignTokens")),
		4.5,
	)


func test_code_native_icon_imports_as_a_square_texture() -> void:
	var icon: Texture2D = load(ICON_PATH)
	assert_not_null(icon)
	if icon != null:
		assert_eq(icon.get_size(), Vector2(512.0, 512.0))


func _collect_text(node: Node) -> String:
	var result := ""
	if node is Label or node is Button:
		result += str(node.text) + "\n"
	for child in node.get_children():
		result += _collect_text(child)
	return result


func _all_controls_ignore_input(node: Node) -> bool:
	if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in node.get_children():
		if not _all_controls_ignore_input(child):
			return false
	return true


func _contrast_ratio(first: Color, second: Color) -> float:
	var brighter := maxf(_relative_luminance(first), _relative_luminance(second))
	var darker := minf(_relative_luminance(first), _relative_luminance(second))
	return (brighter + 0.05) / (darker + 0.05)


func _relative_luminance(color: Color) -> float:
	return (
		0.2126 * _linear_channel(color.r)
		+ 0.7152 * _linear_channel(color.g)
		+ 0.0722 * _linear_channel(color.b)
	)


func _linear_channel(channel: float) -> float:
	if channel <= 0.04045:
		return channel / 12.92
	return pow((channel + 0.055) / 1.055, 2.4)
