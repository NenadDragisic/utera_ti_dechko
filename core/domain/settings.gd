class_name Settings
extends RefCounted


enum Theme {
	SYSTEM,
	DARK,
	LIGHT,
}


var theme: int = Theme.SYSTEM
var reduced_motion: bool = false
var onscreen_keyboard: bool = false
