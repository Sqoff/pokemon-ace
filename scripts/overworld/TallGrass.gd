class_name TallGrass
extends Sprite2D

signal player_stepped_in_grass(grass_node: Node2D)

const TALL_GRASS_EFFECT: PackedScene = preload("res://scenes/overworld/TallGrassEffect.tscn")

enum GrassState {
	NORMAL,
	STEPPED
}

var effect: AnimatedSprite2D


func _ready() -> void:
	frame = GrassState.NORMAL


func _on_entity_entered(body: Node2D) -> void:
	frame = GrassState.STEPPED
	play_effect()
	if body is Player:
		player_stepped_in_grass.emit(self)


func _on_entity_exited(_body: Node2D) -> void:
	frame = GrassState.NORMAL


func play_effect() -> void:
	if not effect:
		effect = TALL_GRASS_EFFECT.instantiate()
		add_child(effect)
	effect.frame = 0
	effect.play(&"default")


func _on_area_2d_body_entered(body: Node2D) -> void:
	_on_entity_entered(body)


func _on_area_2d_body_exited(body: Node2D) -> void:
	_on_entity_exited(body)
