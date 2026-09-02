class_name GodotClipboardAdapter
extends ClipboardPort


func copy(text: String) -> bool:
	DisplayServer.clipboard_set(text)
	if OS.get_name() == "Web":
		return DisplayServer.clipboard_get() == text
	return true
