class_name Inventory
extends Resource

signal inventory_changed(pocket: int, item_id: String, new_count: int)

const POCKET_COUNT: int = 4

var pockets: Dictionary = {
	ItemData.Pocket.ITEMS: [],
	ItemData.Pocket.POKEBALLS: [],
	ItemData.Pocket.TM_HM: [],
	ItemData.Pocket.KEY_ITEMS: []
}

var _item_registry: Dictionary = {}


func _init() -> void:
	_ensure_pockets()


func _ensure_pockets() -> void:
	for p in range(POCKET_COUNT):
		if not pockets.has(p) or not (pockets[p] is Array):
			pockets[p] = []


func _resolve_item_data(item_or_id: Variant) -> ItemData:
	if item_or_id is ItemData:
		var item_data: ItemData = item_or_id as ItemData
		if item_data.id != "":
			_item_registry[item_data.id] = item_data
		return item_data
	elif item_or_id is String:
		var item_id: String = item_or_id as String
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
		return item_or_id as String
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


func clear() -> void:
	for p in range(POCKET_COUNT):
		pockets[p] = []


func populate_starter_items() -> void:
	clear()
	add_item(ItemData.get_default_item("potion"), 3)
	add_item(ItemData.get_default_item("pokeball"), 5)
	add_item(ItemData.get_default_item("great_ball"), 2)
	add_item(ItemData.get_default_item("tm01"), 1)
	add_item(ItemData.get_default_item("bicycle"), 1)


func to_dict() -> Dictionary:
	_ensure_pockets()
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
	return {"pockets": serialized_pockets}


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
