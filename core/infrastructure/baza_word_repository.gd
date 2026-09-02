class_name BazaWordRepository
extends RefCounted


const DATA_PATH := "res://data/baza_words.txt"

var last_error: String = ""


func load_pool() -> WordPool:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		last_error = error_string(FileAccess.get_open_error())
		return WordPool.from_entries(PackedStringArray())

	var entries := file.get_as_text().split("\n", false)
	file.close()
	last_error = ""
	return WordPool.from_entries(entries)
