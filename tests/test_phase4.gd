extends SceneTree

const BATTLE_ARENA_SCENE_PATH: String = "res://scenes/battle/BattleArena.tscn"

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
	print("=== [Phase 4 Headless QA Verification Start] ===")
	
	# ---------------------------------------------------------
	# [사전 점검] MoveData, MoveInstance, MoveRegistry 및 .tres 리소스 로드 검증
	# ---------------------------------------------------------
	print("\n--- [사전 점검] MoveData / MoveInstance / MoveRegistry 리소스 구조 검증 ---")
	var core_move_ids: Array[String] = ["tackle", "ember", "leer", "quick_attack", "water_gun", "razor_leaf", "gust"]
	for m_id in core_move_ids:
		var m_data: MoveData = MoveRegistry.get_move_data(m_id)
		_assert_true(m_data != null and m_data.move_id == m_id, "MoveRegistry loaded MoveData for '%s' (%s)" % [m_id, m_data.display_name if m_data else "null"])
	
	_assert_true(
		MoveRegistry.get_type_effectiveness("Fire", "GRASS") == 2.0 and MoveRegistry.get_type_effectiveness("Water", "FIRE") == 2.0,
		"Type effectiveness chart works (Fire->Grass=2.0x, Water->Fire=2.0x)"
	)
	
	var err: Error = change_scene_to_file(BATTLE_ARENA_SCENE_PATH)
	_assert_true(err == OK, "Loaded BattleArena.tscn successfully")
	await _wait_frames(4)
	
	var arena: BattleArena = current_scene as BattleArena
	_assert_true(arena != null and arena.name == "BattleArena", "Current scene is BattleArena")
	
	var p_actor: PokemonActor = arena.player_actor
	var e_actor: PokemonActor = arena.enemy_actor
	var hud: BattleHUD = arena.battle_hud
	_assert_true(p_actor != null and e_actor != null and hud != null, "PlayerPokemon, EnemyPokemon, and BattleHUD exist in BattleArena")
	
	# Setup Lv.10 Cyndaquil vs Lv.10 Pidgey with high HP so all tests can run cleanly
	var p_mon: PokemonInstance = PokemonRegistry.create_instance("cyndaquil", 10, "브케인")
	p_mon.max_hp = 80
	p_mon.current_hp = 80
	var w_mon: PokemonInstance = PokemonRegistry.create_instance("pidgey", 10, "구구")
	w_mon.max_hp = 120
	w_mon.current_hp = 120
	arena.setup_from_snapshot({
		"player_pokemon": p_mon,
		"wild_pokemon": w_mon,
	})
	await _wait_frames(2)
	
	_assert_true(p_mon.get_move_count() == 4, "PlayerPokemon has 4 MoveInstance slots initialized")
	_assert_true(
		hud.get_slot_text(0).contains("몸통박치기") and hud.get_slot_text(0).contains("35/35")
		and hud.get_slot_text(1).contains("불꽃세례") and hud.get_slot_text(1).contains("25/25")
		and hud.get_slot_text(2).contains("째려보기") and hud.get_slot_text(2).contains("30/30")
		and hud.get_slot_text(3).contains("전광석화") and hud.get_slot_text(3).contains("30/30"),
		"BattleHUD displays all 4 move names and initial PP values"
	)
	
	# ---------------------------------------------------------
	# [검증 1] 4개 기술 발동 및 PP 차감 검증
	# ---------------------------------------------------------
	print("\n--- [검증 1] 4개 기술(몸통박치기/불꽃세례/째려보기/전광석화) 발동 및 PP 1씩 차감 검증 ---")
	
	# 1-1. Slot 0: 몸통박치기 (MELEE_LUNGE)
	p_actor.global_position = Vector2(100, 120)
	e_actor.global_position = Vector2(130, 120)
	p_actor.set_facing_direction("e")
	p_actor.reset_cooldowns()
	e_actor.clear_invincibility()
	
	var pp0_before: int = p_mon.get_move_instance(0).current_pp
	var pos_before_lunge: Vector2 = p_actor.global_position
	var used_0: bool = p_actor.use_move(0, Vector2.RIGHT)
	var pp0_after: int = p_mon.get_move_instance(0).current_pp
	_assert_true(used_0, "Slot 0 (몸통박치기 - MELEE_LUNGE) executed successfully")
	_assert_true(pp0_after == pp0_before - 1, "Slot 0 PP decreased by 1 (%d -> %d)" % [pp0_before, pp0_after])
	_assert_true(p_actor.global_position.x > pos_before_lunge.x, "Slot 0 MELEE_LUNGE moved actor forward (%s -> %s)" % [str(pos_before_lunge), str(p_actor.global_position)])
	_assert_true(hud.get_slot_text(0).contains("%d/%d" % [pp0_after, p_mon.get_move_instance(0).max_pp]), "BattleHUD Slot 0 label updated PP to %d/%d" % [pp0_after, p_mon.get_move_instance(0).max_pp])
	
	# 1-2. Slot 1: 불꽃세례 (PROJECTILE)
	p_actor.global_position = Vector2(100, 120)
	e_actor.global_position = Vector2(170, 120)
	p_actor.reset_cooldowns()
	e_actor.clear_invincibility()
	
	var proj_spawned: Array[bool] = [false]
	var on_proj := func(_proj: Projectile, _dir: Vector2) -> void:
		proj_spawned[0] = true
	p_actor.projectile_fired.connect(on_proj, CONNECT_ONE_SHOT)
	
	var pp1_before: int = p_mon.get_move_instance(1).current_pp
	var used_1: bool = p_actor.use_move(1, Vector2.RIGHT)
	var pp1_after: int = p_mon.get_move_instance(1).current_pp
	_assert_true(used_1 and proj_spawned[0], "Slot 1 (불꽃세례 - PROJECTILE) spawned Projectile toward target")
	_assert_true(pp1_after == pp1_before - 1, "Slot 1 PP decreased by 1 (%d -> %d)" % [pp1_before, pp1_after])
	_assert_true(hud.get_slot_text(1).contains("%d/%d" % [pp1_after, p_mon.get_move_instance(1).max_pp]), "BattleHUD Slot 1 label updated PP to %d/%d" % [pp1_after, p_mon.get_move_instance(1).max_pp])
	
	# Wait for projectile to hit enemy
	await _wait_frames(20)
	
	# 1-3. Slot 2: 째려보기 (DEBUFF_WAVE)
	p_actor.global_position = Vector2(120, 120)
	e_actor.global_position = Vector2(156, 120)
	p_actor.reset_cooldowns()
	e_actor.defense_stage = 0
	
	var pp2_before: int = p_mon.get_move_instance(2).current_pp
	var used_2: bool = p_actor.use_move(2, Vector2.RIGHT)
	var pp2_after: int = p_mon.get_move_instance(2).current_pp
	_assert_true(used_2, "Slot 2 (째려보기 - DEBUFF_WAVE) executed successfully")
	_assert_true(pp2_after == pp2_before - 1, "Slot 2 PP decreased by 1 (%d -> %d)" % [pp2_before, pp2_after])
	_assert_true(e_actor.defense_stage == -1, "Slot 2 DEBUFF_WAVE lowered EnemyPokemon defense_stage to -1")
	_assert_true(hud.get_slot_text(2).contains("%d/%d" % [pp2_after, p_mon.get_move_instance(2).max_pp]), "BattleHUD Slot 2 label updated PP to %d/%d" % [pp2_after, p_mon.get_move_instance(2).max_pp])
	
	# 1-4. Slot 3: 전광석화 (QUICK_DASH)
	p_actor.global_position = Vector2(100, 120)
	e_actor.global_position = Vector2(140, 120)
	p_actor.reset_cooldowns()
	e_actor.clear_invincibility()
	
	var pp3_before: int = p_mon.get_move_instance(3).current_pp
	var pos_before_dash: Vector2 = p_actor.global_position
	var e_hp_before_dash: int = w_mon.current_hp
	var used_3: bool = p_actor.use_move(3, Vector2.RIGHT)
	var pp3_after: int = p_mon.get_move_instance(3).current_pp
	_assert_true(used_3, "Slot 3 (전광석화 - QUICK_DASH) executed successfully")
	_assert_true(pp3_after == pp3_before - 1, "Slot 3 PP decreased by 1 (%d -> %d)" % [pp3_before, pp3_after])
	_assert_true(p_actor.global_position.x - pos_before_dash.x >= 25.0, "Slot 3 QUICK_DASH dashed forward rapidly (dx=%.1f)" % (p_actor.global_position.x - pos_before_dash.x))
	_assert_true(w_mon.current_hp < e_hp_before_dash, "Slot 3 QUICK_DASH dealt damage to EnemyPokemon along dash path (%d -> %d)" % [e_hp_before_dash, w_mon.current_hp])
	_assert_true(hud.get_slot_text(3).contains("%d/%d" % [pp3_after, p_mon.get_move_instance(3).max_pp]), "BattleHUD Slot 3 label updated PP to %d/%d" % [pp3_after, p_mon.get_move_instance(3).max_pp])
	
	# ---------------------------------------------------------
	# [검증 2] PP 0일 때 시전 불가 및 경고 메시지/시그널 검증
	# ---------------------------------------------------------
	print("\n--- [검증 2] PP 0일 때 기술 시전 불가 및 경고 시그널/HUD 메시지 검증 ---")
	p_actor.reset_cooldowns()
	var ember_inst: MoveInstance = p_mon.get_move_instance(1)
	ember_inst.current_pp = 0
	hud.refresh_all()
	
	var no_pp_signal_caught: Array[bool] = [false]
	var failed_slot_idx: Array[int] = [-1]
	p_actor.move_failed_no_pp.connect(func(slot_idx: int, _m_name: String) -> void:
		no_pp_signal_caught[0] = true
		failed_slot_idx[0] = slot_idx
	, CONNECT_ONE_SHOT)
	
	var used_when_zero_pp: bool = p_actor.use_move(1, Vector2.RIGHT)
	_assert_true(not used_when_zero_pp, "use_move(1) returns false when current_pp == 0")
	_assert_true(no_pp_signal_caught[0] and failed_slot_idx[0] == 1, "move_failed_no_pp signal emitted for slot 1")
	_assert_true(ember_inst.current_pp == 0, "Slot 1 PP remains 0 after blocked cast")
	_assert_true(hud.is_slot_zero_pp(1), "BattleHUD marks slot 1 as 0 PP")
	_assert_true(hud.get_battle_message().contains("PP가 부족"), "BattleHUD message displays no-PP warning: '%s'" % hud.get_battle_message())
	
	# Restore PP for remaining tests
	p_mon.restore_all_pp()
	hud.refresh_all()
	
	# ---------------------------------------------------------
	# [검증 3] 피격 데미지 공식, 디버프(째려보기) 배율, 무적 시간(i-frame) 및 플로팅 텍스트 검증
	# ---------------------------------------------------------
	print("\n--- [검증 3] 위력 공식 데미지, 째려보기 방어력 하락 반영, i-frame 무적 시간 및 플로팅 텍스트 검증 ---")
	w_mon.current_hp = w_mon.max_hp
	e_actor.defense_stage = 0
	e_actor.clear_invincibility()
	p_actor.reset_cooldowns()
	p_actor.global_position = Vector2(110, 120)
	e_actor.global_position = Vector2(132, 120)
	
	var hp_start: int = w_mon.current_hp
	var hit1_ok: bool = p_actor.use_move(0, Vector2.RIGHT) # 몸통박치기 (defense_stage = 0)
	var hp_after_hit1: int = w_mon.current_hp
	var dmg_stage_0: int = hp_start - hp_after_hit1
	_assert_true(hit1_ok and dmg_stage_0 > 0, "Hit 1 (defense_stage=0) dealt %d damage (HP %d -> %d)" % [dmg_stage_0, hp_start, hp_after_hit1])
	_assert_true(e_actor.last_floating_text == "-%d" % dmg_stage_0, "EnemyPokemon spawned floating damage text '%s'" % e_actor.last_floating_text)
	_assert_true(int(hud.enemy_hp_bar.value) == hp_after_hit1, "BattleHUD enemy HP bar updated to %d" % int(hud.enemy_hp_bar.value))
	
	# Immediately test i-frame block while e_actor.is_invincible() is true
	_assert_true(e_actor.is_invincible(), "EnemyPokemon is in i-frame (invincible_timer=%.2fs > 0)" % e_actor.invincible_timer)
	p_actor.reset_cooldowns()
	p_actor.global_position = Vector2(110, 120)
	e_actor.global_position = Vector2(132, 120)
	
	var iframe_blocked: Array[bool] = [false]
	e_actor.hit_blocked_iframe.connect(func(_src: String) -> void:
		iframe_blocked[0] = true
	, CONNECT_ONE_SHOT)
	
	p_actor.use_move(0, Vector2.RIGHT) # Attack during i-frame
	var hp_during_iframe: int = w_mon.current_hp
	_assert_true(
		iframe_blocked[0] and hp_during_iframe == hp_after_hit1,
		"Attack during i-frame was blocked (HP remained %d)" % hp_during_iframe
	)
	
	# Wait for i-frame to expire naturally, then apply Leer (-2 defense stages) and hit again
	await _wait_frames(35)
	_assert_true(not e_actor.is_invincible(), "EnemyPokemon i-frame expired after duration")
	
	p_actor.reset_cooldowns()
	p_actor.global_position = Vector2(110, 120)
	e_actor.global_position = Vector2(136, 120)
	p_actor.use_move(2, Vector2.RIGHT) # 째려보기 (-1)
	p_actor.reset_cooldowns()
	p_actor.use_move(2, Vector2.RIGHT) # 째려보기 (-2)
	_assert_true(e_actor.defense_stage == -2, "Leer stacked EnemyPokemon defense_stage to -2")
	_assert_true(e_actor.last_floating_text.contains("방어력 감소"), "Floating text recorded stat debuff: '%s'" % e_actor.last_floating_text)
	
	p_actor.reset_cooldowns()
	p_actor.global_position = Vector2(110, 120)
	e_actor.global_position = Vector2(132, 120)
	var hp_before_debuffed_hit: int = w_mon.current_hp
	p_actor.use_move(0, Vector2.RIGHT) # 몸통박치기 (defense_stage = -2)
	var dmg_stage_minus2: int = hp_before_debuffed_hit - w_mon.current_hp
	print("Damage comparison: stage 0 = %d vs stage -2 = %d" % [dmg_stage_0, dmg_stage_minus2])
	_assert_true(
		dmg_stage_minus2 > dmg_stage_0,
		"Defense debuff from Leer increased Tackle damage (%d -> %d)" % [dmg_stage_0, dmg_stage_minus2]
	)
	
	# ---------------------------------------------------------
	# [검증 4] 적 야생 포켓몬 간이 FSM AI (IDLE_WANDER -> CHASE -> ATTACK) 검증
	# ---------------------------------------------------------
	print("\n--- [검증 4] 적 야생 포켓몬 간이 FSM AI (IDLE_WANDER -> CHASE -> ATTACK) 검증 ---")
	p_actor.clear_move_input()
	p_actor.clear_invincibility()
	e_actor.clear_invincibility()
	e_actor.reset_cooldowns()
	w_mon.restore_all_pp()
	
	# 4-A. Far distance (220px > ai_detect_range 150px) -> IDLE_WANDER
	p_actor.global_position = Vector2(40, 180)
	e_actor.global_position = Vector2(260, 60)
	e_actor.set_ai_state(PokemonActor.AIState.IDLE_WANDER)
	e_actor.set_ai_enabled(true, p_actor)
	await _wait_frames(6)
	_assert_true(
		e_actor.ai_state == PokemonActor.AIState.IDLE_WANDER,
		"Enemy AI stays in IDLE_WANDER when player is outside detect range (dist=%.1f)" % p_actor.global_position.distance_to(e_actor.global_position)
	)
	
	# 4-B. Medium distance (100px <= ai_detect_range 150px, > ai_attack_range 44px) -> CHASE
	p_actor.global_position = Vector2(140, 120)
	e_actor.global_position = Vector2(240, 120)
	var dist_before_chase: float = p_actor.global_position.distance_to(e_actor.global_position)
	await _wait_frames(8)
	var dist_after_chase: float = p_actor.global_position.distance_to(e_actor.global_position)
	_assert_true(
		e_actor.ai_state == PokemonActor.AIState.CHASE,
		"Enemy AI transitioned from IDLE_WANDER to CHASE when player entered detect range"
	)
	_assert_true(
		dist_after_chase < dist_before_chase,
		"Enemy AI in CHASE state moved closer to player (dist %.1f -> %.1f)" % [dist_before_chase, dist_after_chase]
	)
	
	# 4-C. Close distance (<= ai_attack_range 44px) -> ATTACK & skill execution + PP deduction
	var enemy_move_casted: Array[bool] = [false]
	var enemy_slot_used: Array[int] = [-1]
	e_actor.move_used.connect(func(slot_idx: int, _m_inst: MoveInstance, _m_data: MoveData) -> void:
		enemy_move_casted[0] = true
		enemy_slot_used[0] = slot_idx
	, CONNECT_ONE_SHOT)
	
	var total_enemy_pp_before: int = 0
	for i in range(w_mon.get_move_count()):
		total_enemy_pp_before += w_mon.get_move_instance(i).current_pp
	
	e_actor.reset_cooldowns()
	p_actor.global_position = Vector2(160, 120)
	e_actor.global_position = Vector2(190, 120) # dist = 30px <= ai_attack_range (44px)
	await _wait_frames(6)
	
	var total_enemy_pp_after: int = 0
	for i in range(w_mon.get_move_count()):
		total_enemy_pp_after += w_mon.get_move_instance(i).current_pp
	
	_assert_true(
		e_actor.ai_state == PokemonActor.AIState.ATTACK,
		"Enemy AI transitioned to ATTACK state within attack range"
	)
	_assert_true(
		enemy_move_casted[0] and total_enemy_pp_after == total_enemy_pp_before - 1,
		"Enemy AI cast move slot %d and deducted 1 PP (total PP %d -> %d)" % [enemy_slot_used[0], total_enemy_pp_before, total_enemy_pp_after]
	)
	
	e_actor.set_ai_enabled(false)
	
	# Summary
	if failures.is_empty():
		print("\n=== [ALL PHASE 4 HEADLESS QA TESTS PASSED] ===")
		quit(0)
	else:
		printerr("\n=== [PHASE 4 QA FAILED: %d failure(s)] ===" % failures.size())
		quit(1)
