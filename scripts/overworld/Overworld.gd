extends Node2D

const TILESET: TileSet = preload("res://resources/tilesets/overworld_tileset.tres")
const TALL_GRASS_SCENE: PackedScene = preload("res://scenes/overworld/TallGrass.tscn")
const ROUTE29_ENCOUNTER_TABLE: EncounterTable = preload("res://resources/pokemon/route29_encounter_table.tres")

var tint_tween: Tween

@onready var day_night_modulate: CanvasModulate = $DayNightModulate
@onready var ground: TileMapLayer = $Ground
@onready var upper_ground: TileMapLayer = $UpperGround
@onready var tall_grass_container: Node2D = $TallGrassContainer
@onready var signpost: Signpost = $Signpost
@onready var npc: NPC = $NPC
@onready var start_menu_ui: StartMenuUI = $StartMenuUI
@onready var bag_ui: BagUI = $BagUI


func _ready() -> void:
	_build_town_map()
	var player: Node2D = get_node_or_null("Player")
	if player and player.has_method("_resolve_map_layers"):
		player._resolve_map_layers()
	
	if start_menu_ui and bag_ui:
		start_menu_ui.bind_bag_ui(bag_ui)
	
	var tm: Node = get_node_or_null("/root/TimeManager")
	if tm:
		if not tm.time_period_changed.is_connected(_on_time_period_changed):
			tm.time_period_changed.connect(_on_time_period_changed)
		if tm.has_method("get_target_tint"):
			apply_time_tint(tm.get_target_tint(), 0.0)


func _on_time_period_changed(_new_period: int, _period_name: String, target_color: Color) -> void:
	var tm: Node = get_node_or_null("/root/TimeManager")
	var dur: float = 0.0
	if tm and tm.get("transition_duration") != null:
		dur = float(tm.get("transition_duration"))
	apply_time_tint(target_color, dur)


func apply_time_tint(target_color: Color, duration: float = 0.0) -> void:
	if not day_night_modulate:
		return
	if tint_tween and tint_tween.is_valid():
		tint_tween.kill()
	if duration <= 0.0:
		day_night_modulate.color = target_color
	else:
		tint_tween = create_tween()
		tint_tween.tween_property(day_night_modulate, "color", target_color, duration)


func _build_town_map() -> void:
	if ground and not ground.tile_set:
		ground.tile_set = TILESET
	if upper_ground and not upper_ground.tile_set:
		upper_ground.tile_set = TILESET
	
	if not ground or not upper_ground:
		return
	
	ground.clear()
	upper_ground.clear()
	
	# Fill 20x15 ground with grass (atlas 6:0) and dirt path (atlas 1:4)
	for x in range(20):
		for y in range(15):
			ground.set_cell(Vector2i(x, y), 0, Vector2i(6, 0))
	
	for y in range(4, 13):
		ground.set_cell(Vector2i(5, y), 0, Vector2i(1, 4))
		ground.set_cell(Vector2i(6, y), 0, Vector2i(1, 4))
	
	# Outer boundary walls (atlas 15:10 tree/fence block)
	for x in range(20):
		upper_ground.set_cell(Vector2i(x, 0), 0, Vector2i(15, 10))
		upper_ground.set_cell(Vector2i(x, 14), 0, Vector2i(15, 10))
	for y in range(15):
		upper_ground.set_cell(Vector2i(0, y), 0, Vector2i(15, 10))
		upper_ground.set_cell(Vector2i(19, y), 0, Vector2i(15, 10))
	
	# Interior obstacle wall at tile (3, 5) -> pixel (48, 80) for wall collision test
	upper_ground.set_cell(Vector2i(3, 5), 0, Vector2i(15, 10))
	
	# Building (PokeCenter / House) footprint: x=10..14, y=2..4, with door opening at (12, 4) -> pixel (192, 64)
	for bx in range(10, 15):
		for by in range(2, 5):
			if bx == 12 and by == 4:
				# Door tile is walkable on ground so Player can step onto WarpPoint at (192, 64)
				ground.set_cell(Vector2i(bx, by), 0, Vector2i(23, 5))
			else:
				upper_ground.set_cell(Vector2i(bx, by), 0, Vector2i(22, 3))
	
	# Visual ledge ridge tiles at y=8, x=7..10 (LedgeArea nodes are placed at these coordinates)
	for lx in range(7, 11):
		ground.set_cell(Vector2i(lx, 8), 0, Vector2i(15, 6))
	
	# Populate TallGrass patch at x=13..16, y=9..11 if container is empty
	if tall_grass_container and tall_grass_container.get_child_count() == 0:
		for gx in range(13, 17):
			for gy in range(9, 12):
				var grass: TallGrass = TALL_GRASS_SCENE.instantiate() as TallGrass
				grass.position = Vector2(gx * 16, gy * 16)
				grass.encounter_table = ROUTE29_ENCOUNTER_TABLE
				tall_grass_container.add_child(grass)
