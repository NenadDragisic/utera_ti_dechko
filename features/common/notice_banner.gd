class_name NoticeBanner
extends Control


signal dismissed


var _message_label: Label
var _dismiss_button: Button


func _ready() -> void:
	_configure()
	visible = false


func _configure() -> void:
	if _message_label == null:
		_message_label = get_node("TopMargin/Panel/Layout/Message") as Label
	if _dismiss_button == null:
		_dismiss_button = get_node(
			"TopMargin/Panel/Layout/DismissButton"
		) as Button
	accessibility_live = AccessibilityServer.LIVE_POLITE
	_dismiss_button.accessibility_name = "Затвори обавештење"
	if not _dismiss_button.pressed.is_connected(dismiss):
		_dismiss_button.pressed.connect(dismiss)


func show_message(message: String) -> void:
	_configure()
	if message.is_empty():
		dismiss()
		return
	_message_label.text = message
	accessibility_name = "Обавештење: %s" % message
	visible = true


func dismiss() -> void:
	if not visible:
		return
	visible = false
	dismissed.emit()
