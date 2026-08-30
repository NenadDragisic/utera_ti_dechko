class_name SessionFactory
extends RefCounted


const BUNDLE_ANSWER_COUNT := 15


var _random: RandomPort


func _init(random: RandomPort) -> void:
	_random = random


func create_bundle(sequence: int, pool: WordPool, bag: AnswerShuffleBag) -> GameBundle:
	var answers := bag.draw(BUNDLE_ANSWER_COUNT, pool, _random)
	if answers.size() != BUNDLE_ANSWER_COUNT:
		return GameBundle.insufficient_answers(sequence, answers.size())

	return GameBundle.new(sequence, {
		1: GameSession.create(answers.slice(0, 1)),
		2: GameSession.create(answers.slice(1, 3)),
		4: GameSession.create(answers.slice(3, 7)),
		8: GameSession.create(answers.slice(7, 15)),
	})
