class_name WordPool
extends RefCounted


const ALPHABET := "АБВГДЂЕЖЗИЈКЛЉМНЊОПРСТЋУФХЦЧЏШ"

var _answers: PackedStringArray = PackedStringArray()
var _members: Dictionary = {}


static func from_entries(entries: PackedStringArray) -> WordPool:
	var result := WordPool.new()
	for raw in entries:
		var word := raw.strip_edges().to_upper()
		if _is_valid_word(word) and not result._members.has(word):
			result._members[word] = true
			result._answers.append(word)
	return result


func contains(word: String) -> bool:
	return _members.has(word.strip_edges().to_upper())


func answers() -> PackedStringArray:
	return _answers


func fingerprint() -> String:
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update("\n".join(_answers).to_utf8_buffer())
	return hasher.finish().hex_encode()


static func _is_valid_word(word: String) -> bool:
	if word.length() != 5:
		return false
	for letter in word:
		if not ALPHABET.contains(letter):
			return false
	return true
