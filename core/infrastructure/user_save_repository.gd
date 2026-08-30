class_name UserSaveRepository
extends SaveRepositoryPort


const DEFAULT_SAVE_PATH := "user://save_v1.json"
const DEFAULT_RECOVERY_PREFIX := "user://save_recovery_"


var last_recovery_path: String = ""

var _save_path: String
var _recovery_prefix: String


func _init(
	save_path: String = DEFAULT_SAVE_PATH,
	recovery_prefix: String = DEFAULT_RECOVERY_PREFIX,
) -> void:
	_save_path = save_path
	_recovery_prefix = recovery_prefix


func load_text() -> Dictionary:
	var source_path := _save_path
	if not FileAccess.file_exists(source_path):
		var previous_path := _save_path + ".previous"
		if not FileAccess.file_exists(previous_path):
			return {"error": OK, "found": false, "text": ""}
		source_path = previous_path

	var file := FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		return {"error": FileAccess.get_open_error(), "found": true, "text": ""}
	var raw := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK:
		return {"error": read_error, "found": true, "text": raw}

	if source_path.ends_with(".previous"):
		DirAccess.rename_absolute(_absolute(source_path), _absolute(_save_path))
	return {"error": OK, "found": true, "text": raw}


func save_text(json: String) -> Error:
	var temporary_path := _save_path + ".tmp"
	var previous_path := _save_path + ".previous"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(json)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		_remove_if_present(temporary_path)
		return write_error

	_remove_if_present(previous_path)
	var moved_previous := false
	if FileAccess.file_exists(_save_path):
		var previous_error := DirAccess.rename_absolute(_absolute(_save_path), _absolute(previous_path))
		if previous_error != OK:
			_remove_if_present(temporary_path)
			return previous_error
		moved_previous = true

	var install_error := DirAccess.rename_absolute(_absolute(temporary_path), _absolute(_save_path))
	if install_error != OK:
		if moved_previous:
			DirAccess.rename_absolute(_absolute(previous_path), _absolute(_save_path))
		_remove_if_present(temporary_path)
		return install_error

	_remove_if_present(previous_path)
	return OK


func preserve_corrupt(raw: String) -> Error:
	last_recovery_path = _next_recovery_path()
	var file := FileAccess.open(last_recovery_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(raw)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		_remove_if_present(last_recovery_path)
		last_recovery_path = ""
		return write_error

	var remove_error := _remove_if_present(_save_path)
	if remove_error != OK:
		return remove_error
	_remove_if_present(_save_path + ".previous")
	return OK


func _next_recovery_path() -> String:
	var timestamp := str(int(Time.get_unix_time_from_system()))
	var candidate := _recovery_prefix + timestamp + ".json"
	var suffix := 1
	while FileAccess.file_exists(candidate):
		candidate = _recovery_prefix + timestamp + "_%d.json" % suffix
		suffix += 1
	return candidate


func _remove_if_present(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(_absolute(path))


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path)
