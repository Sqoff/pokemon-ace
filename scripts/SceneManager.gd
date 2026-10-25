extends Node

signal warp_started(target_scene_path: String)
signal fade_out_completed()
signal scene_loaded(scene_root: Node)
signal warp_completed(target_scene_path: String, spawn_pos: Vector2)

var canvas_layer: CanvasLayer
var fade_rect: ColorRect
var is_transitioning: bool = false
var fade_duration: float = 0.25

var pending_spawn_position: Vector2 = Vector2(-1, -1)
var pending_facing_direction: Vector2 = Vector2.ZERO
var has_pending_spawn: bool = false


func _ready() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	canvas_layer.name = "TransitionLayer"
	add_child(canvas_layer)
	
	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(fade_rect)


func fade_out(duration: float = -1.0) -> void:
	var d: float = fade_duration if duration < 0.0 else duration
	if d <= 0.0:
		fade_rect.color.a = 1.0
		fade_out_completed.emit()
		return
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, d)
	await tween.finished
	fade_out_completed.emit()


func fade_in(duration: float = -1.0) -> void:
	var d: float = fade_duration if duration < 0.0 else duration
	if d <= 0.0:
		fade_rect.color.a = 0.0
		return
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, d)
	await tween.finished


func warp_to_scene(target_scene_path: String, spawn_pos: Vector2, facing_dir: Vector2 = Vector2.DOWN, duration: float = -1.0) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	warp_started.emit(target_scene_path)
	
	pending_spawn_position = spawn_pos
	pending_facing_direction = facing_dir
	has_pending_spawn = true
	
	await fade_out(duration)
	
	var err: Error = get_tree().change_scene_to_file(target_scene_path)
	if err != OK:
		push_error("SceneManager: Failed to change scene to %s (err=%d)" % [target_scene_path, err])
		is_transitioning = false
		return
	
	# Wait for the new scene tree root to initialize
	await get_tree().process_frame
	await get_tree().process_frame
	
	var current_scene: Node = get_tree().current_scene
	if current_scene:
		var player: Node2D = current_scene.get_node_or_null("Player")
		if player and has_pending_spawn:
			if player.has_method("teleport_to"):
				player.teleport_to(pending_spawn_position, pending_facing_direction)
			else:
				player.global_position = pending_spawn_position
			has_pending_spawn = false
		scene_loaded.emit(current_scene)
	
	await fade_in(duration)
	is_transitioning = false
	warp_completed.emit(target_scene_path, spawn_pos)


func warp_in_place(player: Node2D, target_pos: Vector2, facing_dir: Vector2 = Vector2.DOWN, duration: float = -1.0) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	warp_started.emit("")
	
	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)
	
	await fade_out(duration)
	
	if is_instance_valid(player):
		if player.has_method("teleport_to"):
			player.teleport_to(target_pos, facing_dir)
		else:
			player.global_position = target_pos
	
	await get_tree().process_frame
	await fade_in(duration)
	
	if is_instance_valid(player) and player.has_method("set_input_enabled"):
		player.set_input_enabled(true)
	
	is_transitioning = false
	warp_completed.emit("", target_pos)
