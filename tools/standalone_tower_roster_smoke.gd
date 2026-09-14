extends SceneTree

const GameStats = preload("res://stat_database.gd")
const DraftManagerScript = preload("res://draft_manager.gd")
const Registry = preload("res://tower_attacks/tower_attack_component_registry.gd")

func _initialize() -> void:
	var families := GameStats.get_playable_tower_family_ids()
	assert(not families.has(&"invader"))
	for tower_id in [&"gunslinger", &"laser_cannon", &"gauss_gunner"]:
		assert(families.has(tower_id))
		assert(GameStats.get_tower_paths(tower_id).is_empty())
		assert(not GameStats.get_tower_inherent_path(tower_id).is_empty() or tower_id == &"gauss_gunner")
	var laser := GameStats.get_tower(&"laser_cannon")
	assert(laser["display_name"] == "Laser Cannon")
	assert(laser["inherent_path"]["primary_damage_type"] == &"beam")
	assert(Registry.create_component(&"laser_cannon", laser, &"spawner") != null)
	var gauss := GameStats.get_tower(&"gauss_gunner")
	assert(Registry.create_component(&"gauss_gunner", gauss, &"spawner") != null)
	var draft := DraftManagerScript.new(RandomNumberGenerator.new())
	var offers := draft.roll_tower_offers([], [&"gunslinger", &"laser_cannon", &"gauss_gunner"])
	assert(offers.size() == 3)
	print("Standalone tower roster smoke checks passed")
	quit()
