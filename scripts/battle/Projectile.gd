class_name Projectile
extends Area2D

signal hit_actor(target: Node2D, damage: int)
signal expired()

@export var speed: float = 200.0
@export var damage: int = 8
@export var max_lifetime: float = 2.5

var direction: Vector2 = Vector2.RIGHT
var shooter: Node2D = null
var shooter_team: int = 0
var move_data: MoveData = null
var elapsed: float = 0.0
var has_hit: bool = false

@onready var visual_poly: Polygon2D = get_node_or_null("Visual") as Polygon2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 3
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func setup(
	p_shooter: Node2D,
	p_team: int,
	p_direction: Vector2,
	p_damage: int,
	p_speed: float = 200.0,
	p_move_data: MoveData = null
) -> void:
	shooter = p_shooter
	shooter_team = p_team
	direction = p_direction.normalized() if p_direction.length_squared() > 0.0001 else Vector2.DOWN
	damage = maxi(1, p_damage)
	speed = p_speed
	move_data = p_move_data
	rotation = direction.angle()
	if move_data != null:
		var vis: Polygon2D = get_node_or_null("Visual") as Polygon2D
		if vis != null:
			vis.color = move_data.tint_color


func _physics_process(delta: float) -> void:
	if has_hit:
		return
	
	elapsed += delta
	if elapsed >= max_lifetime:
		expired.emit()
		queue_free()
		return
	
	global_position += direction * speed * delta
	
	# Check overlapping bodies actively in case of fast step in headless physics
	for body in get_overlapping_bodies():
		if _try_hit_body(body):
			return
	
	# Despawn if outside 640x480 arena bounds
	if global_position.x < -32.0 or global_position.x > 672.0 or global_position.y < -32.0 or global_position.y > 512.0:
		expired.emit()
		queue_free()


func _on_body_entered(body: Node) -> void:
	_try_hit_body(body)


func _try_hit_body(body: Node) -> bool:
	if has_hit or body == null or body == shooter:
		return false
	
	if body is PokemonActor:
		var actor: PokemonActor = body as PokemonActor
		if actor.team != shooter_team:
			has_hit = true
			var dealt_dmg: int = damage
			if move_data != null and shooter is PokemonActor:
				dealt_dmg = actor.receive_move_hit(shooter as PokemonActor, move_data, direction)
			else:
				var hp_before: int = actor.pokemon_instance.current_hp if actor.pokemon_instance else 20
				actor.receive_hit(damage, direction)
				var hp_after: int = actor.pokemon_instance.current_hp if actor.pokemon_instance else 0
				dealt_dmg = maxi(0, hp_before - hp_after)
			hit_actor.emit(actor, dealt_dmg)
			queue_free()
			return true
		return false
	
	if body is StaticBody2D:
		has_hit = true
		expired.emit()
		queue_free()
		return true
	
	return false
