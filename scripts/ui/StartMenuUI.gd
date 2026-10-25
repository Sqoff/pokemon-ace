class_name StartMenuUI
extends CanvasLayer

signal menu_opened()
signal menu_closed()

const MENU_ITEMS: Array[String] = [
	"가방 (BAG)",
	"시간 전환 (TIME)",
	"닫기 (EXIT)"
]

var is_open: bool = false
var selected_index: int = 0
var bag_ui: BagUI

@onready var root_control: Control = $RootControl
@onready var time_label: Label = $RootControl/MenuPanel/TimeLabel
@onready var options_label: Label = $RootControl/MenuPanel/OptionsLabel


func _ready() -> void:
	layer = 80
	if root_control:
		root_control.visible = false


func bind_bag_ui(p_bag_ui: BagUI) -> void:
	bag_ui = p_bag_ui
	if bag_ui and not bag_ui.bag_closed.is_connected(_on_bag_closed):
		bag_ui.bag_closed.connect(_on_bag_closed)


func open_menu() -> void:
	if is_open:
		return
	var dm: Node = get_node_or_null("/root/DialogueManager")
	if dm and dm.get("is_active"):
		return
	is_open = true
	selected_index = 0
	if root_control:
		root_control.visible = true
	_set_player_locked(true)
	_refresh_menu()
	menu_opened.emit()


func close_menu() -> void:
	if not is_open:
		return
	is_open = false
	if root_control:
		root_control.visible = false
	_set_player_locked(false)
	menu_closed.emit()


func _refresh_menu() -> void:
	var tm: Node = get_node_or_null("/root/TimeManager")
	if time_label and tm:
		var p_disp: String = tm.get_current_period_display_name() if tm.has_method("get_current_period_display_name") else "낮"
		var hr: int = int(tm.get("current_hour"))
		time_label.text = "[%s] %02d:00" % [p_disp, hr]
	
	var lines: Array[String] = []
	for i in range(MENU_ITEMS.size()):
		var prefix: String = "▶ " if i == selected_index else "  "
		lines.append(prefix + MENU_ITEMS[i])
	if options_label:
		options_label.text = "\n".join(lines)


func _activate_selected() -> void:
	match selected_index:
		0: # BAG
			if bag_ui:
				if root_control:
					root_control.visible = false
				var player: Node = _get_player()
				var inv: Inventory = player.get("inventory") if player else null
				bag_ui.open_bag(inv, 0)
		1: # TIME
			var tm: Node = get_node_or_null("/root/TimeManager")
			if tm and tm.has_method("cycle_next_period"):
				tm.cycle_next_period(true)
			_refresh_menu()
		2: # EXIT
			close_menu()


func _on_bag_closed() -> void:
	if is_open and root_control:
		root_control.visible = true
		_refresh_menu()


func _get_player() -> Node:
	var scene: Node = get_tree().current_scene
	if scene:
		return scene.get_node_or_null("Player")
	return null


func _set_player_locked(locked: bool) -> void:
	var player: Node = _get_player()
	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(not locked)


func _unhandled_input(event: InputEvent) -> void:
	if bag_ui and bag_ui.is_open:
		return
	var dm: Node = get_node_or_null("/root/DialogueManager")
	if dm and dm.get("is_active"):
		return
	
	if not is_open:
		if event.is_action_pressed("menu_start"):
			open_menu()
			get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		selected_index = posmod(selected_index - 1, MENU_ITEMS.size())
		_refresh_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		selected_index = posmod(selected_index + 1, MENU_ITEMS.size())
		_refresh_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("action_interact") or event.is_action_pressed("ui_accept"):
		_activate_selected()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_start") or event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
