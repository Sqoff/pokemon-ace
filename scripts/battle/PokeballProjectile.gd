class_name PokeballProjectile
extends Area2D

signal ball_hit_enemy(enemy: PokemonActor, ball_item_id: String, ball_multiplier: float)
signal shake_step(step_number: int)
signal catch_succeeded(enemy: PokemonActor, pokemon: PokemonInstance)
signal catch_failed(enemy: PokemonActor, pokemon: PokemonInstance, shakes_done: int)
signal expired()

@export var speed: float = 190.0
@export var max_lifetime: float = 2.5
@export var arc_height: float = 22.0
@export var shake_interval: float = 0.06

var direction: Vector2 = Vector2.RIGHT
var shooter: Node2D = null
var shooter_team: int = 0
var ball_item_id: String = "pokeball"
var ball_multiplier: float = 1.0
var elapsed: float = 0.0
var flight_duration: float = 0.55
var has_hit: bool = false
var is_resolving_catch: bool = false

## Optional test overrides: -1 means use RNG; 1 means force success; 0 means force fail
var forced_catch_outcome: int = -1
var custom_rng: RandomNumberGenerator = null

@onready var shadow_poly: Polygon2D = get_node_or_null("Shadow") as Polygon2D
@onready var ball_visual: Node2D = get_node_or_null("BallVisual") as Node2D
@onready var top_half: Polygon2D = get_node_or_null("BallVisual/TopHalf") as Polygon2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 3
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


static func normalize_ball_id(item_id: String) -> String:
	var clean: String = item_id.strip_edges().to_lower()
	if clean == "poke_ball" or clean == "pokeball" or clean.is_empty():
		return "pokeball"
	return clean


static func resolve_ball_multiplier(item_id: String) -> float:
	var norm_id: String = normalize_ball_id(item_id)
	var item_data: ItemData = ItemData.get_default_item(norm_id)
	if item_data != null and item_data.ball_multiplier > 0.0:
		return item_data.ball_multiplier
	if norm_id == "great_ball":
		return 1.5
	if norm_id == "ultra_ball":
		return 2.0
	return 1.0


## SPECIFICATION.md 2.2.C formula raw value (0..255+ scale):
## ((3 * MaxHP - 2 * CurrentHP) / (3 * MaxHP)) * CatchRate * BallMultiplier
static func calculate_catch_formula_value(max_hp: int, current_hp: int, catch_rate: int, p_ball_multiplier: float = 1.0) -> float:
	var safe_max: float = float(maxi(1, max_hp))
	var safe_cur: float = clampf(float(current_hp), 0.0, safe_max)
	var hp_factor: float = (3.0 * safe_max - 2.0 * safe_cur) / (3.0 * safe_max)
	return hp_factor * float(maxi(1, catch_rate)) * maxf(0.1, p_ball_multiplier)


## Normalized catch probability (0.02 .. 1.0) from the specification formula
static func calculate_catch_probability(max_hp: int, current_hp: int, catch_rate: int, p_ball_multiplier: float = 1.0) -> float:
	var raw_val: float = calculate_catch_formula_value(max_hp, current_hp, catch_rate, p_ball_multiplier)
	return clampf(raw_val / 255.0, 0.02, 1.0)


func setup(
	p_shooter: Node2D,
	p_team: int,
	p_direction: Vector2,
	p_ball_item_id: String = "pokeball",
	p_ball_multiplier: float = -1.0,
	p_speed: float = 190.0
) -> void:
	shooter = p_shooter
	shooter_team = p_team
	direction = p_direction.normalized() if p_direction.length_squared() > 0.0001 else Vector2.RIGHT
	ball_item_id = normalize_ball_id(p_ball_item_id)
	ball_multiplier = p_ball_multiplier if p_ball_multiplier > 0.0 else resolve_ball_multiplier(ball_item_id)
	speed = p_speed
	_apply_ball_colors()


func _apply_ball_colors() -> void:
	var top_node: Polygon2D = get_node_or_null("BallVisual/TopHalf") as Polygon2D
	if top_node == null:
		return
	if ball_item_id == "great_ball":
		top_node.color = Color(0.2, 0.45, 0.92, 1.0)
	else:
		top_node.color = Color(0.92, 0.22, 0.2, 1.0)


func _physics_process(delta: float) -> void:
	if has_hit or is_resolving_catch:
		return
	
	elapsed += delta
	if elapsed >= max_lifetime:
		expired.emit()
		queue_free()
		return
	
	global_position += direction * speed * delta
	
	# Parabolic arc visual height offset: 4 * h * t * (1 - t)
	var t: float = clampf(elapsed / maxf(0.15, flight_duration), 0.0, 1.0)
	var current_arc_y: float = -4.0 * arc_height * t * (1.0 - t)
	if ball_visual == null:
		ball_visual = get_node_or_null("BallVisual") as Node2D
	if ball_visual != null:
		ball_visual.position.y = current_arc_y
		ball_visual.rotation += delta * 14.0
	
	for body in get_overlapping_bodies():
		if _try_hit_body(body):
			return
	
	if global_position.x < -32.0 or global_position.x > 672.0 or global_position.y < -32.0 or global_position.y > 512.0:
		expired.emit()
		queue_free()


func _on_body_entered(body: Node) -> void:
	_try_hit_body(body)


func _try_hit_body(body: Node) -> bool:
	if has_hit or is_resolving_catch or body == null or body == shooter:
		return false
	
	if body is PokemonActor:
		var actor: PokemonActor = body as PokemonActor
		if actor.team != shooter_team:
			has_hit = true
			is_resolving_catch = true
			set_deferred("monitoring", false)
			ball_hit_enemy.emit(actor, ball_item_id, ball_multiplier)
			_run_capture_sequence(actor)
			return true
		return false
	
	if body is StaticBody2D:
		has_hit = true
		expired.emit()
		queue_free()
		return true
	
	return false


func _run_capture_sequence(enemy: PokemonActor) -> void:
	if not is_instance_valid(enemy):
		queue_free()
		return
	
	global_position = enemy.global_position
	if ball_visual == null:
		ball_visual = get_node_or_null("BallVisual") as Node2D
	if ball_visual != null:
		ball_visual.position = Vector2.ZERO
		ball_visual.rotation = 0.0
	
	# Absorb wild pokemon into ball temporarily
	enemy.set_captured_in_ball_visual(true)
	
	var mon: PokemonInstance = enemy.pokemon_instance
	var max_hp_val: int = mon.max_hp if mon != null else 20
	var cur_hp_val: int = mon.current_hp if mon != null else 20
	var c_rate: int = (mon.data.catch_rate if (mon != null and mon.data != null) else 255)
	var prob: float = calculate_catch_probability(max_hp_val, cur_hp_val, c_rate, ball_multiplier)
	
	var is_caught: bool = false
	if forced_catch_outcome == 1:
		is_caught = true
	elif forced_catch_outcome == 0:
		is_caught = false
	else:
		var roll: float = custom_rng.randf() if custom_rng != null else randf()
		is_caught = (roll < prob)
	
	var shakes_to_play: int = 3 if is_caught else 2
	var step_dur: float = maxf(0.01, shake_interval)
	
	for s in range(1, shakes_to_play + 1):
		if not is_inside_tree():
			return
		shake_step.emit(s)
		if ball_visual != null:
			var tw: Tween = create_tween()
			var tilt: float = 0.35 if (s % 2 == 1) else -0.35
			tw.tween_property(ball_visual, "rotation", tilt, step_dur * 0.5)
			tw.tween_property(ball_visual, "rotation", 0.0, step_dur * 0.5)
			await tw.finished
		else:
			await get_tree().process_frame
	
	if not is_inside_tree():
		return
	
	if is_caught:
		if ball_visual != null:
			ball_visual.modulate = Color(1.0, 0.95, 0.55, 1.0)
		catch_succeeded.emit(enemy, mon)
		queue_free()
	else:
		if is_instance_valid(enemy):
			enemy.set_captured_in_ball_visual(false)
			enemy.enter_enrage_state(6.0)
		catch_failed.emit(enemy, mon, shakes_to_play)
		queue_free()
