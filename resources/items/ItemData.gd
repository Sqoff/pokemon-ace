class_name ItemData
extends Resource

enum Pocket {
	ITEMS = 0,
	POKEBALLS = 1,
	TM_HM = 2,
	KEY_ITEMS = 3
}

@export var id: String = ""
@export var display_name: String = ""
@export var pocket: int = Pocket.ITEMS
@export var description: String = ""
@export var heal_amount: int = 0
@export var ball_multiplier: float = 1.0
@export var usable_in_overworld: bool = false
@export var usable_in_battle: bool = false


static func create(
	p_id: String,
	p_display_name: String,
	p_pocket: int = Pocket.ITEMS,
	p_description: String = "",
	p_heal_amount: int = 0,
	p_ball_multiplier: float = 1.0,
	p_usable_overworld: bool = false,
	p_usable_battle: bool = false
) -> ItemData:
	var item := ItemData.new()
	item.id = p_id
	item.display_name = p_display_name
	item.pocket = clampi(p_pocket, Pocket.ITEMS, Pocket.KEY_ITEMS)
	item.description = p_description
	item.heal_amount = p_heal_amount
	item.ball_multiplier = p_ball_multiplier
	item.usable_in_overworld = p_usable_overworld
	item.usable_in_battle = p_usable_battle
	return item


static func get_pocket_name(pocket_idx: int) -> String:
	match pocket_idx:
		Pocket.ITEMS:
			return "일반 도구"
		Pocket.POKEBALLS:
			return "몬스터볼"
		Pocket.TM_HM:
			return "기술머신"
		Pocket.KEY_ITEMS:
			return "중요한 물건"
	return "일반 도구"


static func get_all_default_items() -> Dictionary:
	return {
		"potion": create(
			"potion", "상처약", Pocket.ITEMS,
			"포켓몬의 체력을 20 회복한다.", 20, 1.0, true, true
		),
		"super_potion": create(
			"super_potion", "좋은상처약", Pocket.ITEMS,
			"포켓몬의 체력을 50 회복한다.", 50, 1.0, true, true
		),
		"pokeball": create(
			"pokeball", "몬스터볼", Pocket.POKEBALLS,
			"야생 포켓몬을 잡기 위한 도구.", 0, 1.0, false, true
		),
		"great_ball": create(
			"great_ball", "수퍼볼", Pocket.POKEBALLS,
			"몬스터볼보다 포획률이 높은 좋은 볼.", 0, 1.5, false, true
		),
		"tm01": create(
			"tm01", "기술머신01", Pocket.TM_HM,
			"폭발펀치를 가르치는 기술머신.", 0, 1.0, true, false
		),
		"hm01": create(
			"hm01", "비전머신01", Pocket.TM_HM,
			"풀베기를 가르치는 비전머신.", 0, 1.0, true, false
		),
		"bicycle": create(
			"bicycle", "자전거", Pocket.KEY_ITEMS,
			"빠르게 이동할 수 있는 접이식 자전거.", 0, 1.0, true, false
		),
		"pokedex": create(
			"pokedex", "포켓몬도감", Pocket.KEY_ITEMS,
			"만난 포켓몬을 자동으로 기록하는 하이테크 도감.", 0, 1.0, true, false
		),
	}


static func get_default_item(item_id: String) -> ItemData:
	var key: String = item_id.strip_edges().to_lower()
	if key == "poke_ball":
		key = "pokeball"
	var catalog: Dictionary = get_all_default_items()
	if catalog.has(key):
		return catalog[key]
	return null
