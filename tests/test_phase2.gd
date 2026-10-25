extends SceneTree

const OVERWORLD_SCENE_PATH: String = "res://scenes/overworld/Overworld.tscn"

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


func _assert_eq_color(actual: Color, expected: Color, message: String) -> void:
	var diff: float = absf(actual.r - expected.r) + absf(actual.g - expected.g) + absf(actual.b - expected.b) + absf(actual.a - expected.a)
	_assert_true(diff < 0.02, "%s (expected=%s, actual=%s)" % [message, str(expected), str(actual)])


func _wait_frames(count: int = 2) -> void:
	for i in range(count):
		await process_frame
		await physics_frame


func _run_all_tests() -> void:
	print("=== [Phase 2 Headless QA Verification Start] ===")
	
	var time_mgr: Node = root.get_node_or_null("TimeManager")
	var dialogue_mgr: Node = root.get_node_or_null("DialogueManager")
	_assert_true(time_mgr != null, "TimeManager Autoload singleton is registered")
	_assert_true(dialogue_mgr != null, "DialogueManager Autoload singleton is registered")
	
	var err: Error = change_scene_to_file(OVERWORLD_SCENE_PATH)
	_assert_true(err == OK, "Loaded Overworld.tscn successfully")
	await _wait_frames(4)
	
	var overworld: Node2D = current_scene as Node2D
	_assert_true(overworld != null and overworld.name == "Overworld", "Current scene is Overworld")
	
	var modulate_node: CanvasModulate = overworld.get_node_or_null("DayNightModulate") as CanvasModulate
	_assert_true(modulate_node != null, "DayNightModulate (CanvasModulate) exists in Overworld")
	
	# ---------------------------------------------------------
	# [검증 1] 낮/밤 색조 (TimeManager + CanvasModulate)
	# ---------------------------------------------------------
	print("\n--- [검증 1] 낮/밤 3단계 시간대(새벽 06시 / 낮 12시 / 밤 22시) 색조 전환 검증 ---")
	
	# 1-A. Morning (06:00) -> Period.MORNING (0)
	time_mgr.set_forced_hour(6)
	await _wait_frames(1)
	_assert_true(time_mgr.current_period == 0, "Hour 06:00 sets TimeManager period to MORNING (0)")
	_assert_true(time_mgr.get_current_period_name() == "MORNING", "Period name is MORNING")
	_assert_eq_color(modulate_node.color, time_mgr.TINT_MORNING, "Overworld CanvasModulate matches MORNING tint at 06:00")
	
	# 1-B. Day (12:00) -> Period.DAY (1)
	time_mgr.set_forced_hour(12)
	await _wait_frames(1)
	_assert_true(time_mgr.current_period == 1, "Hour 12:00 sets TimeManager period to DAY (1)")
	_assert_true(time_mgr.get_current_period_name() == "DAY", "Period name is DAY")
	_assert_eq_color(modulate_node.color, time_mgr.TINT_DAY, "Overworld CanvasModulate matches DAY tint at 12:00")
	
	# 1-C. Night (22:00) -> Period.NIGHT (2)
	time_mgr.set_forced_hour(22)
	await _wait_frames(1)
	_assert_true(time_mgr.current_period == 2, "Hour 22:00 sets TimeManager period to NIGHT (2)")
	_assert_true(time_mgr.get_current_period_name() == "NIGHT", "Period name is NIGHT")
	_assert_eq_color(modulate_node.color, time_mgr.TINT_NIGHT, "Overworld CanvasModulate matches NIGHT tint at 22:00")
	
	# ---------------------------------------------------------
	# [검증 2] 시간대별 인카운터 (EncounterTable + TallGrass)
	# ---------------------------------------------------------
	print("\n--- [검증 2] 새벽/낮/밤 시간대별 야생 포켓몬 인카운터 테이블 분기 검증 ---")
	var grass_container: Node2D = overworld.get_node_or_null("TallGrassContainer") as Node2D
	_assert_true(grass_container != null and grass_container.get_child_count() > 0, "TallGrassContainer has grass nodes")
	var sample_grass: TallGrass = grass_container.get_child(0) as TallGrass
	_assert_true(sample_grass != null and sample_grass.encounter_table != null, "TallGrass has EncounterTable assigned")
	
	var table: EncounterTable = sample_grass.encounter_table
	var morning_pool: Array[String] = table.get_species_ids_for_period(0)
	var day_pool: Array[String] = table.get_species_ids_for_period(1)
	var night_pool: Array[String] = table.get_species_ids_for_period(2)
	
	_assert_true(morning_pool.has("pidgey") and morning_pool.has("cyndaquil") and not morning_pool.has("hoothoot"), "Morning pool has pidgey/cyndaquil and excludes night-only hoothoot")
	_assert_true(day_pool.has("pidgey") and day_pool.has("chikorita") and not day_pool.has("hoothoot"), "Day pool has pidgey/chikorita and excludes night-only hoothoot")
	_assert_true(night_pool.has("hoothoot") and night_pool.has("totodile") and not night_pool.has("pidgey"), "Night pool has hoothoot/totodile and excludes day-only pidgey")
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261025
	
	# Roll encounters in NIGHT (22:00) via TallGrass + TimeManager
	time_mgr.set_forced_hour(22)
	var saw_hoothoot_at_night: bool = false
	var night_rolls_valid: bool = true
	for i in range(30):
		var enc: Dictionary = sample_grass.force_encounter(-1, rng)
		var sp: String = str(enc.get("species_id", ""))
		if not night_pool.has(sp):
			night_rolls_valid = false
		if sp == "hoothoot":
			saw_hoothoot_at_night = true
	_assert_true(night_rolls_valid, "All Night encounter rolls from TallGrass belong strictly to Night encounter table")
	_assert_true(saw_hoothoot_at_night, "Night encounter rolls produced night-signature pokemon 'hoothoot' (부우부)")
	
	# Roll encounters in MORNING (06:00)
	time_mgr.set_forced_hour(6)
	var morning_rolls_valid: bool = true
	for i in range(20):
		var enc_m: Dictionary = sample_grass.force_encounter(-1, rng)
		var sp_m: String = str(enc_m.get("species_id", ""))
		if not morning_pool.has(sp_m):
			morning_rolls_valid = false
	_assert_true(morning_rolls_valid, "All Morning encounter rolls from TallGrass belong strictly to Morning encounter table")
	
	# ---------------------------------------------------------
	# [검증 3] 4포켓 가방 (Inventory & BagUI)
	# ---------------------------------------------------------
	print("\n--- [검증 3] 4포켓 가방(일반 도구 / 몬스터볼 / 기술머신 / 중요한 물건) 검증 ---")
	var inv := Inventory.new()
	inv.clear()
	
	var potion: ItemData = load("res://resources/items/potion.tres") as ItemData
	var pokeball: ItemData = load("res://resources/items/pokeball.tres") as ItemData
	var great_ball: ItemData = load("res://resources/items/great_ball.tres") as ItemData
	var tm01: ItemData = load("res://resources/items/tm01.tres") as ItemData
	var bicycle: ItemData = load("res://resources/items/bicycle.tres") as ItemData
	
	_assert_true(potion != null and potion.pocket == ItemData.Pocket.ITEMS, "Loaded potion.tres in ITEMS pocket (0)")
	_assert_true(pokeball != null and pokeball.pocket == ItemData.Pocket.POKEBALLS, "Loaded pokeball.tres in POKEBALLS pocket (1)")
	_assert_true(tm01 != null and tm01.pocket == ItemData.Pocket.TM_HM, "Loaded tm01.tres in TM_HM pocket (2)")
	_assert_true(bicycle != null and bicycle.pocket == ItemData.Pocket.KEY_ITEMS, "Loaded bicycle.tres in KEY_ITEMS pocket (3)")
	
	inv.add_item(potion, 3)
	inv.add_item(pokeball, 5)
	inv.add_item(great_ball, 2)
	inv.add_item(tm01, 1)
	inv.add_item(bicycle, 1)
	
	_assert_true(inv.get_item_count("potion") == 3, "Pocket 0 (ITEMS) has 3 Potions")
	_assert_true(inv.get_item_count("pokeball") == 5 and inv.get_item_count("great_ball") == 2, "Pocket 1 (POKEBALLS) has 5 Pokeballs and 2 Great Balls")
	_assert_true(inv.get_item_count("tm01") == 1, "Pocket 2 (TM_HM) has 1 TM01")
	_assert_true(inv.get_item_count("bicycle") == 1, "Pocket 3 (KEY_ITEMS) has 1 Bicycle")
	
	_assert_true(inv.get_pocket_items(ItemData.Pocket.ITEMS).size() == 1, "Pocket 0 has 1 distinct item stack")
	_assert_true(inv.get_pocket_items(ItemData.Pocket.POKEBALLS).size() == 2, "Pocket 1 has 2 distinct item stacks")
	_assert_true(inv.get_pocket_items(ItemData.Pocket.TM_HM).size() == 1, "Pocket 2 has 1 distinct item stack")
	_assert_true(inv.get_pocket_items(ItemData.Pocket.KEY_ITEMS).size() == 1, "Pocket 3 has 1 distinct item stack")
	
	# Deduct item and verify removal when count reaches 0
	var removed_ok: bool = inv.remove_item("potion", 2)
	_assert_true(removed_ok and inv.get_item_count("potion") == 1, "Removed 2 Potions -> 1 remaining")
	var removed_over: bool = inv.remove_item("potion", 5)
	_assert_true(not removed_over and inv.get_item_count("potion") == 1, "Cannot remove more items than currently held")
	var removed_last: bool = inv.remove_item("potion", 1)
	_assert_true(removed_last and inv.get_item_count("potion") == 0 and inv.get_pocket_items(ItemData.Pocket.ITEMS).is_empty(), "Removing last Potion clears stack from Pocket 0")
	
	# Verify BagUI pocket switching
	var bag_ui: BagUI = overworld.get_node_or_null("BagUI") as BagUI
	_assert_true(bag_ui != null, "BagUI exists in Overworld")
	bag_ui.open_bag(inv, 1)
	_assert_true(bag_ui.is_open and bag_ui.current_pocket == 1, "BagUI opened at Pocket 1 (POKEBALLS)")
	bag_ui.switch_pocket(3)
	_assert_true(bag_ui.current_pocket == 3, "BagUI switched to Pocket 3 (KEY_ITEMS)")
	bag_ui.close_bag()
	_assert_true(not bag_ui.is_open, "BagUI closed cleanly")
	
	# ---------------------------------------------------------
	# [검증 4] 대화창(Dialogue) 및 표지판/NPC 상호작용 검증
	# ---------------------------------------------------------
	print("\n--- [검증 4] 표지판(Signpost) 및 NPC 상호작용과 대화창(DialogueManager) 검증 ---")
	var player: Player = overworld.get_node_or_null("Player") as Player
	var signpost: Signpost = overworld.get_node_or_null("Signpost") as Signpost
	var npc: NPC = overworld.get_node_or_null("NPC") as NPC
	_assert_true(player != null and signpost != null and npc != null, "Player, Signpost, and NPC exist in Overworld")
	
	# Place player 1 tile below Signpost (Signpost is at (96, 64), so player at (96, 80) facing UP)
	player.teleport_to(Vector2(96, 80), Vector2.UP)
	await _wait_frames(2)
	
	var target_obj: Node = player.get_facing_interactable()
	_assert_true(target_obj == signpost, "Player facing UP at (96, 80) detects Signpost at (96, 64)")
	
	var interacted: bool = player.interact()
	await _wait_frames(1)
	_assert_true(interacted, "Player.interact() triggered Signpost interaction")
	_assert_true(dialogue_mgr.is_active, "DialogueManager is active after interacting with Signpost")
	_assert_true(not player.input_enabled, "Player movement input is locked while DialogueBox is open")
	_assert_true(dialogue_mgr.get_current_text() == signpost.dialogue_lines[0], "DialogueBox displays line 1: '%s'" % dialogue_mgr.get_current_text())
	
	# Advance to line 2
	dialogue_mgr.advance_dialogue()
	await _wait_frames(1)
	_assert_true(dialogue_mgr.is_active, "DialogueManager remains active for line 2")
	_assert_true(dialogue_mgr.get_current_text() == signpost.dialogue_lines[1], "DialogueBox displays line 2: '%s'" % dialogue_mgr.get_current_text())
	
	# Advance past last line -> closes dialogue and unlocks player
	dialogue_mgr.advance_dialogue()
	await _wait_frames(1)
	_assert_true(not dialogue_mgr.is_active, "DialogueManager closed after last line")
	_assert_true(player.input_enabled, "Player movement input is unlocked after dialogue closes")
	
	# Also verify NPC interaction at (144, 80) from (144, 96) facing UP
	player.teleport_to(Vector2(144, 96), Vector2.UP)
	await _wait_frames(2)
	var npc_interacted: bool = player.interact()
	await _wait_frames(1)
	_assert_true(npc_interacted and dialogue_mgr.is_active, "Interacting with NPC opens DialogueManager")
	_assert_true(dialogue_mgr.current_speaker == npc.npc_name, "Dialogue speaker matches NPC name ('%s')" % npc.npc_name)
	dialogue_mgr.close_dialogue()
	await _wait_frames(1)
	_assert_true(not dialogue_mgr.is_active and player.input_enabled, "NPC dialogue closed and Player unlocked")
	
	# Summary
	if failures.is_empty():
		print("\n=== [ALL PHASE 2 HEADLESS QA TESTS PASSED] ===")
		quit(0)
	else:
		printerr("\n=== [PHASE 2 QA FAILED: %d failure(s)] ===" % failures.size())
		quit(1)
