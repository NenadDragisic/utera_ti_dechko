class_name InputMapper
extends RefCounted


const LATIN_POSITION_MAP := {
	KEY_A: "А", KEY_B: "Б", KEY_V: "В", KEY_G: "Г", KEY_D: "Д",
	KEY_BRACKETRIGHT: "Ђ", KEY_E: "Е", KEY_BACKSLASH: "Ж",
	KEY_Y: "З", KEY_Z: "З", KEY_I: "И", KEY_J: "Ј", KEY_K: "К",
	KEY_L: "Л", KEY_Q: "Љ", KEY_M: "М", KEY_N: "Н", KEY_W: "Њ",
	KEY_O: "О", KEY_P: "П", KEY_R: "Р", KEY_S: "С", KEY_T: "Т",
	KEY_APOSTROPHE: "Ћ", KEY_U: "У", KEY_F: "Ф", KEY_H: "Х",
	KEY_C: "Ц", KEY_SEMICOLON: "Ч", KEY_X: "Џ", KEY_BRACKETLEFT: "Ш",
}


static func map_event(event: InputEventKey) -> String:
	if (
		event == null
		or not event.pressed
		or event.ctrl_pressed
		or event.alt_pressed
		or event.meta_pressed
	):
		return ""
	if LATIN_POSITION_MAP.has(event.physical_keycode):
		return LATIN_POSITION_MAP[event.physical_keycode]
	if event.unicode == 0:
		return ""
	var letter := String.chr(event.unicode).to_upper()
	if letter.length() == 1 and WordPool.ALPHABET.contains(letter):
		return letter
	return ""
