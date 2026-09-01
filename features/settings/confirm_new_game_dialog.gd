class_name ConfirmNewGameDialog
extends Control


signal confirmed
signal cancelled


func _ready() -> void:
	$Center/Panel/Content/Actions/CancelButton.pressed.connect(cancelled.emit)
	$Center/Panel/Content/Actions/ConfirmButton.pressed.connect(confirmed.emit)
