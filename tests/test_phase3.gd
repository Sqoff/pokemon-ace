extends SceneTree

const OVERWORLD_SCENE_PATH: String = "res://scenes/overworld/Overworld.tscn"
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
	print("=== [Phase 3 Headless QA Verification Start] ===")
	
	var scene_mgr: Node = root.get_node_or_null("SceneManager")
	_assert_true(scene_mgr != null, "SceneManager Autoload singleton is registered")
	if scene_mgr:
		scene_mgr.fade_duration = 0.03
	
	# ---------------------------------------------------------
	# [검증 1] PMDCollab/SpriteCollab 8방향 에셋 연동 및 SpriteFrames 생성 검증
	# ---------------------------------------------------------
	print("\n--- [검증 1] PMDCollab/SpriteCollab AnimData.xml 파싱 및 8방향 x 4상태 SpriteFrames 검증 ---")
	var species_to_verify: Array[String] = ["cyndaquil", "chikorita", "totodile", "pidgey", "rattata", "hoothoot", "sentret"]
	var expected_dirs: Array[String] = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
	var expected_actions: Array[String] = ["idle", "walk", "attack", "hurt"]
	
	for sp_id in species_to_verify:
		var anim_data: Dictionary = PMDSpriteLoader.parse_anim_data(sp_id)
		_assert_true(not anim_data.is_empty(), "Parsed AnimData.xml for species '%s'" % sp_id)
		
		var frames: SpriteFrames = PMDSpriteLoader.build_sprite_frames(sp_id)
		_assert_true(frames != null, "Built SpriteFrames for species '%s'" % sp_id)
		if frames != null:
			var all_32_valid: bool = true
			for act in expected_actions:
				for d in expected_dirs:
					var anim_name := StringName("%s_%s" % [act, d])
					if not frames.has_animation(anim_name) or frames.get_frame_count(anim_name) <= 0:
						all_32_valid = false
						printerr("Missing or empty animation '%s' for species '%s'" % [anim_name, sp_id])
			_assert_true(all_32_valid, "Species '%s' has all 32 animations (8 directions x 4 actions) with valid frames" % sp_id)
	
	# ---------------------------------------------------------
	# [검증 2] 풀숲 조우 및 아레나 전환 스냅샷 전달 검증
	# ---------------------------------------------------------
	print("\n--- [검증 2] 오버월드 풀숲 조우 -> BattleArena 씬 전환 및 포켓몬 스탯 스냅샷 전달 검증 ---")
	var err: Error = change_scene_to_file(OVERWORLD_SCENE_PATH)
	_assert_true(err == OK, "Loaded Overworld.tscn successfully")
	await _wait_frames(4)
	
	var overworld: Node2D = current_scene as Node2D
	_assert_true(overworld != null and overworld.name == "Overworld", "Current scene is Overworld")
	
	var player: Player = overworld.get_node_or_null("Player") as Player
	_assert_true(player != null, "Player node exists in Overworld")
	player.movement_duration = 0.03
	
	# Configure custom player lead pokemon stats to verify lossless snapshot transfer
	var lead_mon: PokemonInstance = scene_mgr.get_lead_pokemon()
	lead_mon.nickname = "파트너브케인"
	lead_mon.level = 7
	lead_mon.recalculate_stats(true)
	lead_mon.current_hp = lead_mon.max_hp - 3
	var expected_p_hp: int = lead_mon.current_hp
	var expected_p_max_hp: int = lead_mon.max_hp
	var expected_p_atk: int = lead_mon.attack
	var expected_p_def: int = lead_mon.defense
	var expected_p_spd: int = lead_mon.speed
	
	# Position player right next to TallGrass at (208, 144) (grass patch starts at x=13*16=208, y=9*16=144)
	player.teleport_to(Vector2(192, 144), Vector2.RIGHT)
	await _wait_frames(2)
	
	var grass_container: Node2D = overworld.get_node_or_null("TallGrassContainer") as Node2D
	_assert_true(grass_container != null and grass_container.get_child_count() > 0, "TallGrassContainer has grass nodes")
	var target_grass: TallGrass = grass_container.get_child(0) as TallGrass
	target_grass.trigger_chance = 1.0
	target_grass.encounter_table.encounter_rate = 1.0
	
	# Step RIGHT onto TallGrass at (208, 144) to trigger encounter & battle transition
	var stepped: bool = player.try_to_move(Vector2.RIGHT)
	_assert_true(stepped, "Player stepped RIGHT into TallGrass at (208, 144)")
	
	await scene_mgr.warp_completed
	await _wait_frames(3)
	
	var arena: BattleArena = current_scene as BattleArena
	_assert_true(arena != null and arena.name == "BattleArena", "Transitioned to BattleArena scene on grass encounter")
	
	var p_actor: PokemonActor = arena.player_actor
	var e_actor: PokemonActor = arena.enemy_actor
	_assert_true(p_actor != null and e_actor != null, "PlayerPokemon and EnemyPokemon actors exist in BattleArena")
	_assert_true(p_actor.pokemon_instance != null and e_actor.pokemon_instance != null, "Both actors received PokemonInstance data")
	
	_assert_true(p_actor.pokemon_instance.get_display_name() == "파트너브케인", "PlayerPokemon snapshot preserved nickname ('파트너브케인')")
	_assert_true(p_actor.pokemon_instance.level == 7, "PlayerPokemon snapshot preserved level (7)")
	_assert_true(
		p_actor.pokemon_instance.current_hp == expected_p_hp and p_actor.pokemon_instance.max_hp == expected_p_max_hp,
		"PlayerPokemon snapshot preserved HP (%d/%d)" % [p_actor.pokemon_instance.current_hp, p_actor.pokemon_instance.max_hp]
	)
	_assert_true(
		p_actor.pokemon_instance.attack == expected_p_atk and p_actor.pokemon_instance.defense == expected_p_def and p_actor.pokemon_instance.speed == expected_p_spd,
		"PlayerPokemon snapshot preserved ATK/DEF/SPD (%d/%d/%d)" % [p_actor.pokemon_instance.attack, p_actor.pokemon_instance.defense, p_actor.pokemon_instance.speed]
	)
	_assert_true(
		arena.last_stat_log.contains("파트너브케인") and arena.last_stat_log.contains(e_actor.pokemon_instance.get_display_name()),
		"BattleArena printed complete stat snapshot log: %s" % arena.last_stat_log
	)
	
	# ---------------------------------------------------------
	# [검증 3] 8방향 자유 이동, 방향별 애니메이션 전환 및 320x240 경계 벽 충돌 검증
	# ---------------------------------------------------------
	print("\n--- [검증 3] 8방향(상/하/좌/우/대각선 4방향) 자유 이동 및 320x240 경기장 벽 충돌 검증 ---")
	var dir_cases: Array[Dictionary] = [
		{"vec": Vector2(0, 1),   "key": "s",  "dx": 0,  "dy": 1},
		{"vec": Vector2(1, 1),   "key": "se", "dx": 1,  "dy": 1},
		{"vec": Vector2(1, 0),   "key": "e",  "dx": 1,  "dy": 0},
		{"vec": Vector2(1, -1),  "key": "ne", "dx": 1,  "dy": -1},
		{"vec": Vector2(0, -1),  "key": "n",  "dx": 0,  "dy": -1},
		{"vec": Vector2(-1, -1), "key": "nw", "dx": -1, "dy": -1},
		{"vec": Vector2(-1, 0),  "key": "w",  "dx": -1, "dy": 0},
		{"vec": Vector2(-1, 1),  "key": "sw", "dx": -1, "dy": 1},
	]
	
	for dc in dir_cases:
		p_actor.global_position = Vector2(160, 120)
		var start_pos: Vector2 = p_actor.global_position
		var vec: Vector2 = dc["vec"]
		var expected_key: String = dc["key"]
		
		p_actor.set_move_input(vec)
		await _wait_frames(5)
		
		var moved_pos: Vector2 = p_actor.global_position
		var delta_pos: Vector2 = moved_pos - start_pos
		var anim_while_moving: String = p_actor.get_current_animation_name()
		
		var dir_ok: bool = true
		if int(dc["dx"]) > 0 and delta_pos.x <= 0.5:
			dir_ok = false
		elif int(dc["dx"]) < 0 and delta_pos.x >= -0.5:
			dir_ok = false
		if int(dc["dy"]) > 0 and delta_pos.y <= 0.5:
			dir_ok = false
		elif int(dc["dy"]) < 0 and delta_pos.y >= -0.5:
			dir_ok = false
		
		_assert_true(
			dir_ok and anim_while_moving == "walk_" + expected_key,
			"8-Dir move '%s': delta=%s, anim='%s'" % [expected_key, str(delta_pos.snapped(Vector2(0.1, 0.1))), anim_while_moving]
		)
		
		p_actor.clear_move_input()
		await _wait_frames(2)
		_assert_true(
			p_actor.get_current_animation_name() == "idle_" + expected_key,
			"8-Dir stop '%s' transitions to 'idle_%s'" % [expected_key, expected_key]
		)
	
	# Boundary Wall Collision Check (Left, Right, Top, Bottom walls inside 320x240)
	# 3-A. Left & Top corner push (-1, -1) from near top-left (32, 32)
	p_actor.global_position = Vector2(32, 32)
	p_actor.set_move_input(Vector2(-1, -1))
	await _wait_frames(25)
	p_actor.clear_move_input()
	print("PlayerPokemon pos after pushing into Top-Left wall: ", p_actor.global_position)
	_assert_true(
		p_actor.global_position.x >= 16.0 and p_actor.global_position.y >= 16.0,
		"TopWall & LeftWall keep PokemonActor inside arena bounds (pos=%s >= (16, 16))" % str(p_actor.global_position)
	)
	
	# 3-B. Right & Bottom corner push (1, 1) from near bottom-right (288, 208)
	p_actor.global_position = Vector2(288, 208)
	p_actor.set_move_input(Vector2(1, 1))
	await _wait_frames(25)
	p_actor.clear_move_input()
	print("PlayerPokemon pos after pushing into Bottom-Right wall: ", p_actor.global_position)
	_assert_true(
		p_actor.global_position.x <= 304.0 and p_actor.global_position.y <= 224.0,
		"RightWall & BottomWall keep PokemonActor inside 320x240 arena bounds (pos=%s <= (304, 224))" % str(p_actor.global_position)
	)
	
	# ---------------------------------------------------------
	# [검증 4] 투사체 발사 및 적 포켓몬 피격/HP 감소 검증
	# ---------------------------------------------------------
	print("\n--- [검증 4] 기본 공격(투사체 발사) 및 적 피격 데미지 판정 검증 ---")
	p_actor.global_position = Vector2(120, 120)
	e_actor.global_position = Vector2(180, 120)
	p_actor.set_facing_direction("e")
	await _wait_frames(2)
	
	var enemy_hp_before: int = e_actor.pokemon_instance.current_hp
	var hit_detected: Array[bool] = [false]
	var damage_dealt: Array[int] = [0]
	e_actor.damaged.connect(func(amt: int, _cur: int, _max: int) -> void:
		hit_detected[0] = true
		damage_dealt[0] = amt
	)
	
	var proj: Projectile = p_actor.fire_projectile(Vector2.RIGHT)
	_assert_true(proj != null, "PlayerPokemon fired projectile toward RIGHT ('e')")
	_assert_true(p_actor.get_current_animation_name() == "attack_e", "PlayerPokemon plays 'attack_e' animation on projectile fire")
	
	# Wait up to 30 physics frames for projectile to travel 60px at 210px/s (~0.28s) and hit enemy
	for i in range(30):
		await _wait_frames(1)
		if hit_detected[0]:
			break
	
	var enemy_hp_after: int = e_actor.pokemon_instance.current_hp
	print("Enemy HP before hit: %d -> after hit: %d (damage=%d)" % [enemy_hp_before, enemy_hp_after, damage_dealt[0]])
	_assert_true(hit_detected[0], "Projectile collided with EnemyPokemon and triggered damaged signal")
	_assert_true(enemy_hp_after < enemy_hp_before, "EnemyPokemon HP decreased from %d to %d" % [enemy_hp_before, enemy_hp_after])
	_assert_true(e_actor.get_current_animation_name().begins_with("hurt_"), "EnemyPokemon plays hurt animation ('%s') upon hit" % e_actor.get_current_animation_name())
	
	# Verify return to Overworld preserves battle state
	await scene_mgr.exit_battle_arena({"victory": true, "caught": false})
	await _wait_frames(3)
	_assert_true(current_scene != null and current_scene.name == "Overworld", "Returned cleanly to Overworld after exit_battle_arena()")
	
	# Summary
	if failures.is_empty():
		print("\n=== [ALL PHASE 3 HEADLESS QA TESTS PASSED] ===")
		quit(0)
	else:
		printerr("\n=== [PHASE 3 QA FAILED: %d failure(s)] ===" % failures.size())
		quit(1)
