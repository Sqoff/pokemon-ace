class_name PMDSpriteLoader
extends RefCounted

const BASE_PMD_PATH: String = "res://assets/sprites/pokemon/pmd"

## PMDCollab standard 8-direction row order:
## Row 0: Down (s), Row 1: DownRight (se), Row 2: Right (e), Row 3: UpRight (ne),
## Row 4: Up (n), Row 5: UpLeft (nw), Row 6: Left (w), Row 7: DownLeft (sw)
const DIRECTIONS: Array[String] = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]

const ACTION_MAP: Dictionary = {
	"idle": "Idle",
	"walk": "Walk",
	"attack": "Attack",
	"hurt": "Hurt",
}

static var _sprite_frames_cache: Dictionary = {}
static var _texture_cache: Dictionary = {}
static var _anim_data_cache: Dictionary = {}


static func clear_cache() -> void:
	_sprite_frames_cache.clear()
	_texture_cache.clear()
	_anim_data_cache.clear()


static func resolve_pmd_dir(species_or_dir: String) -> String:
	var cleaned: String = species_or_dir.strip_edges().trim_suffix("/")
	if cleaned.begins_with("res://"):
		return cleaned
	return "%s/%s" % [BASE_PMD_PATH, cleaned.to_lower()]


static func load_texture_safe(res_path: String) -> Texture2D:
	if _texture_cache.has(res_path):
		return _texture_cache[res_path]
	
	var tex: Texture2D = null
	var import_meta_path: String = ProjectSettings.globalize_path(res_path + ".import")
	if (FileAccess.file_exists(import_meta_path) or not OS.has_feature("editor")) and ResourceLoader.exists(res_path):
		tex = load(res_path) as Texture2D
	
	if tex == null and FileAccess.file_exists(res_path):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(res_path)
		if not bytes.is_empty():
			var img := Image.new()
			if img.load_png_from_buffer(bytes) == OK and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	
	if tex == null:
		var abs_path: String = ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path):
			var img := Image.new()
			var err: Error = img.load(abs_path)
			if err == OK and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	
	if tex != null:
		_texture_cache[res_path] = tex
	return tex


static func parse_anim_data(species_or_dir: String) -> Dictionary:
	var pmd_dir: String = resolve_pmd_dir(species_or_dir)
	if _anim_data_cache.has(pmd_dir):
		return _anim_data_cache[pmd_dir]
	
	var xml_path: String = "%s/AnimData.xml" % pmd_dir
	var abs_xml_path: String = ProjectSettings.globalize_path(xml_path)
	var parser := XMLParser.new()
	var err: Error = parser.open(xml_path)
	if err != OK and FileAccess.file_exists(abs_xml_path):
		err = parser.open(abs_xml_path)
	if err != OK:
		push_error("PMDSpriteLoader: Failed to open AnimData.xml at %s" % xml_path)
		return {}
	
	var raw_anims: Dictionary = {}
	var shadow_size: int = 1
	
	var in_anim: bool = false
	var in_durations: bool = false
	var current_tag: String = ""
	var current_anim: Dictionary = {}
	var current_durations: Array[int] = []
	
	while parser.read() == OK:
		var node_type: XMLParser.NodeType = parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT:
			var node_name: String = parser.get_node_name()
			current_tag = node_name
			if node_name == "Anim":
				in_anim = true
				current_anim = {}
				current_durations = []
			elif node_name == "Durations" and in_anim:
				in_durations = true
		elif node_type == XMLParser.NODE_TEXT:
			var text: String = parser.get_node_data().strip_edges()
			if text.is_empty():
				continue
			if not in_anim and current_tag == "ShadowSize":
				shadow_size = text.to_int()
			elif in_anim:
				if in_durations and current_tag == "Duration":
					current_durations.append(maxi(1, text.to_int()))
				elif not in_durations:
					match current_tag:
						"Name":
							current_anim["name"] = text
						"Index":
							current_anim["index"] = text.to_int()
						"FrameWidth":
							current_anim["frame_width"] = text.to_int()
						"FrameHeight":
							current_anim["frame_height"] = text.to_int()
						"CopyOf":
							current_anim["copy_of"] = text
						"HitFrame":
							current_anim["hit_frame"] = text.to_int()
						"RushFrame":
							current_anim["rush_frame"] = text.to_int()
						"ReturnFrame":
							current_anim["return_frame"] = text.to_int()
		elif node_type == XMLParser.NODE_ELEMENT_END:
			var end_name: String = parser.get_node_name()
			if end_name == "Durations":
				in_durations = false
			elif end_name == "Anim":
				in_anim = false
				current_anim["durations"] = current_durations.duplicate()
				var anim_name: String = str(current_anim.get("name", ""))
				if not anim_name.is_empty():
					raw_anims[anim_name] = current_anim
			current_tag = ""
	
	# Resolve CopyOf references
	var resolved_anims: Dictionary = {}
	for anim_name in raw_anims.keys():
		var entry: Dictionary = raw_anims[anim_name].duplicate(true)
		var copy_target: String = str(entry.get("copy_of", ""))
		var guard: int = 0
		while not copy_target.is_empty() and raw_anims.has(copy_target) and guard < 8:
			var src: Dictionary = raw_anims[copy_target]
			entry["source_name"] = src.get("name", copy_target)
			entry["frame_width"] = src.get("frame_width", 0)
			entry["frame_height"] = src.get("frame_height", 0)
			entry["durations"] = src.get("durations", []).duplicate()
			entry["hit_frame"] = src.get("hit_frame", entry.get("hit_frame", 0))
			copy_target = str(src.get("copy_of", ""))
			guard += 1
		if not entry.has("source_name"):
			entry["source_name"] = anim_name
		resolved_anims[anim_name] = entry
	
	var result: Dictionary = {
		"pmd_dir": pmd_dir,
		"shadow_size": shadow_size,
		"anims": resolved_anims,
	}
	_anim_data_cache[pmd_dir] = result
	return result


static func build_sprite_frames(species_or_dir: String) -> SpriteFrames:
	var pmd_dir: String = resolve_pmd_dir(species_or_dir)
	if _sprite_frames_cache.has(pmd_dir):
		return _sprite_frames_cache[pmd_dir]
	
	var anim_data: Dictionary = parse_anim_data(pmd_dir)
	if anim_data.is_empty():
		return null
	
	var anims_dict: Dictionary = anim_data.get("anims", {})
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	
	for action_key in ACTION_MAP.keys():
		var xml_action_name: String = ACTION_MAP[action_key]
		var meta: Dictionary = anims_dict.get(xml_action_name, {})
		if meta.is_empty() and action_key == "attack" and anims_dict.has("Shoot"):
			meta = anims_dict["Shoot"]
		if meta.is_empty():
			continue
		
		var source_name: String = str(meta.get("source_name", xml_action_name))
		var png_path: String = "%s/%s-Anim.png" % [pmd_dir, source_name]
		var sheet_tex: Texture2D = load_texture_safe(png_path)
		if sheet_tex == null:
			push_warning("PMDSpriteLoader: Missing texture %s" % png_path)
			continue
		
		var fw: int = int(meta.get("frame_width", 0))
		var fh: int = int(meta.get("frame_height", 0))
		var durations: Array = meta.get("durations", [])
		if fw <= 0 or fh <= 0:
			continue
		
		var tex_w: int = sheet_tex.get_width()
		var tex_h: int = sheet_tex.get_height()
		var num_cols: int = maxi(1, int(tex_w / fw))
		var num_rows: int = maxi(1, int(tex_h / fh))
		var frame_count: int = durations.size() if not durations.is_empty() else num_cols
		frame_count = mini(frame_count, num_cols)
		
		var is_looping: bool = (action_key == "idle" or action_key == "walk")
		
		for dir_idx in range(DIRECTIONS.size()):
			var dir_suffix: String = DIRECTIONS[dir_idx]
			var anim_name := StringName("%s_%s" % [action_key, dir_suffix])
			frames.add_animation(anim_name)
			frames.set_animation_loop(anim_name, is_looping)
			frames.set_animation_speed(anim_name, 60.0)
			
			var row_idx: int = mini(dir_idx, num_rows - 1)
			for col_idx in range(frame_count):
				var atlas := AtlasTexture.new()
				atlas.atlas = sheet_tex
				atlas.region = Rect2(col_idx * fw, row_idx * fh, fw, fh)
				var tick_dur: float = float(durations[col_idx]) if col_idx < durations.size() else 6.0
				frames.add_frame(anim_name, atlas, maxf(1.0, tick_dur))
	
	_sprite_frames_cache[pmd_dir] = frames
	return frames


static func direction_from_vector(vec: Vector2, fallback: String = "s") -> String:
	if vec.length_squared() < 0.0001:
		return fallback
	var angle: float = vec.angle() # 0 is Right (e), PI/2 is Down (s), -PI/2 is Up (n)
	# Snap angle to 8 sectors of 45 degrees (PI / 4)
	var sector: int = int(round(angle / (PI / 4.0)))
	match sector:
		0:
			return "e"
		1:
			return "se"
		2:
			return "s"
		3:
			return "sw"
		4, -4:
			return "w"
		-3:
			return "nw"
		-2:
			return "n"
		-1:
			return "ne"
	return fallback


static func vector_from_direction(dir_name: String) -> Vector2:
	match dir_name.to_lower():
		"s":
			return Vector2(0, 1)
		"se":
			return Vector2(1, 1).normalized()
		"e":
			return Vector2(1, 0)
		"ne":
			return Vector2(1, -1).normalized()
		"n":
			return Vector2(0, -1)
		"nw":
			return Vector2(-1, -1).normalized()
		"w":
			return Vector2(-1, 0)
		"sw":
			return Vector2(-1, 1).normalized()
	return Vector2(0, 1)
