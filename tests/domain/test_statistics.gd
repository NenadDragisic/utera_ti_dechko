extends GutTest


func test_record_increments_global_and_per_mode_score_counts() -> void:
	var statistics := Statistics.new()

	assert_true(statistics.record(4, 3, "bundle-5-mode-4"))

	assert_eq(statistics.score_counts[3], 1)
	assert_eq(statistics.score_counts_by_mode[4][3], 1)
	assert_eq(statistics.score_counts_by_mode[1][3], 0)


func test_record_is_idempotent_per_completed_session() -> void:
	var statistics := Statistics.new()
	assert_true(statistics.record(8, 0, "bundle-8-mode-8"))

	assert_false(statistics.record(8, 0, "bundle-8-mode-8"))
	assert_eq(statistics.score_counts[0], 1)
	assert_eq(statistics.score_counts_by_mode[8][0], 1)


func test_record_rejects_unknown_modes_and_out_of_range_scores() -> void:
	var statistics := Statistics.new()

	assert_false(statistics.record(3, 2, "invalid-mode"))
	assert_false(statistics.record(1, -1, "low-score"))
	assert_false(statistics.record(1, 7, "high-score"))
	assert_eq(statistics.score_counts, PackedInt32Array([0, 0, 0, 0, 0, 0, 0]))
