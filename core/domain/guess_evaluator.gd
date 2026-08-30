class_name GuessEvaluator
extends RefCounted


static func evaluate(guess: String, answer: String) -> GuessRow:
	return GuessRow.new(guess, marks_for(guess, answer))


static func marks_for(guess: String, answer: String) -> Array[LetterMark.Value]:
	assert(WordPool._is_valid_word(guess))
	assert(WordPool._is_valid_word(answer))

	var guess_letters: Array[String] = []
	var answer_letters: Array[String] = []
	for letter in guess:
		guess_letters.append(letter)
	for letter in answer:
		answer_letters.append(letter)

	var marks: Array[LetterMark.Value] = []
	var consumed: Array[bool] = []
	for _index in range(answer_letters.size()):
		marks.append(LetterMark.Value.ABSENT)
		consumed.append(false)

	for index in range(guess_letters.size()):
		if guess_letters[index] == answer_letters[index]:
			marks[index] = LetterMark.Value.CORRECT
			consumed[index] = true

	for guess_index in range(guess_letters.size()):
		if marks[guess_index] == LetterMark.Value.CORRECT:
			continue
		for answer_index in range(answer_letters.size()):
			if consumed[answer_index] or guess_letters[guess_index] != answer_letters[answer_index]:
				continue
			marks[guess_index] = LetterMark.Value.PRESENT
			consumed[answer_index] = true
			break

	return marks
