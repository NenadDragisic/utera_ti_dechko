class_name ResultsView
extends Control


signal copy_requested(text: String)
signal mode_selected(mode: int)
signal home_requested


const MODES := [1, 2, 4, 8]


var _share_text: String = ""

@onready var _answers: VBoxContainer = $Center/Content/Answers
@onready var _share_button: Button = $Center/Content/ShareButton
@onready var _share_fallback: PanelContainer = $Center/Content/ShareFallback


func _ready() -> void:
	_share_button.pressed.connect(_on_share_pressed)
	$Center/Content/HomeButton.pressed.connect(home_requested.emit)
	for mode in MODES:
		_mode_button(mode).pressed.connect(mode_selected.emit.bind(mode))


func render(session: GameSession, active_mode: int, share_text: String) -> void:
	_clear_answers()
	_share_text = ""
	_share_fallback.visible = false
	for mode in MODES:
		var button := _mode_button(mode)
		button.button_pressed = mode == active_mode
		button.disabled = mode == active_mode
	$Center/Content/Mode.text = "РЕЖИМ · %d" % active_mode
	if session == null or session.status == GameSession.Status.ACTIVE:
		$Center/Content/Score.text = "—/6"
		_share_button.visible = false
		return

	$Center/Content/Score.text = "%d/6" % session.score()
	_share_text = share_text
	_share_button.visible = not share_text.is_empty()
	for index in range(session.boards.size()):
		_add_answer(index, session.boards[index])


func show_share_fallback(text: String) -> void:
	var share_text: TextEdit = _share_fallback.get_node("ShareText")
	share_text.text = text
	_share_fallback.visible = true
	share_text.select_all()


func show_copy_success() -> void:
	_share_fallback.visible = false


func _on_share_pressed() -> void:
	if not _share_text.is_empty():
		copy_requested.emit(_share_text)


func _add_answer(index: int, board: BoardState) -> void:
	var row := PanelContainer.new()
	row.name = "Board%d" % index
	row.custom_minimum_size = Vector2(0, DesignTokens.MINIMUM_TOUCH_TARGET)
	var state := "solved" if board.is_solved else "missed"
	row.set_meta("answer_state", state)
	row.modulate = (
		_semantic_color(&"success", DesignTokens.MINT_SUCCESS)
		if board.is_solved
		else _semantic_color(&"invalid", DesignTokens.RED_INVALID)
	)
	var answer := Label.new()
	answer.name = "Answer"
	answer.text = "%d.  %s  ·  %s" % [
		index + 1,
		board.answer,
		"РЕШЕНА" if board.is_solved else "ПРОМАШЕНА",
	]
	answer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	answer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(answer)
	_answers.add_child(row)


func _clear_answers() -> void:
	for child in _answers.get_children():
		_answers.remove_child(child)
		child.free()


func _mode_button(mode: int) -> Button:
	return get_node("Center/Content/ContinueModes/Mode%d" % mode) as Button


func _semantic_color(color_name: StringName, fallback: Color) -> Color:
	if has_theme_color(color_name, &"DesignTokens"):
		return get_theme_color(color_name, &"DesignTokens")
	return fallback
