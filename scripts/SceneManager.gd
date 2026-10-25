extends Node

signal warp_started(target_scene_path: String)
signal fade_out_completed()
signal scene_loaded(scene_root: Node)
signal warp_completed(target_scene_path: String, spawn_pos: Vector2)
signal battle_transition_started(wild_pokemon: PokemonInstance, snapshot: Dictionary)
signal battle_arena_entered(arena_scene: Node, snapshot: Dictionary)
signal battle_arena_exited(battle_result: Dictionary)

const BATTLE_ARENA_SCENE_PATH: String = "res://scenes/battle/BattleArena.tscn"
const DEFAULT_OVERWORLD_SCENE_PATH: String = "res://scenes/overworld/Overworld.tscn"

var canvas_layer: CanvasLayer
var fade_rect: ColorRect
var is_transitioning: bool = false
var fade_duration: float = 0.25

var pending_spawn_position: Vector2 = Vector2(-1, -1)
var pending_facing_direction: Vector2 = Vector2.ZERO
var has_pending_spawn: bool = false

## Persistent Game State across Overworld <-> BattleArena
var party: Array[PokemonInstance] = []
var player_inventory: Inventory = null
var active_wild_pokemon: PokemonInstance = null
var last_encounter_data: Dictionary = {}
var battle_snapshot: Dictionary = {}

var return_scene_path: String = DEFAULT_OVERWORLD_SCENE_PATH
var return_player_position: Vector2 = Vector2(64, 80)
var return_facing_direction: Vector2 = Vector2.DOWN


func _ready() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	canvas_layer.name = "TransitionLayer"
	add_child(canvas_layer)
	
	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(fade_rect)
	
	ensure_default_party()
	if player_inventory == null:
		player_inventory = Inventory.new()
		player_inventory.populate_starter_items()


func _exit_tree() -> void:
	party.clear()
	player_inventory = null
	active_wild_pokemon = null
	battle_snapshot.clear()
	PMDSpriteLoader.clear_cache()
	PokemonRegistry.clear_cache()


func ensure_default_party() -> void:
	if party.is_empty():
		var starter: PokemonInstance = PokemonRegistry.create_instance("cyndaquil", 5, "브케인")
		party.append(starter)


func get_lead_pokemon() -> PokemonInstance:
	ensure_default_party()
	for member in party:
		if member != null and not member.is_fainted():
			return member
	return party[0]


func capture_overworld_snapshot(wild_pokemon: PokemonInstance = null, encounter_meta: Dictionary = {}) -> Dictionary:
	ensure_default_party()
	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.scene_file_path != "" and current_scene.scene_file_path != BATTLE_ARENA_SCENE_PATH:
		return_scene_path = current_scene.scene_file_path
		var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
		if player != null:
			return_player_position = player.position
			if player.get("facing_direction") != null:
				return_facing_direction = player.get("facing_direction")
			if player.get("inventory") != null:
				player_inventory = player.get("inventory")
			if player.get("party") is Array and not (player.get("party") as Array).is_empty():
				party = player.get("party")
	
	if wild_pokemon != null:
		active_wild_pokemon = wild_pokemon
	elif active_wild_pokemon == null:
		active_wild_pokemon = PokemonRegistry.create_instance("pidgey", 3, "구구")
	
	var lead: PokemonInstance = get_lead_pokemon()
	battle_snapshot = {
		"player_pokemon": lead,
		"player_pokemon_dict": lead.to_dict() if lead else {},
		"wild_pokemon": active_wild_pokemon,
		"wild_pokemon_dict": active_wild_pokemon.to_dict() if active_wild_pokemon else {},
		"return_scene_path": return_scene_path,
		"return_player_position": return_player_position,
		"return_facing_direction": return_facing_direction,
		"encounter_meta": encounter_meta.duplicate(true),
	}
	return battle_snapshot


func play_encounter_flash(flashes: int = 2, step_duration: float = -1.0) -> void:
	var d: float = (fade_duration * 0.25) if step_duration < 0.0 else step_duration
	if d <= 0.0:
		return
	for i in range(flashes):
		var tween_on: Tween = create_tween()
		tween_on.tween_property(fade_rect, "color", Color(1.0, 1.0, 1.0, 0.85), d)
		await tween_on.finished
		var tween_off: Tween = create_tween()
		tween_off.tween_property(fade_rect, "color", Color(0.0, 0.0, 0.0, 0.0), d)
		await tween_off.finished


func enter_battle_arena(wild_pokemon_or_dict: Variant = null, encounter_meta: Dictionary = {}, duration: float = -1.0) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	
	var wild_inst: PokemonInstance = null
	var meta: Dictionary = encounter_meta.duplicate(true)
	if wild_pokemon_or_dict is PokemonInstance:
		wild_inst = wild_pokemon_or_dict as PokemonInstance
	elif wild_pokemon_or_dict is Dictionary:
		var d: Dictionary = wild_pokemon_or_dict as Dictionary
		if meta.is_empty():
			meta = d.duplicate(true)
		wild_inst = PokemonRegistry.create_from_encounter_dict(d)
	else:
		wild_inst = PokemonRegistry.create_instance("pidgey", 3, "구구")
	
	last_encounter_data = meta
	var snapshot: Dictionary = capture_overworld_snapshot(wild_inst, meta)
	
	var current_scene: Node = get_tree().current_scene
	if current_scene:
		var player: Node = current_scene.get_node_or_null("Player")
		if player and player.has_method("set_input_enabled"):
			player.set_input_enabled(false)
	
	battle_transition_started.emit(wild_inst, snapshot)
	warp_started.emit(BATTLE_ARENA_SCENE_PATH)
	
	var d: float = fade_duration if duration < 0.0 else duration
	await play_encounter_flash(2, d * 0.2)
	await fade_out(d)
	
	var err: Error = get_tree().change_scene_to_file(BATTLE_ARENA_SCENE_PATH)
	if err != OK:
		push_error("SceneManager: Failed to change scene to %s (err=%d)" % [BATTLE_ARENA_SCENE_PATH, err])
		is_transitioning = false
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var arena_scene: Node = get_tree().current_scene
	if arena_scene:
		scene_loaded.emit(arena_scene)
		battle_arena_entered.emit(arena_scene, battle_snapshot)
	
	await fade_in(d)
	is_transitioning = false
	warp_completed.emit(BATTLE_ARENA_SCENE_PATH, Vector2.ZERO)


func exit_battle_arena(battle_result: Dictionary = {}, duration: float = -1.0) -> void:
	if is_transitioning:
		return
	if battle_result.get("caught", false) and active_wild_pokemon != null:
		if not party.has(active_wild_pokemon):
			party.append(active_wild_pokemon)
	
	var target_path: String = return_scene_path if not return_scene_path.is_empty() else DEFAULT_OVERWORLD_SCENE_PATH
	await warp_to_scene(target_path, return_player_position, return_facing_direction, duration)
	battle_arena_exited.emit(battle_result)


func fade_out(duration: float = -1.0) -> void:
	var d: float = fade_duration if duration < 0.0 else duration
	fade_rect.color = Color(0.0, 0.0, 0.0, fade_rect.color.a)
	if d <= 0.0:
		fade_rect.color.a = 1.0
		fade_out_completed.emit()
		return
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, d)
	await tween.finished
	fade_out_completed.emit()


func fade_in(duration: float = -1.0) -> void:
	var d: float = fade_duration if duration < 0.0 else duration
	fade_rect.color = Color(0.0, 0.0, 0.0, fade_rect.color.a)
	if d <= 0.0:
		fade_rect.color.a = 0.0
		return
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, d)
	await tween.finished


func warp_to_scene(target_scene_path: String, spawn_pos: Vector2, facing_dir: Vector2 = Vector2.DOWN, duration: float = -1.0) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	warp_started.emit(target_scene_path)
	
	pending_spawn_position = spawn_pos
	pending_facing_direction = facing_dir
	has_pending_spawn = true
	
	await fade_out(duration)
	
	var err: Error = get_tree().change_scene_to_file(target_scene_path)
	if err != OK:
		push_error("SceneManager: Failed to change scene to %s (err=%d)" % [target_scene_path, err])
		is_transitioning = false
		return
	
	# Wait for the new scene tree root to initialize
	await get_tree().process_frame
	await get_tree().process_frame
	
	var current_scene: Node = get_tree().current_scene
	if current_scene:
		var player: Node2D = current_scene.get_node_or_null("Player")
		if player and has_pending_spawn:
			if player.has_method("teleport_to"):
				player.teleport_to(pending_spawn_position, pending_facing_direction)
			else:
				player.global_position = pending_spawn_position
			has_pending_spawn = false
		scene_loaded.emit(current_scene)
	
	await fade_in(duration)
	is_transitioning = false
	warp_completed.emit(target_scene_path, spawn_pos)


func warp_in_place(player: Node2D, target_pos: Vector2, facing_dir: Vector2 = Vector2.DOWN, duration: float = -1.0) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	warp_started.emit("")
	
	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)
	
	await fade_out(duration)
	
	if is_instance_valid(player):
		if player.has_method("teleport_to"):
			player.teleport_to(target_pos, facing_dir)
		else:
			player.global_position = target_pos
	
	await get_tree().process_frame
	await fade_in(duration)
	
	if is_instance_valid(player) and player.has_method("set_input_enabled"):
		player.set_input_enabled(true)
	
	is_transitioning = false
	warp_completed.emit("", target_pos)
