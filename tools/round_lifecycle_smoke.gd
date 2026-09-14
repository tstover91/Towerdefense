extends Node

const MAIN_SCENE = preload("res://main.tscn")
const TOWER_SCENE = preload("res://base_tower.tscn")
const RoundControllerScript = preload("res://round_controller.gd")


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var gameplay := MAIN_SCENE.instantiate()
	add_child(gameplay)
	assert(gameplay.round_controller != null)
	assert(gameplay.round_number == 0)
	assert(not gameplay.round_active)

	var starting_money: int = gameplay.money
	gameplay.start_round()
	assert(gameplay.round_number == 1)
	assert(gameplay.round_active)
	assert(gameplay.round_controller.phase == RoundControllerScript.PHASE_ACTIVE)
	assert(gameplay.round_duration > 0.0)

	gameplay.end_round()
	assert(not gameplay.round_active)
	assert(gameplay.money > starting_money)
	assert(gameplay.post_round_transition_pending)
	assert(not gameplay.shop_open)
	assert(gameplay.pause_button.disabled)
	assert(gameplay.round_timer_display.text == "Round complete")
	await get_tree().create_timer(
		gameplay.POST_ROUND_REVEAL_DELAY + 0.1
	).timeout
	assert(not gameplay.post_round_transition_pending)
	assert(not gameplay.shop_open)
	assert(gameplay.round_controller.phase == RoundControllerScript.PHASE_BUILD)
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"slinger"
	tower.main = gameplay
	gameplay.add_child(tower)
	await get_tree().process_frame
	tower.is_placed = true
	gameplay.run_state.add_tower_item(&"live_wire")
	assert(gameplay.equip_inventory_item_to_tower(
		&"live_wire",
		tower,
		0
	))
	gameplay.start_round()
	assert(gameplay.round_active)
	gameplay.item_drop_manager.drop_kill_target = 1
	var defeated_enemy := Node2D.new()
	gameplay.add_child(defeated_enemy)
	gameplay._on_mob_died(defeated_enemy)
	assert(not gameplay.newest_dropped_item_id.is_empty())
	assert(gameplay.new_item_badge.visible)
	assert(gameplay.run_state.get_tower_item_count(gameplay.newest_dropped_item_id) == 1)
	gameplay.inventory_button.button_pressed = true
	gameplay._on_inventory_button_pressed()
	assert(gameplay.tower_item_inventory_panel.get_selected_inventory_item_id() != &"")
	assert(not gameplay.new_item_badge.visible)
	assert(gameplay.unequip_tower_item_to_inventory(tower, 0))
	assert(tower.get_equipped_item_ids()[0].is_empty())

	print("Round lifecycle smoke test passed: rewards, uninterrupted build phases, combat loot feedback, and quick item equipping.")
	get_tree().quit(0)
