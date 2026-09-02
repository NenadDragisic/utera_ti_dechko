class_name FakeClipboard
extends ClipboardPort


var next_result: bool = true
var copied_text: String = ""


func copy(text: String) -> bool:
	copied_text = text
	return next_result
