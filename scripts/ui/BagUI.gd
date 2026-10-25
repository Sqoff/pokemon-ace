class_name BagUI
extends CanvasLayer

signal bag_opened(pocket: int)
signal bag_closed()
signal pocket_switched(pocket: int, pocket_name: String)

var inventory: Inventory
var current_pocket: int = ItemData.Pocket.ITEMS
var selected_index: int = 0
var is_open: bool = false

@onready var root_control: Control = $RootControl
@onready var pocket_title_label: Label = $RootControl/Panel/PocketTitleLabel
@onready var item_list_label: Label = $RootControl/Panel/ItemListLabel
@onready var description_label: Label = $RootControl/Panel/DescriptionLabel


func _ready() -> void:
	layer = 85
	if root_control:
		root_control.visible = false
	if inventory == null:
		inventory = Inventory.new()
		inventory.populate_starter_items()


func open_bag(inv: Inventory = null, initial_pocket: int = 0) -> void:
	if inv != null:
		inventory = inv
	elif inventory == null:
		inventory = Inventory.new()
		inventory.populate_starter_items()
	
	current_pocket = clampi(initial_pocket, 0, Inventory.POCKET_COUNT - 1)
	selected_index = 0
	is_open = true
	if root_control:
		root_control.visible = true
	_refresh_view()
	bag_opened.emit(current_pocket)


func close_bag() -> void:
	if not is_open:
		return
	is_open = false
	if root_control:
		root_control.visible = false
	bag_closed.emit()


func switch_pocket(pocket_idx: int) -> void:
	current_pocket = posmod(pocket_idx, Inventory.POCKET_COUNT)
	selected_index = 0
	_refresh_view()
	pocket_switched.emit(current_pocket, ItemData.get_pocket_name(current_pocket))


func _refresh_view() -> void:
	if not inventory:
		return
	var p_name: String = ItemData.get_pocket_name(current_pocket)
	if pocket_title_label:
		pocket_title_label.text = "◀ [%d/4] %s ▶" % [current_pocket + 1, p_name]
	
	var items: Array = inventory.get_pocket_items(current_pocket)
	if items.is_empty():
		selected_index = 0
		if item_list_label:
			item_list_label.text = "(비어 있음)"
		if description_label:
			description_label.text = "이 포켓에는 도구가 없습니다."
		return
	
	selected_index = clampi(selected_index, 0, items.size() - 1)
	var lines: Array[String] = []
	for i in range(items.size()):
		var entry: Dictionary = items[i]
		var prefix: String = "▶ " if i == selected_index else "  "
		var d_name: String = str(entry.get("display_name", entry.get("id", "")))
		var cnt: int = int(entry.get("count", 1))
		lines.append("%s%s  x%d" % [prefix, d_name, cnt])
	
	if item_list_label:
		item_list_label.text = "\n".join(lines)
	
	var sel_entry: Dictionary = items[selected_index]
	var item_obj: ItemData = sel_entry.get("item", null) as ItemData
	if description_label:
		description_label.text = item_obj.description if item_obj else ""


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		switch_pocket(current_pocket - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		switch_pocket(current_pocket + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		selected_index = maxi(0, selected_index - 1)
		_refresh_view()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		selected_index += 1
		_refresh_view()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_start") or event.is_action_pressed("ui_cancel"):
		close_bag()
		get_viewport().set_input_as_handled()
