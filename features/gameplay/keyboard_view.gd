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
const ROW_DRAG_THRESHOLD := 8.0


var collapsed: bool = false
var reduced_motion: bool = false
var collapse_animation_enabled: bool = false

var _collapse_tween: Tween
var _expanded_height: float = 44.0
var _tracked_row_pointer: int = -1
var _tracked_row: ScrollContainer
var _row_pointer_start := Vector2.ZERO
var _row_scroll_start: int = 0
var _row_pointer_moved: bool = false

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
		var scroll: ScrollContainer = get_node(
			"SheetContent/Content/Rows/Row%d" % (row_index + 1)
		)
		var row: HBoxContainer = scroll.get_node("Keys")
		scroll.gui_input.connect(_on_row_gui_input.bind(scroll))
		for letter in KEY_ROWS[row_index]:
			var button := Button.new()
			button.name = "Key_%s" % letter
			button.text = letter
			button.custom_minimum_size = MINIMUM_TARGET_SIZE
			button.focus_mode = Control.FOCUS_ALL
			# The row owns pointer gestures so a drag that begins over a key can
			# scroll. Buttons remain keyboard/screen-reader activatable through
			# their pressed signal; row taps activate the hit-tested key below.
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_to_group("keyboard_letters")
			button.pressed.connect(letter_pressed.emit.bind(letter))
			row.add_child(button)


func _on_row_gui_input(event: InputEvent, row: ScrollContainer) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_row_pointer(touch.index, row, touch.position)
			row.accept_event()
		elif touch.index == _tracked_row_pointer and row == _tracked_row:
			_finish_row_pointer(row, touch.position)
			row.accept_event()
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _tracked_row_pointer and row == _tracked_row:
			_update_row_pointer(row, drag.position)
			row.accept_event()
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			_begin_row_pointer(0, row, mouse_button.position)
		else:
			_finish_row_pointer(row, mouse_button.position)
		row.accept_event()
		return
	if (
		event is InputEventMouseMotion
		and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT
		and row == _tracked_row
	):
		_update_row_pointer(row, (event as InputEventMouseMotion).position)
		row.accept_event()


func _begin_row_pointer(pointer: int, row: ScrollContainer, position: Vector2) -> void:
	if _tracked_row_pointer != -1:
		return
	_tracked_row_pointer = pointer
	_tracked_row = row
	_row_pointer_start = position
	_row_scroll_start = row.scroll_horizontal
	_row_pointer_moved = false


func _update_row_pointer(row: ScrollContainer, position: Vector2) -> void:
	var travel := position - _row_pointer_start
	if travel.length() > ROW_DRAG_THRESHOLD:
		_row_pointer_moved = true
	if absf(travel.x) <= ROW_DRAG_THRESHOLD or absf(travel.x) <= absf(travel.y):
		return
	row.scroll_horizontal = _row_scroll_start - roundi(travel.x)


func _finish_row_pointer(row: ScrollContainer, position: Vector2) -> void:
	if row != _tracked_row:
		return
	_update_row_pointer(row, position)
	if not _row_pointer_moved:
		_emit_row_key_at(row, position)
	_tracked_row_pointer = -1
	_tracked_row = null


func _emit_row_key_at(row: ScrollContainer, position: Vector2) -> void:
	var content_x := position.x + row.scroll_horizontal
	var keys := row.get_node("Keys") as HBoxContainer
	for child in keys.get_children():
		var button := child as Button
		if (
			content_x >= button.position.x
			and content_x <= button.position.x + button.size.x
			and position.y >= button.position.y
			and position.y <= button.position.y + button.size.y
		):
			letter_pressed.emit(button.text)
			return


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
