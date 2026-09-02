class_name ConfirmNewGameDialog
extends Control


signal confirmed
signal cancelled


@onready var _cancel_button: Button = $Center/Panel/Content/Actions/CancelButton
@onready var _confirm_button: Button = $Center/Panel/Content/Actions/ConfirmButton


func _ready() -> void:
	_cancel_button.pressed.connect(cancelled.emit)
	_confirm_button.pressed.connect(confirmed.emit)
	_cancel_button.focus_next = _cancel_button.get_path_to(_confirm_button)
	_cancel_button.focus_previous = _cancel_button.get_path_to(_confirm_button)
	_confirm_button.focus_next = _confirm_button.get_path_to(_cancel_button)
	_confirm_button.focus_previous = _confirm_button.get_path_to(_cancel_button)
	_cancel_button.grab_focus()
