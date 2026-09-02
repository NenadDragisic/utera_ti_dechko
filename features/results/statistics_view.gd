class_name StatisticsView
extends Control


signal filter_selected(mode: int)
signal home_requested


const FILTERS := [0, 1, 2, 4, 8]


@onready var _histogram: HBoxContainer = $Center/Content/Histogram


func _ready() -> void:
	for mode in FILTERS:
		_filter_button(mode).pressed.connect(filter_selected.emit.bind(mode))
	$Center/Content/HomeButton.pressed.connect(home_requested.emit)
	_build_histogram()


func render(statistics: Statistics, selected_mode: int = 0) -> void:
	if statistics == null or not FILTERS.has(selected_mode):
		return
	for mode in FILTERS:
		_filter_button(mode).button_pressed = mode == selected_mode
	var counts: PackedInt32Array = (
		statistics.score_counts
		if selected_mode == 0
		else statistics.score_counts_by_mode[selected_mode]
	)
	var largest := 0
	for count in counts:
		largest = maxi(largest, count)
	for score in range(Statistics.SCORE_BUCKET_COUNT):
		var bucket := _histogram.get_child(score) as VBoxContainer
		var count := counts[score]
		bucket.set_meta("count", count)
		(bucket.get_node("Count") as Label).text = str(count)
		var bar := bucket.get_node("Bar") as ColorRect
		bar.custom_minimum_size.y = 4.0 if largest == 0 else maxf(4.0, 120.0 * count / largest)


func _build_histogram() -> void:
	if _histogram.get_child_count() == Statistics.SCORE_BUCKET_COUNT:
		return
	for score in range(Statistics.SCORE_BUCKET_COUNT):
		var bucket := VBoxContainer.new()
		bucket.name = "Bucket%d" % score
		bucket.custom_minimum_size = Vector2(36, 156)
		bucket.alignment = BoxContainer.ALIGNMENT_END
		bucket.add_theme_constant_override("separation", DesignTokens.SPACE_1)
		var count := Label.new()
		count.name = "Count"
		count.text = "0"
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bucket.add_child(count)
		var bar := ColorRect.new()
		bar.name = "Bar"
		bar.custom_minimum_size = Vector2(0, 4)
		bar.color = _semantic_color(&"action", DesignTokens.MINT_ACTION)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bucket.add_child(bar)
		var score_label := Label.new()
		score_label.name = "Score"
		score_label.text = str(score)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bucket.add_child(score_label)
		_histogram.add_child(bucket)


func _filter_button(mode: int) -> Button:
	var button_name := "All" if mode == 0 else "Mode%d" % mode
	return get_node("Center/Content/Filters/%s" % button_name) as Button


func _semantic_color(color_name: StringName, fallback: Color) -> Color:
	if has_theme_color(color_name, &"DesignTokens"):
		return get_theme_color(color_name, &"DesignTokens")
	return fallback
