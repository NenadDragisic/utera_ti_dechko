class_name SaveRepositoryPort
extends RefCounted


func load_text() -> Dictionary:
	assert(false, "SaveRepositoryPort.load_text must be implemented by an adapter")
	return {"error": ERR_METHOD_NOT_FOUND, "found": false, "text": ""}


func save_text(_json: String) -> Error:
	assert(false, "SaveRepositoryPort.save_text must be implemented by an adapter")
	return ERR_METHOD_NOT_FOUND


func preserve_corrupt(_raw: String) -> Error:
	assert(false, "SaveRepositoryPort.preserve_corrupt must be implemented by an adapter")
	return ERR_METHOD_NOT_FOUND
