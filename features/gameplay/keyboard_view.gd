class_name KeyboardView
extends Control


signal letter_pressed(letter: String)
signal erase_pressed
signal submit_pressed
signal collapsed_changed(collapsed: bool)


const KEY_ROWS := [
	"ЉЊЕРТУИОПШ",
	"АСДФГХЈКЛЧ",
	"ЂЖЋЗЏЦВБНМ",
]
const MINIMUM_TARGET_SIZE := Vector2(44, 44)
const COLLAPSE_TWEEN_SECONDS := 0.14


var collapsed: bool = false
var reduced_motion: bool = false
var collapse_animation_enabled: bool = false

var _collapse_tween: Tween
var _expanded_height: float = 44.0

@onready var _reopen_button: Button = $ReopenButton
@onready var _sheet_content: PanelContainer = $SheetContent
@onready var _entry_label: Label = $SheetContent/Content/Header/EntryLabel
@onready var _submit_button: Button = $SheetContent/Content/Header/Actions/SubmitButton


func _ready() -> void:
	_build_letter_rows()
	_reopen_button.pressed.connect(set_collapsed.bind(false))
	$SheetContent/Content/Header/CollapseButton.pressed.connect(set_collapsed.bind(true))
	$SheetContent/Content/Header/Actions/EraseButton.pressed.connect(erase_pressed.emit)
	_submit_button.pressed.connect(_on_submit_pressed)
	_expanded_height = maxf(44.0, _sheet_content.get_combined_minimum_size().y)
	_sheet_content.offset_top = -_expanded_height
	_apply_collapsed_state()


func render(session: GameSession) -> void:
	if session == null:
		_entry_label.text = "_ _ _ _ _"
		_submit_button.disabled = true
		return
	var entry := ""
	for index in range(5):
		entry += session.current_input[index] if index < session.current_input.length() else "_"
		if index < 4:
			entry += " "
	_entry_label.text = entry
	_submit_button.disabled = (
		session.status != GameSession.Status.ACTIVE
		or session.current_input.length() != 5
		or session.input_is_invalid
	)


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if reduced_motion and _collapse_tween != null:
		_collapse_tween.kill()
		_collapse_tween = null
	collapse_animation_enabled = false
	if is_node_ready():
		_set_height(_target_height())


func set_collapsed(value: bool) -> void:
	if collapsed == value:
		return
	collapsed = value
	collapse_animation_enabled = not reduced_motion
	_apply_collapsed_state()
	collapsed_changed.emit(collapsed)


func _build_letter_rows() -> void:
	for row_index in range(KEY_ROWS.size()):
		var row: HBoxContainer = get_node(
			"SheetContent/Content/Rows/Row%d/Keys" % (row_index + 1)
		)
		for letter in KEY_ROWS[row_index]:
			var button := Button.new()
			button.name = "Key_%s" % letter
			button.text = letter
			button.custom_minimum_size = MINIMUM_TARGET_SIZE
			button.focus_mode = Control.FOCUS_ALL
			button.add_to_group("keyboard_letters")
			button.pressed.connect(letter_pressed.emit.bind(letter))
			row.add_child(button)


func _apply_collapsed_state() -> void:
	if not is_node_ready():
		return
	if _collapse_tween != null:
		_collapse_tween.kill()
		_collapse_tween = null
	_sheet_content.visible = not collapsed
	_reopen_button.visible = collapsed
	var target_height := _target_height()
	if reduced_motion:
		_set_height(target_height)
		return
	_collapse_tween = create_tween()
	_collapse_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_collapse_tween.tween_property(
		self,
		"custom_minimum_size:y",
		target_height,
		COLLAPSE_TWEEN_SECONDS,
	)


func _target_height() -> float:
	return 44.0 if collapsed else _expanded_height


func _set_height(value: float) -> void:
	custom_minimum_size.y = value


func _on_submit_pressed() -> void:
	if _submit_button.disabled:
		return
	set_collapsed(true)
	submit_pressed.emit()
