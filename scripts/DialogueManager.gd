extends Node

signal dialogue_started(lines: Array[String], speaker: String)
signal dialogue_line_changed(line_index: int, text: String)
signal dialogue_finished()

const DIALOGUE_BOX_SCENE: PackedScene = preload("res://scenes/ui/DialogueBox.tscn")

var canvas_layer: CanvasLayer
var dialogue_box: DialogueBox

var is_active: bool = false
var current_lines: Array[String] = []
var current_line_index: int = 0
var current_speaker: String = ""
var current_text: String = ""


func _ready() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 90
	canvas_layer.name = "DialogueLayer"
	add_child(canvas_layer)
	
	dialogue_box = DIALOGUE_BOX_SCENE.instantiate() as DialogueBox
	dialogue_box.visible = false
	canvas_layer.add_child(dialogue_box)


func start_dialogue(lines_or_text: Variant, speaker: String = "") -> void:
	var parsed_lines: Array[String] = []
	if lines_or_text is String:
		var s: String = lines_or_text as String
		if s.strip_edges() != "":
			parsed_lines.append(s)
	elif lines_or_text is Array:
		for item in lines_or_text:
			var s: String = str(item)
			if s.strip_edges() != "":
				parsed_lines.append(s)
	
	if parsed_lines.is_empty():
		return
	
	current_lines = parsed_lines
	current_speaker = speaker
	current_line_index = 0
	current_text = current_lines[0]
	is_active = true
	
	_set_player_input_locked(true)
	
	if dialogue_box:
		dialogue_box.visible = true
		dialogue_box.set_dialogue(current_speaker, current_text, current_lines.size() > 1)
	
	dialogue_started.emit(current_lines, current_speaker)
	dialogue_line_changed.emit(current_line_index, current_text)


func advance_dialogue() -> void:
	if not is_active:
		return
	current_line_index += 1
	if current_line_index < current_lines.size():
		current_text = current_lines[current_line_index]
		if dialogue_box:
			dialogue_box.set_dialogue(
				current_speaker,
				current_text,
				current_line_index < current_lines.size() - 1
			)
		dialogue_line_changed.emit(current_line_index, current_text)
	else:
		close_dialogue()


func close_dialogue() -> void:
	if not is_active:
		return
	is_active = false
	current_lines.clear()
	current_line_index = 0
	current_speaker = ""
	current_text = ""
	if dialogue_box:
		dialogue_box.visible = false
	_set_player_input_locked(false)
	dialogue_finished.emit()


func get_current_text() -> String:
	return current_text


func _set_player_input_locked(locked: bool) -> void:
	var scene: Node = get_tree().current_scene
	if not scene:
		return
	var player: Node = scene.get_node_or_null("Player")
	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(not locked)


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event.is_action_pressed("action_interact") or event.is_action_pressed("ui_accept"):
		advance_dialogue()
		get_viewport().set_input_as_handled()
