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


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(text)
	file.close()


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
