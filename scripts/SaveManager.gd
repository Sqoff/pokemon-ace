extends Node

signal game_saved(file_path: String, save_data: Dictionary)
signal game_loaded(file_path: String, save_data: Dictionary)

const DEFAULT_SAVE_PATH: String = "user://savegame.json"

var last_saved_data: Dictionary = {}
var last_loaded_data: Dictionary = {}


func _get_scene_manager() -> Node:
	return get_node_or_null("/root/SceneManager")


func _get_time_manager() -> Node:
	return get_node_or_null("/root/TimeManager")


func build_save_data() -> Dictionary:
	var sm: Node = _get_scene_manager()
	var tm: Node = _get_time_manager()
	
	var current_scene: Node = get_tree().current_scene
	var scene_path: String = "res://scenes/overworld/Overworld.tscn"
	var player_pos: Vector2 = Vector2(64, 80)
	var facing_dir: Vector2 = Vector2.DOWN
	var party_list: Array = []
	var inv_obj: Inventory = null
	
	if sm != null:
		if sm.get("return_scene_path") is String and not str(sm.get("return_scene_path")).is_empty():
			scene_path = str(sm.get("return_scene_path"))
		if sm.get("return_player_position") is Vector2:
			player_pos = sm.get("return_player_position")
		if sm.get("return_facing_direction") is Vector2:
			facing_dir = sm.get("return_facing_direction")
		if sm.get("party") is Array:
			party_list = sm.get("party")
		if sm.get("player_inventory") is Inventory:
			inv_obj = sm.get("player_inventory")
	
	if current_scene != null:
		if current_scene.scene_file_path != "" and current_scene.scene_file_path != "res://scenes/battle/BattleArena.tscn":
			scene_path = current_scene.scene_file_path
		var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
		if player != null:
			player_pos = player.position
			if player.get("facing_direction") is Vector2:
				facing_dir = player.get("facing_direction")
			if player.get("party") is Array and not (player.get("party") as Array).is_empty():
				party_list = player.get("party")
			if player.get("inventory") is Inventory:
				inv_obj = player.get("inventory")
	
	var serialized_party: Array[Dictionary] = []
	for member in party_list:
		if member is PokemonInstance:
			var mon: PokemonInstance = member as PokemonInstance
			mon.ensure_move_instances()
			mon.sync_moves_array()
			serialized_party.append(mon.to_dict())
	
	var serialized_inventory: Dictionary = {}
	if inv_obj != null:
		serialized_inventory = inv_obj.to_dict()
	
	var hour_val: int = 12
	var minute_val: int = 0
	var period_val: int = 1
	var period_name_val: String = "DAY"
	if tm != null:
		hour_val = int(tm.get("current_hour"))
		minute_val = int(tm.get("current_minute"))
		period_val = int(tm.get("current_period"))
		if tm.has_method("get_current_period_name"):
			period_name_val = str(tm.get_current_period_name())
	
	return {
		"version": 1,
		"scene_path": scene_path,
		"player_position": {"x": player_pos.x, "y": player_pos.y},
		"facing_direction": {"x": facing_dir.x, "y": facing_dir.y},
		"party": serialized_party,
		"inventory": serialized_inventory,
		"time": {
			"current_hour": hour_val,
			"current_minute": minute_val,
			"current_period": period_val,
			"period_name": period_name_val,
		}
	}


func save_game(file_path: String = DEFAULT_SAVE_PATH) -> bool:
	var target_path: String = file_path if not file_path.is_empty() else DEFAULT_SAVE_PATH
	var data: Dictionary = build_save_data()
	var json_str: String = JSON.stringify(data, "\t")
	
	var file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Failed to open '%s' for writing" % target_path)
		return false
	file.store_string(json_str)
	file.close()
	
	last_saved_data = data.duplicate(true)
	game_saved.emit(target_path, data)
	return true


func has_save_file(file_path: String = DEFAULT_SAVE_PATH) -> bool:
	var target_path: String = file_path if not file_path.is_empty() else DEFAULT_SAVE_PATH
	return FileAccess.file_exists(target_path)


func load_game(file_path: String = DEFAULT_SAVE_PATH) -> bool:
	var target_path: String = file_path if not file_path.is_empty() else DEFAULT_SAVE_PATH
	if not FileAccess.file_exists(target_path):
		push_error("SaveManager: Save file does not exist at '%s'" % target_path)
		return false
	
	var file: FileAccess = FileAccess.open(target_path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Failed to open '%s' for reading" % target_path)
		return false
	var raw_text: String = file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(raw_text)
	if not (parsed is Dictionary):
		push_error("SaveManager: Invalid JSON in '%s'" % target_path)
		return false
	
	var data: Dictionary = parsed as Dictionary
	last_loaded_data = data.duplicate(true)
	
	var sm: Node = _get_scene_manager()
	var tm: Node = _get_time_manager()
	
	# 1. Restore Time
	if data.get("time") is Dictionary and tm != null:
		var t_dict: Dictionary = data["time"] as Dictionary
		if t_dict.has("current_hour") and tm.has_method("set_forced_hour"):
			tm.set_forced_hour(int(t_dict.get("current_hour", 12)), true)
		elif t_dict.has("current_period") and tm.has_method("set_time_period"):
			tm.set_time_period(int(t_dict.get("current_period", 1)), true)
	
	# 2. Restore Party
	var restored_party: Array[PokemonInstance] = []
	if data.get("party") is Array:
		for entry in data["party"] as Array:
			if entry is Dictionary:
				restored_party.append(PokemonInstance.from_dict(entry as Dictionary))
	if restored_party.is_empty():
		restored_party.append(PokemonRegistry.create_instance("cyndaquil", 5, "브케인"))
	
	# 3. Restore Inventory
	var restored_inv: Inventory = null
	if sm != null and sm.get("player_inventory") is Inventory:
		restored_inv = sm.get("player_inventory") as Inventory
	else:
		restored_inv = Inventory.new()
	if data.get("inventory") is Dictionary:
		restored_inv.from_dict(data["inventory"] as Dictionary)
	
	# 4. Restore Scene & Player Position/Facing
	var saved_scene_path: String = str(data.get("scene_path", "res://scenes/overworld/Overworld.tscn"))
	var pos_dict: Dictionary = data.get("player_position", {"x": 64.0, "y": 80.0}) if data.get("player_position") is Dictionary else {"x": 64.0, "y": 80.0}
	var face_dict: Dictionary = data.get("facing_direction", {"x": 0.0, "y": 1.0}) if data.get("facing_direction") is Dictionary else {"x": 0.0, "y": 1.0}
	var saved_pos := Vector2(float(pos_dict.get("x", 64.0)), float(pos_dict.get("y", 80.0)))
	var saved_facing := Vector2(float(face_dict.get("x", 0.0)), float(face_dict.get("y", 1.0)))
	if saved_facing.length_squared() < 0.0001:
		saved_facing = Vector2.DOWN
	
	if sm != null:
		sm.set("party", restored_party)
		sm.set("player_inventory", restored_inv)
		sm.set("return_scene_path", saved_scene_path)
		sm.set("return_player_position", saved_pos)
		sm.set("return_facing_direction", saved_facing)
	
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
		if player != null:
			if player.has_method("teleport_to"):
				player.teleport_to(saved_pos, saved_facing)
			else:
				player.position = saved_pos
				player.set("facing_direction", saved_facing)
			player.set("party", restored_party)
			player.set("inventory", restored_inv)
	
	game_loaded.emit(target_path, data)
	return true
