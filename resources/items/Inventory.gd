class_name Inventory
extends Resource

signal inventory_changed(pocket: int, item_id: String, new_count: int)
signal quick_slot_changed(slot_index: int, item_id: String)

const POCKET_COUNT: int = 4
const QUICK_SLOT_COUNT: int = 4
const DEFAULT_QUICK_SLOTS: Array[String] = ["potion", "pokeball", "great_ball", ""]

var pockets: Dictionary = {
	ItemData.Pocket.ITEMS: [],
	ItemData.Pocket.POKEBALLS: [],
	ItemData.Pocket.TM_HM: [],
	ItemData.Pocket.KEY_ITEMS: []
}

var quick_slots: Array[String] = ["potion", "pokeball", "great_ball", ""]

var _item_registry: Dictionary = {}


func _init() -> void:
	_ensure_pockets()
	_ensure_quick_slots()


func _ensure_pockets() -> void:
	for p in range(POCKET_COUNT):
		if not pockets.has(p) or not (pockets[p] is Array):
			pockets[p] = []


func _ensure_quick_slots() -> void:
	while quick_slots.size() < QUICK_SLOT_COUNT:
		var def_idx: int = quick_slots.size()
		quick_slots.append(DEFAULT_QUICK_SLOTS[def_idx] if def_idx < DEFAULT_QUICK_SLOTS.size() else "")
	if quick_slots.size() > QUICK_SLOT_COUNT:
		quick_slots.resize(QUICK_SLOT_COUNT)


func _resolve_item_data(item_or_id: Variant) -> ItemData:
	if item_or_id is ItemData:
		var item_data: ItemData = item_or_id as ItemData
		if item_data.id != "":
			_item_registry[item_data.id] = item_data
		return item_data
	elif item_or_id is String:
		var item_id: String = _resolve_item_id(item_or_id)
		if _item_registry.has(item_id):
			return _item_registry[item_id]
		var default_item: ItemData = ItemData.get_default_item(item_id)
		if default_item != null:
			_item_registry[item_id] = default_item
			return default_item
	return null


func _resolve_item_id(item_or_id: Variant) -> String:
	if item_or_id is ItemData:
		return (item_or_id as ItemData).id
	elif item_or_id is String:
		var s: String = (item_or_id as String).strip_edges()
		if s == "poke_ball":
			return "pokeball"
		return s
	return ""


func add_item(item_or_id: Variant, count: int = 1) -> bool:
	if count <= 0:
		return false
	_ensure_pockets()
	var item_data: ItemData = _resolve_item_data(item_or_id)
	if item_data == null or item_data.id == "":
		return false
	
	var target_pocket: int = clampi(item_data.pocket, 0, POCKET_COUNT - 1)
	var pocket_list: Array = pockets[target_pocket]
	
	for entry in pocket_list:
		if entry is Dictionary and entry.get("id", "") == item_data.id:
			var new_count: int = int(entry.get("count", 0)) + count
			entry["count"] = new_count
			entry["item"] = item_data
			inventory_changed.emit(target_pocket, item_data.id, new_count)
			return true
	
	var stack_entry: Dictionary = {
		"id": item_data.id,
		"display_name": item_data.display_name,
		"pocket": target_pocket,
		"count": count,
		"item": item_data
	}
	pocket_list.append(stack_entry)
	inventory_changed.emit(target_pocket, item_data.id, count)
	return true


func remove_item(item_or_id: Variant, count: int = 1) -> bool:
	if count <= 0:
		return false
	_ensure_pockets()
	var item_id: String = _resolve_item_id(item_or_id)
	if item_id == "":
		return false
	
	for p in range(POCKET_COUNT):
		var pocket_list: Array = pockets[p]
		for i in range(pocket_list.size()):
			var entry: Dictionary = pocket_list[i]
			if entry.get("id", "") == item_id:
				var current_count: int = int(entry.get("count", 0))
				if current_count < count:
					return false
				var remaining: int = current_count - count
				if remaining <= 0:
					pocket_list.remove_at(i)
					inventory_changed.emit(p, item_id, 0)
				else:
					entry["count"] = remaining
					inventory_changed.emit(p, item_id, remaining)
				return true
	return false


func get_item_count(item_or_id: Variant) -> int:
	_ensure_pockets()
	var item_id: String = _resolve_item_id(item_or_id)
	if item_id == "":
		return 0
	for p in range(POCKET_COUNT):
		var pocket_list: Array = pockets[p]
		for entry in pocket_list:
			if entry is Dictionary and entry.get("id", "") == item_id:
				return int(entry.get("count", 0))
	return 0


func has_item(item_or_id: Variant, min_count: int = 1) -> bool:
	return get_item_count(item_or_id) >= min_count


func get_item_pocket(item_or_id: Variant) -> int:
	_ensure_pockets()
	var item_id: String = _resolve_item_id(item_or_id)
	for p in range(POCKET_COUNT):
		var pocket_list: Array = pockets[p]
		for entry in pocket_list:
			if entry is Dictionary and entry.get("id", "") == item_id:
				return p
	var item_data: ItemData = _resolve_item_data(item_or_id)
	if item_data:
		return item_data.pocket
	return -1


func get_pocket_items(pocket: int) -> Array:
	_ensure_pockets()
	var p: int = clampi(pocket, 0, POCKET_COUNT - 1)
	return pockets[p]


func get_item_data(item_id: String) -> ItemData:
	return _resolve_item_data(item_id)


func set_quick_slot(slot_index: int, item_or_id: Variant) -> bool:
	if slot_index < 0 or slot_index >= QUICK_SLOT_COUNT:
		return false
	_ensure_quick_slots()
	var item_id: String = _resolve_item_id(item_or_id)
	if item_id.is_empty():
		quick_slots[slot_index] = ""
		quick_slot_changed.emit(slot_index, "")
		return true
	
	var item_data: ItemData = _resolve_item_data(item_or_id)
	if item_data == null:
		return false
	# Only healing items or Pokeball items can be assigned to quick slots 1..4
	var is_heal: bool = item_data.heal_amount > 0
	var is_ball: bool = (item_data.pocket == ItemData.Pocket.POKEBALLS)
	if not is_heal and not is_ball:
		return false
	
	for i in range(QUICK_SLOT_COUNT):
		if i != slot_index and quick_slots[i] == item_id:
			quick_slots[i] = ""
	quick_slots[slot_index] = item_id
	quick_slot_changed.emit(slot_index, item_id)
	return true


func get_quick_slot_item_id(slot_index: int) -> String:
	_ensure_quick_slots()
	if slot_index < 0 or slot_index >= QUICK_SLOT_COUNT:
		return ""
	return quick_slots[slot_index]


func get_quick_slot_item_data(slot_index: int) -> ItemData:
	var item_id: String = get_quick_slot_item_id(slot_index)
	if item_id.is_empty():
		return null
	return _resolve_item_data(item_id)


func get_quick_slot_count(slot_index: int) -> int:
	var item_id: String = get_quick_slot_item_id(slot_index)
	if item_id.is_empty():
		return 0
	return get_item_count(item_id)


func find_quick_slot_for_item(item_or_id: Variant) -> int:
	_ensure_quick_slots()
	var item_id: String = _resolve_item_id(item_or_id)
	if item_id.is_empty():
		return -1
	return quick_slots.find(item_id)


func clear() -> void:
	for p in range(POCKET_COUNT):
		pockets[p] = []
	quick_slots = DEFAULT_QUICK_SLOTS.duplicate()


func populate_starter_items() -> void:
	clear()
	add_item(ItemData.get_default_item("potion"), 3)
	add_item(ItemData.get_default_item("pokeball"), 5)
	add_item(ItemData.get_default_item("great_ball"), 2)
	add_item(ItemData.get_default_item("tm01"), 1)
	add_item(ItemData.get_default_item("bicycle"), 1)
	quick_slots = DEFAULT_QUICK_SLOTS.duplicate()


func to_dict() -> Dictionary:
	_ensure_pockets()
	_ensure_quick_slots()
	var serialized_pockets: Dictionary = {}
	for p in range(POCKET_COUNT):
		var arr: Array = []
		for entry in pockets[p]:
			if entry is Dictionary:
				arr.append({
					"id": entry.get("id", ""),
					"display_name": entry.get("display_name", ""),
					"pocket": p,
					"count": int(entry.get("count", 0))
				})
		serialized_pockets[str(p)] = arr
	return {
		"pockets": serialized_pockets,
		"quick_slots": quick_slots.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	clear()
	var serialized_pockets: Dictionary = data.get("pockets", {})
	for key in serialized_pockets.keys():
		var arr: Variant = serialized_pockets[key]
		if arr is Array:
			for entry in arr:
				if entry is Dictionary:
					var item_id: String = str(entry.get("id", ""))
					var count: int = int(entry.get("count", 0))
					var item_data: ItemData = _resolve_item_data(item_id)
					if item_data == null and item_id != "":
						item_data = ItemData.create(
							item_id,
							str(entry.get("display_name", item_id)),
							int(entry.get("pocket", int(key)))
						)
					if item_data != null and count > 0:
						add_item(item_data, count)
	if data.get("quick_slots") is Array:
		var saved_slots: Array = data.get("quick_slots") as Array
		quick_slots.clear()
		for i in range(QUICK_SLOT_COUNT):
			if i < saved_slots.size():
				quick_slots.append(_resolve_item_id(str(saved_slots[i])))
			else:
				quick_slots.append("")
