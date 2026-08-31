extends GutTest


const EXPECTED_POSITION_MAP := {
	KEY_A: "А", KEY_B: "Б", KEY_V: "В", KEY_G: "Г", KEY_D: "Д",
	KEY_BRACKETRIGHT: "Ђ", KEY_E: "Е", KEY_BACKSLASH: "Ж",
	KEY_Y: "З", KEY_Z: "З", KEY_I: "И", KEY_J: "Ј", KEY_K: "К",
	KEY_L: "Л", KEY_Q: "Љ", KEY_M: "М", KEY_N: "Н", KEY_W: "Њ",
	KEY_O: "О", KEY_P: "П", KEY_R: "Р", KEY_S: "С", KEY_T: "Т",
	KEY_APOSTROPHE: "Ћ", KEY_U: "У", KEY_F: "Ф", KEY_H: "Х",
	KEY_C: "Ц", KEY_SEMICOLON: "Ч", KEY_X: "Џ", KEY_BRACKETLEFT: "Ш",
}


func test_all_31_physical_positions_map_to_the_reference_serbian_letters() -> void:
	assert_eq(EXPECTED_POSITION_MAP.size(), 31)
	for physical_keycode in EXPECTED_POSITION_MAP:
		var event := _event(physical_keycode, "?")
		assert_eq(InputMapper.map_event(event), EXPECTED_POSITION_MAP[physical_keycode], "physical key %d" % physical_keycode)


func test_physical_position_values_cover_the_exact_30_letter_alphabet() -> void:
	var mapped_letters: Dictionary = {}
	for letter in EXPECTED_POSITION_MAP.values():
		mapped_letters[letter] = true

	assert_eq(mapped_letters.size(), 30)
	for letter in WordPool.ALPHABET:
		assert_true(mapped_letters.has(letter), "missing %s" % letter)
	assert_eq(EXPECTED_POSITION_MAP[KEY_Y], "З")
	assert_eq(EXPECTED_POSITION_MAP[KEY_Z], "З")


func test_direct_cyrillic_unicode_passes_through_uppercased() -> void:
	for uppercase_letter in WordPool.ALPHABET:
		var lowercase_letter: String = uppercase_letter.to_lower()
		assert_eq(InputMapper.map_event(_event(KEY_NONE, lowercase_letter)), uppercase_letter)


func test_modifier_shortcuts_unknown_keys_and_key_releases_are_rejected() -> void:
	var ctrl_event := _event(KEY_A, "а")
	ctrl_event.ctrl_pressed = true
	var alt_event := _event(KEY_A, "а")
	alt_event.alt_pressed = true
	var meta_event := _event(KEY_A, "а")
	meta_event.meta_pressed = true
	var release_event := _event(KEY_A, "а")
	release_event.pressed = false

	assert_eq(InputMapper.map_event(ctrl_event), "")
	assert_eq(InputMapper.map_event(alt_event), "")
	assert_eq(InputMapper.map_event(meta_event), "")
	assert_eq(InputMapper.map_event(_event(KEY_1, "1")), "")
	assert_eq(InputMapper.map_event(release_event), "")


func test_shift_does_not_block_a_physical_letter_position() -> void:
	var event := _event(KEY_A, "A")
	event.shift_pressed = true

	assert_eq(InputMapper.map_event(event), "А")


func _event(physical_keycode: Key, unicode_text: String) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = physical_keycode
	if not unicode_text.is_empty():
		event.unicode = unicode_text.unicode_at(0)
	return event
