extends Node2D

const TILESET: TileSet = preload("res://resources/tilesets/overworld_tileset.tres")

@onready var ground: TileMapLayer = $Ground
@onready var upper_ground: TileMapLayer = $UpperGround
@onready var start_menu_ui: StartMenuUI = get_node_or_null("StartMenuUI") as StartMenuUI
@onready var bag_ui: BagUI = get_node_or_null("BagUI") as BagUI
@onready var party_ui: PartyUI = get_node_or_null("PartyUI") as PartyUI


func _ready() -> void:
	_build_interior_map()
	var player: Node2D = get_node_or_null("Player")
	if player and player.has_method("_resolve_map_layers"):
		player._resolve_map_layers()
	if start_menu_ui and bag_ui:
		start_menu_ui.bind_bag_ui(bag_ui)
	if start_menu_ui and party_ui:
		start_menu_ui.bind_party_ui(party_ui)


func _build_interior_map() -> void:
	if ground and not ground.tile_set:
		ground.tile_set = TILESET
	if upper_ground and not upper_ground.tile_set:
		upper_ground.tile_set = TILESET
	
	if not ground or not upper_ground:
		return
	
	ground.clear()
	upper_ground.clear()
	
	# 12x10 indoor room
	for x in range(12):
		for y in range(10):
			ground.set_cell(Vector2i(x, y), 0, Vector2i(40, 21))
	
	# Room walls around perimeter, except exit door mat at (5, 8) -> pixel (80, 128)
	for x in range(12):
		upper_ground.set_cell(Vector2i(x, 0), 0, Vector2i(40, 20))
		upper_ground.set_cell(Vector2i(x, 1), 0, Vector2i(40, 20))
		if x != 5:
			upper_ground.set_cell(Vector2i(x, 8), 0, Vector2i(40, 20))
		upper_ground.set_cell(Vector2i(x, 9), 0, Vector2i(40, 20))
	
	for y in range(10):
		upper_ground.set_cell(Vector2i(0, y), 0, Vector2i(40, 20))
		upper_ground.set_cell(Vector2i(11, y), 0, Vector2i(40, 20))
	
	# Counter desk obstacle at y=3, x=3..8
	for cx in range(3, 9):
		upper_ground.set_cell(Vector2i(cx, 3), 0, Vector2i(41, 22))
