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

## Stores either move_id strings or MoveInstance dictionaries
@export var moves: Array = []
## Up to 4 MoveInstance resources representing equipped moves and their current/max PP
@export var move_instances: Array[MoveInstance] = []


static func create(p_data: PokemonData, p_level: int = 5, p_nickname: String = "") -> PokemonInstance:
	var inst := PokemonInstance.new()
	inst.data = p_data
	inst.level = maxi(1, p_level)
	inst.nickname = p_nickname if not p_nickname.is_empty() else (p_data.display_name if p_data else "포켓몬")
	inst.recalculate_stats(true)
	if p_data != null:
		inst.moves = p_data.learnable_moves.duplicate()
	else:
		inst.moves = ["tackle", "ember", "leer", "quick_attack"]
	inst.ensure_move_instances()
	return inst


func ensure_move_instances() -> void:
	if not move_instances.is_empty():
		sync_moves_array()
		return
	
	var source_list: Array = moves
	if source_list.is_empty() and data != null:
		source_list = data.learnable_moves.duplicate()
	if source_list.is_empty():
		source_list = ["tackle", "ember", "leer", "quick_attack"]
	
	move_instances.clear()
	for entry in source_list:
		if move_instances.size() >= 4:
			break
		if entry is MoveInstance:
			move_instances.append(entry as MoveInstance)
		elif entry is Dictionary:
			move_instances.append(MoveInstance.from_dict(entry as Dictionary))
		elif entry is String:
			move_instances.append(MoveRegistry.create_move_instance(entry as String))
	
	# Ensure at least 4 slots if fewer than 4 were listed
	var fallback_ids: Array[String] = ["tackle", "ember", "leer", "quick_attack"]
	var idx: int = 0
	while move_instances.size() < 4 and idx < fallback_ids.size():
		move_instances.append(MoveRegistry.create_move_instance(fallback_ids[idx]))
		idx += 1
	
	sync_moves_array()


func sync_moves_array() -> void:
	if move_instances.is_empty():
		return
	var updated_ids: Array = []
	for m_inst in move_instances:
		if m_inst != null:
			updated_ids.append(m_inst.get_move_id())
	moves = updated_ids


func get_move_instance(slot_index: int) -> MoveInstance:
	ensure_move_instances()
	if slot_index < 0 or slot_index >= move_instances.size():
		return null
	return move_instances[slot_index]


func get_move_count() -> int:
	ensure_move_instances()
	return move_instances.size()


func restore_all_pp() -> void:
	ensure_move_instances()
	for m_inst in move_instances:
		if m_inst != null:
			m_inst.restore_pp(-1)


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
	max_hp = (int(((data.base_hp + iv_hp) * 2 * lv) / 100.0) + lv + 14) * 2
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
	ensure_move_instances()
	var move_inst_dicts: Array[Dictionary] = []
	for m_inst in move_instances:
		if m_inst != null:
			move_inst_dicts.append(m_inst.to_dict())
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
		"move_instances": move_inst_dicts,
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
	
	if d.has("move_instances") and d["move_instances"] is Array:
		inst.move_instances.clear()
		for item in d["move_instances"] as Array:
			if item is Dictionary:
				inst.move_instances.append(MoveInstance.from_dict(item as Dictionary))
			elif item is MoveInstance:
				inst.move_instances.append(item as MoveInstance)
		inst.sync_moves_array()
	else:
		inst.ensure_move_instances()
	return inst
