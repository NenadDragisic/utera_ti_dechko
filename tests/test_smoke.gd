extends GutTest


func test_app_root_can_be_instantiated() -> void:
	var root: Node = load("res://app/app_root.tscn").instantiate()
	assert_not_null(root)
	root.free()
