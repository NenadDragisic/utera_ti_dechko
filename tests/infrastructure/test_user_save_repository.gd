extends GutTest


var _save_path: String
var _recovery_prefix: String


func before_each() -> void:
	var nonce := "%s_%s" % [Time.get_ticks_usec(), randi()]
	_save_path = "user://task_6_%s.json" % nonce
	_recovery_prefix = "user://task_6_recovery_%s_" % nonce


func after_each() -> void:
	_remove(_save_path)
	_remove(_save_path + ".tmp")
	_remove(_save_path + ".previous")
	var user_dir := DirAccess.open("user://")
	if user_dir == null:
		return
	var prefix_name := _recovery_prefix.get_file()
	for file_name in user_dir.get_files():
		if file_name.begins_with(prefix_name):
			_remove("user://" + file_name)


func test_save_text_atomically_replaces_canonical_and_cleans_transaction_files() -> void:
	var repository := UserSaveRepository.new(_save_path, _recovery_prefix)

	assert_eq(repository.save_text("first"), OK)
	assert_eq(repository.save_text("second"), OK)

	assert_eq(FileAccess.get_file_as_string(_save_path), "second")
	assert_false(FileAccess.file_exists(_save_path + ".tmp"))
	assert_false(FileAccess.file_exists(_save_path + ".previous"))


func test_load_text_uses_previous_copy_when_interrupted_before_canonical_rename() -> void:
	_write(_save_path + ".previous", "recoverable")
	var repository := UserSaveRepository.new(_save_path, _recovery_prefix)

	var loaded := repository.load_text()

	assert_eq(loaded.error, OK)
	assert_true(loaded.found)
	assert_eq(loaded.text, "recoverable")


func test_preserve_corrupt_keeps_raw_bytes_and_removes_incompatible_canonical() -> void:
	_write(_save_path, "{broken")
	var repository := UserSaveRepository.new(_save_path, _recovery_prefix)

	assert_eq(repository.preserve_corrupt("{broken"), OK)

	assert_false(FileAccess.file_exists(_save_path))
	assert_true(FileAccess.file_exists(repository.last_recovery_path))
	assert_eq(FileAccess.get_file_as_string(repository.last_recovery_path), "{broken")


func test_install_and_rollback_failure_preserve_previous_across_successful_retry() -> void:
	var filesystem := FakeSaveFileSystem.new()
	filesystem.files[_save_path] = "durable-old"
	filesystem.fail_rename(_save_path + ".tmp", _save_path, ERR_CANT_CREATE)
	filesystem.fail_rename(_save_path + ".previous", _save_path, ERR_FILE_CANT_WRITE)
	var repository := UserSaveRepository.new(_save_path, _recovery_prefix, filesystem)

	assert_eq(repository.save_text("first-attempt"), ERR_FILE_CANT_WRITE)
	assert_false(filesystem.files.has(_save_path))
	assert_eq(filesystem.files[_save_path + ".previous"], "durable-old")

	assert_eq(repository.save_text("successful-retry"), OK)
	assert_eq(filesystem.files[_save_path], "successful-retry")
	assert_false(filesystem.files.has(_save_path + ".previous"))


func test_load_returns_previous_promotion_error_without_losing_previous() -> void:
	var filesystem := FakeSaveFileSystem.new()
	filesystem.files[_save_path + ".previous"] = "recoverable"
	filesystem.fail_rename(_save_path + ".previous", _save_path, ERR_CANT_CREATE)
	var repository := UserSaveRepository.new(_save_path, _recovery_prefix, filesystem)

	var loaded := repository.load_text()

	assert_eq(loaded.error, ERR_CANT_CREATE)
	assert_true(loaded.found)
	assert_eq(loaded.text, "recoverable")
	assert_eq(filesystem.files[_save_path + ".previous"], "recoverable")


func test_save_returns_canonical_backup_rename_error_and_keeps_canonical() -> void:
	var filesystem := FakeSaveFileSystem.new()
	filesystem.files[_save_path] = "durable-old"
	filesystem.fail_rename(_save_path, _save_path + ".previous", ERR_CANT_CREATE)
	var repository := UserSaveRepository.new(_save_path, _recovery_prefix, filesystem)

	assert_eq(repository.save_text("new"), ERR_CANT_CREATE)
	assert_eq(filesystem.files[_save_path], "durable-old")


func test_install_failure_returns_install_error_after_successful_rollback() -> void:
	var filesystem := FakeSaveFileSystem.new()
	filesystem.files[_save_path] = "durable-old"
	filesystem.fail_rename(_save_path + ".tmp", _save_path, ERR_CANT_CREATE)
	var repository := UserSaveRepository.new(_save_path, _recovery_prefix, filesystem)

	assert_eq(repository.save_text("new"), ERR_CANT_CREATE)
	assert_eq(filesystem.files[_save_path], "durable-old")
	assert_false(filesystem.files.has(_save_path + ".previous"))


func test_post_install_previous_cleanup_error_is_returned_with_both_copies_intact() -> void:
	var filesystem := FakeSaveFileSystem.new()
	filesystem.files[_save_path] = "durable-old"
	filesystem.fail_remove(_save_path + ".previous", ERR_FILE_CANT_WRITE)
	var repository := UserSaveRepository.new(_save_path, _recovery_prefix, filesystem)

	assert_eq(repository.save_text("installed-new"), ERR_FILE_CANT_WRITE)
	assert_eq(filesystem.files[_save_path], "installed-new")
	assert_eq(filesystem.files[_save_path + ".previous"], "durable-old")


func test_stale_previous_cleanup_error_aborts_before_replacing_canonical() -> void:
	var filesystem := FakeSaveFileSystem.new()
	filesystem.files[_save_path] = "durable-current"
	filesystem.files[_save_path + ".previous"] = "older"
	filesystem.fail_remove(_save_path + ".previous", ERR_FILE_CANT_WRITE)
	var repository := UserSaveRepository.new(_save_path, _recovery_prefix, filesystem)

	assert_eq(repository.save_text("new"), ERR_FILE_CANT_WRITE)
	assert_eq(filesystem.files[_save_path], "durable-current")
	assert_eq(filesystem.files[_save_path + ".previous"], "older")


func test_recovery_previous_cleanup_error_is_returned_after_raw_is_preserved() -> void:
	var filesystem := FakeSaveFileSystem.new()
	filesystem.files[_save_path] = "{broken"
	filesystem.files[_save_path + ".previous"] = "older-broken"
	filesystem.fail_remove(_save_path + ".previous", ERR_FILE_CANT_WRITE)
	var repository := UserSaveRepository.new(_save_path, _recovery_prefix, filesystem)

	assert_eq(repository.preserve_corrupt("{broken"), ERR_FILE_CANT_WRITE)

	assert_eq(filesystem.files[repository.last_recovery_path], "{broken")
	assert_false(filesystem.files.has(_save_path))
	assert_eq(filesystem.files[_save_path + ".previous"], "older-broken")


func test_recovery_canonical_cleanup_error_is_returned_after_raw_is_preserved() -> void:
	var filesystem := FakeSaveFileSystem.new()
	filesystem.files[_save_path] = "{broken"
	filesystem.fail_remove(_save_path, ERR_FILE_CANT_WRITE)
	var repository := UserSaveRepository.new(_save_path, _recovery_prefix, filesystem)

	assert_eq(repository.preserve_corrupt("{broken"), ERR_FILE_CANT_WRITE)

	assert_eq(filesystem.files[repository.last_recovery_path], "{broken")
	assert_eq(filesystem.files[_save_path], "{broken")


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(text)
	file.close()


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


class FakeSaveFileSystem extends RefCounted:
	var files: Dictionary = {}
	var _rename_errors: Dictionary = {}
	var _remove_errors: Dictionary = {}

	func exists(path: String) -> bool:
		return files.has(path)

	func read_text(path: String) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "text": ""}
		return {"error": OK, "text": files[path]}

	func write_text(path: String, text: String) -> Error:
		files[path] = text
		return OK

	func rename_path(from: String, to: String) -> Error:
		var operation := from + " -> " + to
		var configured_error := _take_error(_rename_errors, operation)
		if configured_error != OK:
			return configured_error
		if not files.has(from) or files.has(to):
			return ERR_ALREADY_EXISTS if files.has(to) else ERR_FILE_NOT_FOUND
		files[to] = files[from]
		files.erase(from)
		return OK

	func remove_path(path: String) -> Error:
		var configured_error := _take_error(_remove_errors, path)
		if configured_error != OK:
			return configured_error
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func fail_rename(from: String, to: String, error: Error) -> void:
		_queue_error(_rename_errors, from + " -> " + to, error)

	func fail_remove(path: String, error: Error) -> void:
		_queue_error(_remove_errors, path, error)

	func _queue_error(target: Dictionary, operation: String, error: Error) -> void:
		if not target.has(operation):
			target[operation] = []
		target[operation].append(error)

	func _take_error(source: Dictionary, operation: String) -> Error:
		if not source.has(operation) or source[operation].is_empty():
			return OK
		return source[operation].pop_front()
