class_name BattleArena
extends Node2D

signal arena_initialized(player_pokemon: PokemonInstance, wild_pokemon: PokemonInstance)
signal pokeball_thrown(ball: PokeballProjectile, ball_item_id: String, remaining_count: int)
signal pokeball_throw_failed_empty(ball_item_id: String)
signal pokemon_captured(captured_pokemon: PokemonInstance)
signal pokemon_capture_failed(wild_pokemon: PokemonInstance, shakes_done: int)
signal battle_ended(result: Dictionary)

const ARENA_WIDTH: float = 320.0
const ARENA_HEIGHT: float = 240.0
const WALL_THICKNESS: float = 16.0
const POKEBALL_PROJECTILE_SCENE: PackedScene = preload("res://scenes/battle/PokeballProjectile.tscn")

var player_pokemon: PokemonInstance = null
var wild_pokemon: PokemonInstance = null
var active_snapshot: Dictionary = {}
var last_stat_log: String = ""
var outcome: String = ""
var is_battle_resolved: bool = false
var auto_exit_on_battle_end: bool = false

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


static func calculate_catch_formula_value(max_hp: int, current_hp: int, catch_rate: int, ball_multiplier: float = 1.0) -> float:
	return PokeballProjectile.calculate_catch_formula_value(max_hp, current_hp, catch_rate, ball_multiplier)


static func calculate_catch_probability(max_hp: int, current_hp: int, catch_rate: int, ball_multiplier: float = 1.0) -> float:
	return PokeballProjectile.calculate_catch_probability(max_hp, current_hp, catch_rate, ball_multiplier)


func setup_from_snapshot(snapshot: Dictionary = {}) -> void:
	active_snapshot = snapshot.duplicate(true)
	outcome = ""
	is_battle_resolved = false
	
	var sm: Node = _get_scene_manager()
	if snapshot.get("player_pokemon") is PokemonInstance:
		player_pokemon = snapshot.get("player_pokemon") as PokemonInstance
	elif snapshot.get("player_pokemon_dict") is Dictionary and not (snapshot.get("player_pokemon_dict") as Dictionary).is_empty():
		player_pokemon = PokemonInstance.from_dict(snapshot.get("player_pokemon_dict"))
	else:
		if sm and sm.has_method("get_lead_pokemon"):
			player_pokemon = sm.get_lead_pokemon()
		else:
			player_pokemon = PokemonRegistry.create_instance("cyndaquil", 5, "브케인")
	
	if snapshot.get("wild_pokemon") is PokemonInstance:
		wild_pokemon = snapshot.get("wild_pokemon") as PokemonInstance
	elif snapshot.get("wild_pokemon_dict") is Dictionary and not (snapshot.get("wild_pokemon_dict") as Dictionary).is_empty():
		wild_pokemon = PokemonInstance.from_dict(snapshot.get("wild_pokemon_dict"))
	else:
		if sm and sm.get("active_wild_pokemon") is PokemonInstance:
			wild_pokemon = sm.get("active_wild_pokemon")
		else:
			wild_pokemon = PokemonRegistry.create_instance("pidgey", 3, "구구")
	
	if sm != null:
		sm.set("active_wild_pokemon", wild_pokemon)
	
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


func get_player_inventory() -> Inventory:
	var sm: Node = _get_scene_manager()
	if sm != null:
		if sm.get("player_inventory") == null:
			var inv := Inventory.new()
			inv.populate_starter_items()
			sm.set("player_inventory", inv)
		return sm.get("player_inventory") as Inventory
	return null


func start_aiming_pokeball(aim_dir: Vector2 = Vector2.ZERO) -> void:
	if player_actor != null:
		player_actor.start_aiming_pokeball(aim_dir)
		if battle_hud != null:
			battle_hud.set_battle_message("몬스터볼 조준 중... 방향키로 조준 후 떼면 투척!")


func release_pokeball(ball_item_id: String = "pokeball", forced_outcome: int = -1, rng: RandomNumberGenerator = null) -> PokeballProjectile:
	if player_actor == null:
		return null
	var dir: Vector2 = player_actor.facing_direction
	player_actor.stop_aiming_pokeball()
	return throw_pokeball_at(dir, ball_item_id, forced_outcome, rng)


func throw_pokeball_at(
	dir: Vector2 = Vector2.ZERO,
	ball_item_id: String = "pokeball",
	forced_outcome: int = -1,
	rng: RandomNumberGenerator = null
) -> PokeballProjectile:
	if player_actor == null:
		return null
	return throw_pokeball_from_actor(player_actor, dir, ball_item_id, forced_outcome, rng)


func throw_pokeball_from_actor(
	actor: PokemonActor,
	dir: Vector2 = Vector2.ZERO,
	ball_item_id: String = "pokeball",
	forced_outcome: int = -1,
	rng: RandomNumberGenerator = null
) -> PokeballProjectile:
	if actor == null or is_battle_resolved:
		return null
	
	var norm_ball_id: String = PokeballProjectile.normalize_ball_id(ball_item_id)
	var inv: Inventory = get_player_inventory()
	if inv != null:
		if not inv.has_item(norm_ball_id, 1):
			var empty_msg: String = "남은 몬스터볼이 없다!"
			if battle_hud != null:
				battle_hud.set_battle_message(empty_msg)
			actor.last_battle_message = empty_msg
			pokeball_throw_failed_empty.emit(norm_ball_id)
			return null
		inv.remove_item(norm_ball_id, 1)
	
	var fire_dir: Vector2 = actor.facing_direction
	if dir.length_squared() > 0.0001:
		fire_dir = dir.normalized()
		actor.set_facing_direction(fire_dir)
	else:
		fire_dir = PMDSpriteLoader.vector_from_direction(actor.facing_dir_key)
	
	actor.stop_aiming_pokeball()
	
	var ball: PokeballProjectile = POKEBALL_PROJECTILE_SCENE.instantiate() as PokeballProjectile
	ball.forced_catch_outcome = forced_outcome
	ball.custom_rng = rng
	var ball_mult: float = PokeballProjectile.resolve_ball_multiplier(norm_ball_id)
	ball.setup(actor, actor.team, fire_dir, norm_ball_id, ball_mult)
	ball.global_position = actor.global_position + fire_dir * 10.0
	
	ball.shake_step.connect(_on_pokeball_shake_step)
	ball.catch_succeeded.connect(_on_pokeball_catch_succeeded)
	ball.catch_failed.connect(_on_pokeball_catch_failed)
	
	var container: Node = projectiles_container if projectiles_container != null else self
	container.add_child(ball)
	
	var rem_count: int = inv.get_item_count(norm_ball_id) if inv != null else 0
	var item_data: ItemData = ItemData.get_default_item(norm_ball_id)
	var ball_name: String = item_data.display_name if item_data != null else "몬스터볼"
	if battle_hud != null:
		battle_hud.set_battle_message("%s을(를) 던졌다! (잔여: %d)" % [ball_name, rem_count])
	
	actor.pokeball_thrown.emit(ball, fire_dir, norm_ball_id)
	pokeball_thrown.emit(ball, norm_ball_id, rem_count)
	return ball


func _on_pokeball_shake_step(step_num: int) -> void:
	if battle_hud != null:
		battle_hud.set_battle_message("흔들... (%d/3)" % step_num)


func _on_pokeball_catch_succeeded(_enemy: PokemonActor, captured_mon: PokemonInstance) -> void:
	if is_battle_resolved:
		return
	is_battle_resolved = true
	outcome = "captured"
	
	var target_mon: PokemonInstance = captured_mon if captured_mon != null else wild_pokemon
	var mon_name: String = target_mon.get_display_name() if target_mon != null else "포켓몬"
	var catch_msg: String = "신난다! %s을(를) 잡았다!" % mon_name
	if battle_hud != null:
		battle_hud.set_battle_message(catch_msg)
	if player_actor != null:
		player_actor.last_battle_message = catch_msg
	
	var sm: Node = _get_scene_manager()
	if sm != null and target_mon != null:
		if sm.has_method("add_pokemon_to_party"):
			sm.add_pokemon_to_party(target_mon)
		elif sm.get("party") is Array and not (sm.get("party") as Array).has(target_mon):
			(sm.get("party") as Array).append(target_mon)
	
	pokemon_captured.emit(target_mon)
	
	var result: Dictionary = {
		"outcome": "captured",
		"victory": true,
		"defeated": false,
		"caught": true,
		"captured_pokemon": target_mon,
		"player_pokemon": player_pokemon,
		"player_hp": player_pokemon.current_hp if player_pokemon else 0,
		"wild_hp": target_mon.current_hp if target_mon else 0,
		"message": catch_msg,
	}
	battle_ended.emit(result)
	if auto_exit_on_battle_end and sm != null and sm.has_method("exit_battle_arena"):
		sm.exit_battle_arena(result)


func _on_pokeball_catch_failed(_enemy: PokemonActor, failed_mon: PokemonInstance, shakes_done: int) -> void:
	var target_mon: PokemonInstance = failed_mon if failed_mon != null else wild_pokemon
	var mon_name: String = target_mon.get_display_name() if target_mon != null else "포켓몬"
	var fail_msg: String = "아깝다! 조금만 더 하면 잡을 수 있었는데! 야생 %s이(가) 분노하여 공격 속도가 빨라졌다!" % mon_name
	if battle_hud != null:
		battle_hud.set_battle_message(fail_msg)
	pokemon_capture_failed.emit(target_mon, shakes_done)


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
	if is_battle_resolved:
		return
	is_battle_resolved = true
	_update_hud()
	var won: bool = (actor == enemy_actor)
	outcome = "victory" if won else "defeat"
	
	var end_msg: String = ""
	if won:
		var w_name: String = wild_pokemon.get_display_name() if wild_pokemon != null else "야생 포켓몬"
		end_msg = "야생 %s은(는) 쓰러졌다! 전투에서 승리했다!" % w_name
	else:
		end_msg = "눈앞이 캄캄해졌다!"
	
	if battle_hud != null:
		battle_hud.set_battle_message(end_msg)
	if player_actor != null:
		player_actor.last_battle_message = end_msg
	
	var result: Dictionary = {
		"outcome": outcome,
		"victory": won,
		"defeated": not won,
		"caught": false,
		"player_pokemon": player_pokemon,
		"player_hp": player_pokemon.current_hp if player_pokemon else 0,
		"wild_hp": wild_pokemon.current_hp if wild_pokemon else 0,
		"message": end_msg,
	}
	battle_ended.emit(result)
	var sm: Node = _get_scene_manager()
	if auto_exit_on_battle_end and sm != null and sm.has_method("exit_battle_arena"):
		sm.exit_battle_arena(result)
