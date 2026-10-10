extends RefCounted
# Stable existing contact/save identities; only appearance is mapped here.
const NAMES: Array[String] = ["Rod", "Kobi", "Malik", "Diddy", "Jeremias", "Marcuss", "Tyler", "Mahto", "Mike"]
static func has_character(contact: String) -> bool:
	return contact in NAMES
static func model_path(contact: String) -> String:
	return "res://assets/characters/" + contact + ".glb" if has_character(contact) else ""
