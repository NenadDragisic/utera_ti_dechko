class_name NoticeBanner
extends Control


signal dismissed


var _message_label: Label
var _dismiss_button: Button
var _queued_messages: Array[String] = []


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
		clear()
		return
	if visible:
		if message == _message_label.text or _queued_messages.has(message):
			return
		_queued_messages.append(message)
		return
	_present(message)


func clear() -> void:
	_queued_messages.clear()
	visible = false
	accessibility_name = ""


func _present(message: String) -> void:
	_message_label.text = message
	accessibility_name = "Обавештење: %s" % message
	visible = true


func dismiss() -> void:
	if not visible:
		return
	dismissed.emit()
	if not _queued_messages.is_empty():
		_present(_queued_messages.pop_front())
		return
	visible = false
	accessibility_name = ""
