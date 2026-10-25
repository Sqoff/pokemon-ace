class_name LedgeArea
extends Area2D

@export var jump_direction: Vector2 = Vector2.DOWN


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	monitorable = true
