class_name Signpost
extends StaticBody2D

signal signpost_read(lines: Array[String])

@export var title: String = "표지판"
@export var dialogue_lines: Array[String] = [
	"여기는 연두마을(New Bark Town).",
	"새로운 바람이 시작되는 마을!"
]


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	add_to_group("interactables")
	add_to_group("signposts")


func interact(_interactor: Node = null) -> void:
	var dm: Node = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("start_dialogue"):
		dm.start_dialogue(dialogue_lines, title)
	signpost_read.emit(dialogue_lines)
