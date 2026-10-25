class_name Player
extends CharacterBody2D

signal step_started(from_pos: Vector2, to_pos: Vector2, direction: Vector2)
signal step_completed(current_pos: Vector2, direction: Vector2)
signal step_blocked(at_pos: Vector2, direction: Vector2)
signal ledge_jump_started(from_pos: Vector2, to_pos: Vector2, direction: Vector2)
signal ledge_jump_completed(current_pos: Vector2, direction: Vector2)
signal interacted_with(target: Node)
signal sprint_state_changed(sprinting: bool)

const TILE_SIZE: int = 16

@export var map_root: Node2D
@export var movement_duration: float = 0.16
@export var sprint_duration_multiplier: float = 0.55
@export var double_tap_window: float = 0.28
@export var jump_duration: float = 0.30
@export var jump_height: float = 10.0
@export var require_turn_before_move: bool = false

var ground: TileMapLayer
var upper_ground: TileMapLayer
var movement_tween: Tween
var inventory: Inventory
var party: Array[PokemonInstance] = []

var is_moving: bool = false
var is_jumping: bool = false
var is_sprinting: bool = false
var input_enabled: bool = true
var _last_dir_tap_key: String = ""
var _last_dir_tap_timer: float = 0.0

var input_vector: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.DOWN
var input_stack: Array[String] = []
var queued_direction: Vector2 = Vector2.ZERO

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_ray: RayCast2D = $CollisionRayCast2D
@onready var ledge_ray: RayCast2D = $LedgeRayCast2D


func _get_scene_manager() -> Node:
	return get_node_or_null("/root/SceneManager")


func _get_dialogue_manager() -> Node:
	return get_node_or_null("/root/DialogueManager")


func _ready() -> void:
	var sm: Node = _get_scene_manager()
	if inventory == null:
		if sm and sm.get("player_inventory") != null:
			inventory = sm.get("player_inventory")
		else:
			inventory = Inventory.new()
			inventory.populate_starter_items()
	if party.is_empty():
		if sm and sm.has_method("ensure_default_party"):
			sm.ensure_default_party()
			party = sm.get("party")
		else:
			party.append(PokemonRegistry.create_instance("cyndaquil", 5, "브케인"))
	_resolve_map_layers()
	snap_to_grid()
	if sm and sm.get("has_pending_spawn"):
		teleport_to(sm.get("pending_spawn_position"), sm.get("pending_facing_direction"))
		sm.set("has_pending_spawn", false)
	else:
		set_animation(facing_direction, "_idle")


func _resolve_map_layers() -> void:
	if not map_root:
		map_root = get_parent() if get_parent() is Node2D else null
	if map_root:
		ground = map_root.get_node_or_null("Ground") as TileMapLayer
		upper_ground = map_root.get_node_or_null("UpperGround") as TileMapLayer
		if not ground and map_root.get_child_count() > 0:
			for child in map_root.get_children():
				if child is TileMapLayer:
					if not ground:
						ground = child
					elif not upper_ground:
						upper_ground = child
						break


func _physics_process(delta: float) -> void:
	if _last_dir_tap_timer > 0.0:
		_last_dir_tap_timer = maxf(0.0, _last_dir_tap_timer - delta)
	
	var sm: Node = _get_scene_manager()
	if not input_enabled or (sm and sm.get("is_transitioning")):
		return
	
	update_input_stack()
	input_vector = _get_stack_direction()
	
	if is_moving or is_jumping:
		if input_vector != Vector2.ZERO:
			queued_direction = input_vector
		return
	
	var dir_to_process: Vector2 = input_vector
	if dir_to_process == Vector2.ZERO and queued_direction != Vector2.ZERO:
		dir_to_process = queued_direction
		queued_direction = Vector2.ZERO
	
	if dir_to_process != Vector2.ZERO:
		try_to_move(dir_to_process)
	else:
		if is_sprinting and input_stack.is_empty():
			set_sprinting(false)
		set_animation(facing_direction, "_idle")


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
		animated_sprite_2d.speed_scale = 1.65 if is_sprinting else 1.0
	sprint_state_changed.emit(is_sprinting)


func get_effective_movement_duration() -> float:
	return movement_duration * (sprint_duration_multiplier if is_sprinting else 1.0)


func update_input_stack() -> void:
	var just_pressed: Dictionary = {
		"up": Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("ui_up"),
		"down": Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("ui_down"),
		"left": Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("ui_left"),
		"right": Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("ui_right"),
	}
	for jp_key in just_pressed.keys():
		if just_pressed[jp_key]:
			register_direction_tap(jp_key)
	
	var directions: Dictionary = {
		"up": Input.is_action_pressed("move_up") or Input.is_action_pressed("ui_up"),
		"down": Input.is_action_pressed("move_down") or Input.is_action_pressed("ui_down"),
		"left": Input.is_action_pressed("move_left") or Input.is_action_pressed("ui_left"),
		"right": Input.is_action_pressed("move_right") or Input.is_action_pressed("ui_right"),
	}
	
	for key in input_stack.duplicate():
		if not directions.get(key, false):
			input_stack.erase(key)
	
	for key in directions.keys():
		if directions[key] and not input_stack.has(key):
			input_stack.append(key)


func _get_stack_direction() -> Vector2:
	if input_stack.is_empty():
		return Vector2.ZERO
	match input_stack[-1]:
		"up": return Vector2.UP
		"down": return Vector2.DOWN
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
	return Vector2.ZERO


func snap_to_grid() -> void:
	position = Vector2(
		floorf((position.x + 0.01) / float(TILE_SIZE)) * TILE_SIZE,
		floorf((position.y + 0.01) / float(TILE_SIZE)) * TILE_SIZE
	)


func teleport_to(target_pos: Vector2, new_facing: Vector2 = Vector2.ZERO) -> void:
	if movement_tween and movement_tween.is_valid():
		movement_tween.kill()
	is_moving = false
	is_jumping = false
	queued_direction = Vector2.ZERO
	input_stack.clear()
	position = Vector2(
		floorf((target_pos.x + 0.01) / float(TILE_SIZE)) * TILE_SIZE,
		floorf((target_pos.y + 0.01) / float(TILE_SIZE)) * TILE_SIZE
	)
	if animated_sprite_2d:
		animated_sprite_2d.position = Vector2(8, 0)
	if new_facing != Vector2.ZERO:
		facing_direction = new_facing
	set_animation(facing_direction, "_idle")


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		input_stack.clear()
		queued_direction = Vector2.ZERO


## Attempts a 16x16 grid step or a 32px ledge jump in `direction`.
## Returns true if movement/jump started, false if blocked or turned in place.
func try_to_move(direction: Vector2) -> bool:
	if is_moving or is_jumping:
		queued_direction = direction
		return false
	
	direction = direction.normalized()
	if require_turn_before_move and facing_direction != direction:
		facing_direction = direction
		set_animation(facing_direction, "_idle")
		return false
	
	facing_direction = direction
	
	# 1. Check Ledge RayCast2D first
	var ledge: LedgeArea = _check_ledge_at(direction)
	if ledge != null:
		if ledge.jump_direction.normalized() == direction:
			var landing_pos: Vector2 = position + direction * (TILE_SIZE * 2)
			if not _is_tile_blocked_at_offset(direction * (TILE_SIZE * 2)):
				jump_tween(landing_pos, direction)
				return true
		# Ledge approached from forbidden direction (e.g. bottom-to-top) or landing blocked
		set_animation(facing_direction, "_idle")
		step_blocked.emit(position, direction)
		return false
	
	# 2. Check obstacle via RayCast2D & UpperGround tilemap data
	if _is_tile_blocked_at_offset(direction * TILE_SIZE):
		set_animation(facing_direction, "_idle")
		step_blocked.emit(position, direction)
		return false
	
	# 3. Execute 16px grid step
	var target_position: Vector2 = position + direction * TILE_SIZE
	move_step(target_position, direction)
	return true


func _check_ledge_at(direction: Vector2) -> LedgeArea:
	if not ledge_ray:
		return null
	ledge_ray.position = Vector2(8, 8)
	ledge_ray.target_position = direction * TILE_SIZE
	ledge_ray.force_raycast_update()
	if ledge_ray.is_colliding():
		var collider: Object = ledge_ray.get_collider()
		if collider is LedgeArea:
			return collider as LedgeArea
	return null


func _is_tile_blocked_at_offset(offset: Vector2) -> bool:
	# Check physics obstacle via RayCast2D
	if collision_ray:
		collision_ray.position = Vector2(8, 8)
		collision_ray.target_position = offset
		collision_ray.force_raycast_update()
		if collision_ray.is_colliding():
			return true
	
	# Check UpperGround TileMapLayer obstacle tile data
	var target_world_pos: Vector2 = global_position + offset + Vector2(8, 8)
	if upper_ground:
		var local_pos: Vector2 = upper_ground.to_local(target_world_pos)
		var tile_coord: Vector2i = upper_ground.local_to_map(local_pos)
		var tile_data: TileData = upper_ground.get_cell_tile_data(tile_coord)
		if tile_data != null:
			return true
	
	return false


func move_step(target_position: Vector2, direction: Vector2) -> void:
	is_moving = true
	var start_pos: Vector2 = position
	step_started.emit(start_pos, target_position, direction)
	set_animation(direction, "_walk")
	
	var step_dur: float = get_effective_movement_duration()
	if step_dur <= 0.0:
		position = target_position
		_on_movement_finished(direction)
		return
	
	movement_tween = create_tween()
	movement_tween.tween_property(self, "position", target_position, step_dur)
	movement_tween.finished.connect(_on_movement_finished.bind(direction))


func jump_tween(target_position: Vector2, direction: Vector2) -> void:
	is_moving = true
	is_jumping = true
	var start_pos: Vector2 = position
	ledge_jump_started.emit(start_pos, target_position, direction)
	set_animation(direction, "_walk")
	
	if jump_duration <= 0.0:
		position = target_position
		if animated_sprite_2d:
			animated_sprite_2d.position = Vector2(8, 0)
		_on_jump_finished(direction)
		return
	
	movement_tween = create_tween()
	movement_tween.set_parallel(true)
	movement_tween.tween_property(self, "position", target_position, jump_duration)
	
	if animated_sprite_2d:
		var arc_tween: Tween = create_tween()
		arc_tween.tween_property(animated_sprite_2d, "position:y", -jump_height, jump_duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		arc_tween.tween_property(animated_sprite_2d, "position:y", 0.0, jump_duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	movement_tween.finished.connect(_on_jump_finished.bind(direction))


func _on_movement_finished(direction: Vector2) -> void:
	snap_to_grid()
	is_moving = false
	if input_vector == Vector2.ZERO and queued_direction == Vector2.ZERO:
		set_animation(direction, "_idle")
	step_completed.emit(position, direction)


func _on_jump_finished(direction: Vector2) -> void:
	snap_to_grid()
	if animated_sprite_2d:
		animated_sprite_2d.position = Vector2(8, 0)
	is_moving = false
	is_jumping = false
	if input_vector == Vector2.ZERO and queued_direction == Vector2.ZERO:
		set_animation(direction, "_idle")
	ledge_jump_completed.emit(position, direction)


func set_animation(direction: Vector2, state: String = "_idle") -> void:
	if not animated_sprite_2d or not animated_sprite_2d.sprite_frames:
		return
	if direction.x != 0:
		animated_sprite_2d.play("side" + state)
		animated_sprite_2d.flip_h = direction.x > 0
	elif direction.y > 0:
		animated_sprite_2d.play("down" + state)
		animated_sprite_2d.flip_h = false
	elif direction.y < 0:
		animated_sprite_2d.play("up" + state)
		animated_sprite_2d.flip_h = false


func get_facing_interactable() -> Node:
	var offset: Vector2 = facing_direction.normalized() * TILE_SIZE
	if collision_ray:
		collision_ray.position = Vector2(8, 8)
		collision_ray.target_position = offset
		collision_ray.force_raycast_update()
		if collision_ray.is_colliding():
			var collider: Object = collision_ray.get_collider()
			if collider is Node and (collider as Node).has_method("interact"):
				return collider as Node
	
	var target_pos: Vector2 = global_position + offset
	for node in get_tree().get_nodes_in_group("interactables"):
		if node is Node2D and (node as Node2D).global_position.distance_to(target_pos) < 4.0:
			if node.has_method("interact"):
				return node
	return null


func interact() -> bool:
	var dm: Node = _get_dialogue_manager()
	if dm and dm.get("is_active"):
		if dm.has_method("advance_dialogue"):
			dm.advance_dialogue()
		return true
	
	if is_moving or is_jumping:
		return false
	
	var target: Node = get_facing_interactable()
	if target != null and target.has_method("interact"):
		target.interact(self)
		interacted_with.emit(target)
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("action_interact"):
		var dm: Node = _get_dialogue_manager()
		if dm and dm.get("is_active"):
			dm.advance_dialogue()
			get_viewport().set_input_as_handled()
			return
		if input_enabled and not is_moving and not is_jumping:
			if interact():
				get_viewport().set_input_as_handled()
