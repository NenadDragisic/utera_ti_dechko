class_name BoardState
extends RefCounted


var answer: String
var rows: Array[GuessRow] = []
var is_solved: bool = false
var solved_attempt: int = -1


func _init(board_answer: String) -> void:
	answer = board_answer


func _append_row(row: GuessRow, attempt: int) -> void:
	rows.append(row)
	if row.guess() == answer:
		is_solved = true
		solved_attempt = attempt
