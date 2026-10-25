class_name EncounterEntry
extends Resource

@export var species_id: String = "pidgey"
@export var display_name: String = "구구"
@export var min_level: int = 2
@export var max_level: int = 5
@export var weight: int = 30


static func create(
	p_species_id: String,
	p_display_name: String,
	p_min_level: int = 2,
	p_max_level: int = 5,
	p_weight: int = 30
) -> EncounterEntry:
	var entry := EncounterEntry.new()
	entry.species_id = p_species_id
	entry.display_name = p_display_name
	entry.min_level = p_min_level
	entry.max_level = maxi(p_min_level, p_max_level)
	entry.weight = maxi(1, p_weight)
	return entry
