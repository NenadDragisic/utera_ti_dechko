class_name GodotRandomSource
extends RandomPort


var _random := RandomNumberGenerator.new()


func _init() -> void:
	_random.randomize()


func shuffle(values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := _random.randi_range(0, index)
		var temporary: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary
