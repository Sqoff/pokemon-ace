extends SceneTree

const OVERWORLD_SCENE_PATH: String = "res://scenes/overworld/Overworld.tscn"
const BATTLE_ARENA_SCENE_PATH: String = "res://scenes/battle/BattleArena.tscn"
const POKECENTER_SCENE_PATH: String = "res://scenes/overworld/PokeCenter.tscn"
const SAVE_FILE_PATH: String = "user://savegame.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_all_tests")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		var err: String = "[FAIL] " + message
		printerr(err)
		failures.append(err)
	else:
		print("[PASS] " + message)


func _wait_frames(count: int = 2) -> void:
	for i in range(count):
		await process_frame
		await physics_frame


func _run_all_tests() -> void:
	print("=== [Phase 5 Headless QA Verification Start] ===")
	
	var scene_mgr: Node = root.get_node_or_null("SceneManager")
	var time_mgr: Node = root.get_node_or_null("TimeManager")
	var dialogue_mgr: Node = root.get_node_or_null("DialogueManager")
	var save_mgr: Node = root.get_node_or_null("SaveManager")
	
	_assert_true(scene_mgr != null, "SceneManager Autoload singleton is registered")
	_assert_true(save_mgr != null, "SaveManager Autoload singleton is registered")
	if scene_mgr:
		scene_mgr.fade_duration = 0.02
	
	# Load BattleArena first for Verification 1 & 2
	var err: Error = change_scene_to_file(BATTLE_ARENA_SCENE_PATH)
	_assert_true(err == OK, "Loaded BattleArena.tscn successfully")
	await _wait_frames(4)
	
	var arena: BattleArena = current_scene as BattleArena
	_assert_true(arena != null and arena.name == "BattleArena", "Current scene is BattleArena")
	
	var p_actor: PokemonActor = arena.player_actor
	var e_actor: PokemonActor = arena.enemy_actor
	var hud: BattleHUD = arena.battle_hud
	_assert_true(p_actor != null and e_actor != null and hud != null, "PlayerPokemon, EnemyPokemon, and BattleHUD exist in BattleArena")
	
	# ---------------------------------------------------------
	# [검증 1] 실시간 몬스터볼 조준/발사 및 체력별 포획 확률 검증
	# ---------------------------------------------------------
	print("\n--- [검증 1] 실시간 몬스터볼 조준(Reticle), 포물선 투척 및 HP 100% vs HP 10% 포획 확률 공식 검증 ---")
	p_actor.global_position = Vector2(100, 120)
	p_actor.set_move_input(Vector2.RIGHT)
	await _wait_frames(3)
	_assert_true(p_actor.velocity.length() > 1.0, "PlayerPokemon is moving before aiming Pokeball")
	
	arena.start_aiming_pokeball(Vector2.RIGHT)
	await _wait_frames(2)
	_assert_true(p_actor.is_aiming_pokeball, "PlayerPokemon entered pokeball aiming state (is_aiming_pokeball == true)")
	_assert_true(p_actor.aim_reticle_node != null and p_actor.aim_reticle_node.visible, "AimReticle node is visible while aiming")
	_assert_true(p_actor.velocity.length() < 0.01, "PlayerPokemon stops moving while aiming Pokeball")
	
	# Verify rotating aim direction while holding aim
	p_actor.set_move_input(Vector2(1, -1))
	await _wait_frames(2)
	_assert_true(p_actor.facing_dir_key == "ne", "AimReticle rotates with directional input ('ne') while stationary")
	p_actor.clear_move_input()
	p_actor.stop_aiming_pokeball()
	_assert_true(not p_actor.aim_reticle_node.visible, "AimReticle hides when aiming ends")
	
	# Catch formula comparison: HP 100% vs HP 10% (e.g., MaxHP=100, CatchRate=120, BallMultiplier=1.0)
	var raw_100pct: float = PokeballProjectile.calculate_catch_formula_value(100, 100, 120, 1.0)
	var raw_10pct: float = PokeballProjectile.calculate_catch_formula_value(100, 10, 120, 1.0)
	var prob_100pct: float = PokeballProjectile.calculate_catch_probability(100, 100, 120, 1.0)
	var prob_10pct: float = PokeballProjectile.calculate_catch_probability(100, 10, 120, 1.0)
	var prob_great_ball_10pct: float = PokeballProjectile.calculate_catch_probability(100, 10, 120, 1.5)
	
	print("Catch Formula Check: HP 100%% -> raw=%.2f (prob=%.3f) | HP 10%% -> raw=%.2f (prob=%.3f) | GreatBall HP 10%% -> prob=%.3f" % [
		raw_100pct, prob_100pct, raw_10pct, prob_10pct, prob_great_ball_10pct
	])
	_assert_true(absf(raw_100pct - 40.0) < 0.01, "Catch formula at 100%% HP matches ((300-200)/300)*120*1.0 = 40.0")
	_assert_true(absf(raw_10pct - 112.0) < 0.01, "Catch formula at 10%% HP matches ((300-20)/300)*120*1.0 = 112.0")
	_assert_true(prob_10pct > prob_100pct, "Catch probability at 10%% HP (%.3f) > 100%% HP (%.3f)" % [prob_10pct, prob_100pct])
	_assert_true(prob_great_ball_10pct > prob_10pct, "Great Ball (1.5x) increases catch probability over Poke Ball (1.0x)")
	
	# Multi-trial simulation (500 rolls each with deterministic seed)
	var sim_rng := RandomNumberGenerator.new()
	sim_rng.seed = 20261025
	var catches_at_100pct: int = 0
	var catches_at_10pct: int = 0
	var trials: int = 500
	for i in range(trials):
		if sim_rng.randf() < prob_100pct:
			catches_at_100pct += 1
		if sim_rng.randf() < prob_10pct:
			catches_at_10pct += 1
	print("Simulation (%d trials): HP 100%% caught %d vs HP 10%% caught %d" % [trials, catches_at_100pct, catches_at_10pct])
	_assert_true(
		catches_at_10pct > catches_at_100pct * 2,
		"10%% HP simulation catch count (%d) is significantly higher than 100%% HP (%d)" % [catches_at_10pct, catches_at_100pct]
	)
	
	# ---------------------------------------------------------
	# [검증 2] 포획 실패 시 적 포켓몬 분노(Enrage) 상태 돌입 검증
	# ---------------------------------------------------------
	print("\n--- [검증 2] 포획 실패 시 몬스터볼 파괴 및 적 포켓몬 분노(Enrage) 상태 돌입 검증 ---")
	var inv_test: Inventory = arena.get_player_inventory()
	inv_test.populate_starter_items()
	
	e_actor.clear_enrage_state()
	e_actor.set_ai_enabled(false)
	p_actor.global_position = Vector2(100, 120)
	e_actor.global_position = Vector2(148, 120)
	
	var base_enemy_speed: float = e_actor.get_effective_move_speed()
	var base_enemy_cd_rate: float = e_actor.get_effective_cooldown_rate()
	var capture_failed_caught: Array[bool] = [false]
	arena.pokemon_capture_failed.connect(func(_mon: PokemonInstance, _shakes: int) -> void:
		capture_failed_caught[0] = true
	, CONNECT_ONE_SHOT)
	
	var fail_ball: PokeballProjectile = arena.throw_pokeball_at(Vector2.RIGHT, "pokeball", 0)
	_assert_true(fail_ball != null, "Spawned PokeballProjectile toward EnemyPokemon (forced_outcome=0 fail)")
	if fail_ball != null:
		fail_ball.shake_interval = 0.02
	
	for i in range(45):
		await _wait_frames(1)
		if capture_failed_caught[0]:
			break
	
	_assert_true(capture_failed_caught[0], "pokemon_capture_failed signal emitted after failed catch attempt")
	_assert_true(e_actor.is_enraged, "EnemyPokemon entered Enrage state (is_enraged == true) after breakout")
	_assert_true(not e_actor.is_in_ball_capture and e_actor.animated_sprite_2d.visible, "EnemyPokemon broke out of ball and is visible again")
	_assert_true(
		e_actor.get_effective_move_speed() > base_enemy_speed and e_actor.get_effective_cooldown_rate() > base_enemy_cd_rate,
		"Enraged EnemyPokemon has increased move speed (%.1f -> %.1f) and attack cooldown rate (%.2fx -> %.2fx)" % [
			base_enemy_speed, e_actor.get_effective_move_speed(), base_enemy_cd_rate, e_actor.get_effective_cooldown_rate()
		]
	)
	_assert_true(
		hud.get_battle_message().contains("분노"),
		"BattleHUD displays Enrage warning message: '%s'" % hud.get_battle_message()
	)
	
	# ---------------------------------------------------------
	# [검증 3] 포획 성공(3회 흔들림) 및 오버월드 복귀 후 데이터(파티/HP/PP/몬스터볼/UI) 유지 검증
	# ---------------------------------------------------------
	print("\n--- [검증 3] 배틀 중 HP/PP/몬스터볼 소모 및 포획 성공 후 오버월드 데이터/UI 동기화 검증 ---")
	err = change_scene_to_file(OVERWORLD_SCENE_PATH)
	_assert_true(err == OK, "Loaded Overworld.tscn for full battle->capture->overworld loop")
	await _wait_frames(4)
	
	# Reset clean party (1 starter Cyndaquil) and starter inventory (5 pokeballs)
	var starter: PokemonInstance = PokemonRegistry.create_instance("cyndaquil", 8, "에이스브케인")
	starter.recalculate_stats(true)
	var typed_party: Array[PokemonInstance] = [starter]
	scene_mgr.party = typed_party
	scene_mgr.player_inventory.populate_starter_items()
	
	var overworld_node: Node2D = current_scene as Node2D
	var ow_player: Player = overworld_node.get_node_or_null("Player") as Player
	ow_player.party = scene_mgr.party
	ow_player.inventory = scene_mgr.player_inventory
	ow_player.teleport_to(Vector2(128, 96), Vector2.DOWN)
	await _wait_frames(2)
	
	var initial_party_size: int = scene_mgr.party.size()
	var initial_pokeballs: int = scene_mgr.player_inventory.get_item_count("pokeball")
	var initial_pp_slot0: int = starter.get_move_instance(0).current_pp
	_assert_true(initial_party_size == 1 and initial_pokeballs == 5, "Initial state: party size=1, pokeballs=5")
	
	# Enter BattleArena against a wild Totodile Lv.6
	var wild_target: PokemonInstance = PokemonRegistry.create_instance("totodile", 6, "야생리아코")
	await scene_mgr.enter_battle_arena(wild_target, {"species_id": "totodile", "level": 6}, 0.02)
	await _wait_frames(3)
	
	var battle_scene: BattleArena = current_scene as BattleArena
	_assert_true(battle_scene != null and battle_scene.name == "BattleArena", "Entered BattleArena against wild Totodile")
	
	var bp_actor: PokemonActor = battle_scene.player_actor
	var be_actor: PokemonActor = battle_scene.enemy_actor
	be_actor.set_ai_enabled(false)
	bp_actor.global_position = Vector2(100, 120)
	be_actor.global_position = Vector2(130, 120)
	
	# Player uses Slot 0 move (consumes 1 PP) and takes 7 damage in battle
	bp_actor.reset_cooldowns()
	var move_cast_ok: bool = bp_actor.use_move(0, Vector2.RIGHT)
	_assert_true(move_cast_ok, "PlayerPokemon cast slot 0 move during battle")
	starter.take_damage(7)
	battle_scene._update_hud()
	var expected_hp_after_battle: int = starter.current_hp
	var expected_pp_after_battle: int = starter.get_move_instance(0).current_pp
	_assert_true(expected_pp_after_battle == initial_pp_slot0 - 1, "PlayerPokemon slot 0 PP decreased by 1 (%d -> %d)" % [initial_pp_slot0, expected_pp_after_battle])
	
	# Throw Pokeball and capture wild Totodile (3 shakes)
	var shake_count_seen: Array[int] = [0]
	var capture_done: Array[bool] = [false]
	battle_scene.pokemon_captured.connect(func(_captured: PokemonInstance) -> void:
		capture_done[0] = true
	, CONNECT_ONE_SHOT)
	
	bp_actor.global_position = Vector2(100, 120)
	be_actor.global_position = Vector2(145, 120)
	var catch_ball: PokeballProjectile = battle_scene.throw_pokeball_at(Vector2.RIGHT, "poke_ball", 1)
	_assert_true(catch_ball != null, "Threw poke_ball at wild Totodile")
	if catch_ball != null:
		catch_ball.shake_interval = 0.02
		catch_ball.shake_step.connect(func(step_n: int) -> void:
			shake_count_seen[0] = step_n
		)
	
	for i in range(50):
		await _wait_frames(1)
		if capture_done[0]:
			break
	
	_assert_true(capture_done[0] and battle_scene.outcome == "captured", "Wild Totodile captured after 3 shakes (shakes=%d, outcome='%s')" % [shake_count_seen[0], battle_scene.outcome])
	_assert_true(shake_count_seen[0] == 3, "Pokeball shook 3 times before capture completed")
	_assert_true(battle_scene.battle_hud.get_battle_message().contains("잡았다"), "BattleHUD shows capture message: '%s'" % battle_scene.battle_hud.get_battle_message())
	
	# Return to Overworld via SceneManager.exit_battle_arena
	await scene_mgr.exit_battle_arena({
		"outcome": "captured",
		"caught": true,
		"captured_pokemon": wild_target,
		"player_pokemon": starter,
	}, 0.02)
	await _wait_frames(4)
	
	var returned_ow: Node2D = current_scene as Node2D
	_assert_true(returned_ow != null and returned_ow.name == "Overworld", "Returned to Overworld after capturing wild pokemon")
	
	# Verify 1) Party size increased by 1 and contains captured pokemon
	_assert_true(
		scene_mgr.player_party.size() == initial_party_size + 1 and scene_mgr.player_party[1].get_species_id() == "totodile",
		"Overworld party size increased to %d and includes captured '%s'" % [scene_mgr.player_party.size(), scene_mgr.player_party[1].get_display_name()]
	)
	# Verify 2) Lead pokemon HP and PP consumed in battle are preserved in Overworld
	var ow_lead: PokemonInstance = scene_mgr.player_party[0]
	_assert_true(
		ow_lead.current_hp == expected_hp_after_battle and ow_lead.get_move_instance(0).current_pp == expected_pp_after_battle,
		"Lead pokemon preserved battle HP (%d/%d) and slot 0 PP (%d/%d) in Overworld" % [
			ow_lead.current_hp, ow_lead.max_hp, ow_lead.get_move_instance(0).current_pp, ow_lead.get_move_instance(0).max_pp
		]
	)
	# Verify 3) Inventory pokeball count decreased by 1
	var pokeballs_after: int = scene_mgr.player_inventory.get_item_count("pokeball")
	_assert_true(
		pokeballs_after == initial_pokeballs - 1,
		"Overworld inventory pokeball count decreased by 1 (%d -> %d)" % [initial_pokeballs, pokeballs_after]
	)
	# Verify 4) Overworld PartyUI and BagUI display updated state via StartMenuUI
	var start_menu: StartMenuUI = returned_ow.get_node_or_null("StartMenuUI") as StartMenuUI
	var party_ui: PartyUI = returned_ow.get_node_or_null("PartyUI") as PartyUI
	var bag_ui: BagUI = returned_ow.get_node_or_null("BagUI") as BagUI
	_assert_true(start_menu != null and party_ui != null and bag_ui != null, "StartMenuUI, PartyUI, and BagUI exist in Overworld")
	
	start_menu.open_menu()
	start_menu.select_option_by_index(0) # Open [포켓몬] PartyUI
	await _wait_frames(1)
	_assert_true(party_ui.is_open, "PartyUI opened from StartMenuUI [포켓몬] option")
	_assert_true(
		party_ui.get_party_list_text().contains("에이스브케인")
		and party_ui.get_party_list_text().contains("야생리아코")
		and party_ui.get_party_list_text().contains("HP %d/%d" % [ow_lead.current_hp, ow_lead.max_hp]),
		"PartyUI displays both party members and updated HP: '%s'" % party_ui.get_party_list_text().replace("\n", " | ")
	)
	_assert_true(
		party_ui.get_details_text().contains("PP %d/%d" % [ow_lead.get_move_instance(0).current_pp, ow_lead.get_move_instance(0).max_pp]),
		"PartyUI displays updated move PP: '%s'" % party_ui.get_details_text().replace("\n", " ")
	)
	party_ui.close_party()
	
	start_menu.select_option_by_index(1) # Open [가방] BagUI
	bag_ui.switch_pocket(ItemData.Pocket.POKEBALLS)
	await _wait_frames(1)
	_assert_true(
		bag_ui.is_open and bag_ui.get_item_list_text().contains("몬스터볼  x%d" % pokeballs_after),
		"BagUI Pokeballs pocket displays updated count '몬스터볼  x%d'" % pokeballs_after
	)
	
	# Verify 1~4 Quick Slot registration in BagUI
	bag_ui.select_item_by_index(1) # Select 수퍼볼 (great_ball)
	var assign_ball_ok: bool = bag_ui.assign_selected_to_quick_slot(2) # Slot index 2 ([3번])
	_assert_true(
		assign_ball_ok and scene_mgr.player_inventory.get_quick_slot_item_id(2) == "great_ball" and bag_ui.get_item_list_text().contains("[3번]"),
		"BagUI assigned 'great_ball' to quick slot 3 ([3번])"
	)
	bag_ui.switch_pocket(ItemData.Pocket.ITEMS)
	bag_ui.select_item_by_index(0) # Select 상처약 (potion)
	var assign_potion_ok: bool = bag_ui.assign_selected_to_quick_slot(0) # Slot index 0 ([1번])
	_assert_true(
		assign_potion_ok and scene_mgr.player_inventory.get_quick_slot_item_id(0) == "potion",
		"BagUI assigned 'potion' to quick slot 1 ([1번])"
	)
	bag_ui.switch_pocket(ItemData.Pocket.KEY_ITEMS)
	bag_ui.select_item_by_index(0) # Select 자전거 (bicycle) -> should be rejected for quick slot
	var assign_key_item_ok: bool = bag_ui.assign_selected_to_quick_slot(3)
	_assert_true(
		not assign_key_item_ok and scene_mgr.player_inventory.get_quick_slot_item_id(3) == "",
		"BagUI rejects assigning Key Item ('bicycle') to battle quick slot 4"
	)
	bag_ui.close_bag()
	start_menu.close_menu()
	
	# ---------------------------------------------------------
	# [검증 4] 실시간 포켓몬 교체(Q/W 퀵 태그 & Tab 파티 선택), 1~4번 아이템 퀵슬롯(상처약 회복/볼 투척) 및 기절 시 연속 출전 -> 전원 기절 시 패배/포켓몬센터 회복 검증
	# ---------------------------------------------------------
	print("\n--- [검증 4] A/S/Z/X 기술 키 + Q/W/Tab 태그 + 1~4 아이템 퀵슬롯(회복약/몬스터볼) 및 기절 연속 출전 -> 전원 기절 패배 검증 ---")
	await scene_mgr.enter_battle_arena(PokemonRegistry.create_instance("rattata", 5, "꼬렛"), {}, 0.02)
	await _wait_frames(3)
	
	var defeat_arena: BattleArena = current_scene as BattleArena
	_assert_true(defeat_arena != null and defeat_arena.name == "BattleArena", "Entered BattleArena for switch & defeat test")
	defeat_arena.enemy_actor.set_ai_enabled(false)
	_assert_true(defeat_arena.battle_party.size() == 2, "BattleArena synced 2 party members ('%s', '%s')" % [
		defeat_arena.battle_party[0].get_display_name(),
		defeat_arena.battle_party[1].get_display_name()
	])
	_assert_true(defeat_arena.battle_hud.get_party_dots_text() == "●●", "BattleHUD shows '●●' for 2 alive party pokemon")
	_assert_true(
		defeat_arena.battle_hud.get_slot_text(0).contains("[A]")
		and defeat_arena.battle_hud.get_slot_text(1).contains("[S]")
		and defeat_arena.battle_hud.get_slot_text(2).contains("[Z]")
		and defeat_arena.battle_hud.get_slot_text(3).contains("[X]"),
		"BattleHUD 2x2 move grid displays [A], [S], [Z], [X] key hints"
	)
	_assert_true(
		defeat_arena.battle_hud.get_quick_slots_summary_text().contains("[1]상처약:")
		and defeat_arena.battle_hud.get_quick_slots_summary_text().contains("[3]수퍼볼:"),
		"BattleHUD displays 1~4 quick slots summary: '%s'" % defeat_arena.battle_hud.get_quick_slots_summary_text()
	)
	
	# 4-0. Quick Slot 1~4 Healing Item (Potion) & Pokeball (Great Ball) usage in BattleArena
	var lead_mon_in_battle: PokemonInstance = defeat_arena.player_pokemon
	lead_mon_in_battle.current_hp = maxi(1, lead_mon_in_battle.max_hp - 12)
	defeat_arena._update_hud()
	var hp_before_potion: int = lead_mon_in_battle.current_hp
	var potions_before: int = scene_mgr.player_inventory.get_item_count("potion")
	var used_potion: Variant = defeat_arena.use_quick_slot_item(0) # Slot 0 = [1번] 상처약
	_assert_true(
		bool(used_potion) and lead_mon_in_battle.current_hp == lead_mon_in_battle.max_hp and scene_mgr.player_inventory.get_item_count("potion") == potions_before - 1,
		"Quick slot 1 ([1번] 상처약) healed PlayerPokemon HP (%d -> %d) and deducted 1 potion (%d -> %d)" % [
			hp_before_potion, lead_mon_in_battle.current_hp, potions_before, scene_mgr.player_inventory.get_item_count("potion")
		]
	)
	_assert_true(
		defeat_arena.player_actor.last_floating_text.begins_with("+") and defeat_arena.battle_hud.get_battle_message().contains("회복했다"),
		"Healing item spawned green +HP floating text ('%s') and HUD message ('%s')" % [
			defeat_arena.player_actor.last_floating_text, defeat_arena.battle_hud.get_battle_message()
		]
	)
	# Using potion again at full HP must be blocked without consuming item
	var potions_at_full: int = scene_mgr.player_inventory.get_item_count("potion")
	var used_potion_when_full: Variant = defeat_arena.use_quick_slot_item(0)
	_assert_true(
		not bool(used_potion_when_full) and scene_mgr.player_inventory.get_item_count("potion") == potions_at_full,
		"Using healing item at full HP is blocked and does not consume potion"
	)
	defeat_arena.player_actor.reset_cooldowns()
	
	# Quick slot 3 ([3번] 수퍼볼) throw test (aim away from enemy so battle continues for switch test)
	defeat_arena.player_actor.global_position = Vector2(120, 240)
	defeat_arena.enemy_actor.global_position = Vector2(420, 240)
	var great_balls_before: int = scene_mgr.player_inventory.get_item_count("great_ball")
	var quick_ball_proj: PokeballProjectile = defeat_arena.use_quick_slot_item(2, Vector2.LEFT) as PokeballProjectile
	_assert_true(
		quick_ball_proj != null and quick_ball_proj.ball_item_id == "great_ball" and absf(quick_ball_proj.ball_multiplier - 1.5) < 0.01,
		"Quick slot 3 ([3번] 수퍼볼) spawned PokeballProjectile with ball_item_id='great_ball' (1.5x)"
	)
	_assert_true(
		scene_mgr.player_inventory.get_item_count("great_ball") == great_balls_before - 1,
		"Quick slot 3 deducted 1 great_ball from inventory (%d -> %d)" % [
			great_balls_before, scene_mgr.player_inventory.get_item_count("great_ball")
		]
	)
	if quick_ball_proj != null and is_instance_valid(quick_ball_proj):
		quick_ball_proj.queue_free()
	await _wait_frames(1)
	
	# 4-A. Q/E Quick Tag switch verification
	defeat_arena.player_actor.global_position = Vector2(212, 236)
	defeat_arena.player_actor.set_facing_direction("ne")
	var pre_switch_pos: Vector2 = defeat_arena.player_actor.global_position
	var pre_switch_dir: String = defeat_arena.player_actor.facing_dir_key
	
	var switched_sig_caught: Array[bool] = [false]
	defeat_arena.pokemon_switched.connect(func(_new_m: PokemonInstance, _old_m: PokemonInstance, _idx: int) -> void:
		switched_sig_caught[0] = true
	, CONNECT_ONE_SHOT)
	
	var quick_switched: bool = defeat_arena.cycle_switch_pokemon(1) # E key: switch to index 1 (야생리아코)
	_assert_true(quick_switched and switched_sig_caught[0], "cycle_switch_pokemon(1) switched active pokemon to slot 1 ('야생리아코')")
	_assert_true(
		defeat_arena.active_party_index == 1 and defeat_arena.player_pokemon.get_display_name() == "야생리아코",
		"Active pokemon is now '야생리아코' (index 1)"
	)
	_assert_true(
		defeat_arena.player_actor.global_position.distance_to(pre_switch_pos) < 0.01 and defeat_arena.player_actor.facing_dir_key == pre_switch_dir,
		"Switch preserved player_actor position %s and facing_dir_key '%s'" % [str(pre_switch_pos), pre_switch_dir]
	)
	_assert_true(
		absf(defeat_arena.player_actor.invincible_timer - 0.3) < 0.05
		and absf(defeat_arena.player_actor.shared_cooldown - 1.0) < 0.05
		and absf(defeat_arena.switch_cooldown - 4.0) < 0.05,
		"Switch applied 0.3s invincibility (%.2f), 1.0s shared skill cooldown (%.2f), and 4.0s switch cooldown (%.2f)" % [
			defeat_arena.player_actor.invincible_timer,
			defeat_arena.player_actor.shared_cooldown,
			defeat_arena.switch_cooldown
		]
	)
	_assert_true(
		defeat_arena.battle_hud.get_battle_message().contains("돌아와 에이스브케인! 가라 야생리아코!"),
		"BattleHUD displays switch message: '%s'" % defeat_arena.battle_hud.get_battle_message()
	)
	_assert_true(
		defeat_arena.battle_hud.get_slot_text(1).contains("물대포"),
		"BattleHUD move slots updated immediately to Totodile's moves ('물대포')"
	)
	
	# Verify 4.0s switch cooldown blocks immediate re-switch
	var cd_block_caught: Array[bool] = [false]
	defeat_arena.switch_failed.connect(func(_reason: String) -> void:
		cd_block_caught[0] = true
	, CONNECT_ONE_SHOT)
	var blocked_by_switch_cd: bool = not defeat_arena.cycle_switch_pokemon(-1)
	_assert_true(
		blocked_by_switch_cd and cd_block_caught[0] and defeat_arena.battle_hud.get_battle_message().contains("쿨타임"),
		"Immediate re-switch is blocked during 4.0s switch cooldown"
	)
	
	# 4-B. Tab Party Popup selection verification
	defeat_arena.switch_cooldown = 0.0
	var opened_popup: bool = defeat_arena.open_battle_party_menu()
	_assert_true(
		opened_popup and defeat_arena.is_party_menu_open and defeat_arena.battle_party_ui.is_open,
		"open_battle_party_menu() opened BattlePartyUI and set is_party_menu_open=true"
	)
	_assert_true(
		defeat_arena.player_actor.is_battle_paused and defeat_arena.enemy_actor.is_battle_paused,
		"Player and Enemy actors are paused while BattlePartyUI is open"
	)
	# Selecting already-active slot 1 ('야생리아코') should be rejected with message
	var same_slot_ok: bool = defeat_arena.battle_party_ui.confirm_selection()
	_assert_true(
		not same_slot_ok and defeat_arena.battle_party_ui.is_open and defeat_arena.battle_party_ui.get_details_text().contains("이미 전투에"),
		"Selecting already-active pokemon in BattlePartyUI is rejected with notice"
	)
	# Select slot 0 ('에이스브케인') and confirm
	defeat_arena.battle_party_ui.select_member(0)
	var tab_switch_ok: bool = defeat_arena.battle_party_ui.confirm_selection()
	_assert_true(
		tab_switch_ok and not defeat_arena.is_party_menu_open and not defeat_arena.player_actor.is_battle_paused,
		"Confirming slot 0 in BattlePartyUI closed menu, unpaused actors, and switched to '에이스브케인'"
	)
	_assert_true(
		defeat_arena.active_party_index == 0 and defeat_arena.player_pokemon.get_display_name() == "에이스브케인",
		"Active pokemon switched back to '에이스브케인' (index 0) via BattlePartyUI"
	)
	
	# 4-C. Fainting auto-switch to next alive pokemon, then full party wipe -> Defeat & PokeCenter heal
	var defeat_result_captured: Array[Dictionary] = [{}]
	defeat_arena.battle_ended.connect(func(res: Dictionary) -> void:
		defeat_result_captured[0] = res
	, CONNECT_ONE_SHOT)
	
	# Deal fatal damage to 1st pokemon ('에이스브케인') while 2nd ('야생리아코') is alive -> must auto-switch!
	defeat_arena.player_actor.clear_invincibility()
	defeat_arena.player_actor.receive_hit(9999)
	await _wait_frames(2)
	
	_assert_true(
		not defeat_arena.is_battle_resolved and defeat_arena.outcome == "",
		"Battle continues when 1st pokemon faints while another alive party pokemon exists"
	)
	_assert_true(
		defeat_arena.active_party_index == 1 and defeat_arena.player_pokemon.get_display_name() == "야생리아코",
		"Automatically sent out next alive pokemon ('야생리아코') upon lead fainting"
	)
	_assert_true(
		defeat_arena.battle_hud.get_battle_message().contains("에이스브케인은(는) 쓰러졌다! 가라 야생리아코!"),
		"BattleHUD displays faint-replacement message: '%s'" % defeat_arena.battle_hud.get_battle_message()
	)
	_assert_true(
		defeat_arena.battle_hud.get_party_dots_text() == "○●",
		"BattleHUD party indicator updated to '○●' (slot 0 fainted, slot 1 alive)"
	)
	
	# Now deal fatal damage to the last remaining pokemon ('야생리아코') -> all fainted -> Defeat!
	defeat_arena.player_actor.clear_invincibility()
	defeat_arena.player_actor.receive_hit(9999)
	await _wait_frames(2)
	
	_assert_true(
		defeat_arena.outcome == "defeat" and bool(defeat_result_captured[0].get("defeated", false)),
		"BattleArena recorded defeat when ALL party pokemon HP reached 0"
	)
	_assert_true(
		defeat_arena.battle_hud.get_battle_message().contains("눈앞이 캄캄해졌다"),
		"BattleHUD displays blackout message: '%s'" % defeat_arena.battle_hud.get_battle_message()
	)
	
	await scene_mgr.exit_battle_arena(defeat_result_captured[0], 0.02)
	await _wait_frames(4)
	
	_assert_true(
		current_scene != null and current_scene.name == "PokeCenter",
		"Player warped to PokeCenter.tscn upon battle defeat (current_scene=%s)" % (current_scene.name if current_scene else "null")
	)
	var all_healed: bool = true
	for member in scene_mgr.player_party:
		if member.current_hp != member.max_hp:
			all_healed = false
		for m_i in range(member.get_move_count()):
			var mi: MoveInstance = member.get_move_instance(m_i)
			if mi.current_pp != mi.max_pp:
				all_healed = false
	_assert_true(all_healed, "All party pokemon HP and move PP were fully restored to max at PokeCenter")
	
	# Warp back to Overworld for Save/Load verification
	await scene_mgr.warp_to_scene(OVERWORLD_SCENE_PATH, Vector2(144, 112), Vector2.LEFT, 0.02)
	await _wait_frames(4)
	
	# ---------------------------------------------------------
	# [검증 5] SaveManager (user://savegame.json) 리포트 저장 및 불러오기 검증
	# ---------------------------------------------------------
	print("\n--- [검증 5] SaveManager (user://savegame.json) 리포트 저장 및 상태 완벽 복원 검증 ---")
	var ow_for_save: Node2D = current_scene as Node2D
	var player_for_save: Player = ow_for_save.get_node_or_null("Player") as Player
	var menu_for_save: StartMenuUI = ow_for_save.get_node_or_null("StartMenuUI") as StartMenuUI
	
	# Prepare specific state to save
	player_for_save.teleport_to(Vector2(144, 112), Vector2.LEFT)
	time_mgr.set_forced_hour(22, true) # NIGHT (period 2)
	scene_mgr.player_party[0].current_hp = scene_mgr.player_party[0].max_hp - 5
	scene_mgr.player_party[0].get_move_instance(1).current_pp = 11
	var saved_lead_hp: int = scene_mgr.player_party[0].current_hp
	var saved_lead_pp1: int = scene_mgr.player_party[0].get_move_instance(1).current_pp
	var saved_party_count: int = scene_mgr.player_party.size()
	var saved_ball_count: int = scene_mgr.player_inventory.get_item_count("pokeball")
	var saved_great_ball_count: int = scene_mgr.player_inventory.get_item_count("great_ball")
	
	# Save via StartMenuUI [리포트] option (index 2)
	menu_for_save.open_menu()
	menu_for_save.select_option_by_index(2)
	await _wait_frames(2)
	
	_assert_true(save_mgr.has_save_file(SAVE_FILE_PATH), "user://savegame.json file created on disk")
	_assert_true(
		dialogue_mgr != null and dialogue_mgr.is_active and dialogue_mgr.get_current_text().contains("리포트"),
		"DialogueBox announced report completion: '%s'" % (dialogue_mgr.get_current_text() if dialogue_mgr else "")
	)
	if dialogue_mgr and dialogue_mgr.is_active:
		dialogue_mgr.close_dialogue()
	
	# Mutate all live states (position, facing, time, party, HP, PP, inventory)
	player_for_save.teleport_to(Vector2(64, 64), Vector2.UP)
	time_mgr.set_forced_hour(6, true) # MORNING (period 0)
	scene_mgr.player_party.clear()
	scene_mgr.player_party.append(PokemonRegistry.create_instance("pidgey", 2, "임시구구"))
	scene_mgr.player_inventory.clear()
	
	_assert_true(
		player_for_save.position == Vector2(64, 64) and time_mgr.current_hour == 6 and scene_mgr.player_party.size() == 1,
		"Mutated live game state before calling SaveManager.load_game()"
	)
	
	# Load from user://savegame.json
	var loaded_ok: bool = save_mgr.load_game(SAVE_FILE_PATH)
	await _wait_frames(2)
	_assert_true(loaded_ok, "SaveManager.load_game('user://savegame.json') returned true")
	_assert_true(
		player_for_save.position.distance_to(Vector2(144, 112)) < 0.1 and player_for_save.facing_direction == Vector2.LEFT,
		"Restored Player position (144, 112) and facing direction (LEFT) (actual pos=%s, facing=%s)" % [
			str(player_for_save.position), str(player_for_save.facing_direction)
		]
	)
	_assert_true(
		time_mgr.current_hour == 22 and time_mgr.current_period == 2,
		"Restored TimeManager hour=22 and period=NIGHT (2)"
	)
	_assert_true(
		scene_mgr.player_party.size() == saved_party_count
		and scene_mgr.player_party[0].get_display_name() == "에이스브케인"
		and scene_mgr.player_party[1].get_display_name() == "야생리아코",
		"Restored full party roster including captured pokemon ('%s', '%s')" % [
			scene_mgr.player_party[0].get_display_name(),
			scene_mgr.player_party[1].get_display_name() if scene_mgr.player_party.size() > 1 else "none"
		]
	)
	_assert_true(
		scene_mgr.player_party[0].current_hp == saved_lead_hp
		and scene_mgr.player_party[0].get_move_instance(1).current_pp == saved_lead_pp1,
		"Restored exact lead pokemon HP (%d) and move slot 1 PP (%d)" % [
			scene_mgr.player_party[0].current_hp,
			scene_mgr.player_party[0].get_move_instance(1).current_pp
		]
	)
	_assert_true(
		scene_mgr.player_inventory.get_item_count("pokeball") == saved_ball_count
		and scene_mgr.player_inventory.get_item_count("great_ball") == saved_great_ball_count
		and scene_mgr.player_inventory.get_item_count("bicycle") == 1,
		"Restored all 4 pockets of Inventory (pokeball=%d, great_ball=%d, bicycle=%d)" % [
			scene_mgr.player_inventory.get_item_count("pokeball"),
			scene_mgr.player_inventory.get_item_count("great_ball"),
			scene_mgr.player_inventory.get_item_count("bicycle")
		]
	)
	
	# Summary
	if failures.is_empty():
		print("\n=== [ALL PHASE 5 HEADLESS QA TESTS PASSED] ===")
		quit(0)
	else:
		printerr("\n=== [PHASE 5 QA FAILED: %d failure(s)] ===" % failures.size())
		quit(1)
