class_name PokemonActor
extends CharacterBody2D

signal projectile_fired(projectile: Projectile, direction: Vector2)
signal damaged(amount: int, current_hp: int, max_hp: int)
signal fainted(actor: PokemonActor)
signal action_state_changed(action_name: String, dir_key: String)

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/battle/Projectile.tscn")

@export var is_player_controlled: bool = false
@export var team: int = 0
@export var species_id: String = "cyndaquil"
@export var base_move_speed: float = 100.0
@export var attack_cooldown: float = 0.20

var pokemon_instance: PokemonInstance = null
var facing_direction: Vector2 = Vector2(0, 1)
var facing_dir_key: String = "s"
var current_action: String = "idle"

var simulated_input_vector: Vector2 = Vector2.ZERO
var action_lock_timer: float = 0.0
var cooldown_timer: float = 0.0

@onready var shadow_poly: Polygon2D = $Shadow
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	
	if pokemon_instance == null:
		pokemon_instance = PokemonRegistry.create_instance(species_id, 5)
	_apply_pokemon_visuals()
	_play_state_animation("idle", facing_dir_key, true)


func setup_from_instance(inst: PokemonInstance, p_is_player: bool = false, initial_dir_key: String = "s") -> void:
	if inst != null:
		pokemon_instance = inst
		species_id = inst.get_species_id()
		base_move_speed = clampf(85.0 + float(inst.speed) * 1.5, 85.0, 150.0)
	is_player_controlled = p_is_player
	team = 0 if p_is_player else 1
	facing_dir_key = initial_dir_key if PMDSpriteLoader.DIRECTIONS.has(initial_dir_key) else "s"
	facing_direction = PMDSpriteLoader.vector_from_direction(facing_dir_key)
	if is_node_ready():
		_apply_pokemon_visuals()
		_play_state_animation("idle", facing_dir_key, true)


func _apply_pokemon_visuals() -> void:
	if not animated_sprite_2d:
		animated_sprite_2d = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if not animated_sprite_2d:
		return
	var pmd_dir: String = pokemon_instance.get_pmd_sprite_dir() if pokemon_instance else species_id
	var frames: SpriteFrames = PMDSpriteLoader.build_sprite_frames(pmd_dir)
	if frames != null:
		animated_sprite_2d.sprite_frames = frames


func set_move_input(vec: Vector2) -> void:
	simulated_input_vector = vec
	if vec.length_squared() > 0.0001:
		facing_direction = vec.normalized()
		facing_dir_key = PMDSpriteLoader.direction_from_vector(facing_direction, facing_dir_key)


func clear_move_input() -> void:
	simulated_input_vector = Vector2.ZERO
	velocity = Vector2.ZERO


func set_facing_direction(vec_or_key: Variant) -> void:
	if vec_or_key is Vector2:
		var v: Vector2 = vec_or_key as Vector2
		if v.length_squared() > 0.0001:
			facing_direction = v.normalized()
			facing_dir_key = PMDSpriteLoader.direction_from_vector(facing_direction, facing_dir_key)
	elif vec_or_key is String:
		var k: String = (vec_or_key as String).to_lower()
		if PMDSpriteLoader.DIRECTIONS.has(k):
			facing_dir_key = k
			facing_direction = PMDSpriteLoader.vector_from_direction(k)
	if action_lock_timer <= 0.0:
		_play_state_animation(current_action, facing_dir_key)


func _get_input_vector() -> Vector2:
	if simulated_input_vector.length_squared() > 0.0001:
		return simulated_input_vector.normalized()
	if not is_player_controlled:
		return Vector2.ZERO
	
	var raw := Vector2.ZERO
	if Input.is_action_pressed("move_right") or Input.is_action_pressed("ui_right"):
		raw.x += 1.0
	if Input.is_action_pressed("move_left") or Input.is_action_pressed("ui_left"):
		raw.x -= 1.0
	if Input.is_action_pressed("move_down") or Input.is_action_pressed("ui_down"):
		raw.y += 1.0
	if Input.is_action_pressed("move_up") or Input.is_action_pressed("ui_up"):
		raw.y -= 1.0
	
	if raw.length_squared() > 0.0001:
		return raw.normalized()
	return Vector2.ZERO


func _physics_process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer = maxf(0.0, cooldown_timer - delta)
	if action_lock_timer > 0.0:
		action_lock_timer = maxf(0.0, action_lock_timer - delta)
	
	var move_vec: Vector2 = _get_input_vector()
	if move_vec.length_squared() > 0.0001:
		facing_direction = move_vec
		facing_dir_key = PMDSpriteLoader.direction_from_vector(facing_direction, facing_dir_key)
		velocity = facing_direction * base_move_speed
		move_and_slide()
		if action_lock_timer <= 0.0:
			_play_state_animation("walk", facing_dir_key)
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		if action_lock_timer <= 0.0:
			_play_state_animation("idle", facing_dir_key)
	
	if is_player_controlled and cooldown_timer <= 0.0:
		if Input.is_action_just_pressed("move_1") or Input.is_action_just_pressed("move_2"):
			fire_projectile()


func compute_attack_damage() -> int:
	if pokemon_instance == null:
		return 6
	var atk: int = maxi(1, pokemon_instance.attack)
	var lv: int = maxi(1, pokemon_instance.level)
	return maxi(2, int((2.0 * lv / 5.0 + 2.0) * 40.0 * (float(atk) / 10.0) / 50.0) + 2)


func fire_projectile(override_dir: Vector2 = Vector2.ZERO) -> Projectile:
	var fire_dir: Vector2 = facing_direction
	if override_dir.length_squared() > 0.0001:
		fire_dir = override_dir.normalized()
		facing_direction = fire_dir
		facing_dir_key = PMDSpriteLoader.direction_from_vector(fire_dir, facing_dir_key)
	else:
		fire_dir = PMDSpriteLoader.vector_from_direction(facing_dir_key)
	
	cooldown_timer = attack_cooldown
	action_lock_timer = 0.22
	_play_state_animation("attack", facing_dir_key, true)
	
	var proj: Projectile = PROJECTILE_SCENE.instantiate() as Projectile
	var dmg: int = compute_attack_damage()
	proj.setup(self, team, fire_dir, dmg, 210.0)
	proj.global_position = global_position + fire_dir * 10.0
	
	var container: Node = get_parent()
	if container != null and container.has_node("Projectiles"):
		container = container.get_node("Projectiles")
	if container != null:
		container.add_child(proj)
	
	projectile_fired.emit(proj, fire_dir)
	return proj


func receive_hit(raw_damage: int, knockback_dir: Vector2 = Vector2.ZERO) -> int:
	var def_val: int = pokemon_instance.defense if pokemon_instance != null else 10
	var final_damage: int = maxi(1, raw_damage - int(def_val * 0.15))
	var remaining_hp: int = 0
	var max_hp_val: int = 20
	if pokemon_instance != null:
		remaining_hp = pokemon_instance.take_damage(final_damage)
		max_hp_val = pokemon_instance.max_hp
	
	action_lock_timer = 0.24
	_play_state_animation("hurt", facing_dir_key, true)
	
	if knockback_dir.length_squared() > 0.0001:
		move_and_collide(knockback_dir.normalized() * 4.0)
	
	damaged.emit(final_damage, remaining_hp, max_hp_val)
	if pokemon_instance != null and pokemon_instance.is_fainted():
		fainted.emit(self)
	return remaining_hp


func get_current_animation_name() -> String:
	if animated_sprite_2d:
		return str(animated_sprite_2d.animation)
	return "%s_%s" % [current_action, facing_dir_key]


func _play_state_animation(action_name: String, dir_key: String, force_restart: bool = false) -> void:
	current_action = action_name
	facing_dir_key = dir_key
	var target_anim := StringName("%s_%s" % [action_name, dir_key])
	if animated_sprite_2d and animated_sprite_2d.sprite_frames:
		if animated_sprite_2d.sprite_frames.has_animation(target_anim):
			if force_restart or animated_sprite_2d.animation != target_anim or not animated_sprite_2d.is_playing():
				animated_sprite_2d.play(target_anim)
				action_state_changed.emit(action_name, dir_key)
