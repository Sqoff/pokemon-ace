class_name BattleArena
extends Node2D

signal arena_initialized(player_pokemon: PokemonInstance, wild_pokemon: PokemonInstance)
signal battle_ended(result: Dictionary)

const ARENA_WIDTH: float = 320.0
const ARENA_HEIGHT: float = 240.0
const WALL_THICKNESS: float = 16.0

var player_pokemon: PokemonInstance = null
var wild_pokemon: PokemonInstance = null
var active_snapshot: Dictionary = {}
var last_stat_log: String = ""

@onready var player_actor: PokemonActor = $PlayerPokemon
@onready var enemy_actor: PokemonActor = $EnemyPokemon
@onready var projectiles_container: Node2D = $Projectiles
@onready var battle_hud: BattleHUD = $HUDLayer/HUDRoot
@onready var player_stat_label: Label = $HUDLayer/HUDRoot/PlayerStatLabel
@onready var enemy_stat_label: Label = $HUDLayer/HUDRoot/EnemyStatLabel


func _get_scene_manager() -> Node:
	return get_node_or_null("/root/SceneManager")


func _ready() -> void:
	var sm: Node = _get_scene_manager()
	var snap: Dictionary = {}
	if sm and sm.get("battle_snapshot") is Dictionary:
		snap = sm.get("battle_snapshot")
	setup_from_snapshot(snap)


func setup_from_snapshot(snapshot: Dictionary = {}) -> void:
	active_snapshot = snapshot.duplicate(true)
	
	if snapshot.get("player_pokemon") is PokemonInstance:
		player_pokemon = snapshot.get("player_pokemon") as PokemonInstance
	elif snapshot.get("player_pokemon_dict") is Dictionary and not (snapshot.get("player_pokemon_dict") as Dictionary).is_empty():
		player_pokemon = PokemonInstance.from_dict(snapshot.get("player_pokemon_dict"))
	else:
		var sm: Node = _get_scene_manager()
		if sm and sm.has_method("get_lead_pokemon"):
			player_pokemon = sm.get_lead_pokemon()
		else:
			player_pokemon = PokemonRegistry.create_instance("cyndaquil", 5, "브케인")
	
	if snapshot.get("wild_pokemon") is PokemonInstance:
		wild_pokemon = snapshot.get("wild_pokemon") as PokemonInstance
	elif snapshot.get("wild_pokemon_dict") is Dictionary and not (snapshot.get("wild_pokemon_dict") as Dictionary).is_empty():
		wild_pokemon = PokemonInstance.from_dict(snapshot.get("wild_pokemon_dict"))
	else:
		var sm: Node = _get_scene_manager()
		if sm and sm.get("active_wild_pokemon") is PokemonInstance:
			wild_pokemon = sm.get("active_wild_pokemon")
		else:
			wild_pokemon = PokemonRegistry.create_instance("pidgey", 3, "구구")
	
	if player_pokemon != null:
		player_pokemon.ensure_move_instances()
	if wild_pokemon != null:
		wild_pokemon.ensure_move_instances()
	
	if player_actor:
		player_actor.setup_from_instance(player_pokemon, true, "e")
		if not player_actor.damaged.is_connected(_on_actor_damaged):
			player_actor.damaged.connect(_on_actor_damaged)
		if not player_actor.fainted.is_connected(_on_actor_fainted):
			player_actor.fainted.connect(_on_actor_fainted)
	
	if enemy_actor:
		enemy_actor.setup_from_instance(wild_pokemon, false, "w")
		enemy_actor.target_actor = player_actor
		if not enemy_actor.damaged.is_connected(_on_actor_damaged):
			enemy_actor.damaged.connect(_on_actor_damaged)
		if not enemy_actor.fainted.is_connected(_on_actor_fainted):
			enemy_actor.fainted.connect(_on_actor_fainted)
	
	if battle_hud:
		battle_hud.bind_actors(player_actor, enemy_actor)
	
	_update_hud()
	last_stat_log = _format_battle_stat_log()
	print(last_stat_log)
	arena_initialized.emit(player_pokemon, wild_pokemon)


func _format_battle_stat_log() -> String:
	var p_summary: String = player_pokemon.get_summary_text() if player_pokemon else "None"
	var w_summary: String = wild_pokemon.get_summary_text() if wild_pokemon else "None"
	return "[BattleArena Snapshot] Player=%s vs Wild=%s" % [p_summary, w_summary]


func _update_hud() -> void:
	if battle_hud:
		battle_hud.refresh_all()
		return
	if player_stat_label and player_pokemon:
		player_stat_label.text = "%s Lv.%d  HP %d/%d" % [
			player_pokemon.get_display_name(),
			player_pokemon.level,
			player_pokemon.current_hp,
			player_pokemon.max_hp
		]
	if enemy_stat_label and wild_pokemon:
		enemy_stat_label.text = "야생 %s Lv.%d  HP %d/%d" % [
			wild_pokemon.get_display_name(),
			wild_pokemon.level,
			wild_pokemon.current_hp,
			wild_pokemon.max_hp
		]


func _on_actor_damaged(_amount: int, _current_hp: int, _max_hp: int) -> void:
	_update_hud()


func _on_actor_fainted(actor: PokemonActor) -> void:
	_update_hud()
	var won: bool = (actor == enemy_actor)
	var result: Dictionary = {
		"victory": won,
		"defeated": not won,
		"caught": false,
		"player_hp": player_pokemon.current_hp if player_pokemon else 0,
		"wild_hp": wild_pokemon.current_hp if wild_pokemon else 0,
	}
	battle_ended.emit(result)
