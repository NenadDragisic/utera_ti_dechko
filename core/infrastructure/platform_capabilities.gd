class_name PlatformCapabilities
extends RefCounted


const MOBILE_WEB_MAX_WIDTH := 720.0


func is_mobile_layout(viewport_size: Vector2) -> bool:
	var platform_name := _platform_name()
	return platform_name == "Android" or (
		platform_name == "Web"
		and _touchscreen_available()
		and viewport_size.x < MOBILE_WEB_MAX_WIDTH
	)


func persistence_warning() -> String:
	if _platform_name() == "Web":
		return "У веб прегледачу напредак може бити изгубљен ако трајно чување није доступно."
	return ""


func _platform_name() -> String:
	return OS.get_name()


func _touchscreen_available() -> bool:
	return DisplayServer.is_touchscreen_available()
