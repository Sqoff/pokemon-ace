class_name BattleArena
extends Node2D

signal arena_initialized(player_pokemon: PokemonInstance, wild_pokemon: PokemonInstance)
signal pokeball_thrown(ball: PokeballProjectile, ball_item_id: String, remaining_count: int)
signal pokeball_throw_failed_empty(ball_item_id: String)
signal pokemon_captured(captured_pokemon: PokemonInstance)
signal pokemon_capture_failed(wild_pokemon: PokemonInstance, shakes_done: int)
signal pokemon_switched(new_pokemon: PokemonInstance, old_pokemon: PokemonInstance, party_index: int)
signal switch_failed(reason: String)
signal battle_ended(result: Dictionary)

const ARENA_WIDTH: float = 640.0
const ARENA_HEIGHT: float = 480.0
const WALL_THICKNESS: float = 16.0
const POKEBALL_PROJECTILE_SCENE: PackedScene = preload("res://scenes/battle/PokeballProjectile.tscn")

var player_pokemon: PokemonInstance = null
var wild_pokemon: PokemonInstance = null
var battle_party: Array[PokemonInstance] = []
var active_party_index: int = 0
var switch_cooldown: float = 0.0
var switch_cooldown_max: float = 4.0
var is_party_menu_open: bool = false
var active_snapshot: Dictionary = {}
var last_stat_log: String = ""
var outcome: String = ""
var is_battle_resolved: bool = false
var auto_exit_on_battle_end: bool = false

@onready var player_actor: PokemonActor = $PlayerPokemon
@onready var enemy_actor: PokemonActor = $EnemyPokemon
@onready var projectiles_container: Node2D = $Projectiles
@onready var battle_camera: Camera2D = get_node_or_null("BattleCamera") as Camera2D
@onready var battle_hud: BattleHUD = $HUDLayer/HUDRoot
@onready var battle_party_ui: PartyUI = get_node_or_null("HUDLayer/BattlePartyUI") as PartyUI
@onready var player_stat_label: Label = $HUDLayer/HUDRoot/PlayerStatLabel
@onready var enemy_stat_label: Label = $HUDLayer/HUDRoot/EnemyStatLabel


func _get_scene_manager() -> Node:
	return get_node_or_null("/root/SceneManager")


func _ready() -> void:
	if battle_party_ui != null:
		battle_party_ui.battle_select_mode = true
		if not battle_party_ui.pokemon_selected.is_connected(_on_battle_party_pokemon_selected):
			battle_party_ui.pokemon_selected.connect(_on_battle_party_pokemon_selected)
		if not battle_party_ui.party_closed.is_connected(_on_battle_party_closed):
			battle_party_ui.party_closed.connect(_on_battle_party_closed)
	var sm: Node = _get_scene_manager()
	var snap: Dictionary = {}
	if sm and sm.get("battle_snapshot") is Dictionary:
		snap = sm.get("battle_snapshot")
	setup_from_snapshot(snap)


func _process(delta: float) -> void:
	if not is_party_menu_open and switch_cooldown > 0.0:
		switch_cooldown = maxf(0.0, switch_cooldown - delta)
		if battle_hud != null:
			battle_hud.update_party_status(battle_party, active_party_index, switch_cooldown, switch_cooldown_max)
	if battle_camera != null and player_actor != null and is_instance_valid(player_actor):
		battle_camera.global_position = player_actor.global_position


func _unhandled_input(event: InputEvent) -> void:
	if is_battle_resolved or is_party_menu_open:
		return
	if event.is_action_pressed("switch_prev"):
		cycle_switch_pokemon(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("switch_next"):
		cycle_switch_pokemon(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("switch_party"):
		open_battle_party_menu()
		get_viewport().set_input_as_handled()


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
	
	battle_party.clear()
	switch_cooldown = 0.0
	is_party_menu_open = false
	if battle_party_ui != null and battle_party_ui.is_open:
		battle_party_ui.close_party()
	
	if snapshot.get("party") is Array and not (snapshot.get("party") as Array).is_empty():
		for m in snapshot.get("party") as Array:
			if m is PokemonInstance and not battle_party.has(m):
				(m as PokemonInstance).ensure_move_instances()
				battle_party.append(m as PokemonInstance)
	elif sm != null and sm.get("party") is Array and not (sm.get("party") as Array).is_empty():
		for m in sm.get("party") as Array:
			if m is PokemonInstance and not battle_party.has(m):
				(m as PokemonInstance).ensure_move_instances()
				battle_party.append(m as PokemonInstance)
	
	if player_pokemon != null and not battle_party.has(player_pokemon):
		battle_party.insert(0, player_pokemon)
	active_party_index = maxi(0, battle_party.find(player_pokemon))
	
	if player_actor:
		player_actor.set_battle_paused(false)
		player_actor.setup_from_instance(player_pokemon, true, "e")
		if not player_actor.damaged.is_connected(_on_actor_damaged):
			player_actor.damaged.connect(_on_actor_damaged)
		if not player_actor.fainted.is_connected(_on_actor_fainted):
			player_actor.fainted.connect(_on_actor_fainted)
	
	if enemy_actor:
		enemy_actor.set_battle_paused(false)
		enemy_actor.setup_from_instance(wild_pokemon, false, "w")
		enemy_actor.target_actor = player_actor
		if not enemy_actor.damaged.is_connected(_on_actor_damaged):
			enemy_actor.damaged.connect(_on_actor_damaged)
		if not enemy_actor.fainted.is_connected(_on_actor_fainted):
			enemy_actor.fainted.connect(_on_actor_fainted)
	
	var encounter_meta: Dictionary = snapshot.get("encounter_meta", {}) if snapshot.get("encounter_meta") is Dictionary else {}
	if bool(encounter_meta.get("enable_ai", false)) and enemy_actor != null:
		enemy_actor.set_ai_enabled(true, player_actor)
	if bool(encounter_meta.get("auto_exit", false)) or bool(encounter_meta.get("enable_ai", false)):
		auto_exit_on_battle_end = true
	
	if battle_hud:
		battle_hud.bind_actors(player_actor, enemy_actor)
		battle_hud.update_party_status(battle_party, active_party_index, switch_cooldown, switch_cooldown_max)
		if wild_pokemon != null:
			battle_hud.set_battle_message("야생 %s(이)가 나타났다! [방향키:이동 / 1~4:기술 / Space:포획 / Q,E,Tab:교체]" % wild_pokemon.get_display_name())
	
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
		battle_hud.refresh_all()
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
		battle_hud.update_party_status(battle_party, active_party_index, switch_cooldown, switch_cooldown_max)
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


func has_alive_party_pokemon(exclude_index: int = -1) -> bool:
	for i in range(battle_party.size()):
		if i == exclude_index:
			continue
		var m: PokemonInstance = battle_party[i]
		if m != null and not m.is_fainted():
			return true
	return false


func find_next_alive_party_index(from_index: int, step: int = 1) -> int:
	var n: int = battle_party.size()
	if n <= 1:
		return -1
	var dir_step: int = -1 if step < 0 else 1
	for offset in range(1, n):
		var idx: int = posmod(from_index + dir_step * offset, n)
		var m: PokemonInstance = battle_party[idx]
		if m != null and not m.is_fainted():
			return idx
	return -1


func is_pokeball_capture_in_progress() -> bool:
	if enemy_actor != null and enemy_actor.is_in_ball_capture:
		return true
	if projectiles_container != null:
		for child in projectiles_container.get_children():
			if child is PokeballProjectile and is_instance_valid(child):
				return true
	return false


func cycle_switch_pokemon(step: int = 1) -> bool:
	if is_battle_resolved:
		return false
	if is_pokeball_capture_in_progress():
		var cap_msg: String = "몬스터볼 포획 중에는 교체할 수 없다!"
		if battle_hud != null:
			battle_hud.set_battle_message(cap_msg)
		switch_failed.emit(cap_msg)
		return false
	if switch_cooldown > 0.0:
		var cd_msg: String = "포켓몬 교체 쿨타임 중이다! (%.1f초)" % switch_cooldown
		if battle_hud != null:
			battle_hud.set_battle_message(cd_msg)
		switch_failed.emit(cd_msg)
		return false
	var target_idx: int = find_next_alive_party_index(active_party_index, step)
	if target_idx < 0 or target_idx == active_party_index:
		var no_mon_msg: String = "교체할 수 있는 다른 포켓몬이 없다!"
		if battle_hud != null:
			battle_hud.set_battle_message(no_mon_msg)
		switch_failed.emit(no_mon_msg)
		return false
	return switch_to_party_index(target_idx, false)


func open_battle_party_menu() -> bool:
	if is_battle_resolved:
		return false
	if is_pokeball_capture_in_progress():
		var cap_msg: String = "몬스터볼 포획 중에는 교체할 수 없다!"
		if battle_hud != null:
			battle_hud.set_battle_message(cap_msg)
		switch_failed.emit(cap_msg)
		return false
	if battle_party_ui == null:
		return false
	is_party_menu_open = true
	if player_actor != null:
		player_actor.set_battle_paused(true)
	if enemy_actor != null:
		enemy_actor.set_battle_paused(true)
	battle_party_ui.open_battle_party(battle_party, active_party_index)
	return true


func close_battle_party_menu() -> void:
	if battle_party_ui != null and battle_party_ui.is_open:
		battle_party_ui.close_party()
	_on_battle_party_closed()


func _on_battle_party_closed() -> void:
	is_party_menu_open = false
	if player_actor != null:
		player_actor.set_battle_paused(false)
	if enemy_actor != null:
		enemy_actor.set_battle_paused(false)


func _on_battle_party_pokemon_selected(party_index: int, _pokemon: PokemonInstance) -> void:
	_on_battle_party_closed()
	switch_to_party_index(party_index, false)


func _spawn_switch_beam_effect(pos: Vector2) -> void:
	var recall_beam := Polygon2D.new()
	recall_beam.name = "RecallBeamEffect"
	recall_beam.global_position = pos
	recall_beam.polygon = PackedVector2Array([
		Vector2(-10, -18), Vector2(10, -18),
		Vector2(14, 0), Vector2(10, 14),
		Vector2(-10, 14), Vector2(-14, 0)
	])
	recall_beam.color = Color(1.0, 0.25, 0.28, 0.85)
	add_child(recall_beam)
	var tw_recall: Tween = recall_beam.create_tween()
	tw_recall.tween_property(recall_beam, "scale", Vector2(0.2, 1.4), 0.14)
	tw_recall.parallel().tween_property(recall_beam, "modulate:a", 0.0, 0.14)
	tw_recall.tween_callback(recall_beam.queue_free)
	
	var summon_beam := Polygon2D.new()
	summon_beam.name = "SummonBeamEffect"
	summon_beam.global_position = pos
	summon_beam.polygon = PackedVector2Array([
		Vector2(0, -16), Vector2(12, -10), Vector2(16, 0), Vector2(12, 10),
		Vector2(0, 16), Vector2(-12, 10), Vector2(-16, 0), Vector2(-12, -10)
	])
	summon_beam.color = Color(0.55, 0.90, 1.0, 0.90)
	summon_beam.scale = Vector2(0.3, 0.3)
	add_child(summon_beam)
	var tw_summon: Tween = summon_beam.create_tween()
	tw_summon.tween_property(summon_beam, "scale", Vector2(1.35, 1.35), 0.20)
	tw_summon.parallel().tween_property(summon_beam, "modulate:a", 0.0, 0.20)
	tw_summon.tween_callback(summon_beam.queue_free)
	
	if player_actor != null and player_actor.animated_sprite_2d != null:
		player_actor.animated_sprite_2d.scale = Vector2(0.3, 0.3)
		var tw_pop: Tween = player_actor.create_tween()
		tw_pop.tween_property(player_actor.animated_sprite_2d, "scale", Vector2(1.0, 1.0), 0.18)


func switch_to_party_index(target_idx: int, is_forced_on_faint: bool = false) -> bool:
	if is_battle_resolved:
		return false
	if target_idx < 0 or target_idx >= battle_party.size():
		var invalid_msg: String = "교체할 수 있는 다른 포켓몬이 없다!"
		if battle_hud != null:
			battle_hud.set_battle_message(invalid_msg)
		switch_failed.emit(invalid_msg)
		return false
	
	var next_mon: PokemonInstance = battle_party[target_idx]
	if next_mon == null:
		return false
	if target_idx == active_party_index and not is_forced_on_faint:
		var same_msg: String = "%s은(는) 이미 전투에 나와 있다!" % next_mon.get_display_name()
		if battle_hud != null:
			battle_hud.set_battle_message(same_msg)
		switch_failed.emit(same_msg)
		return false
	if next_mon.is_fainted():
		var faint_msg: String = "%s은(는) 싸울 힘이 남아있지 않다!" % next_mon.get_display_name()
		if battle_hud != null:
			battle_hud.set_battle_message(faint_msg)
		switch_failed.emit(faint_msg)
		return false
	
	if not is_forced_on_faint:
		if is_pokeball_capture_in_progress():
			var cap_msg: String = "몬스터볼 포획 중에는 교체할 수 없다!"
			if battle_hud != null:
				battle_hud.set_battle_message(cap_msg)
			switch_failed.emit(cap_msg)
			return false
		if switch_cooldown > 0.0:
			var cd_msg: String = "포켓몬 교체 쿨타임 중이다! (%.1f초)" % switch_cooldown
			if battle_hud != null:
				battle_hud.set_battle_message(cd_msg)
			switch_failed.emit(cd_msg)
			return false
	
	var old_pokemon: PokemonInstance = player_pokemon
	var prev_pos: Vector2 = player_actor.global_position if player_actor != null else Vector2(180, 240)
	var prev_dir_key: String = player_actor.facing_dir_key if player_actor != null else "e"
	
	player_pokemon = next_mon
	active_party_index = target_idx
	player_pokemon.ensure_move_instances()
	
	if player_actor != null:
		player_actor.setup_from_instance(player_pokemon, true, prev_dir_key)
		player_actor.global_position = prev_pos
		player_actor.invincible_timer = 0.3
		player_actor.apply_shared_cooldown(1.0)
	
	_spawn_switch_beam_effect(prev_pos)
	switch_cooldown = switch_cooldown_max
	
	var switch_msg: String = ""
	if is_forced_on_faint:
		switch_msg = "%s은(는) 쓰러졌다! 가라 %s!" % [
			old_pokemon.get_display_name() if old_pokemon != null else "포켓몬",
			player_pokemon.get_display_name()
		]
	else:
		switch_msg = "돌아와 %s! 가라 %s!" % [
			old_pokemon.get_display_name() if old_pokemon != null else "포켓몬",
			player_pokemon.get_display_name()
		]
	
	_update_hud()
	if battle_hud != null:
		battle_hud.set_battle_message(switch_msg)
	if player_actor != null:
		player_actor.last_battle_message = switch_msg
	
	pokemon_switched.emit(player_pokemon, old_pokemon, active_party_index)
	return true


func _on_actor_damaged(_amount: int, _current_hp: int, _max_hp: int) -> void:
	_update_hud()


func _on_actor_fainted(actor: PokemonActor) -> void:
	if is_battle_resolved:
		return
	if actor == player_actor and has_alive_party_pokemon():
		var next_alive_idx: int = find_next_alive_party_index(active_party_index, 1)
		if next_alive_idx >= 0:
			switch_to_party_index(next_alive_idx, true)
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
