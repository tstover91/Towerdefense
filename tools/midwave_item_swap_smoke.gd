extends Node

const TOWER_SCENE = preload("res://base_tower.tscn")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := true
	var shop_open := false
	var game_ended := false
	var sandbox_mode := true
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
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"invader"
	tower.main = fake_main
	add_child(tower)
	await get_tree().process_frame

	assert(tower.equip_item(&"patient_hunter", 0))
	tower.item_controller.patient_hunter_charge_seconds = 3.25
	tower.item_controller.runtime_state_by_slot[0]["pending_test"] = true

	# This is the same unequip/replacement sequence used by the live inventory.
	assert(tower.unequip_item(0) == &"patient_hunter")
	assert(tower.equip_item(&"reinforced_components", 0))
	assert(is_equal_approx(
		tower.item_controller.patient_hunter_charge_seconds, 3.25
	))
	assert(bool(tower.item_controller.runtime_state_by_slot[0].get(
		"pending_test", false
	)))
	assert(tower.damage > 0)

	# A wave boundary remains the deliberate reset point.
	tower.item_controller.reset_runtime_state()
	assert(is_zero_approx(tower.item_controller.patient_hunter_charge_seconds))
	assert(not tower.item_controller.runtime_state_by_slot[0].has("pending_test"))

	print("Mid-wave item swap smoke test passed: equipment refresh preserves combat state.")
	get_tree().quit(0)
