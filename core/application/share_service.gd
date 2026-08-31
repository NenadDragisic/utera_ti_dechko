class_name ShareService
extends RefCounted


const MODES := [1, 2, 4, 8]
const HEADER := "УТЕРА ТИ ДЕЧКО"


var _clipboard: ClipboardPort


func _init(clipboard: ClipboardPort) -> void:
	_clipboard = clipboard


func mode_text(bundle: GameBundle, mode: int) -> String:
	var body := _completed_mode_text(bundle, mode)
	if body.is_empty():
		return ""
	return _header(bundle) + "\n" + body


func combined_text(bundle: GameBundle) -> String:
	var mode_texts: Array[String] = []
	for mode in MODES:
		var body := _completed_mode_text(bundle, mode)
		if not body.is_empty():
			mode_texts.append(body)
	if mode_texts.is_empty():
		return _header(bundle)
	return _header(bundle) + "\n\n" + "\n\n".join(mode_texts)


func copy(text: String) -> bool:
	return _clipboard.copy(text)


func _header(bundle: GameBundle) -> String:
	return "%s #%d" % [HEADER, bundle.sequence]


func _completed_mode_text(bundle: GameBundle, mode: int) -> String:
	if bundle == null or not bundle.sessions.has(mode):
		return ""
	var session: GameSession = bundle.sessions[mode]
	if session.status == GameSession.Status.ACTIVE:
		return ""

	var grid_groups: Array[String] = []
	for board in session.boards:
		var rows: Array[String] = []
		for row in board.rows:
			rows.append(_marks_text(row.marks()))
		if not rows.is_empty():
			grid_groups.append("\n".join(rows))

	var result := "Режим: %d · Резултат: %d/6" % [mode, session.score()]
	if not grid_groups.is_empty():
		result += "\n" + "\n\n".join(grid_groups)
	return result


func _marks_text(marks: Array[LetterMark.Value]) -> String:
	var emoji := ""
	for mark in marks:
		emoji += _emoji_for(mark)
	return emoji


func _emoji_for(mark: LetterMark.Value) -> String:
	match mark:
		LetterMark.Value.CORRECT:
			return "🟩"
		LetterMark.Value.PRESENT:
			return "🟨"
		LetterMark.Value.ABSENT:
			return "⬛"
	assert(false, "Unknown LetterMark value")
	return ""
