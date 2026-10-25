class_name StartMenuUI
extends CanvasLayer

signal menu_opened()
signal menu_closed()
signal report_saved(success: bool)

const MENU_ITEMS: Array[String] = [
	"포켓몬 (POKEMON)",
	"가방 (BAG)",
	"리포트 (REPORT)",
	"시간 전환 (TIME)",
	"닫기 (EXIT)"
]

var is_open: bool = false
var selected_index: int = 0
var bag_ui: BagUI = null
var party_ui: PartyUI = null

@onready var root_control: Control = $RootControl
@onready var time_label: Label = $RootControl/MenuPanel/TimeLabel
@onready var options_label: Label = $RootControl/MenuPanel/OptionsLabel


func _ready() -> void:
	layer = 80
	if root_control:
		root_control.visible = false


func bind_bag_ui(p_bag_ui: BagUI) -> void:
	bag_ui = p_bag_ui
	if bag_ui and not bag_ui.bag_closed.is_connected(_on_sub_ui_closed):
		bag_ui.bag_closed.connect(_on_sub_ui_closed)


func bind_party_ui(p_party_ui: PartyUI) -> void:
	party_ui = p_party_ui
	if party_ui and not party_ui.party_closed.is_connected(_on_sub_ui_closed):
		party_ui.party_closed.connect(_on_sub_ui_closed)


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


func select_option_by_index(index: int) -> void:
	selected_index = posmod(index, MENU_ITEMS.size())
	_refresh_menu()
	_activate_selected()


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
	var sm: Node = get_node_or_null("/root/SceneManager")
	match selected_index:
		0: # POKEMON (PartyUI)
			if party_ui:
				if root_control:
					root_control.visible = false
				var party_arr: Array = []
				if sm and sm.get("party") is Array:
					party_arr = sm.get("party")
				else:
					var player: Node = _get_player()
					if player and player.get("party") is Array:
						party_arr = player.get("party")
				party_ui.open_party(party_arr)
		1: # BAG (BagUI)
			if bag_ui:
				if root_control:
					root_control.visible = false
				var inv: Inventory = null
				if sm and sm.get("player_inventory") is Inventory:
					inv = sm.get("player_inventory") as Inventory
				if inv == null:
					var player: Node = _get_player()
					inv = player.get("inventory") if player else null
				bag_ui.open_bag(inv, 0)
		2: # REPORT (SaveManager)
			var save_mgr: Node = get_node_or_null("/root/SaveManager")
			var ok: bool = false
			if save_mgr and save_mgr.has_method("save_game"):
				ok = save_mgr.save_game()
			close_menu()
			var dm: Node = get_node_or_null("/root/DialogueManager")
			if dm and dm.has_method("start_dialogue"):
				if ok:
					dm.start_dialogue("포켓몬 리포트를 작성했습니다!", "리포트")
				else:
					dm.start_dialogue("리포트 작성에 실패했습니다.", "리포트")
			report_saved.emit(ok)
		3: # TIME
			var tm: Node = get_node_or_null("/root/TimeManager")
			if tm and tm.has_method("cycle_next_period"):
				tm.cycle_next_period(true)
			_refresh_menu()
		4: # EXIT
			close_menu()


func _on_sub_ui_closed() -> void:
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
	if (bag_ui and bag_ui.is_open) or (party_ui and party_ui.is_open):
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
