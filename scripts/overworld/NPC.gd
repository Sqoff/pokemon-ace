class_name NPC
extends StaticBody2D

signal npc_talked(npc_name: String, lines: Array[String])

@export var npc_name: String = "주민"
@export var dialogue_lines: Array[String] = [
	"안녕! 포켓몬 골드 세상에 온 걸 환영해!",
	"밤에는 풀숲에서 부우부가 나타나기도 한단다."
]
@export var facing_direction: Vector2 = Vector2.DOWN


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	add_to_group("interactables")
	add_to_group("npcs")


func interact(interactor: Node = null) -> void:
	if interactor is Node2D:
		var diff: Vector2 = (interactor as Node2D).global_position - global_position
		if diff != Vector2.ZERO:
			facing_direction = diff.normalized()
	var dm: Node = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("start_dialogue"):
		dm.start_dialogue(dialogue_lines, npc_name)
	npc_talked.emit(npc_name, dialogue_lines)
