class_name FakeRandomSource
extends RandomPort


var shuffle_calls: int = 0


func shuffle(values: Array) -> void:
	shuffle_calls += 1
	values.reverse()
