extends Node

const GameStats = preload("res://stat_database.gd")
const DraftManagerScript = preload("res://draft_manager.gd")
const RunStateScript = preload("res://run_state.gd")
const TOWER_SCENE = preload("res://base_tower.tscn")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := false
	var sandbox_mode := true
	var money := 1_000_000
	var owned_shop_items: Dictionary = {}

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0

	func show_tower_details(_tower: Node) -> void:
		pass


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var families := GameStats.get_playable_tower_family_ids()
	assert(families.size() == 11)
	assert(families.has(&"invader"))
	assert(families.has(&"brainiac"))
	assert(families.has(&"dronedepot"))
	assert(not families.has(&"gauss_repeater"))
	assert(not families.has(&"beholder"))
	assert(not families.has(&"hivemother"))
	assert(not families.has(&"mechbay"))
	assert(GameStats.get_canonical_tower_family_id(&"gauss_repeater") == &"invader")
	assert(GameStats.get_canonical_tower_family_id(&"beholder") == &"brainiac")
	assert(GameStats.get_canonical_tower_family_id(&"hivemother") == &"dronedepot")
	assert(GameStats.get_canonical_tower_family_id(&"mechbay") == &"dronedepot")
	assert(GameStats.get_tower(&"brainiac")["display_name"] == "Psion")
	assert(GameStats.get_tower(&"dronedepot")["display_name"] == "Alien Outpost")

	var invader_data := GameStats.get_tower(&"invader")
	assert(invader_data["delivery_type"] == GameStats.DELIVERY_PROJECTILE)
	for level_data in invader_data["levels"]:
		assert(not level_data.get("add_bonus_tags", []).has(&"reveal"))

	var rng := RandomNumberGenerator.new()
	rng.seed = 4731
	var draft_manager = DraftManagerScript.new(rng)
	var offers: Array[StringName] = draft_manager.roll_tower_offers([])
	for offer_id in offers:
		assert(GameStats.is_playable_tower_family(offer_id))

	var state = RunStateScript.new()
	state.initialize(GameStats.get_mode(&"easy"), false)
	state.set_tower_roster([&"gauss_repeater", &"beholder", &"hivemother", &"mechbay"])
	assert(state.tower_roster == [&"invader", &"brainiac", &"dronedepot"])

	var longshot_level_1 := GameStats.get_tower_xp_level_stats(&"longshot", 1)
	var longshot_level_3 := GameStats.get_tower_xp_level_stats(&"longshot", 3)
	var longshot_level_5 := GameStats.get_tower_xp_level_stats(&"longshot", 5)
	var longshot_level_15 := GameStats.get_tower_xp_level_stats(&"longshot", 15)
	assert(longshot_level_3["damage"] > longshot_level_1["damage"])
	assert(longshot_level_3["damage"] < longshot_level_5["damage"])

	var slinger_level_14 := GameStats.get_tower_xp_level_stats(&"slinger", 14)
	var slinger_level_15 := GameStats.get_tower_xp_level_stats(&"slinger", 15)
	assert(int(slinger_level_14["bounce_count"]) == 1)
	assert(int(slinger_level_15["bounce_count"]) == 2)

	var outpost_level_4 := GameStats.get_tower_xp_level_stats(&"dronedepot", 4)
	var outpost_level_5 := GameStats.get_tower_xp_level_stats(&"dronedepot", 5)
	assert(int(outpost_level_4["spawn_limit"]) == 1)
	assert(int(outpost_level_5["spawn_limit"]) == 2)

	var longshot_level_20 := GameStats.get_tower_xp_level_stats(&"longshot", 20)
	assert(longshot_level_20["damage"] > longshot_level_15["damage"])
	assert(longshot_level_20["firerate"] < longshot_level_15["firerate"])

	var fake_main := FakeMain.new()
	add_child(fake_main)
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"energycore"
	tower.main = fake_main
	add_child(tower)
	await get_tree().process_frame
	var starting_damage := tower.damage
	tower.instance_progression.grant_xp(
		tower.instance_progression.get_total_xp_required_for_level(5)
	)
	assert(tower.instance_progression.level == 5)
	assert(tower.tower_level == 1)
	assert(tower.damage > starting_damage)
	assert(not tower.get_node("HBoxContainer/upgradetower").visible)

	print("Tower family progression smoke test passed: consolidation, canonical rosters, XP interpolation, milestones, mastery, and paid-upgrade removal.")
	get_tree().quit(0)
