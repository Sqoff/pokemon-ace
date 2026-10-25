extends SceneTree

const OVERWORLD_SCENE_PATH: String = "res://scenes/overworld/Overworld.tscn"
const POKECENTER_SCENE_PATH: String = "res://scenes/overworld/PokeCenter.tscn"

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


func _assert_eq_vec2(actual: Vector2, expected: Vector2, message: String) -> void:
	var ok: bool = actual.distance_to(expected) < 0.01
	_assert_true(ok, "%s (expected=%s, actual=%s)" % [message, str(expected), str(actual)])


func _wait_frames(count: int = 2) -> void:
	for i in range(count):
		await process_frame
		await physics_frame


func _run_all_tests() -> void:
	print("=== [Phase 1 Headless QA Verification Start] ===")
	
	# Speed up animations slightly for fast headless testing while keeping real Tween frames
	var scene_mgr: Node = root.get_node_or_null("SceneManager")
	_assert_true(scene_mgr != null, "SceneManager Autoload singleton is registered")
	if scene_mgr:
		scene_mgr.fade_duration = 0.05
	
	# Load main scene Overworld.tscn
	var err: Error = change_scene_to_file(OVERWORLD_SCENE_PATH)
	_assert_true(err == OK, "Loaded Overworld.tscn successfully")
	await _wait_frames(4)
	
	var overworld: Node2D = current_scene as Node2D
	_assert_true(overworld != null and overworld.name == "Overworld", "Current scene is Overworld")
	
	var player: Player = overworld.get_node_or_null("Player") as Player
	_assert_true(player != null, "Player node exists in Overworld")
	player.movement_duration = 0.04
	player.jump_duration = 0.06
	
	# ---------------------------------------------------------
	# [검증 1] 그리드 이동 및 벽 충돌 차단 검증
	# ---------------------------------------------------------
	print("\n--- [검증 1] 16x16 그리드 이동 및 전방 벽/장애물 충돌 차단 ---")
	player.teleport_to(Vector2(64, 80), Vector2.DOWN)
	await _wait_frames(2)
	_assert_eq_vec2(player.position, Vector2(64, 80), "Initial player grid position is (64, 80)")
	
	# 1-A. Move RIGHT 1 step -> +16px (80, 80)
	var moved_right: bool = player.try_to_move(Vector2.RIGHT)
	_assert_true(moved_right, "Step RIGHT initiated from (64, 80)")
	await player.step_completed
	await _wait_frames(1)
	print("Player pos after RIGHT step: ", player.position)
	_assert_eq_vec2(player.position, Vector2(80, 80), "Step RIGHT moved exactly 16px to (80, 80)")
	
	# 1-B. Move DOWN 1 step -> +16px (80, 96)
	var moved_down: bool = player.try_to_move(Vector2.DOWN)
	_assert_true(moved_down, "Step DOWN initiated from (80, 80)")
	await player.step_completed
	await _wait_frames(1)
	print("Player pos after DOWN step: ", player.position)
	_assert_eq_vec2(player.position, Vector2(80, 96), "Step DOWN moved exactly 16px to (80, 96)")
	
	# 1-C. Move LEFT 1 step -> -16px (64, 96), then UP 1 step -> -16px (64, 80)
	var moved_left: bool = player.try_to_move(Vector2.LEFT)
	_assert_true(moved_left, "Step LEFT initiated from (80, 96)")
	await player.step_completed
	var moved_up: bool = player.try_to_move(Vector2.UP)
	_assert_true(moved_up, "Step UP initiated from (64, 96)")
	await player.step_completed
	await _wait_frames(1)
	_assert_eq_vec2(player.position, Vector2(64, 80), "Returned to (64, 80) on exact 16px grid")
	
	# 1-D. Wall / Obstacle collision at (48, 80) (LEFT of (64, 80))
	var blocked_left: bool = player.try_to_move(Vector2.LEFT)
	await _wait_frames(2)
	print("Player pos after blocked LEFT input toward obstacle (48, 80): ", player.position)
	_assert_true(not blocked_left, "Movement toward obstacle at (48, 80) is blocked by RayCast2D/TileMap")
	_assert_eq_vec2(player.position, Vector2(64, 80), "Player position unchanged at (64, 80) and not stuck in wall")
	
	# Verify player is not stuck and can immediately move DOWN after wall block
	var move_after_wall: bool = player.try_to_move(Vector2.DOWN)
	_assert_true(move_after_wall, "Player is not stuck and can move DOWN freely after hitting wall")
	await player.step_completed
	_assert_eq_vec2(player.position, Vector2(64, 96), "Player moved cleanly to (64, 96)")
	
	# Double-tap directional key sprint check in Overworld
	var normal_dur: float = player.get_effective_movement_duration()
	var ow_tap1: bool = player.register_direction_tap("down")
	var ow_tap2: bool = player.register_direction_tap("down")
	var sprint_dur: float = player.get_effective_movement_duration()
	_assert_true(not ow_tap1 and ow_tap2 and player.is_sprinting, "Double-tapping direction key activates sprint in Overworld")
	_assert_true(sprint_dur < normal_dur, "Overworld sprint step duration (%.3fs) is faster than normal step duration (%.3fs)" % [sprint_dur, normal_dur])
	player.set_sprinting(false)
	
	# ---------------------------------------------------------
	# [검증 2] 언덕(Ledge) 단방향 점프 및 역방향 차단 검증
	# ---------------------------------------------------------
	print("\n--- [검증 2] 언덕(Ledge) 2타일(32px) 점프 및 역방향 통과 불가 ---")
	# Ledge row is at y=128 (tile y=8), x=112..160. Place player above ledge at (128, 112) (tile 8, 7)
	player.teleport_to(Vector2(128, 112), Vector2.DOWN)
	await _wait_frames(2)
	_assert_eq_vec2(player.position, Vector2(128, 112), "Player positioned above ledge at (128, 112)")
	
	# 2-A. Press DOWN above ledge -> jumps 2 tiles (32px) over y=128 to (128, 144)
	var jump_started: bool = player.try_to_move(Vector2.DOWN)
	_assert_true(jump_started and player.is_jumping, "Ledge jump DOWN triggered from (128, 112)")
	await player.ledge_jump_completed
	await _wait_frames(1)
	print("Player pos after Ledge jump DOWN: ", player.position)
	_assert_eq_vec2(player.position, Vector2(128, 144), "Ledge jump moved player 2 tiles (32px) to (128, 144)")
	
	# 2-B. Press UP from below ledge (128, 144) toward ledge (128, 128) -> MUST BE BLOCKED
	var climb_ledge: bool = player.try_to_move(Vector2.UP)
	await _wait_frames(2)
	print("Player pos after trying to climb UP ledge from (128, 144): ", player.position)
	_assert_true(not climb_ledge, "Ledge blocks upward movement from below (128, 144)")
	_assert_eq_vec2(player.position, Vector2(128, 144), "Player remains at (128, 144) below ledge")
	
	# ---------------------------------------------------------
	# [검증 3] 건물 진입 및 워프(Fade In/Out) 씬 전환 검증
	# ---------------------------------------------------------
	print("\n--- [검증 3] 건물 진입 및 워프(Fade In/Out) 동작 검증 ---")
	# PokeCenterDoor is at (192, 64). Place player 1 tile below at (192, 80) and step UP into door
	player.teleport_to(Vector2(192, 80), Vector2.UP)
	await _wait_frames(2)
	
	var fade_out_seen: Array[bool] = [false]
	var on_fade_out := func() -> void:
		if scene_mgr.fade_rect.color.a >= 0.99:
			fade_out_seen[0] = true
	scene_mgr.fade_out_completed.connect(on_fade_out)
	
	var step_into_door: bool = player.try_to_move(Vector2.UP)
	_assert_true(step_into_door, "Player stepped UP toward PokeCenterDoor at (192, 64)")
	
	await scene_mgr.warp_completed
	await _wait_frames(2)
	
	_assert_true(fade_out_seen[0], "Fade Out reached alpha 1.0 during scene transition")
	_assert_true(scene_mgr.fade_rect.color.a <= 0.01, "Fade In restored alpha 0.0 after scene transition")
	_assert_true(current_scene != null and current_scene.name == "PokeCenter", "Warped into PokeCenter interior scene")
	
	var indoor_player: Player = current_scene.get_node_or_null("Player") as Player
	_assert_true(indoor_player != null, "Player exists in PokeCenter scene")
	if indoor_player:
		indoor_player.movement_duration = 0.04
		print("Indoor Player spawn pos: ", indoor_player.position)
		_assert_eq_vec2(indoor_player.position, Vector2(80, 112), "Indoor Player spawned at target coordinate (80, 112)")
		
		# Step DOWN onto ExitDoor at (80, 128) to warp back to Overworld
		var step_exit: bool = indoor_player.try_to_move(Vector2.DOWN)
		_assert_true(step_exit, "Indoor Player stepped DOWN onto ExitDoor at (80, 128)")
		await scene_mgr.warp_completed
		await _wait_frames(2)
		
		_assert_true(current_scene != null and current_scene.name == "Overworld", "Warped back to Overworld scene")
		var returned_player: Player = current_scene.get_node_or_null("Player") as Player
		_assert_true(returned_player != null, "Player exists after returning to Overworld")
		if returned_player:
			print("Returned Overworld Player pos: ", returned_player.position)
			_assert_eq_vec2(returned_player.position, Vector2(192, 80), "Returned Player spawned in front of door at (192, 80)")
	
	# Summary
	if failures.is_empty():
		print("\n=== [ALL PHASE 1 HEADLESS QA TESTS PASSED] ===")
		quit(0)
	else:
		printerr("\n=== [PHASE 1 QA FAILED: %d failure(s)] ===" % failures.size())
		quit(1)
