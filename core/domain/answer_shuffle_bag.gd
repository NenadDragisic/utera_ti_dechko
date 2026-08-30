class_name AnswerShuffleBag
extends RefCounted


var remaining_words: PackedStringArray = PackedStringArray()
var pool_fingerprint: String = ""


func draw(
	count: int,
	pool: WordPool,
	random: RandomPort,
	excluded: PackedStringArray = PackedStringArray(),
) -> PackedStringArray:
	assert(count >= 0)
	var fingerprint := pool.fingerprint()
	if pool_fingerprint != fingerprint:
		_filter_remaining_words(pool, excluded)
		pool_fingerprint = fingerprint

	if remaining_words.size() < count:
		_refill(pool, random, excluded)

	var draw_count := mini(count, remaining_words.size())
	var selected := remaining_words.slice(0, draw_count)
	remaining_words = remaining_words.slice(draw_count)
	return selected


func _filter_remaining_words(pool: WordPool, excluded: PackedStringArray) -> void:
	var filtered := PackedStringArray()
	var seen: Dictionary = {}
	var excluded_words: Dictionary = {}
	for word in excluded:
		excluded_words[word] = true
	for word in remaining_words:
		if pool.contains(word) and not excluded_words.has(word) and not seen.has(word):
			seen[word] = true
			filtered.append(word)
	remaining_words = filtered


func _refill(pool: WordPool, random: RandomPort, excluded: PackedStringArray) -> void:
	var unavailable: Dictionary = {}
	for word in remaining_words:
		unavailable[word] = true
	for word in excluded:
		unavailable[word] = true

	var candidates: Array = []
	for word in pool.answers():
		if not unavailable.has(word):
			candidates.append(word)
	random.shuffle(candidates)
	for word in candidates:
		remaining_words.append(word)
