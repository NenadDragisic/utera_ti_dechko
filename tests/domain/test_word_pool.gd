extends GutTest


func test_pool_normalizes_rejects_and_deduplicates() -> void:
	var pool := WordPool.from_entries(PackedStringArray([" кућаА ", "КУЋАА", "ABCDE", "КРАТ", "ЖИВОТ"]))
	assert_eq(pool.answers(), PackedStringArray(["КУЋАА", "ЖИВОТ"]))
	assert_true(pool.contains("кућаА"))
	assert_false(pool.contains("ABCDE"))


func test_fingerprint_is_stable_for_equal_normalized_content() -> void:
	var a := WordPool.from_entries(PackedStringArray(["ЖИВОТ", "АВАЛА"]))
	var b := WordPool.from_entries(PackedStringArray(["живот", "авала", "ЖИВОТ"]))
	assert_eq(a.fingerprint(), b.fingerprint())
