class_name MemorySaveRepository
extends SaveRepositoryPort


var text: String = ""
var has_save: bool = false
var save_calls: int = 0
var preserved_texts: Array[String] = []
var next_load_error: Error = OK
var next_save_error: Error = OK
var next_preserve_error: Error = OK


func _init(initial_text: String = "") -> void:
	text = initial_text
	has_save = not initial_text.is_empty()


func load_text() -> Dictionary:
	var result_error := next_load_error
	next_load_error = OK
	return {"error": result_error, "found": has_save, "text": text}


func save_text(json: String) -> Error:
	save_calls += 1
	var result_error := next_save_error
	next_save_error = OK
	if result_error == OK:
		text = json
		has_save = true
	return result_error


func preserve_corrupt(raw: String) -> Error:
	var result_error := next_preserve_error
	next_preserve_error = OK
	if result_error == OK:
		preserved_texts.append(raw)
		text = ""
		has_save = false
	return result_error


func reset_tracking() -> void:
	save_calls = 0
	preserved_texts.clear()
