class_name GuessRow
extends RefCounted


var _guess: String
var _marks: Array[LetterMark.Value]


func _init(guess: String, marks: Array[LetterMark.Value]) -> void:
	_guess = guess
	_marks = marks.duplicate()


func guess() -> String:
	return _guess


func marks() -> Array[LetterMark.Value]:
	return _marks.duplicate()
