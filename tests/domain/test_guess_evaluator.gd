extends GutTest


func test_exact_match_marks_every_letter_correct() -> void:
	assert_eq(_marks("ЖИВОТ", "ЖИВОТ"), [2, 2, 2, 2, 2])


func test_present_letters_are_consumed_only_once() -> void:
	assert_eq(_marks("ААААА", "АВАЛА"), [2, 0, 2, 0, 2])


func test_exact_pass_has_priority_over_present_pass() -> void:
	assert_eq(_marks("АБАБА", "БАБАА"), [1, 1, 1, 1, 2])


func test_zero_matches_are_absent() -> void:
	assert_eq(_marks("АБВГД", "ЕЖЗИЈ"), [0, 0, 0, 0, 0])


func test_anagram_marks_each_letter_present_when_no_position_matches() -> void:
	assert_eq(_marks("АБВГД", "БВГДА"), [1, 1, 1, 1, 1])


func test_duplicate_guess_letters_do_not_exceed_answer_occurrences() -> void:
	assert_eq(_marks("ААБВГ", "ЖАБВГ"), [0, 2, 2, 2, 2])


func test_serbian_compound_letters_are_single_characters() -> void:
	assert_eq(_marks("ЉЊЏАБ", "ЏЊЉАБ"), [1, 2, 1, 2, 2])


func test_guess_row_exposes_a_copy_of_its_marks() -> void:
	var row := GuessEvaluator.evaluate("ЖИВОТ", "ЖИВОТ")
	assert_eq(row.guess(), "ЖИВОТ")
	var marks := row.marks()
	marks[0] = LetterMark.Value.ABSENT
	assert_eq(row.marks(), [2, 2, 2, 2, 2])


func _marks(guess: String, answer: String) -> Array:
	return GuessEvaluator.evaluate(guess, answer).marks()
