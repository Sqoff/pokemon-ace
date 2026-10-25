class_name MoveRegistry
extends RefCounted

const DATA_DIR: String = "res://resources/moves/data"

static var _registry: Dictionary = {}


static func clear_cache() -> void:
	_registry.clear()


static func _ensure_initialized() -> void:
	if not _registry.is_empty():
		return
	
	var defaults: Array[MoveData] = [
		MoveData.create(
			"tackle", "몸통박치기", "Normal", MoveData.Pattern.MELEE_LUNGE,
			40, 100, 35, 1.2, 28.0, 0.0, 18.0, "", 0, Color(0.95, 0.95, 0.9, 1.0)
		),
		MoveData.create(
			"ember", "불꽃세례", "Fire", MoveData.Pattern.PROJECTILE,
			40, 100, 25, 1.35, 260.0, 210.0, 0.0, "", 0, Color(1.0, 0.42, 0.15, 1.0)
		),
		MoveData.create(
			"leer", "째려보기", "Normal", MoveData.Pattern.DEBUFF_WAVE,
			0, 100, 30, 1.1, 64.0, 0.0, 0.0, "defense", 1, Color(0.95, 0.8, 0.2, 1.0)
		),
		MoveData.create(
			"quick_attack", "전광석화", "Normal", MoveData.Pattern.QUICK_DASH,
			40, 100, 30, 1.0, 56.0, 0.0, 48.0, "", 0, Color(0.75, 0.95, 1.0, 1.0)
		),
		MoveData.create(
			"water_gun", "물대포", "Water", MoveData.Pattern.PROJECTILE,
			40, 100, 25, 1.35, 260.0, 205.0, 0.0, "", 0, Color(0.25, 0.65, 1.0, 1.0)
		),
		MoveData.create(
			"razor_leaf", "잎날가르기", "Grass", MoveData.Pattern.PROJECTILE,
			55, 95, 25, 1.35, 260.0, 220.0, 0.0, "", 0, Color(0.3, 0.85, 0.35, 1.0)
		),
		MoveData.create(
			"gust", "바람일으키기", "Flying", MoveData.Pattern.PROJECTILE,
			40, 100, 35, 1.35, 250.0, 200.0, 0.0, "", 0, Color(0.75, 0.9, 1.0, 1.0)
		),
		MoveData.create(
			"scratch", "할퀴기", "Normal", MoveData.Pattern.MELEE_LUNGE,
			40, 100, 35, 1.2, 28.0, 0.0, 16.0, "", 0, Color(0.95, 0.9, 0.85, 1.0)
		),
		MoveData.create(
			"peck", "쪼기", "Flying", MoveData.Pattern.MELEE_LUNGE,
			35, 100, 35, 1.15, 28.0, 0.0, 18.0, "", 0, Color(0.85, 0.9, 1.0, 1.0)
		),
		MoveData.create(
			"growl", "울음소리", "Normal", MoveData.Pattern.DEBUFF_WAVE,
			0, 100, 40, 1.1, 64.0, 0.0, 0.0, "attack", 1, Color(1.0, 0.65, 0.75, 1.0)
		),
		MoveData.create(
			"tail_whip", "꼬리흔들기", "Normal", MoveData.Pattern.DEBUFF_WAVE,
			0, 100, 30, 1.1, 64.0, 0.0, 0.0, "defense", 1, Color(0.95, 0.85, 0.4, 1.0)
		),
		MoveData.create(
			"sand_attack", "모래뿌리기", "Normal", MoveData.Pattern.DEBUFF_WAVE,
			0, 100, 15, 1.1, 64.0, 0.0, 0.0, "defense", 1, Color(0.82, 0.68, 0.42, 1.0)
		),
		MoveData.create(
			"rage", "분노", "Normal", MoveData.Pattern.MELEE_LUNGE,
			20, 100, 20, 1.05, 28.0, 0.0, 20.0, "", 0, Color(1.0, 0.35, 0.35, 1.0)
		),
		MoveData.create(
			"hyper_fang", "필살앞니", "Normal", MoveData.Pattern.MELEE_LUNGE,
			80, 90, 15, 1.45, 30.0, 0.0, 22.0, "", 0, Color(1.0, 0.85, 0.75, 1.0)
		),
		MoveData.create(
			"fury_swipes", "마구할퀴기", "Normal", MoveData.Pattern.QUICK_DASH,
			36, 85, 15, 1.15, 48.0, 0.0, 36.0, "", 0, Color(0.95, 0.95, 0.85, 1.0)
		),
		MoveData.create(
			"defense_curl", "웅크리기", "Normal", MoveData.Pattern.DEBUFF_WAVE,
			0, 100, 40, 1.1, 56.0, 0.0, 0.0, "attack", 1, Color(0.75, 0.85, 1.0, 1.0)
		),
		MoveData.create(
			"synthesis", "광합성", "Grass", MoveData.Pattern.DEBUFF_WAVE,
			0, 100, 5, 1.5, 56.0, 0.0, 0.0, "attack", 1, Color(0.45, 0.95, 0.45, 1.0)
		),
		MoveData.create(
			"hypnosis", "최면술", "Normal", MoveData.Pattern.DEBUFF_WAVE,
			0, 60, 20, 1.35, 64.0, 0.0, 0.0, "defense", 1, Color(0.75, 0.5, 0.95, 1.0)
		),
	]
	
	for entry in defaults:
		var tres_path: String = "%s/%s.tres" % [DATA_DIR, entry.move_id]
		if ResourceLoader.exists(tres_path):
			var loaded: MoveData = load(tres_path) as MoveData
			if loaded != null:
				_registry[entry.move_id] = loaded
				continue
		_registry[entry.move_id] = entry


static func get_move_data(move_id: String) -> MoveData:
	_ensure_initialized()
	var key: String = move_id.strip_edges().to_lower()
	if _registry.has(key):
		return _registry[key]
	return _registry.get("tackle")


static func create_move_instance(move_id: String, current_pp: int = -1) -> MoveInstance:
	var data: MoveData = get_move_data(move_id)
	return MoveInstance.create(data, current_pp)


static func get_type_effectiveness(move_type: String, defender_primary: String, defender_secondary: String = "") -> float:
	var atk_t: String = move_type.strip_edges().to_upper()
	var mult: float = _single_type_effectiveness(atk_t, defender_primary.strip_edges().to_upper())
	if not defender_secondary.strip_edges().is_empty():
		mult *= _single_type_effectiveness(atk_t, defender_secondary.strip_edges().to_upper())
	return mult


static func _single_type_effectiveness(atk_type: String, def_type: String) -> float:
	if def_type.is_empty():
		return 1.0
	match atk_type:
		"FIRE":
			if def_type in ["GRASS", "BUG", "ICE", "STEEL"]:
				return 2.0
			if def_type in ["WATER", "FIRE", "ROCK", "DRAGON"]:
				return 0.5
		"WATER":
			if def_type in ["FIRE", "GROUND", "ROCK"]:
				return 2.0
			if def_type in ["WATER", "GRASS", "DRAGON"]:
				return 0.5
		"GRASS":
			if def_type in ["WATER", "GROUND", "ROCK"]:
				return 2.0
			if def_type in ["FIRE", "GRASS", "FLYING", "BUG", "POISON", "DRAGON", "STEEL"]:
				return 0.5
		"FLYING":
			if def_type in ["GRASS", "FIGHTING", "BUG"]:
				return 2.0
			if def_type in ["ROCK", "STEEL", "ELECTRIC"]:
				return 0.5
	return 1.0
