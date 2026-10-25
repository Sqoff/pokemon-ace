class_name EncounterTable
extends Resource

@export var area_name: String = "29번 도로 (Route 29)"
@export var encounter_rate: float = 0.25
@export var morning_encounters: Array[EncounterEntry] = []
@export var day_encounters: Array[EncounterEntry] = []
@export var night_encounters: Array[EncounterEntry] = []


func _init() -> void:
	pass


func ensure_defaults() -> void:
	if morning_encounters.is_empty():
		morning_encounters = [
			EncounterEntry.create("pidgey", "구구", 2, 4, 45),
			EncounterEntry.create("rattata", "꼬렛", 2, 4, 35),
			EncounterEntry.create("cyndaquil", "브케인", 5, 5, 20),
		]
	if day_encounters.is_empty():
		day_encounters = [
			EncounterEntry.create("pidgey", "구구", 2, 4, 45),
			EncounterEntry.create("rattata", "꼬렛", 2, 4, 35),
			EncounterEntry.create("chikorita", "치코리타", 5, 5, 20),
		]
	if night_encounters.is_empty():
		night_encounters = [
			EncounterEntry.create("hoothoot", "부우부", 2, 4, 55),
			EncounterEntry.create("rattata", "꼬렛", 2, 4, 25),
			EncounterEntry.create("totodile", "리아코", 5, 5, 20),
		]


func get_entries_for_period(period: int = -1) -> Array[EncounterEntry]:
	ensure_defaults()
	var resolved_period: int = _resolve_period(period)
	match resolved_period:
		0: # MORNING
			return morning_encounters
		1: # DAY
			return day_encounters
		2: # NIGHT
			return night_encounters
	return day_encounters


func get_species_ids_for_period(period: int = -1) -> Array[String]:
	var entries: Array[EncounterEntry] = get_entries_for_period(period)
	var ids: Array[String] = []
	for entry in entries:
		if entry and not ids.has(entry.species_id):
			ids.append(entry.species_id)
	return ids


func roll_encounter(period: int = -1, rng: RandomNumberGenerator = null) -> Dictionary:
	var resolved_period: int = _resolve_period(period)
	var entries: Array[EncounterEntry] = get_entries_for_period(resolved_period)
	if entries.is_empty():
		return {}
	
	var total_weight: int = 0
	for entry in entries:
		if entry:
			total_weight += maxi(1, entry.weight)
	
	var roll: int = 0
	if rng != null:
		roll = rng.randi_range(0, total_weight - 1)
	else:
		roll = randi() % total_weight
	
	var chosen: EncounterEntry = entries[0]
	var accum: int = 0
	for entry in entries:
		if not entry:
			continue
		accum += maxi(1, entry.weight)
		if roll < accum:
			chosen = entry
			break
	
	var min_lv: int = chosen.min_level
	var max_lv: int = maxi(min_lv, chosen.max_level)
	var level: int = min_lv
	if max_lv > min_lv:
		if rng != null:
			level = rng.randi_range(min_lv, max_lv)
		else:
			level = randi_range(min_lv, max_lv)
	
	return {
		"species_id": chosen.species_id,
		"display_name": chosen.display_name,
		"level": level,
		"period": resolved_period,
		"area_name": area_name
	}


func _resolve_period(period: int) -> int:
	if period >= 0:
		return clampi(period, 0, 2)
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var tm: Node = (main_loop as SceneTree).root.get_node_or_null("TimeManager")
		if tm and tm.get("current_period") != null:
			return int(tm.get("current_period"))
	return 1


static func create_default_route29_table() -> EncounterTable:
	var table := EncounterTable.new()
	table.area_name = "29번 도로 (Route 29)"
	table.encounter_rate = 0.25
	table.ensure_defaults()
	return table
