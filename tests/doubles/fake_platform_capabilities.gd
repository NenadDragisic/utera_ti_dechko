extends PlatformCapabilities


var _test_platform_name: String
var _test_touchscreen_available: bool


func _init(platform_name: String, touchscreen_available: bool) -> void:
	_test_platform_name = platform_name
	_test_touchscreen_available = touchscreen_available


func _platform_name() -> String:
	return _test_platform_name


func _touchscreen_available() -> bool:
	return _test_touchscreen_available
