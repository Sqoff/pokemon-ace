class_name MoveInstance
extends Resource

@export var move_data: MoveData
@export var current_pp: int = 35
@export var max_pp: int = 35


static func create(p_move_data: MoveData, p_current_pp: int = -1) -> MoveInstance:
	var inst := MoveInstance.new()
	inst.move_data = p_move_data
	if p_move_data != null:
		inst.max_pp = maxi(1, p_move_data.max_pp)
	else:
		inst.max_pp = 35
	if p_current_pp < 0:
		inst.current_pp = inst.max_pp
	else:
		inst.current_pp = clampi(p_current_pp, 0, inst.max_pp)
	return inst


func get_move_id() -> String:
	return move_data.move_id if move_data != null else "tackle"


func get_display_name() -> String:
	return move_data.display_name if move_data != null else "몸통박치기"


func can_use() -> bool:
	return current_pp > 0


func consume_pp(amount: int = 1) -> bool:
	var cost: int = maxi(1, amount)
	if current_pp < cost or current_pp <= 0:
		return false
	current_pp = maxi(0, current_pp - cost)
	return true


func restore_pp(amount: int = -1) -> void:
	if amount < 0:
		current_pp = max_pp
	else:
		current_pp = clampi(current_pp + amount, 0, max_pp)


func to_dict() -> Dictionary:
	return {
		"move_id": get_move_id(),
		"display_name": get_display_name(),
		"current_pp": current_pp,
		"max_pp": max_pp,
	}


static func from_dict(d: Dictionary) -> MoveInstance:
	var m_id: String = str(d.get("move_id", "tackle"))
	var m_data: MoveData = MoveRegistry.get_move_data(m_id)
	var inst := MoveInstance.new()
	inst.move_data = m_data
	inst.max_pp = int(d.get("max_pp", m_data.max_pp if m_data else 35))
	inst.current_pp = clampi(int(d.get("current_pp", inst.max_pp)), 0, inst.max_pp)
	return inst
