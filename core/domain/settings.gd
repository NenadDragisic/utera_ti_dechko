class_name Settings
extends RefCounted


enum ThemePreference {
	SYSTEM,
	DARK,
	LIGHT,
}


var theme: int = ThemePreference.SYSTEM
var reduced_motion: bool = false
var onscreen_keyboard: bool = false
