extends GutTest


func test_draw_returns_fifteen_unique_answers() -> void:
	var bag := AnswerShuffleBag.new()
	var drawn := bag.draw(15, _pool(20), FakeRandomSource.new())

	assert_eq(drawn.size(), 15)
	assert_eq(_unique_count(drawn), 15)
	assert_eq(drawn, PackedStringArray([
		"ТТТТТ", "ССССС", "РРРРР", "ППППП", "ООООО", "ННННН", "МММММ", "ЛЛЛЛЛ", "ККККК", "ЈЈЈЈЈ",
		"ИИИИИ", "ЗЗЗЗЗ", "ЖЖЖЖЖ", "ЕЕЕЕЕ", "ЂЂЂЂЂ",
	]))


func test_draw_does_not_repeat_before_remaining_words_are_exhausted() -> void:
	var bag := AnswerShuffleBag.new()
	var random := FakeRandomSource.new()
	var pool := _pool(20)
	var first := bag.draw(15, pool, random)
	var second := bag.draw(5, pool, random)

	assert_eq(second, PackedStringArray(["ДДДДД", "ГГГГГ", "ВВВВВ", "БББББ", "ААААА"]))
	assert_eq(_unique_count(first + second), 20)
	assert_eq(random.shuffle_calls, 1)


func test_draw_refills_after_exhaustion() -> void:
	var bag := AnswerShuffleBag.new()
	var random := FakeRandomSource.new()
	var pool := _pool(15)
	var first := bag.draw(15, pool, random)
	var second := bag.draw(15, pool, random)

	assert_eq(second, first)
	assert_eq(random.shuffle_calls, 2)


func test_draw_rebuilds_from_new_pool_after_fingerprint_change() -> void:
	var bag := AnswerShuffleBag.new()
	var random := FakeRandomSource.new()
	bag.draw(15, _pool(20), random)
	var replacement_pool := WordPool.from_entries(PackedStringArray([
		"УУУУУ", "ФФФФФ", "ХХХХХ", "ЦЦЦЦЦ", "ЧЧЧЧЧ", "ЏЏЏЏЏ", "ШШШШШ", "ААААА", "БББББ", "ВВВВВ",
		"ГГГГГ", "ДДДДД", "ЂЂЂЂЂ", "ЕЕЕЕЕ", "ЖЖЖЖЖ",
	]))

	var drawn := bag.draw(15, replacement_pool, random)

	assert_eq(drawn, PackedStringArray([
		"ДДДДД", "ГГГГГ", "ВВВВВ", "БББББ", "ААААА", "ЖЖЖЖЖ", "ЕЕЕЕЕ", "ЂЂЂЂЂ", "ШШШШШ", "ЏЏЏЏЏ",
		"ЧЧЧЧЧ", "ЦЦЦЦЦ", "ХХХХХ", "ФФФФФ", "УУУУУ",
	]))
	assert_eq(bag.pool_fingerprint, replacement_pool.fingerprint())


func test_rebuild_excludes_active_answers() -> void:
	var bag := AnswerShuffleBag.new()
	var pool := _pool(20)
	var excluded := PackedStringArray(["ТТТТТ", "ССССС", "РРРРР", "ППППП", "ООООО"])

	var drawn := bag.draw(15, pool, FakeRandomSource.new(), excluded)

	assert_eq(drawn.size(), 15)
	for answer in excluded:
		assert_false(drawn.has(answer))


func _pool(count: int) -> WordPool:
	return WordPool.from_entries(PackedStringArray([
		"ААААА", "БББББ", "ВВВВВ", "ГГГГГ", "ДДДДД", "ЂЂЂЂЂ", "ЕЕЕЕЕ", "ЖЖЖЖЖ", "ЗЗЗЗЗ", "ИИИИИ",
		"ЈЈЈЈЈ", "ККККК", "ЛЛЛЛЛ", "МММММ", "ННННН", "ООООО", "ППППП", "РРРРР", "ССССС", "ТТТТТ",
	]).slice(0, count))


func _unique_count(values: PackedStringArray) -> int:
	var unique: Dictionary = {}
	for value in values:
		unique[value] = true
	return unique.size()
