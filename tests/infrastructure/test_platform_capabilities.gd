extends GutTest


const FakePlatformCapabilities = preload("res://tests/doubles/fake_platform_capabilities.gd")


func test_android_uses_mobile_layout_at_every_viewport_width() -> void:
	assert_true(_capabilities("Android", false).is_mobile_layout(Vector2(1440, 900)))


func test_touch_capable_narrow_web_uses_mobile_layout() -> void:
	assert_true(_capabilities("Web", true).is_mobile_layout(Vector2(719, 900)))


func test_wide_web_remains_direct_input_layout_even_when_touch_capable() -> void:
	assert_false(_capabilities("Web", true).is_mobile_layout(Vector2(720, 900)))


func test_narrow_web_without_touch_support_remains_direct_input_layout() -> void:
	assert_false(_capabilities("Web", false).is_mobile_layout(Vector2(360, 900)))


func test_only_web_reports_a_persistence_limitation_warning() -> void:
	assert_ne(_capabilities("Web", true).persistence_warning(), "")
	assert_eq(_capabilities("Windows", true).persistence_warning(), "")


func _capabilities(platform_name: String, touchscreen_available: bool) -> PlatformCapabilities:
	return FakePlatformCapabilities.new(platform_name, touchscreen_available)
