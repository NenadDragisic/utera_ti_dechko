class_name Statistics
extends RefCounted


const MODES := [1, 2, 4, 8]
const SCORE_BUCKET_COUNT := 7


var score_counts := PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
var score_counts_by_mode: Dictionary = {
	1: PackedInt32Array([0, 0, 0, 0, 0, 0, 0]),
	2: PackedInt32Array([0, 0, 0, 0, 0, 0, 0]),
	4: PackedInt32Array([0, 0, 0, 0, 0, 0, 0]),
	8: PackedInt32Array([0, 0, 0, 0, 0, 0, 0]),
}
var recorded_session_ids: Dictionary = {}


func record(mode: int, score: int, session_id: String) -> bool:
	if not MODES.has(mode) or score < 0 or score >= SCORE_BUCKET_COUNT or session_id.is_empty():
		return false
	if recorded_session_ids.has(session_id):
		return false

	recorded_session_ids[session_id] = true
	score_counts[score] += 1
	var mode_counts: PackedInt32Array = score_counts_by_mode[mode]
	mode_counts[score] += 1
	score_counts_by_mode[mode] = mode_counts
	return true
