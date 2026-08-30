extends Node

const MAIN_SCENE = preload("res://main.tscn")
const TOWER_SCENE = preload("res://base_tower.tscn")


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	SessionState.sandbox_mode = true
	var gameplay := MAIN_SCENE.instantiate()
	add_child(gameplay)
	await get_tree().process_frame

	var tower_ids := StatDatabase.get_playable_tower_family_ids()
	assert(gameplay.tower_fan_buttons.size() == tower_ids.size())
	var row_positions: Dictionary = {}
	for button in gameplay.tower_fan_buttons:
		row_positions[roundi(button.position.y)] = true
	assert(row_positions.size() == 2)
	for item_id in StatDatabase.get_tower_item_ids():
		assert(
			gameplay.run_state.get_tower_item_count(item_id)
			== gameplay.SANDBOX_ITEM_QUANTITY
		)

	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = tower_ids[0]
	tower.main = gameplay
	gameplay.add_child(tower)
	await get_tree().process_frame
	tower.confirm_placement()
	tower.set_selected(true)
	assert(gameplay.sandbox_set_selected_tower_level(20))
	assert(tower.instance_progression.level == 20)
	assert(gameplay.sandbox_set_selected_tower_level(1))
	assert(tower.instance_progression.level == 1)

	SessionState.sandbox_mode = false
	print("Sandbox HUD smoke test passed: all towers, two rows, stocked items, and selectable tower levels.")
	get_tree().quit(0)
