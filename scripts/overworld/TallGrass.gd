class_name TallGrass
extends Sprite2D

signal player_stepped_in_grass(grass_node: Node2D)
signal wild_encounter_triggered(encounter_data: Dictionary, grass_node: Node2D)

const TALL_GRASS_EFFECT: PackedScene = preload("res://scenes/overworld/TallGrassEffect.tscn")
const DEFAULT_ENCOUNTER_TABLE: EncounterTable = preload("res://resources/pokemon/route29_encounter_table.tres")

enum GrassState {
	NORMAL,
	STEPPED
}

@export var encounter_table: EncounterTable
@export var encounter_enabled: bool = true
@export var trigger_chance: float = 0.25

var effect: AnimatedSprite2D
var last_encounter: Dictionary = {}


func _ready() -> void:
	frame = GrassState.NORMAL
	if encounter_table == null:
		encounter_table = DEFAULT_ENCOUNTER_TABLE
	if encounter_table == null:
		encounter_table = EncounterTable.create_default_route29_table()


func _get_time_manager() -> Node:
	return get_node_or_null("/root/TimeManager")


func _on_entity_entered(body: Node2D) -> void:
	frame = GrassState.STEPPED
	play_effect()
	if body is Player:
		player_stepped_in_grass.emit(self)
		if encounter_enabled:
			var chance: float = encounter_table.encounter_rate if encounter_table else trigger_chance
			if randf() < chance:
				force_encounter()


func force_encounter(period: int = -1, rng: RandomNumberGenerator = null) -> Dictionary:
	if encounter_table == null:
		encounter_table = EncounterTable.create_default_route29_table()
	var target_period: int = period
	if target_period < 0:
		var tm: Node = _get_time_manager()
		if tm and tm.get("current_period") != null:
			target_period = int(tm.get("current_period"))
		else:
			target_period = 1
	last_encounter = encounter_table.roll_encounter(target_period, rng)
	if not last_encounter.is_empty():
		wild_encounter_triggered.emit(last_encounter, self)
	return last_encounter


func _on_entity_exited(_body: Node2D) -> void:
	frame = GrassState.NORMAL


func play_effect() -> void:
	if not effect:
		effect = TALL_GRASS_EFFECT.instantiate()
		add_child(effect)
	effect.frame = 0
	effect.play(&"default")


func _on_area_2d_body_entered(body: Node2D) -> void:
	_on_entity_entered(body)


func _on_area_2d_body_exited(body: Node2D) -> void:
	_on_entity_exited(body)
