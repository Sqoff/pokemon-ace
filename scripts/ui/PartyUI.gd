class_name PartyUI
extends CanvasLayer

signal party_opened()
signal party_closed()
signal member_selected(index: int, pokemon: PokemonInstance)
signal pokemon_selected(party_index: int, pokemon: PokemonInstance)

var party: Array[PokemonInstance] = []
var selected_index: int = 0
var is_open: bool = false
var battle_select_mode: bool = false
var active_battle_index: int = -1
var status_message: String = ""

@onready var root_control: Control = $RootControl
@onready var title_label: Label = $RootControl/Panel/TitleLabel
@onready var party_list_label: Label = $RootControl/Panel/PartyListLabel
@onready var details_label: Label = $RootControl/Panel/DetailsLabel


func _get_scene_manager() -> Node:
	return get_node_or_null("/root/SceneManager")


func _ready() -> void:
	layer = 85
	if root_control:
		root_control.visible = false


func open_party(p_party: Array = []) -> void:
	if not p_party.is_empty():
		party.clear()
		for item in p_party:
			if item is PokemonInstance:
				party.append(item as PokemonInstance)
	else:
		var sm: Node = _get_scene_manager()
		if sm and sm.get("party") is Array:
			party = sm.get("party")
	
	status_message = ""
	selected_index = 0
	is_open = true
	if root_control:
		root_control.visible = true
	_refresh_view()
	party_opened.emit()


func open_battle_party(p_party: Array, p_active_index: int = 0) -> void:
	battle_select_mode = true
	active_battle_index = p_active_index
	open_party(p_party)
	if not party.is_empty():
		selected_index = clampi(p_active_index, 0, party.size() - 1)
		_refresh_view()


func close_party() -> void:
	if not is_open:
		return
	is_open = false
	if root_control:
		root_control.visible = false
	party_closed.emit()


func select_member(idx: int) -> void:
	if party.is_empty():
		selected_index = 0
		return
	status_message = ""
	selected_index = posmod(idx, party.size())
	_refresh_view()
	member_selected.emit(selected_index, party[selected_index])


func confirm_selection() -> bool:
	if not is_open or party.is_empty():
		return false
	selected_index = clampi(selected_index, 0, party.size() - 1)
	var mon: PokemonInstance = party[selected_index]
	if not battle_select_mode:
		member_selected.emit(selected_index, mon)
		return true
	if selected_index == active_battle_index:
		status_message = "%s은(는) 이미 전투에 나와 있다!" % (mon.get_display_name() if mon else "포켓몬")
		_refresh_view()
		return false
	if mon == null or mon.is_fainted():
		status_message = "%s은(는) 싸울 힘이 남아있지 않다!" % (mon.get_display_name() if mon else "포켓몬")
		_refresh_view()
		return false
	var chosen_idx: int = selected_index
	close_party()
	pokemon_selected.emit(chosen_idx, mon)
	return true


func get_party_list_text() -> String:
	return party_list_label.text if party_list_label else ""


func get_details_text() -> String:
	return details_label.text if details_label else ""


func _refresh_view() -> void:
	if title_label:
		if battle_select_mode:
			title_label.text = "교체할 포켓몬 선택 (%d/6) [Z:교체 / Tab:닫기]" % party.size()
		else:
			title_label.text = "포켓몬 파티 (%d/6)" % party.size()
	
	if party.is_empty():
		selected_index = 0
		if party_list_label:
			party_list_label.text = "(파티에 포켓몬이 없습니다)"
		if details_label:
			details_label.text = ""
		return
	
	selected_index = clampi(selected_index, 0, party.size() - 1)
	var lines: Array[String] = []
	for i in range(party.size()):
		var mon: PokemonInstance = party[i]
		if mon == null:
			continue
		var prefix: String = "▶ " if i == selected_index else "  "
		var suffix: String = ""
		if battle_select_mode:
			if i == active_battle_index:
				suffix = " [출전중]"
			elif mon.is_fainted():
				suffix = " [기절]"
		lines.append("%s%d. %s  Lv.%d  HP %d/%d%s" % [
			prefix,
			i + 1,
			mon.get_display_name(),
			mon.level,
			mon.current_hp,
			mon.max_hp,
			suffix
		])
	
	if party_list_label:
		party_list_label.text = "\n".join(lines)
	
	var sel_mon: PokemonInstance = party[selected_index]
	if sel_mon != null and details_label:
		sel_mon.ensure_move_instances()
		var move_lines: Array[String] = []
		for m_idx in range(sel_mon.get_move_count()):
			var m_inst: MoveInstance = sel_mon.get_move_instance(m_idx)
			if m_inst != null:
				move_lines.append("%s PP %d/%d" % [m_inst.get_display_name(), m_inst.current_pp, m_inst.max_pp])
		var base_details: String = "[%s Lv.%d | ATK %d DEF %d SPD %d]\n기술: %s" % [
			sel_mon.get_display_name(),
			sel_mon.level,
			sel_mon.attack,
			sel_mon.defense,
			sel_mon.speed,
			" / ".join(move_lines)
		]
		if not status_message.is_empty():
			base_details += "\n▶ " + status_message
		details_label.text = base_details


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		select_member(selected_index - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		select_member(selected_index + 1)
		get_viewport().set_input_as_handled()
	elif battle_select_mode and (event.is_action_pressed("action_interact") or event.is_action_pressed("ui_accept")):
		confirm_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_start") or event.is_action_pressed("ui_cancel") or (battle_select_mode and event.is_action_pressed("switch_party")):
		close_party()
		get_viewport().set_input_as_handled()
