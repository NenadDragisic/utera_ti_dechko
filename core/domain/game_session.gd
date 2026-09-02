class_name GameSession
extends RefCounted


enum Status {
	ACTIVE,
	WON,
	LOST,
}


const ATTEMPT_LIMITS := {
	1: 6,
	2: 7,
	4: 9,
	8: 13,
}


var current_input: String = ""
var input_is_invalid: bool = false
var attempt_index: int = 0
var attempt_limit: int = 0
var status: int = Status.ACTIVE
var boards: Array[BoardState] = []
var statistics_recorded: bool = false


static func create(answers: PackedStringArray) -> GameSession:
	assert(ATTEMPT_LIMITS.has(answers.size()))

	var session := GameSession.new()
	session.attempt_limit = ATTEMPT_LIMITS[answers.size()]
	var seen_answers: Dictionary = {}
	for answer in answers:
		assert(WordPool._is_valid_word(answer))
		assert(not seen_answers.has(answer))
		seen_answers[answer] = true
		session.boards.append(BoardState.new(answer))
	return session


func type_letter(letter: String, pool: WordPool) -> bool:
	if status != Status.ACTIVE or current_input.length() >= 5:
		return false
	if letter.length() != 1 or not WordPool.ALPHABET.contains(letter):
		return false

	current_input += letter
	_refresh_input_validity(pool)
	return true


func erase_letter() -> bool:
	if status != Status.ACTIVE or current_input.is_empty():
		return false

	current_input = current_input.left(current_input.length() - 1)
	input_is_invalid = false
	return true


func submit(pool: WordPool) -> bool:
	if status != Status.ACTIVE or current_input.length() != 5:
		return false
	if not pool.contains(current_input):
		input_is_invalid = true
		return false

	for board in boards:
		if board.is_solved:
			continue
		board._append_row(GuessEvaluator.evaluate(current_input, board.answer), attempt_index)

	current_input = ""
	input_is_invalid = false
	attempt_index += 1
	_derive_status()
	return true


func score() -> int:
	if status != Status.WON:
		return 0
	return 6 + boards.size() - attempt_index


func _refresh_input_validity(pool: WordPool) -> void:
	input_is_invalid = current_input.length() == 5 and not pool.contains(current_input)


func _derive_status() -> void:
	for board in boards:
		if not board.is_solved:
			if attempt_index >= attempt_limit:
				status = Status.LOST
			return
	status = Status.WON
