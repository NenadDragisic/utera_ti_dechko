class_name GameBundle
extends RefCounted


enum Error {
	NONE,
	INSUFFICIENT_ANSWERS,
}


var sequence: int
var sessions: Dictionary = {}
var error: int = Error.NONE
var available_answer_count: int = 0


func _init(bundle_sequence: int, mode_sessions: Dictionary = {}) -> void:
	sequence = bundle_sequence
	sessions = mode_sessions


static func insufficient_answers(bundle_sequence: int, available_count: int) -> GameBundle:
	var result := GameBundle.new(bundle_sequence)
	result.error = Error.INSUFFICIENT_ANSWERS
	result.available_answer_count = available_count
	return result


func is_valid() -> bool:
	return error == Error.NONE
