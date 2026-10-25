class_name BattleHUD
extends Control

const SLOT_KEY_HINTS: Array[String] = ["1/Z", "2/X", "3/C", "4/V"]

var player_actor: PokemonActor = null
var enemy_actor: PokemonActor = null

@onready var enemy_stat_label: Label = $EnemyStatLabel
@onready var enemy_hp_bar: ProgressBar = $EnemyHPBar
@onready var player_stat_label: Label = $PlayerStatLabel
@onready var player_hp_bar: ProgressBar = $PlayerHPBar
@onready var message_label: Label = $MessageLabel

@onready var slot_labels: Array[Label] = [
	$MoveSlotsContainer/MoveSlot0/SlotLabel,
	$MoveSlotsContainer/MoveSlot1/SlotLabel,
	$MoveSlotsContainer/MoveSlot2/SlotLabel,
	$MoveSlotsContainer/MoveSlot3/SlotLabel,
]

@onready var slot_cooldown_bars: Array[ProgressBar] = [
	$MoveSlotsContainer/MoveSlot0/CooldownBar,
	$MoveSlotsContainer/MoveSlot1/CooldownBar,
	$MoveSlotsContainer/MoveSlot2/CooldownBar,
	$MoveSlotsContainer/MoveSlot3/CooldownBar,
]


func _ready() -> void:
	refresh_all()


func _process(_delta: float) -> void:
	_refresh_cooldown_bars()


func bind_actors(p_player_actor: PokemonActor, p_enemy_actor: PokemonActor) -> void:
	player_actor = p_player_actor
	enemy_actor = p_enemy_actor
	
	if player_actor != null:
		if not player_actor.damaged.is_connected(_on_any_damaged):
			player_actor.damaged.connect(_on_any_damaged)
		if not player_actor.pp_changed.is_connected(_on_player_pp_changed):
			player_actor.pp_changed.connect(_on_player_pp_changed)
		if not player_actor.move_failed_no_pp.is_connected(_on_player_move_failed_no_pp):
			player_actor.move_failed_no_pp.connect(_on_player_move_failed_no_pp)
		if not player_actor.battle_message_requested.is_connected(_on_battle_message_requested):
			player_actor.battle_message_requested.connect(_on_battle_message_requested)
	
	if enemy_actor != null:
		if not enemy_actor.damaged.is_connected(_on_any_damaged):
			enemy_actor.damaged.connect(_on_any_damaged)
		if not enemy_actor.battle_message_requested.is_connected(_on_battle_message_requested):
			enemy_actor.battle_message_requested.connect(_on_battle_message_requested)
	
	refresh_all()


func refresh_all() -> void:
	_refresh_hp_displays()
	_refresh_move_slots()
	_refresh_cooldown_bars()


func _refresh_hp_displays() -> void:
	if player_actor != null and player_actor.pokemon_instance != null:
		var p_mon: PokemonInstance = player_actor.pokemon_instance
		if player_stat_label:
			player_stat_label.text = "%s Lv.%d  HP %d/%d" % [
				p_mon.get_display_name(),
				p_mon.level,
				p_mon.current_hp,
				p_mon.max_hp
			]
		if player_hp_bar:
			player_hp_bar.max_value = maxi(1, p_mon.max_hp)
			player_hp_bar.value = clampi(p_mon.current_hp, 0, p_mon.max_hp)
	
	if enemy_actor != null and enemy_actor.pokemon_instance != null:
		var w_mon: PokemonInstance = enemy_actor.pokemon_instance
		if enemy_stat_label:
			enemy_stat_label.text = "야생 %s Lv.%d  HP %d/%d" % [
				w_mon.get_display_name(),
				w_mon.level,
				w_mon.current_hp,
				w_mon.max_hp
			]
		if enemy_hp_bar:
			enemy_hp_bar.max_value = maxi(1, w_mon.max_hp)
			enemy_hp_bar.value = clampi(w_mon.current_hp, 0, w_mon.max_hp)


func _refresh_move_slots() -> void:
	if player_actor == null or player_actor.pokemon_instance == null:
		return
	var p_mon: PokemonInstance = player_actor.pokemon_instance
	p_mon.ensure_move_instances()
	
	for i in range(4):
		if i >= slot_labels.size() or slot_labels[i] == null:
			continue
		var lbl: Label = slot_labels[i]
		var m_inst: MoveInstance = p_mon.get_move_instance(i)
		var key_hint: String = SLOT_KEY_HINTS[i] if i < SLOT_KEY_HINTS.size() else str(i + 1)
		if m_inst != null and m_inst.move_data != null:
			lbl.text = "[%s] %s PP %d/%d" % [
				key_hint,
				m_inst.get_display_name(),
				m_inst.current_pp,
				m_inst.max_pp
			]
			if m_inst.current_pp <= 0:
				lbl.modulate = Color(1.0, 0.35, 0.35, 1.0)
			else:
				lbl.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			lbl.text = "[%s] -" % key_hint
			lbl.modulate = Color(0.6, 0.6, 0.6, 1.0)


func _refresh_cooldown_bars() -> void:
	if player_actor == null or player_actor.pokemon_instance == null:
		return
	var p_mon: PokemonInstance = player_actor.pokemon_instance
	for i in range(4):
		if i >= slot_cooldown_bars.size() or slot_cooldown_bars[i] == null:
			continue
		var bar: ProgressBar = slot_cooldown_bars[i]
		var m_inst: MoveInstance = p_mon.get_move_instance(i)
		var max_cd: float = m_inst.move_data.cooldown if (m_inst != null and m_inst.move_data != null) else 1.0
		var rem_cd: float = player_actor.get_slot_cooldown(i)
		bar.max_value = maxf(0.05, max_cd)
		bar.value = clampf(rem_cd, 0.0, bar.max_value)


func get_slot_text(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= slot_labels.size() or slot_labels[slot_index] == null:
		return ""
	return slot_labels[slot_index].text


func get_slot_cooldown_ratio(slot_index: int) -> float:
	if slot_index < 0 or slot_index >= slot_cooldown_bars.size() or slot_cooldown_bars[slot_index] == null:
		return 0.0
	var bar: ProgressBar = slot_cooldown_bars[slot_index]
	if bar.max_value <= 0.0001:
		return 0.0
	return float(bar.value / bar.max_value)


func is_slot_zero_pp(slot_index: int) -> bool:
	if player_actor == null or player_actor.pokemon_instance == null:
		return false
	var m_inst: MoveInstance = player_actor.pokemon_instance.get_move_instance(slot_index)
	return m_inst != null and m_inst.current_pp <= 0


func set_battle_message(msg: String) -> void:
	if message_label:
		message_label.text = msg


func get_battle_message() -> String:
	return message_label.text if message_label else ""


func _on_any_damaged(_amount: int, _current_hp: int, _max_hp: int) -> void:
	_refresh_hp_displays()


func _on_player_pp_changed(_slot_index: int, _current_pp: int, _max_pp: int) -> void:
	_refresh_move_slots()
	_refresh_cooldown_bars()


func _on_player_move_failed_no_pp(_slot_index: int, move_name: String) -> void:
	_refresh_move_slots()
	set_battle_message("PP가 부족하여 %s 기술을 쓸 수 없다!" % move_name)


func _on_battle_message_requested(msg: String) -> void:
	set_battle_message(msg)
