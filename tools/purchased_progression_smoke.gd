extends Node

const MAIN = preload("res://main.tscn")
const TOWER = preload("res://base_tower.tscn")
const STATS = preload("res://stat_database.gd")

func _ready() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var game = MAIN.instantiate()
	add_child(game)
	game.money = 1000000
	for tower_id in STATS.get_playable_tower_family_ids():
		var tower = TOWER.instantiate()
		tower.tower_id = tower_id
		tower.main = game
		game.add_child(tower)
		tower.is_placed = true
		tower.set_selected(true)
		assert(not game.tower_xp_bar.visible)
		tower.instance_progression.grant_xp(100000.0)
		assert(tower.tower_level == 0)
		assert(tower.instance_progression.xp == 0.0)
		var levels: Array = STATS.get_tower(tower_id)["levels"]
		assert(levels.size() == 4)
		for rank in range(1, 4):
			var before: int = game.money
			game._on_sidebar_upgrade_pressed()
			game._on_sidebar_upgrade_pressed()
			assert(tower.tower_level == rank)
			assert(game.money == before - int(levels[rank]["upgrade_cost"]))
			assert(tower.get_current_effective_stats()["damage"] == tower.get_effective_stats_for_level(rank)["damage"])
		game._on_sidebar_upgrade_pressed()
		var paths := STATS.get_tower_paths(tower_id)
		if paths.is_empty():
			assert(not game.tower_path_section.visible)
			assert(tower.purchased_paths.is_empty())
		else:
			assert(game.tower_path_section.visible)
			game._on_sidebar_upgrade_pressed()
			assert(not game.tower_path_section.visible)
			game._on_sidebar_upgrade_pressed()
			game._on_sidebar_path_slot_pressed(0)
			game._on_sidebar_path_confirmed()
			assert(tower.purchased_paths.has(&"a"))
			assert(not tower.can_purchase_path(&"b", false))
		tower.set_selected(false)
		tower.free()
	print("Purchased progression integration passed: all playable towers, paid levels, XP disabled, mobile controls and final paths.")
	get_tree().quit()
