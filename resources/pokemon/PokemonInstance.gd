class_name PokemonInstance
extends Resource

@export var data: PokemonData
@export var nickname: String = ""
@export var level: int = 5
@export var max_hp: int = 20
@export var current_hp: int = 20
@export var attack: int = 11
@export var defense: int = 10
@export var speed: int = 13

@export var iv_hp: int = 8
@export var iv_atk: int = 8
@export var iv_def: int = 8
@export var iv_spd: int = 8

## Stores either move_id strings or MoveInstance resources/dictionaries (Phase 4 ready)
@export var moves: Array = []


static func create(p_data: PokemonData, p_level: int = 5, p_nickname: String = "") -> PokemonInstance:
	var inst := PokemonInstance.new()
	inst.data = p_data
	inst.level = maxi(1, p_level)
	inst.nickname = p_nickname if not p_nickname.is_empty() else (p_data.display_name if p_data else "포켓몬")
	inst.recalculate_stats(true)
	if p_data != null:
		inst.moves = p_data.learnable_moves.duplicate()
	return inst


func get_species_id() -> String:
	return data.species_id if data else "cyndaquil"


func get_display_name() -> String:
	if not nickname.is_empty():
		return nickname
	return data.display_name if data else "포켓몬"


func get_pmd_sprite_dir() -> String:
	if data and not data.pmd_sprite_dir.is_empty():
		return data.pmd_sprite_dir
	return "res://assets/sprites/pokemon/pmd/%s" % get_species_id()


func recalculate_stats(restore_full_hp: bool = false) -> void:
	if data == null:
		return
	var lv: int = maxi(1, level)
	var prev_max: int = max_hp
	max_hp = int(((data.base_hp + iv_hp) * 2 * lv) / 100.0) + lv + 10
	attack = int(((data.base_attack + iv_atk) * 2 * lv) / 100.0) + 5
	defense = int(((data.base_defense + iv_def) * 2 * lv) / 100.0) + 5
	speed = int(((data.base_speed + iv_spd) * 2 * lv) / 100.0) + 5
	if restore_full_hp or current_hp <= 0:
		current_hp = max_hp
	else:
		var delta: int = maxi(0, max_hp - prev_max)
		current_hp = clampi(current_hp + delta, 1, max_hp)


func take_damage(amount: int) -> int:
	var actual: int = maxi(1, amount)
	current_hp = maxi(0, current_hp - actual)
	return current_hp


func heal(amount: int) -> void:
	current_hp = clampi(current_hp + maxi(0, amount), 0, max_hp)


func is_fainted() -> bool:
	return current_hp <= 0


func get_summary_text() -> String:
	return "%s (Lv.%d | HP %d/%d | ATK %d | DEF %d | SPD %d)" % [
		get_display_name(), level, current_hp, max_hp, attack, defense, speed
	]


func duplicate_instance() -> PokemonInstance:
	return PokemonInstance.from_dict(to_dict())


func to_dict() -> Dictionary:
	return {
		"species_id": get_species_id(),
		"display_name": data.display_name if data else nickname,
		"nickname": nickname,
		"level": level,
		"max_hp": max_hp,
		"current_hp": current_hp,
		"attack": attack,
		"defense": defense,
		"speed": speed,
		"iv_hp": iv_hp,
		"iv_atk": iv_atk,
		"iv_def": iv_def,
		"iv_spd": iv_spd,
		"moves": moves.duplicate(true),
	}


static func from_dict(d: Dictionary) -> PokemonInstance:
	var sp_id: String = str(d.get("species_id", "cyndaquil"))
	var p_data: PokemonData = PokemonRegistry.get_species_data(sp_id)
	var inst := PokemonInstance.new()
	inst.data = p_data
	inst.nickname = str(d.get("nickname", p_data.display_name if p_data else sp_id))
	inst.level = int(d.get("level", 5))
	inst.iv_hp = int(d.get("iv_hp", 8))
	inst.iv_atk = int(d.get("iv_atk", 8))
	inst.iv_def = int(d.get("iv_def", 8))
	inst.iv_spd = int(d.get("iv_spd", 8))
	inst.recalculate_stats(true)
	if d.has("max_hp"):
		inst.max_hp = int(d["max_hp"])
	if d.has("current_hp"):
		inst.current_hp = clampi(int(d["current_hp"]), 0, inst.max_hp)
	if d.has("attack"):
		inst.attack = int(d["attack"])
	if d.has("defense"):
		inst.defense = int(d["defense"])
	if d.has("speed"):
		inst.speed = int(d["speed"])
	if d.has("moves") and d["moves"] is Array:
		inst.moves = (d["moves"] as Array).duplicate(true)
	elif p_data:
		inst.moves = p_data.learnable_moves.duplicate()
	return inst
