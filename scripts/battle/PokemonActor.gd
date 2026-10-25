class_name PokemonActor
extends CharacterBody2D

signal projectile_fired(projectile: Projectile, direction: Vector2)
signal damaged(amount: int, current_hp: int, max_hp: int)
signal fainted(actor: PokemonActor)
signal action_state_changed(action_name: String, dir_key: String)

signal move_used(slot_index: int, move_inst: MoveInstance, move_data: MoveData)
signal move_failed_no_pp(slot_index: int, move_name: String)
signal move_failed_cooldown(slot_index: int, remaining_cooldown: float)
signal pp_changed(slot_index: int, current_pp: int, max_pp: int)
signal stat_stage_changed(stat_name: String, new_stage: int, delta_stage: int)
signal hit_blocked_iframe(source_name: String)
signal battle_message_requested(message: String)
signal floating_text_spawned(text: String, color: Color)
signal ai_state_changed(new_state: int, old_state: int)
signal pokeball_aim_started(aim_direction: Vector2)
signal pokeball_aim_ended()
signal pokeball_thrown(ball: PokeballProjectile, direction: Vector2, ball_item_id: String)
signal enrage_state_changed(enraged: bool, speed_mult: float, cooldown_mult: float)
signal sprint_state_changed(sprinting: bool)

enum AIState {
	IDLE_WANDER = 0,
	CHASE = 1,
	ATTACK = 2,
}

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/battle/Projectile.tscn")
const POKEBALL_PROJECTILE_SCENE: PackedScene = preload("res://scenes/battle/PokeballProjectile.tscn")

@export var is_player_controlled: bool = false
@export var team: int = 0
@export var species_id: String = "cyndaquil"
@export var base_move_speed: float = 67.0
@export var sprint_speed_multiplier: float = 1.65
@export var double_tap_window: float = 0.28
@export var attack_cooldown: float = 0.20
@export var iframe_duration: float = 0.45

@export var ai_enabled: bool = false
@export var ai_detect_range: float = 320.0
@export var ai_attack_range: float = 44.0

var pokemon_instance: PokemonInstance = null
var facing_direction: Vector2 = Vector2(0, 1)
var facing_dir_key: String = "s"
var current_action: String = "idle"

var simulated_input_vector: Vector2 = Vector2.ZERO
var action_lock_timer: float = 0.0
var cooldown_timer: float = 0.0
var shared_cooldown: float = 0.0
var shared_cooldown_max: float = 1.2
var invincible_timer: float = 0.0
var slot_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]

var attack_stage: int = 0
var defense_stage: int = 0

var ai_state: int = AIState.IDLE_WANDER
var target_actor: PokemonActor = null
var ai_wander_timer: float = 0.0
var ai_wander_step: int = 0
var ai_wander_dir: Vector2 = Vector2.ZERO

var last_floating_text: String = ""
var floating_texts_history: Array[String] = []
var last_battle_message: String = ""

var is_aiming_pokeball: bool = false
var aim_reticle_node: Node2D = null
var selected_ball_id: String = "pokeball"

var is_enraged: bool = false
var enrage_timer: float = 0.0
var enrage_speed_multiplier: float = 1.0
var enrage_cooldown_multiplier: float = 1.0
var is_in_ball_capture: bool = false
var is_battle_paused: bool = false

var is_sprinting: bool = false
var _last_dir_tap_key: String = ""
var _last_dir_tap_timer: float = 0.0

var overhead_hud_node: Node2D = null
var overhead_hp_fill: ColorRect = null
var overhead_border_rect: ColorRect = null
var overhead_status_label: Label = null

@onready var shadow_poly: Polygon2D = $Shadow
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	
	if pokemon_instance == null:
		pokemon_instance = PokemonRegistry.create_instance(species_id, 5)
	else:
		pokemon_instance.ensure_move_instances()
	_reset_slot_cooldowns()
	_ensure_reticle_node()
	_ensure_overhead_hud()
	_apply_pokemon_visuals()
	_refresh_overhead_hud()
	_play_state_animation("idle", facing_dir_key, true)


func setup_from_instance(inst: PokemonInstance, p_is_player: bool = false, initial_dir_key: String = "s") -> void:
	if inst != null:
		pokemon_instance = inst
		pokemon_instance.ensure_move_instances()
		species_id = inst.get_species_id()
		base_move_speed = clampf((85.0 + float(inst.speed) * 1.5) * (2.0 / 3.0), 56.0, 100.0)
	is_player_controlled = p_is_player
	team = 0 if p_is_player else 1
	attack_stage = 0
	defense_stage = 0
	invincible_timer = 0.0
	is_aiming_pokeball = false
	is_in_ball_capture = false
	clear_enrage_state()
	_reset_slot_cooldowns()
	facing_dir_key = initial_dir_key if PMDSpriteLoader.DIRECTIONS.has(initial_dir_key) else "s"
	facing_direction = PMDSpriteLoader.vector_from_direction(facing_dir_key)
	_ensure_reticle_node()
	_update_reticle_visual()
	_ensure_overhead_hud()
	_refresh_overhead_hud()
	if is_node_ready():
		_apply_pokemon_visuals()
		_play_state_animation("idle", facing_dir_key, true)


func _reset_slot_cooldowns() -> void:
	slot_cooldowns = [0.0, 0.0, 0.0, 0.0]
	shared_cooldown = 0.0
	cooldown_timer = 0.0
	action_lock_timer = 0.0


func reset_cooldowns() -> void:
	_reset_slot_cooldowns()


func apply_shared_cooldown(duration: float = 1.0) -> void:
	var cd: float = maxf(0.0, duration)
	shared_cooldown_max = maxf(0.1, cd)
	shared_cooldown = cd
	cooldown_timer = cd
	for i in range(slot_cooldowns.size()):
		slot_cooldowns[i] = cd


func set_battle_paused(paused: bool) -> void:
	is_battle_paused = paused
	if paused:
		velocity = Vector2.ZERO
		set_sprinting(false)
		if action_lock_timer <= 0.0:
			_play_state_animation("idle", facing_dir_key)


func clear_invincibility() -> void:
	invincible_timer = 0.0
	if animated_sprite_2d:
		animated_sprite_2d.modulate.a = 1.0


func is_invincible() -> bool:
	return invincible_timer > 0.0


static func get_stage_multiplier(stage: int) -> float:
	var clamped: int = clampi(stage, -6, 6)
	if clamped >= 0:
		return float(2 + clamped) / 2.0
	return 2.0 / float(2 - clamped)


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
	if is_player_controlled and vec.length_squared() > 0.0001:
		for opp in _get_opposing_actors():
			if opp.ai_enabled:
				opp.set_ai_enabled(false)
	if vec.length_squared() > 0.0001:
		facing_direction = vec.normalized()
		facing_dir_key = PMDSpriteLoader.direction_from_vector(facing_direction, facing_dir_key)


func clear_move_input() -> void:
	simulated_input_vector = Vector2.ZERO
	velocity = Vector2.ZERO
	set_sprinting(false)


func register_direction_tap(dir_key: String) -> bool:
	var norm_key: String = dir_key.strip_edges().to_lower()
	if norm_key.is_empty():
		return false
	if norm_key == _last_dir_tap_key and _last_dir_tap_timer > 0.0:
		_last_dir_tap_timer = 0.0
		set_sprinting(true)
		return true
	_last_dir_tap_key = norm_key
	_last_dir_tap_timer = double_tap_window
	return false


func set_sprinting(enabled: bool) -> void:
	if is_sprinting == enabled:
		return
	is_sprinting = enabled
	if animated_sprite_2d:
		animated_sprite_2d.speed_scale = 1.55 if is_sprinting else 1.0
	if is_sprinting and is_inside_tree():
		_spawn_effect_polygon(
			global_position - facing_direction * 8.0,
			PackedVector2Array([Vector2(-4, -3), Vector2(4, 0), Vector2(-4, 3)]),
			Color(0.75, 0.95, 1.0, 0.8),
			facing_direction.angle(),
			0.16
		)
	sprint_state_changed.emit(is_sprinting)


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
	_update_reticle_visual()


func get_effective_move_speed() -> float:
	var mult: float = (enrage_speed_multiplier if is_enraged else 1.0) * (sprint_speed_multiplier if is_sprinting else 1.0)
	return base_move_speed * mult


func get_effective_cooldown_rate() -> float:
	return enrage_cooldown_multiplier if is_enraged else 1.0


func _ensure_reticle_node() -> void:
	if aim_reticle_node != null and is_instance_valid(aim_reticle_node):
		return
	aim_reticle_node = get_node_or_null("AimReticle") as Node2D
	if aim_reticle_node == null:
		aim_reticle_node = Node2D.new()
		aim_reticle_node.name = "AimReticle"
		aim_reticle_node.visible = false
		
		var line_poly := Polygon2D.new()
		line_poly.name = "AimLine"
		line_poly.color = Color(1.0, 0.9, 0.25, 0.85)
		line_poly.polygon = PackedVector2Array([
			Vector2(10, -1.5),
			Vector2(42, -1.5),
			Vector2(42, -5.0),
			Vector2(50, 0.0),
			Vector2(42, 5.0),
			Vector2(42, 1.5),
			Vector2(10, 1.5),
		])
		aim_reticle_node.add_child(line_poly)
		
		var target_ring := Polygon2D.new()
		target_ring.name = "TargetCrosshair"
		target_ring.position = Vector2(54, 0)
		target_ring.color = Color(1.0, 0.3, 0.25, 0.9)
		target_ring.polygon = PackedVector2Array([
			Vector2(-6, -2), Vector2(-2, -6), Vector2(2, -6), Vector2(6, -2),
			Vector2(6, 2), Vector2(2, 6), Vector2(-2, 6), Vector2(-6, 2)
		])
		aim_reticle_node.add_child(target_ring)
		add_child(aim_reticle_node)


func _update_reticle_visual() -> void:
	_ensure_reticle_node()
	if aim_reticle_node == null:
		return
	aim_reticle_node.visible = is_aiming_pokeball
	if facing_direction.length_squared() > 0.0001:
		aim_reticle_node.rotation = facing_direction.angle()


func _ensure_overhead_hud() -> void:
	if overhead_hud_node != null and is_instance_valid(overhead_hud_node):
		return
	overhead_hud_node = get_node_or_null("OverheadHUD") as Node2D
	if overhead_hud_node == null:
		overhead_hud_node = Node2D.new()
		overhead_hud_node.name = "OverheadHUD"
		overhead_hud_node.position = Vector2(0, -18)
		overhead_hud_node.z_index = 5
		
		overhead_border_rect = ColorRect.new()
		overhead_border_rect.name = "BorderBG"
		overhead_border_rect.position = Vector2(-13, -2)
		overhead_border_rect.size = Vector2(26, 4)
		overhead_border_rect.color = Color(0.08, 0.1, 0.14, 0.92)
		overhead_hud_node.add_child(overhead_border_rect)
		
		var inner_track := ColorRect.new()
		inner_track.name = "InnerTrack"
		inner_track.position = Vector2(-12, -1)
		inner_track.size = Vector2(24, 2)
		inner_track.color = Color(0.22, 0.25, 0.30, 0.95)
		overhead_hud_node.add_child(inner_track)
		
		overhead_hp_fill = ColorRect.new()
		overhead_hp_fill.name = "HPFill"
		overhead_hp_fill.position = Vector2(-12, -1)
		overhead_hp_fill.size = Vector2(24, 2)
		overhead_hp_fill.color = Color(0.22, 0.85, 0.35, 1.0)
		overhead_hud_node.add_child(overhead_hp_fill)
		
		overhead_status_label = Label.new()
		overhead_status_label.name = "StatusLabel"
		overhead_status_label.position = Vector2(-24, -12)
		overhead_status_label.size = Vector2(48, 10)
		overhead_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overhead_status_label.add_theme_font_size_override("font_size", 6)
		overhead_status_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35, 1.0))
		overhead_status_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.95))
		overhead_status_label.add_theme_constant_override("outline_size", 2)
		overhead_status_label.text = ""
		overhead_hud_node.add_child(overhead_status_label)
		
		add_child(overhead_hud_node)


func _refresh_overhead_hud() -> void:
	_ensure_overhead_hud()
	if overhead_hud_node == null:
		return
	overhead_hud_node.visible = not is_in_ball_capture
	if overhead_border_rect != null:
		overhead_border_rect.color = Color(0.18, 0.55, 0.78, 0.95) if is_player_controlled else Color(0.75, 0.32, 0.24, 0.95)
	if pokemon_instance != null and overhead_hp_fill != null:
		var max_hp_f: float = float(maxi(1, pokemon_instance.max_hp))
		var ratio: float = clampf(float(pokemon_instance.current_hp) / max_hp_f, 0.0, 1.0)
		overhead_hp_fill.size.x = round(24.0 * ratio)
		if ratio > 0.5:
			overhead_hp_fill.color = Color(0.22, 0.85, 0.35, 1.0)
		elif ratio > 0.2:
			overhead_hp_fill.color = Color(0.96, 0.75, 0.18, 1.0)
		else:
			overhead_hp_fill.color = Color(0.92, 0.25, 0.22, 1.0)
	if overhead_status_label != null:
		var tags: PackedStringArray = PackedStringArray()
		if is_enraged:
			tags.append("분노!")
		if defense_stage < 0:
			tags.append("방어%d" % defense_stage)
		if attack_stage < 0:
			tags.append("공격%d" % attack_stage)
		overhead_status_label.text = " ".join(tags)
		if is_enraged:
			overhead_status_label.add_theme_color_override("font_color", Color(1.0, 0.38, 0.32, 1.0))
		else:
			overhead_status_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35, 1.0))


func start_aiming_pokeball(aim_dir: Vector2 = Vector2.ZERO) -> void:
	if is_in_ball_capture:
		return
	if aim_dir.length_squared() > 0.0001:
		facing_direction = aim_dir.normalized()
		facing_dir_key = PMDSpriteLoader.direction_from_vector(facing_direction, facing_dir_key)
	is_aiming_pokeball = true
	velocity = Vector2.ZERO
	_play_state_animation("idle", facing_dir_key)
	_update_reticle_visual()
	pokeball_aim_started.emit(facing_direction)


func stop_aiming_pokeball() -> void:
	if not is_aiming_pokeball:
		return
	is_aiming_pokeball = false
	_update_reticle_visual()
	pokeball_aim_ended.emit()


func release_pokeball(ball_item_id: String = "") -> PokeballProjectile:
	var item_to_use: String = ball_item_id if not ball_item_id.is_empty() else selected_ball_id
	stop_aiming_pokeball()
	return throw_pokeball_at(facing_direction, item_to_use)


func throw_pokeball_at(
	dir: Vector2 = Vector2.ZERO,
	ball_item_id: String = "pokeball",
	forced_outcome: int = -1,
	rng: RandomNumberGenerator = null
) -> PokeballProjectile:
	var parent_arena: Node = get_parent()
	if parent_arena != null and parent_arena.has_method("throw_pokeball_from_actor"):
		return parent_arena.throw_pokeball_from_actor(self, dir, ball_item_id, forced_outcome, rng)
	
	var fire_dir: Vector2 = facing_direction
	if dir.length_squared() > 0.0001:
		fire_dir = dir.normalized()
		facing_direction = fire_dir
		facing_dir_key = PMDSpriteLoader.direction_from_vector(fire_dir, facing_dir_key)
	
	is_aiming_pokeball = false
	_update_reticle_visual()
	
	var ball: PokeballProjectile = POKEBALL_PROJECTILE_SCENE.instantiate() as PokeballProjectile
	ball.forced_catch_outcome = forced_outcome
	ball.custom_rng = rng
	ball.setup(self, team, fire_dir, ball_item_id)
	ball.global_position = global_position + fire_dir * 10.0
	
	var container: Node = get_parent()
	if container != null and container.has_node("Projectiles"):
		container = container.get_node("Projectiles")
	if container != null:
		container.add_child(ball)
	
	pokeball_thrown.emit(ball, fire_dir, ball.ball_item_id)
	return ball


func set_captured_in_ball_visual(in_ball: bool) -> void:
	is_in_ball_capture = in_ball
	if in_ball:
		velocity = Vector2.ZERO
		simulated_input_vector = Vector2.ZERO
	if animated_sprite_2d:
		animated_sprite_2d.visible = not in_ball
	if shadow_poly:
		shadow_poly.visible = not in_ball
	if collision_shape_2d:
		collision_shape_2d.set_deferred("disabled", in_ball)
	_refresh_overhead_hud()


func enter_enrage_state(duration: float = 6.0, speed_mult: float = 1.45, cooldown_mult: float = 1.75) -> void:
	is_enraged = true
	enrage_timer = maxf(0.5, duration)
	enrage_speed_multiplier = maxf(1.1, speed_mult)
	enrage_cooldown_multiplier = maxf(1.1, cooldown_mult)
	if animated_sprite_2d:
		animated_sprite_2d.modulate = Color(1.0, 0.55, 0.55, animated_sprite_2d.modulate.a)
	var mon_name: String = pokemon_instance.get_display_name() if pokemon_instance != null else "포켓몬"
	var msg: String = "야생 %s이(가) 분노하여 공격 속도가 빨라졌다!" % mon_name
	last_battle_message = msg
	_refresh_overhead_hud()
	_spawn_floating_text("분노!", Color(1.0, 0.3, 0.2))
	enrage_state_changed.emit(true, enrage_speed_multiplier, enrage_cooldown_multiplier)
	battle_message_requested.emit(msg)


func clear_enrage_state() -> void:
	var was_enraged: bool = is_enraged
	is_enraged = false
	enrage_timer = 0.0
	enrage_speed_multiplier = 1.0
	enrage_cooldown_multiplier = 1.0
	if animated_sprite_2d:
		animated_sprite_2d.modulate = Color(1.0, 1.0, 1.0, 1.0 if invincible_timer <= 0.0 else animated_sprite_2d.modulate.a)
	_refresh_overhead_hud()
	if was_enraged:
		enrage_state_changed.emit(false, 1.0, 1.0)


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
	if is_in_ball_capture or is_battle_paused:
		velocity = Vector2.ZERO
		return
	
	if is_enraged:
		enrage_timer = maxf(0.0, enrage_timer - delta)
		if enrage_timer <= 0.0:
			clear_enrage_state()
	
	var cd_delta: float = delta * get_effective_cooldown_rate()
	if shared_cooldown > 0.0:
		shared_cooldown = maxf(0.0, shared_cooldown - cd_delta)
	if cooldown_timer > 0.0:
		cooldown_timer = maxf(0.0, cooldown_timer - cd_delta)
	if action_lock_timer > 0.0:
		action_lock_timer = maxf(0.0, action_lock_timer - delta)
	for i in range(slot_cooldowns.size()):
		if slot_cooldowns[i] > 0.0:
			slot_cooldowns[i] = maxf(0.0, slot_cooldowns[i] - cd_delta)
	
	if invincible_timer > 0.0:
		invincible_timer = maxf(0.0, invincible_timer - delta)
		if animated_sprite_2d:
			var blink_on: bool = (int(invincible_timer * 24.0) % 2) == 0
			animated_sprite_2d.modulate.a = 0.45 if blink_on else 1.0
		if invincible_timer <= 0.0 and animated_sprite_2d:
			animated_sprite_2d.modulate.a = 1.0
	
	if _last_dir_tap_timer > 0.0:
		_last_dir_tap_timer = maxf(0.0, _last_dir_tap_timer - delta)
	
	if is_player_controlled:
		if Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("ui_right"):
			register_direction_tap("right")
		if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("ui_left"):
			register_direction_tap("left")
		if Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("ui_down"):
			register_direction_tap("down")
		if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("ui_up"):
			register_direction_tap("up")
		
		if Input.is_action_just_pressed("throw_ball"):
			selected_ball_id = "pokeball"
			start_aiming_pokeball()
		elif Input.is_action_just_released("throw_ball") and is_aiming_pokeball:
			release_pokeball("pokeball")
	
	if is_aiming_pokeball:
		set_sprinting(false)
		var aim_vec: Vector2 = _get_input_vector()
		if aim_vec.length_squared() > 0.0001:
			facing_direction = aim_vec
			facing_dir_key = PMDSpriteLoader.direction_from_vector(facing_direction, facing_dir_key)
		velocity = Vector2.ZERO
		move_and_slide()
		if action_lock_timer <= 0.0:
			_play_state_animation("idle", facing_dir_key)
		_update_reticle_visual()
		return
	
	if not is_player_controlled and ai_enabled:
		_update_ai(delta)
	
	var move_vec: Vector2 = _get_input_vector()
	if move_vec.length_squared() > 0.0001:
		facing_direction = move_vec
		facing_dir_key = PMDSpriteLoader.direction_from_vector(facing_direction, facing_dir_key)
		velocity = facing_direction * get_effective_move_speed()
		move_and_slide()
		if action_lock_timer <= 0.0:
			_play_state_animation("walk", facing_dir_key)
	else:
		if is_sprinting:
			set_sprinting(false)
		velocity = Vector2.ZERO
		move_and_slide()
		if action_lock_timer <= 0.0:
			_play_state_animation("idle", facing_dir_key)
	_update_reticle_visual()
	
	if is_player_controlled:
		if Input.is_action_just_pressed("move_1"):
			use_move(0)
		elif Input.is_action_just_pressed("move_2"):
			use_move(1)
		elif Input.is_action_just_pressed("move_3"):
			use_move(2)
		elif Input.is_action_just_pressed("move_4"):
			use_move(3)


func get_slot_cooldown(slot_index: int) -> float:
	if slot_index < 0 or slot_index >= slot_cooldowns.size():
		return shared_cooldown
	return maxf(shared_cooldown, slot_cooldowns[slot_index])


func use_move(slot_index: int, override_dir: Vector2 = Vector2.ZERO) -> bool:
	if pokemon_instance == null:
		return false
	pokemon_instance.ensure_move_instances()
	var move_inst: MoveInstance = pokemon_instance.get_move_instance(slot_index)
	if move_inst == null or move_inst.move_data == null:
		return false
	
	var mdata: MoveData = move_inst.move_data
	if not move_inst.can_use():
		var no_pp_msg: String = "PP가 부족하여 %s 기술을 쓸 수 없다!" % mdata.display_name
		last_battle_message = no_pp_msg
		move_failed_no_pp.emit(slot_index, mdata.display_name)
		battle_message_requested.emit(no_pp_msg)
		_spawn_floating_text("PP 부족!", Color(1.0, 0.35, 0.35))
		return false
	
	if shared_cooldown > 0.0:
		move_failed_cooldown.emit(slot_index, shared_cooldown)
		return false
	if slot_index >= 0 and slot_index < slot_cooldowns.size() and slot_cooldowns[slot_index] > 0.0:
		move_failed_cooldown.emit(slot_index, slot_cooldowns[slot_index])
		return false
	if cooldown_timer > 0.0:
		move_failed_cooldown.emit(slot_index, cooldown_timer)
		return false
	
	var fire_dir: Vector2 = facing_direction
	if override_dir.length_squared() > 0.0001:
		fire_dir = override_dir.normalized()
		facing_direction = fire_dir
		facing_dir_key = PMDSpriteLoader.direction_from_vector(fire_dir, facing_dir_key)
	else:
		fire_dir = PMDSpriteLoader.vector_from_direction(facing_dir_key)
	
	# Deduct PP immediately on cast
	move_inst.consume_pp(1)
	pokemon_instance.sync_moves_array()
	
	var cd_dur: float = maxf(0.1, mdata.cooldown)
	shared_cooldown_max = cd_dur
	shared_cooldown = cd_dur
	cooldown_timer = cd_dur
	for i in range(slot_cooldowns.size()):
		slot_cooldowns[i] = cd_dur
	action_lock_timer = 0.22
	_play_state_animation("attack", facing_dir_key, true)
	
	var cast_msg: String = "%s의 %s!" % [pokemon_instance.get_display_name(), mdata.display_name]
	last_battle_message = cast_msg
	pp_changed.emit(slot_index, move_inst.current_pp, move_inst.max_pp)
	move_used.emit(slot_index, move_inst, mdata)
	battle_message_requested.emit(cast_msg)
	
	match mdata.pattern:
		MoveData.Pattern.MELEE_LUNGE:
			_execute_melee_lunge(mdata, fire_dir)
		MoveData.Pattern.PROJECTILE:
			_execute_projectile_move(mdata, fire_dir)
		MoveData.Pattern.DEBUFF_WAVE:
			_execute_debuff_wave(mdata, fire_dir)
		MoveData.Pattern.QUICK_DASH:
			_execute_quick_dash(mdata, fire_dir)
		_:
			_execute_melee_lunge(mdata, fire_dir)
	
	return true


func _execute_melee_lunge(mdata: MoveData, fire_dir: Vector2) -> void:
	var lunge_dist: float = maxf(8.0, mdata.dash_distance)
	move_and_collide(fire_dir * lunge_dist)
	_spawn_effect_polygon(
		global_position + fire_dir * 12.0,
		PackedVector2Array([Vector2(-8, -8), Vector2(10, 0), Vector2(-8, 8)]),
		mdata.tint_color,
		fire_dir.angle(),
		0.15
	)
	var hit_radius: float = maxf(20.0, mdata.range_px)
	var hit_center: Vector2 = global_position + fire_dir * 12.0
	for enemy in _get_opposing_actors():
		if enemy.global_position.distance_to(hit_center) <= hit_radius or enemy.global_position.distance_to(global_position) <= hit_radius + 8.0:
			enemy.receive_move_hit(self, mdata, fire_dir)


func _execute_projectile_move(mdata: MoveData, fire_dir: Vector2) -> Projectile:
	var proj: Projectile = PROJECTILE_SCENE.instantiate() as Projectile
	var base_dmg: int = compute_move_damage(mdata, null)
	var p_speed: float = mdata.projectile_speed if mdata.projectile_speed > 10.0 else 210.0
	proj.setup(self, team, fire_dir, base_dmg, p_speed, mdata)
	proj.global_position = global_position + fire_dir * 10.0
	
	var container: Node = get_parent()
	if container != null and container.has_node("Projectiles"):
		container = container.get_node("Projectiles")
	if container != null:
		container.add_child(proj)
	
	projectile_fired.emit(proj, fire_dir)
	return proj


func _execute_debuff_wave(mdata: MoveData, fire_dir: Vector2) -> void:
	var wave_range: float = maxf(36.0, mdata.range_px)
	_spawn_effect_polygon(
		global_position + fire_dir * 16.0,
		PackedVector2Array([Vector2(0, -14), Vector2(22, -20), Vector2(28, 0), Vector2(22, 20), Vector2(0, 14)]),
		mdata.tint_color,
		fire_dir.angle(),
		0.22
	)
	var stat_to_lower: String = mdata.debuff_stat if not mdata.debuff_stat.is_empty() else "defense"
	var stages: int = maxi(1, abs(mdata.debuff_stages))
	for enemy in _get_opposing_actors():
		var dist: float = enemy.global_position.distance_to(global_position)
		if dist <= wave_range + 16.0:
			enemy.apply_stat_debuff(stat_to_lower, stages, self)


func _execute_quick_dash(mdata: MoveData, fire_dir: Vector2) -> void:
	var start_pos: Vector2 = global_position
	var dash_dist: float = maxf(28.0, mdata.dash_distance)
	move_and_collide(fire_dir * dash_dist)
	var end_pos: Vector2 = global_position
	
	_spawn_effect_polygon(
		(start_pos + end_pos) * 0.5,
		PackedVector2Array([Vector2(-dash_dist * 0.5, -5), Vector2(dash_dist * 0.5, -2), Vector2(dash_dist * 0.5, 2), Vector2(-dash_dist * 0.5, 5)]),
		mdata.tint_color,
		fire_dir.angle(),
		0.18
	)
	
	var sweep_radius: float = maxf(24.0, mdata.range_px * 0.6)
	for enemy in _get_opposing_actors():
		var closest_pt: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, start_pos, end_pos)
		if enemy.global_position.distance_to(closest_pt) <= sweep_radius or enemy.global_position.distance_to(end_pos) <= mdata.range_px:
			enemy.receive_move_hit(self, mdata, fire_dir)


func _get_opposing_actors() -> Array[PokemonActor]:
	var result: Array[PokemonActor] = []
	var parent_node: Node = get_parent()
	if parent_node == null:
		return result
	for child in parent_node.get_children():
		if child is PokemonActor and child != self:
			var other: PokemonActor = child as PokemonActor
			if other.team != team:
				result.append(other)
	return result


func compute_attack_damage() -> int:
	if pokemon_instance == null:
		return 6
	var atk: float = float(maxi(1, pokemon_instance.attack)) * get_stage_multiplier(attack_stage)
	var lv: int = maxi(1, pokemon_instance.level)
	return maxi(2, int((2.0 * lv / 5.0 + 2.0) * 40.0 * (atk / 10.0) / 50.0) + 2)


func compute_move_damage(mdata: MoveData, defender: PokemonActor = null) -> int:
	if mdata == null or mdata.power <= 0:
		return 0
	var lv: int = pokemon_instance.level if pokemon_instance != null else 5
	var eff_atk: float = float(pokemon_instance.attack if pokemon_instance != null else 11) * get_stage_multiplier(attack_stage)
	var eff_def: float = 10.0
	if defender != null:
		var raw_def: float = float(defender.pokemon_instance.defense if defender.pokemon_instance != null else 10)
		eff_def = maxf(1.0, raw_def * get_stage_multiplier(defender.defense_stage))
	
	var stab: float = 1.0
	if pokemon_instance != null and pokemon_instance.data != null:
		var m_type: String = mdata.move_type.strip_edges().to_upper()
		var p_type: String = pokemon_instance.data.primary_type.strip_edges().to_upper()
		var s_type: String = pokemon_instance.data.secondary_type.strip_edges().to_upper()
		if not m_type.is_empty() and (m_type == p_type or m_type == s_type):
			stab = 1.5
	
	var type_mult: float = 1.0
	if defender != null and defender.pokemon_instance != null and defender.pokemon_instance.data != null:
		type_mult = MoveRegistry.get_type_effectiveness(
			mdata.move_type,
			defender.pokemon_instance.data.primary_type,
			defender.pokemon_instance.data.secondary_type
		)
	
	var raw_damage: float = (((2.0 * float(lv) / 5.0 + 2.0) * float(mdata.power) * (eff_atk / eff_def)) / 18.0 + 2.0) * stab * type_mult
	return maxi(1, int(round(raw_damage)))


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


func apply_stat_debuff(stat_name: String, stages: int = 1, _source: PokemonActor = null) -> int:
	var amount: int = maxi(1, abs(stages))
	var key: String = stat_name.strip_edges().to_lower()
	var new_stage: int = 0
	var label_kor: String = "방어력"
	if key == "attack" or key == "atk":
		attack_stage = clampi(attack_stage - amount, -6, 6)
		new_stage = attack_stage
		label_kor = "공격력"
	else:
		defense_stage = clampi(defense_stage - amount, -6, 6)
		new_stage = defense_stage
		label_kor = "방어력"
	
	var float_msg: String = "%s 감소!" % label_kor
	_refresh_overhead_hud()
	_spawn_floating_text(float_msg, Color(0.95, 0.8, 0.25))
	var b_msg: String = "%s의 %s이(가) 떨어졌다!" % [
		pokemon_instance.get_display_name() if pokemon_instance else "포켓몬",
		label_kor
	]
	last_battle_message = b_msg
	stat_stage_changed.emit(key if not key.is_empty() else "defense", new_stage, -amount)
	battle_message_requested.emit(b_msg)
	return new_stage


func receive_move_hit(attacker: PokemonActor, mdata: MoveData, knockback_dir: Vector2 = Vector2.ZERO) -> int:
	if is_invincible():
		hit_blocked_iframe.emit(mdata.display_name if mdata else "move")
		_spawn_floating_text("무적!", Color(0.7, 0.85, 1.0))
		return 0
	
	var final_damage: int = 1
	if attacker != null and mdata != null:
		final_damage = attacker.compute_move_damage(mdata, self)
	elif mdata != null:
		final_damage = maxi(1, int(mdata.power * 0.25))
	
	_apply_damage_and_iframe(final_damage, knockback_dir)
	return final_damage


func receive_hit(raw_damage: int, knockback_dir: Vector2 = Vector2.ZERO) -> int:
	if is_invincible():
		hit_blocked_iframe.emit("hit")
		_spawn_floating_text("무적!", Color(0.7, 0.85, 1.0))
		return pokemon_instance.current_hp if pokemon_instance != null else 0
	
	var def_val: float = float(pokemon_instance.defense if pokemon_instance != null else 10) * get_stage_multiplier(defense_stage)
	var final_damage: int = maxi(1, raw_damage - int(def_val * 0.15))
	return _apply_damage_and_iframe(final_damage, knockback_dir)


func _apply_damage_and_iframe(final_damage: int, knockback_dir: Vector2 = Vector2.ZERO) -> int:
	var remaining_hp: int = 0
	var max_hp_val: int = 20
	if pokemon_instance != null:
		remaining_hp = pokemon_instance.take_damage(final_damage)
		max_hp_val = pokemon_instance.max_hp
	
	invincible_timer = iframe_duration
	action_lock_timer = 0.24
	_play_state_animation("hurt", facing_dir_key, true)
	
	if knockback_dir.length_squared() > 0.0001:
		move_and_collide(knockback_dir.normalized() * 4.0)
	
	_refresh_overhead_hud()
	_spawn_floating_text("-%d" % final_damage, Color(1.0, 0.3, 0.25))
	damaged.emit(final_damage, remaining_hp, max_hp_val)
	if pokemon_instance != null and pokemon_instance.is_fainted():
		fainted.emit(self)
	return remaining_hp


func play_heal_visual(healed_amount: int) -> void:
	_refresh_overhead_hud()
	_spawn_floating_text("+%d HP" % maxi(0, healed_amount), Color(0.28, 0.96, 0.42))
	_spawn_effect_polygon(
		global_position,
		PackedVector2Array([
			Vector2(0, -14), Vector2(10, -8), Vector2(14, 0), Vector2(10, 8),
			Vector2(0, 14), Vector2(-10, 8), Vector2(-14, 0), Vector2(-10, -8)
		]),
		Color(0.32, 0.96, 0.48, 0.85),
		0.0,
		0.24
	)


func _spawn_floating_text(text: String, color: Color = Color(1, 1, 1, 1)) -> Node2D:
	last_floating_text = text
	floating_texts_history.append(text)
	floating_text_spawned.emit(text, color)
	
	var holder := Node2D.new()
	holder.name = "FloatingText"
	holder.global_position = global_position + Vector2(0, -16)
	
	var lbl := Label.new()
	lbl.name = "Label"
	lbl.text = text
	lbl.position = Vector2(-28, -8)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 2)
	holder.add_child(lbl)
	
	var parent_node: Node = get_parent()
	if parent_node != null:
		parent_node.add_child(holder)
		var tw: Tween = holder.create_tween()
		tw.tween_property(holder, "position:y", holder.position.y - 14.0, 0.45)
		tw.parallel().tween_property(holder, "modulate:a", 0.0, 0.45)
		tw.tween_callback(holder.queue_free)
	return holder


func _spawn_effect_polygon(pos: Vector2, points: PackedVector2Array, color: Color, rot: float, duration: float = 0.18) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var poly := Polygon2D.new()
	poly.name = "MoveEffect"
	poly.global_position = pos
	poly.rotation = rot
	poly.polygon = points
	poly.color = Color(color.r, color.g, color.b, 0.75)
	parent_node.add_child(poly)
	var tw: Tween = poly.create_tween()
	tw.tween_property(poly, "modulate:a", 0.0, duration)
	tw.tween_callback(poly.queue_free)


# -------------------------------------------------------------------------
# Enemy Wild Pokemon FSM AI (IDLE_WANDER -> CHASE -> ATTACK)
# -------------------------------------------------------------------------

func set_ai_enabled(enabled: bool, p_target: PokemonActor = null) -> void:
	ai_enabled = enabled
	if p_target != null:
		target_actor = p_target
	if not enabled:
		simulated_input_vector = Vector2.ZERO


func set_ai_state(new_state: int) -> void:
	if ai_state == new_state:
		return
	var prev: int = ai_state
	ai_state = new_state
	ai_state_changed.emit(ai_state, prev)


func get_ai_state_name() -> String:
	match ai_state:
		AIState.IDLE_WANDER:
			return "IDLE_WANDER"
		AIState.CHASE:
			return "CHASE"
		AIState.ATTACK:
			return "ATTACK"
	return "UNKNOWN"


func step_ai(delta: float) -> void:
	_update_ai(delta)


func _find_target_actor() -> PokemonActor:
	if target_actor != null and is_instance_valid(target_actor):
		return target_actor
	var opponents: Array[PokemonActor] = _get_opposing_actors()
	if not opponents.is_empty():
		target_actor = opponents[0]
		return target_actor
	return null


func _pick_ready_ai_move_slot(dist_to_target: float) -> int:
	if pokemon_instance == null:
		return -1
	pokemon_instance.ensure_move_instances()
	var count: int = pokemon_instance.get_move_count()
	var in_range_slots: Array[int] = []
	var any_ready_slots: Array[int] = []
	for i in range(count):
		var m_inst: MoveInstance = pokemon_instance.get_move_instance(i)
		if m_inst == null or not m_inst.can_use():
			continue
		if i < slot_cooldowns.size() and slot_cooldowns[i] > 0.0:
			continue
		any_ready_slots.append(i)
		if m_inst.move_data != null and dist_to_target <= maxf(ai_attack_range, m_inst.move_data.range_px):
			in_range_slots.append(i)
	if not in_range_slots.is_empty():
		return in_range_slots[0]
	if not any_ready_slots.is_empty():
		return any_ready_slots[0]
	return -1


func _update_ai(delta: float) -> void:
	if pokemon_instance != null and pokemon_instance.is_fainted():
		simulated_input_vector = Vector2.ZERO
		return
	
	var tgt: PokemonActor = _find_target_actor()
	var dist: float = 99999.0
	var to_target: Vector2 = Vector2.ZERO
	if tgt != null and (tgt.pokemon_instance == null or not tgt.pokemon_instance.is_fainted()):
		to_target = tgt.global_position - global_position
		dist = to_target.length()
	
	match ai_state:
		AIState.IDLE_WANDER:
			if tgt != null and dist <= ai_detect_range:
				simulated_input_vector = Vector2.ZERO
				set_ai_state(AIState.CHASE)
				return
			ai_wander_timer -= delta
			if ai_wander_timer <= 0.0:
				ai_wander_timer = 0.6
				var dirs: Array[Vector2] = [
					Vector2.LEFT,
					Vector2.ZERO,
					Vector2.RIGHT,
					Vector2.ZERO,
					Vector2.DOWN,
					Vector2.UP,
				]
				ai_wander_dir = dirs[ai_wander_step % dirs.size()]
				ai_wander_step += 1
			simulated_input_vector = ai_wander_dir
		
		AIState.CHASE:
			if tgt == null or dist > ai_detect_range * 1.25:
				simulated_input_vector = Vector2.ZERO
				set_ai_state(AIState.IDLE_WANDER)
				return
			if dist <= ai_attack_range:
				simulated_input_vector = Vector2.ZERO
				set_ai_state(AIState.ATTACK)
				return
			simulated_input_vector = to_target.normalized()
		
		AIState.ATTACK:
			simulated_input_vector = Vector2.ZERO
			if tgt == null:
				set_ai_state(AIState.IDLE_WANDER)
				return
			if dist > ai_attack_range * 1.25:
				set_ai_state(AIState.CHASE)
				return
			var fire_dir: Vector2 = to_target.normalized() if to_target.length_squared() > 0.0001 else facing_direction
			set_facing_direction(fire_dir)
			if cooldown_timer <= 0.0:
				var slot_to_use: int = _pick_ready_ai_move_slot(dist)
				if slot_to_use >= 0:
					use_move(slot_to_use, fire_dir)


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
