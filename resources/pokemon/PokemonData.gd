class_name PokemonData
extends Resource

@export var species_id: String = "cyndaquil"
@export var display_name: String = "브케인"
@export var dex_number: int = 155
@export var primary_type: String = "FIRE"
@export var secondary_type: String = ""

@export var base_hp: int = 39
@export var base_attack: int = 52
@export var base_defense: int = 43
@export var base_speed: int = 65
@export var catch_rate: int = 45

@export var pmd_sprite_dir: String = "res://assets/sprites/pokemon/pmd/cyndaquil"
@export var learnable_moves: Array[String] = ["tackle", "ember", "leer", "quick_attack"]


static func create(
	p_species_id: String,
	p_display_name: String,
	p_dex_number: int,
	p_primary_type: String,
	p_secondary_type: String,
	p_base_hp: int,
	p_base_attack: int,
	p_base_defense: int,
	p_base_speed: int,
	p_catch_rate: int = 255,
	p_moves: Array[String] = []
) -> PokemonData:
	var d := PokemonData.new()
	d.species_id = p_species_id
	d.display_name = p_display_name
	d.dex_number = p_dex_number
	d.primary_type = p_primary_type
	d.secondary_type = p_secondary_type
	d.base_hp = p_base_hp
	d.base_attack = p_base_attack
	d.base_defense = p_base_defense
	d.base_speed = p_base_speed
	d.catch_rate = p_catch_rate
	d.pmd_sprite_dir = "res://assets/sprites/pokemon/pmd/%s" % p_species_id
	if p_moves.is_empty():
		d.learnable_moves = ["tackle", "growl"]
	else:
		d.learnable_moves = p_moves.duplicate()
	return d
