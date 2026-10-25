class_name BattleHUD
extends Control

const SLOT_KEY_HINTS: Array[String] = ["1/Z", "2/X", "3/C", "4/V"]

const HP_COLOR_HIGH: Color = Color(0.22, 0.85, 0.35, 1.0)
const HP_COLOR_MID: Color = Color(0.96, 0.75, 0.18, 1.0)
const HP_COLOR_LOW: Color = Color(0.92, 0.25, 0.22, 1.0)

const TYPE_COLORS: Dictionary = {
	"FIRE": Color(0.94, 0.41, 0.19, 1.0),
	"WATER": Color(0.22, 0.60, 0.97, 1.0),
	"GRASS": Color(0.28, 0.78, 0.31, 1.0),
	"FLYING": Color(0.53, 0.60, 0.97, 1.0),
	"NORMAL": Color(0.66, 0.66, 0.60, 1.0),
}

const TYPE_KOR_NAMES: Dictionary = {
	"FIRE": "불꽃",
	"WATER": "물",
	"GRASS": "풀",
	"FLYING": "비행",
	"NORMAL": "노말",
}

var player_actor: PokemonActor = null
var enemy_actor: PokemonActor = null

var _enemy_hp_fill_style: StyleBoxFlat = null
var _player_hp_fill_style: StyleBoxFlat = null
var _slot_card_styles: Array[StyleBoxFlat] = []

@onready var enemy_stat_label: Label = $EnemyStatLabel
@onready var enemy_hp_bar: ProgressBar = $EnemyHPBar
@onready var player_stat_label: Label = $PlayerStatLabel
@onready var player_hp_bar: ProgressBar = $PlayerHPBar
@onready var message_label: Label = $MessageLabel

@onready var top_ball_count_label: Label = get_node_or_null("CenterInfoPanel/TopBallCountLabel") as Label
@onready var right_header_label: Label = get_node_or_null("RightInfoAndMessageBox/RightHeaderLabel") as Label

@onready var slot_cards: Array[Panel] = [
	get_node_or_null("FightMovesBox/SlotCardsLayer/SlotCard0") as Panel,
	get_node_or_null("FightMovesBox/SlotCardsLayer/SlotCard1") as Panel,
	get_node_or_null("FightMovesBox/SlotCardsLayer/SlotCard2") as Panel,
	get_node_or_null("FightMovesBox/SlotCardsLayer/SlotCard3") as Panel,
]

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
	_init_dynamic_styles()
	refresh_all()


func _process(_delta: float) -> void:
	_refresh_cooldown_bars()


func _init_dynamic_styles() -> void:
	if _enemy_hp_fill_style == null:
		_enemy_hp_fill_style = StyleBoxFlat.new()
		_enemy_hp_fill_style.bg_color = HP_COLOR_HIGH
		_enemy_hp_fill_style.set_corner_radius_all(1)
		if enemy_hp_bar != null:
			enemy_hp_bar.add_theme_stylebox_override("fill", _enemy_hp_fill_style)
	
	if _player_hp_fill_style == null:
		_player_hp_fill_style = StyleBoxFlat.new()
		_player_hp_fill_style.bg_color = HP_COLOR_HIGH
		_player_hp_fill_style.set_corner_radius_all(1)
		if player_hp_bar != null:
			player_hp_bar.add_theme_stylebox_override("fill", _player_hp_fill_style)
	
	if _slot_card_styles.is_empty():
		for i in range(4):
			var st := StyleBoxFlat.new()
			st.bg_color = Color(0.99, 0.99, 0.96, 1.0)
			st.border_width_left = 3
			st.border_width_top = 1
			st.border_width_right = 1
			st.border_width_bottom = 1
			st.border_color = TYPE_COLORS["NORMAL"]
			st.set_corner_radius_all(2)
			_slot_card_styles.append(st)
			if i < slot_cards.size() and slot_cards[i] != null:
				slot_cards[i].add_theme_stylebox_override("panel", st)


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
		if not player_actor.stat_stage_changed.is_connected(_on_any_stat_or_status_changed):
			player_actor.stat_stage_changed.connect(_on_any_stat_or_status_changed)
	
	if enemy_actor != null:
		if not enemy_actor.damaged.is_connected(_on_any_damaged):
			enemy_actor.damaged.connect(_on_any_damaged)
		if not enemy_actor.battle_message_requested.is_connected(_on_battle_message_requested):
			enemy_actor.battle_message_requested.connect(_on_battle_message_requested)
		if not enemy_actor.stat_stage_changed.is_connected(_on_any_stat_or_status_changed):
			enemy_actor.stat_stage_changed.connect(_on_any_stat_or_status_changed)
		if not enemy_actor.enrage_state_changed.is_connected(_on_enemy_enrage_changed):
			enemy_actor.enrage_state_changed.connect(_on_enemy_enrage_changed)
	
	refresh_all()


func refresh_all() -> void:
	_init_dynamic_styles()
	_refresh_hp_displays()
	_refresh_ball_and_status_info()
	_refresh_move_slots()
	_refresh_cooldown_bars()


static func get_hp_bar_color(ratio: float) -> Color:
	if ratio > 0.5:
		return HP_COLOR_HIGH
	elif ratio > 0.2:
		return HP_COLOR_MID
	return HP_COLOR_LOW


static func get_type_border_color(type_str: String) -> Color:
	var key: String = type_str.strip_edges().to_upper()
	if TYPE_COLORS.has(key):
		return TYPE_COLORS[key]
	return TYPE_COLORS["NORMAL"]


static func get_type_kor_name(type_str: String) -> String:
	var key: String = type_str.strip_edges().to_upper()
	if TYPE_KOR_NAMES.has(key):
		return TYPE_KOR_NAMES[key]
	return "노말"


func _get_pokeball_count() -> int:
	var sm: Node = get_node_or_null("/root/SceneManager")
	if sm != null and sm.get("player_inventory") != null:
		var inv: Inventory = sm.get("player_inventory") as Inventory
		if inv != null:
			return inv.get_item_count("pokeball")
	return 5


func _refresh_ball_and_status_info() -> void:
	var ball_cnt: int = _get_pokeball_count()
	if top_ball_count_label != null:
		top_ball_count_label.text = "● 볼 x%d" % ball_cnt
		if ball_cnt <= 0:
			top_ball_count_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1.0))
		else:
			top_ball_count_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.68, 1.0))
	
	if right_header_label != null:
		var status_suffix: String = ""
		if enemy_actor != null:
			if enemy_actor.is_enraged:
				status_suffix += " [분노!]"
			if enemy_actor.defense_stage < 0:
				status_suffix += " [방어%d]" % enemy_actor.defense_stage
		right_header_label.text = "● 볼 x%d [Space]%s" % [ball_cnt, status_suffix]


func _refresh_hp_displays() -> void:
	_init_dynamic_styles()
	if player_actor != null and player_actor.pokemon_instance != null:
		var p_mon: PokemonInstance = player_actor.pokemon_instance
		var p_max: int = maxi(1, p_mon.max_hp)
		var p_cur: int = clampi(p_mon.current_hp, 0, p_max)
		var p_ratio: float = float(p_cur) / float(p_max)
		if player_stat_label:
			player_stat_label.text = "%s Lv.%d  HP %d/%d" % [
				p_mon.get_display_name(),
				p_mon.level,
				p_cur,
				p_max
			]
		if player_hp_bar:
			player_hp_bar.max_value = p_max
			player_hp_bar.value = p_cur
		if _player_hp_fill_style != null:
			_player_hp_fill_style.bg_color = get_hp_bar_color(p_ratio)
	
	if enemy_actor != null and enemy_actor.pokemon_instance != null:
		var w_mon: PokemonInstance = enemy_actor.pokemon_instance
		var w_max: int = maxi(1, w_mon.max_hp)
		var w_cur: int = clampi(w_mon.current_hp, 0, w_max)
		var w_ratio: float = float(w_cur) / float(w_max)
		var status_tag: String = ""
		if enemy_actor.is_enraged:
			status_tag = " [분노]"
		elif enemy_actor.defense_stage < 0:
			status_tag = " [방어↓]"
		if enemy_stat_label:
			enemy_stat_label.text = "야생 %s Lv.%d  HP %d/%d%s" % [
				w_mon.get_display_name(),
				w_mon.level,
				w_cur,
				w_max,
				status_tag
			]
		if enemy_hp_bar:
			enemy_hp_bar.max_value = w_max
			enemy_hp_bar.value = w_cur
		if _enemy_hp_fill_style != null:
			_enemy_hp_fill_style.bg_color = get_hp_bar_color(w_ratio)


func _refresh_move_slots() -> void:
	_init_dynamic_styles()
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
		var card_style: StyleBoxFlat = _slot_card_styles[i] if i < _slot_card_styles.size() else null
		
		if m_inst != null and m_inst.move_data != null:
			var m_type: String = m_inst.move_data.move_type
			var kor_type: String = get_type_kor_name(m_type)
			lbl.text = "▶[%s] %s\nPP %d/%d [%s]" % [
				key_hint,
				m_inst.get_display_name(),
				m_inst.current_pp,
				m_inst.max_pp,
				kor_type
			]
			if m_inst.current_pp <= 0:
				lbl.modulate = Color(1.0, 0.32, 0.32, 1.0)
				if card_style != null:
					card_style.border_color = Color(0.88, 0.22, 0.22, 1.0)
					card_style.bg_color = Color(1.0, 0.92, 0.92, 1.0)
			else:
				lbl.modulate = Color(1.0, 1.0, 1.0, 1.0)
				if card_style != null:
					card_style.border_color = get_type_border_color(m_type)
					card_style.bg_color = Color(0.99, 0.99, 0.96, 1.0)
		else:
			lbl.text = "▶[%s] -\nPP 0/0" % key_hint
			lbl.modulate = Color(0.6, 0.6, 0.6, 1.0)
			if card_style != null:
				card_style.border_color = Color(0.7, 0.7, 0.7, 1.0)
				card_style.bg_color = Color(0.93, 0.93, 0.91, 1.0)


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
		
		if i < _slot_card_styles.size() and _slot_card_styles[i] != null:
			var st: StyleBoxFlat = _slot_card_styles[i]
			var zero_pp: bool = m_inst != null and m_inst.current_pp <= 0
			if not zero_pp:
				if rem_cd > 0.01:
					st.bg_color = Color(0.90, 0.93, 0.96, 1.0)
				else:
					st.bg_color = Color(0.99, 0.99, 0.96, 1.0)


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


func _on_any_stat_or_status_changed(_stat_name: String, _new_stage: int, _delta_stage: int) -> void:
	_refresh_hp_displays()
	_refresh_ball_and_status_info()


func _on_enemy_enrage_changed(_enraged: bool, _speed_mult: float, _cooldown_mult: float) -> void:
	_refresh_hp_displays()
	_refresh_ball_and_status_info()


func _on_player_pp_changed(_slot_index: int, _current_pp: int, _max_pp: int) -> void:
	_refresh_move_slots()
	_refresh_cooldown_bars()


func _on_player_move_failed_no_pp(_slot_index: int, move_name: String) -> void:
	_refresh_move_slots()
	set_battle_message("PP가 부족하여 %s 기술을 쓸 수 없다!" % move_name)


func _on_battle_message_requested(msg: String) -> void:
	set_battle_message(msg)
	_refresh_ball_and_status_info()
