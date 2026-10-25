class_name MoveData
extends Resource

enum Pattern {
	MELEE_LUNGE = 0,
	PROJECTILE = 1,
	DEBUFF_WAVE = 2,
	QUICK_DASH = 3,
}

@export var move_id: String = "tackle"
@export var display_name: String = "몸통박치기"
@export var move_type: String = "Normal"
@export var pattern: int = Pattern.MELEE_LUNGE
@export var power: int = 40
@export var accuracy: int = 100
@export var max_pp: int = 35
@export var cooldown: float = 0.6
@export var range_px: float = 28.0
@export var projectile_speed: float = 210.0
@export var dash_distance: float = 20.0
@export var debuff_stat: String = ""
@export var debuff_stages: int = 0
@export var tint_color: Color = Color(1.0, 1.0, 1.0, 1.0)


static func create(
	p_move_id: String,
	p_display_name: String,
	p_move_type: String,
	p_pattern: int,
	p_power: int,
	p_accuracy: int,
	p_max_pp: int,
	p_cooldown: float,
	p_range_px: float = 28.0,
	p_projectile_speed: float = 210.0,
	p_dash_distance: float = 20.0,
	p_debuff_stat: String = "",
	p_debuff_stages: int = 0,
	p_tint_color: Color = Color(1.0, 1.0, 1.0, 1.0)
) -> MoveData:
	var m := MoveData.new()
	m.move_id = p_move_id
	m.display_name = p_display_name
	m.move_type = p_move_type
	m.pattern = p_pattern
	m.power = p_power
	m.accuracy = p_accuracy
	m.max_pp = maxi(1, p_max_pp)
	m.cooldown = maxf(0.05, p_cooldown)
	m.range_px = maxf(8.0, p_range_px)
	m.projectile_speed = maxf(0.0, p_projectile_speed)
	m.dash_distance = maxf(0.0, p_dash_distance)
	m.debuff_stat = p_debuff_stat
	m.debuff_stages = p_debuff_stages
	m.tint_color = p_tint_color
	return m
