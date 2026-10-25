class_name WarpPoint
extends Area2D

@export_file("*.tscn") var target_scene_path: String = ""
@export var target_spawn_position: Vector2 = Vector2.ZERO
@export var target_facing_direction: Vector2 = Vector2.DOWN
@export var active: bool = true

var _cooldown: bool = false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func trigger_warp(player: Node2D) -> void:
	var sm: Node = get_node_or_null("/root/SceneManager")
	if not active or _cooldown or (sm and sm.is_transitioning):
		return
	_cooldown = true
	if sm:
		if target_scene_path != "":
			await sm.warp_to_scene(target_scene_path, target_spawn_position, target_facing_direction)
		else:
			await sm.warp_in_place(player, target_spawn_position, target_facing_direction)
	_cooldown = false


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		if body.is_jumping:
			return
		# Wait if player is mid-step so warp happens cleanly on the door tile
		if body.is_moving and body.movement_tween and body.movement_tween.is_valid():
			await body.movement_tween.finished
		trigger_warp(body)
