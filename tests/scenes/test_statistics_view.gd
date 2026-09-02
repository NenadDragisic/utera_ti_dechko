extends GutTest


const STATISTICS_SCENE_PATH := "res://features/results/statistics_view.tscn"
const STATISTICS_SCRIPT_PATH := "res://features/results/statistics_view.gd"


func test_aggregate_histogram_renders_exactly_seven_score_buckets() -> void:
	var view := _instantiate_statistics_view()
	if view == null:
		return
	var statistics := _statistics_fixture()
	var before := statistics.score_counts.duplicate()

	view.render(statistics, 0)

	var histogram: HBoxContainer = view.get_node("Center/Content/Histogram")
	assert_eq(histogram.get_child_count(), 7)
	var expected := [1, 0, 0, 2, 0, 0, 1]
	for score in range(7):
		var bucket: VBoxContainer = histogram.get_child(score)
		assert_eq(bucket.name, "Bucket%d" % score)
		assert_eq(bucket.get_meta("count"), expected[score])
		assert_eq(bucket.get_node("Count").text, str(expected[score]))
		assert_eq(bucket.get_node("Score").text, str(score))
		assert_gte(bucket.custom_minimum_size.x, 36.0)
	assert_eq(statistics.score_counts, before)


func test_mode_filter_uses_the_requested_per_mode_counts() -> void:
	var view := _instantiate_statistics_view()
	if view == null:
		return
	var statistics := _statistics_fixture()

	view.render(statistics, 2)

	var histogram: HBoxContainer = view.get_node("Center/Content/Histogram")
	var expected := [0, 0, 0, 2, 0, 0, 0]
	for score in range(7):
		assert_eq(histogram.get_child(score).get_meta("count"), expected[score])
	assert_true(view.get_node("Center/Content/Filters/Mode2").button_pressed)
	assert_false(view.get_node("Center/Content/Filters/All").button_pressed)


func test_filter_chips_are_touch_sized_and_emit_a_typed_filter_intent() -> void:
	var view := _instantiate_statistics_view()
	if view == null:
		return
	watch_signals(view)
	var filter_signal := _signal_named(view, "filter_selected")

	assert_eq(filter_signal.args.size(), 1)
	assert_eq(filter_signal.args[0].type, TYPE_INT)
	for button in view.get_node("Center/Content/Filters").get_children():
		assert_gte(button.custom_minimum_size.x, 44.0)
		assert_gte(button.custom_minimum_size.y, 44.0)
	view.get_node("Center/Content/Filters/Mode8").pressed.emit()

	assert_signal_emitted_with_parameters(view, "filter_selected", [8])


func test_app_root_opens_statistics_filters_it_and_returns_home() -> void:
	var root: Control = load("res://app/app_root.tscn").instantiate()
	root.save_repository_override = MemorySaveRepository.new()
	add_child_autofree(root)

	root.current_screen.get_node("Center/Content/Actions/StatisticsButton").pressed.emit()
	await get_tree().process_frame
	assert_eq(root.current_screen.get_script().resource_path, STATISTICS_SCRIPT_PATH)

	root.current_screen.get_node("Center/Content/Filters/Mode4").pressed.emit()
	assert_true(root.current_screen.get_node("Center/Content/Filters/Mode4").button_pressed)
	root.current_screen.get_node("Center/Content/HomeButton").pressed.emit()
	await get_tree().process_frame
	assert_true(root.current_screen is HomeScreen)


func _instantiate_statistics_view() -> Control:
	var scene: PackedScene = load(STATISTICS_SCENE_PATH)
	assert_not_null(scene)
	if scene == null:
		return null
	var view := scene.instantiate()
	add_child_autofree(view)
	return view


func _statistics_fixture() -> Statistics:
	var statistics := Statistics.new()
	assert_true(statistics.record(1, 0, "one"))
	assert_true(statistics.record(2, 3, "two-a"))
	assert_true(statistics.record(2, 3, "two-b"))
	assert_true(statistics.record(8, 6, "eight"))
	return statistics


func _signal_named(object: Object, signal_name: String) -> Dictionary:
	for signal_info in object.get_signal_list():
		if signal_info.name == signal_name:
			return signal_info
	return {}
