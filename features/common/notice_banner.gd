class_name NoticeBanner
extends Control


func _ready() -> void:
	visible = false


func show_message(message: String) -> void:
	if message.is_empty():
		visible = false
		return
	var message_label: Label = get_node("TopMargin/Panel/Message")
	message_label.text = message
	visible = true
