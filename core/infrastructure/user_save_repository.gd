class_name UserSaveRepository
extends SaveRepositoryPort


const DEFAULT_SAVE_PATH := "user://save_v1.json"
const DEFAULT_RECOVERY_PREFIX := "user://save_recovery_"


var last_recovery_path: String = ""

var _save_path: String
var _recovery_prefix: String
var _filesystem: Variant


func _init(
	save_path: String = DEFAULT_SAVE_PATH,
	recovery_prefix: String = DEFAULT_RECOVERY_PREFIX,
	filesystem: Variant = null,
) -> void:
	_save_path = save_path
	_recovery_prefix = recovery_prefix
	_filesystem = filesystem if filesystem != null else RealSaveFileSystem.new()


func load_text() -> Dictionary:
	var source_path := _save_path
	if not _filesystem.exists(source_path):
		var previous_path := _save_path + ".previous"
		if not _filesystem.exists(previous_path):
			return {"error": OK, "found": false, "text": ""}
		source_path = previous_path

	var read_result: Dictionary = _filesystem.read_text(source_path)
	var raw: String = read_result["text"]
	if read_result["error"] != OK:
		return {"error": read_result["error"], "found": true, "text": raw}

	if source_path.ends_with(".previous"):
		var promotion_error: Error = _filesystem.rename_path(source_path, _save_path)
		if promotion_error != OK:
			return {"error": promotion_error, "found": true, "text": raw}
	return {"error": OK, "found": true, "text": raw}


func save_text(json: String) -> Error:
	var temporary_path := _save_path + ".tmp"
	var previous_path := _save_path + ".previous"
	var write_error: Error = _filesystem.write_text(temporary_path, json)
	if write_error != OK:
		_remove_if_present(temporary_path)
		return write_error

	var canonical_exists: bool = _filesystem.exists(_save_path)
	if canonical_exists:
		var stale_previous_error := _remove_if_present(previous_path)
		if stale_previous_error != OK:
			_remove_if_present(temporary_path)
			return stale_previous_error
		var previous_error: Error = _filesystem.rename_path(_save_path, previous_path)
		if previous_error != OK:
			_remove_if_present(temporary_path)
			return previous_error

	var install_error: Error = _filesystem.rename_path(temporary_path, _save_path)
	if install_error != OK:
		if canonical_exists:
			var rollback_error: Error = _filesystem.rename_path(previous_path, _save_path)
			if rollback_error != OK:
				_remove_if_present(temporary_path)
				return rollback_error
		_remove_if_present(temporary_path)
		return install_error

	return _remove_if_present(previous_path)


func preserve_corrupt(raw: String) -> Error:
	last_recovery_path = _next_recovery_path()
	var write_error: Error = _filesystem.write_text(last_recovery_path, raw)
	if write_error != OK:
		_remove_if_present(last_recovery_path)
		last_recovery_path = ""
		return write_error

	var remove_error := _remove_if_present(_save_path)
	if remove_error != OK:
		return remove_error
	return _remove_if_present(_save_path + ".previous")


func _next_recovery_path() -> String:
	var timestamp := str(int(Time.get_unix_time_from_system()))
	var candidate := _recovery_prefix + timestamp + ".json"
	var suffix := 1
	while _filesystem.exists(candidate):
		candidate = _recovery_prefix + timestamp + "_%d.json" % suffix
		suffix += 1
	return candidate


func _remove_if_present(path: String) -> Error:
	if not _filesystem.exists(path):
		return OK
	return _filesystem.remove_path(path)


class RealSaveFileSystem extends RefCounted:
	func exists(path: String) -> bool:
		return FileAccess.file_exists(path)

	func read_text(path: String) -> Dictionary:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return {"error": FileAccess.get_open_error(), "text": ""}
		var text := file.get_as_text()
		var read_error := file.get_error()
		file.close()
		return {"error": read_error, "text": text}

	func write_text(path: String, text: String) -> Error:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()
		file.store_string(text)
		file.flush()
		var write_error := file.get_error()
		file.close()
		return write_error

	func rename_path(from: String, to: String) -> Error:
		return DirAccess.rename_absolute(_absolute(from), _absolute(to))

	func remove_path(path: String) -> Error:
		return DirAccess.remove_absolute(_absolute(path))

	func _absolute(path: String) -> String:
		return ProjectSettings.globalize_path(path)
