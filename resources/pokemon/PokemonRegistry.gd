class_name PokemonRegistry
extends RefCounted

const DATA_DIR: String = "res://resources/pokemon/data"

static var _registry: Dictionary = {}


static func clear_cache() -> void:
	_registry.clear()


static func _ensure_initialized() -> void:
	if not _registry.is_empty():
		return
	
	var defaults: Array[PokemonData] = [
		PokemonData.create("cyndaquil", "브케인", 155, "FIRE", "", 39, 52, 43, 65, 45, ["tackle", "ember", "leer", "quick_attack"]),
		PokemonData.create("chikorita", "치코리타", 152, "GRASS", "", 45, 49, 65, 45, 45, ["tackle", "razor_leaf", "growl", "synthesis"]),
		PokemonData.create("totodile", "리아코", 158, "WATER", "", 50, 65, 64, 43, 45, ["scratch", "water_gun", "leer", "rage"]),
		PokemonData.create("pidgey", "구구", 16, "NORMAL", "FLYING", 40, 45, 40, 56, 255, ["tackle", "gust", "sand_attack", "quick_attack"]),
		PokemonData.create("rattata", "꼬렛", 19, "NORMAL", "", 30, 56, 35, 72, 255, ["tackle", "tail_whip", "quick_attack", "hyper_fang"]),
		PokemonData.create("hoothoot", "부우부", 163, "NORMAL", "FLYING", 60, 30, 30, 50, 255, ["tackle", "growl", "peck", "hypnosis"]),
		PokemonData.create("sentret", "꼬리선", 161, "NORMAL", "", 35, 46, 34, 20, 255, ["tackle", "defense_curl", "quick_attack", "fury_swipes"]),
	]
	
	for entry in defaults:
		var tres_path: String = "%s/%s.tres" % [DATA_DIR, entry.species_id]
		if ResourceLoader.exists(tres_path):
			var loaded: PokemonData = load(tres_path) as PokemonData
			if loaded != null:
				_registry[entry.species_id] = loaded
				continue
		_registry[entry.species_id] = entry


static func get_species_data(species_id: String) -> PokemonData:
	_ensure_initialized()
	var key: String = species_id.strip_edges().to_lower()
	if _registry.has(key):
		return _registry[key]
	return _registry.get("cyndaquil")


static func get_all_species_ids() -> Array[String]:
	_ensure_initialized()
	var result: Array[String] = []
	for k in _registry.keys():
		result.append(str(k))
	return result


static func create_instance(species_id: String, level: int = 5, nickname: String = "") -> PokemonInstance:
	var data: PokemonData = get_species_data(species_id)
	return PokemonInstance.create(data, level, nickname)


static func create_from_encounter_dict(encounter_data: Dictionary) -> PokemonInstance:
	var sp_id: String = str(encounter_data.get("species_id", "pidgey"))
	var lv: int = int(encounter_data.get("level", 3))
	var d_name: String = str(encounter_data.get("display_name", ""))
	return create_instance(sp_id, lv, d_name)
