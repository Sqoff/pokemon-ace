class_name Projectile
extends Area2D

signal hit_actor(target: Node2D, damage: int)
signal expired()

@export var speed: float = 200.0
@export var damage: int = 8
@export var max_lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var shooter: Node2D = null
var shooter_team: int = 0
var elapsed: float = 0.0
var has_hit: bool = false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 3
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func setup(p_shooter: Node2D, p_team: int, p_direction: Vector2, p_damage: int, p_speed: float = 200.0) -> void:
	shooter = p_shooter
	shooter_team = p_team
	direction = p_direction.normalized() if p_direction.length_squared() > 0.0001 else Vector2.DOWN
	damage = maxi(1, p_damage)
	speed = p_speed
	rotation = direction.angle()


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
	
	# Despawn if outside 320x240 arena bounds
	if global_position.x < -16.0 or global_position.x > 336.0 or global_position.y < -16.0 or global_position.y > 256.0:
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
			actor.receive_hit(damage, direction)
			hit_actor.emit(actor, damage)
			queue_free()
			return true
		return false
	
	if body is StaticBody2D:
		has_hit = true
		expired.emit()
		queue_free()
		return true
	
	return false
