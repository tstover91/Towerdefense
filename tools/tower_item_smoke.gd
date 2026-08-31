extends Node

const GameStats = preload("res://stat_database.gd")
const TOWER_SCENE = preload("res://base_tower.tscn")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := false
	var shop_open := false
	var game_ended := false
	var sandbox_mode := true
	var money := 100_000
	var owned_shop_items: Dictionary = {}

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0

	func spend_money(amount: int) -> bool:
		if amount > money:
			return false
		money -= amount
		money_changed.emit(money)
		return true

	func add_money(amount: int) -> void:
		money += amount
		money_changed.emit(money)

	func show_tower_details(_tower: Node) -> void:
		pass

	func can_purchase_tower_evolution() -> bool:
		return not game_ended and not shop_open


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var equipped_slinger := await _create_tower(fake_main, &"slinger")
	var untouched_slinger := await _create_tower(fake_main, &"slinger")

	if not _check(
		equipped_slinger.get_equipped_item_ids().size() == 4,
		"Tower instances did not receive exactly four item slots."
	):
		return
	for item_id in equipped_slinger.get_equipped_item_ids():
		if not _check(item_id.is_empty(), "A new tower item slot was not empty."):
			return

	if not _check(
		not equipped_slinger.can_equip_item(&"beam_optics"),
		"A projectile tower accepted a Beam-only item."
	):
		return
	if not _check(equipped_slinger.equip_item(&"ricochet_module"), "Ricochet Module could not be equipped."):
		return
	if not _check(equipped_slinger.equip_item(&"penetrator_rounds"), "Penetrator Rounds could not be equipped."):
		return
	if not _check(equipped_slinger.equip_item(&"live_wire"), "Live Wire could not be equipped."):
		return
	if not _check(equipped_slinger.equip_item(&"overclocked_actuator"), "Overclocked Actuator could not be equipped."):
		return
	if not _check(
		not equipped_slinger.equip_item(&"scanner_implant"),
		"A fifth distinct item bypassed the four-slot cap."
	):
		return

	if not _check(equipped_slinger.bounce_count == 2, "Ricochet Module did not add one bounce."):
		return
	if not _check(
		equipped_slinger.bounce_range_pixels >= 5.0 * BaseTower.RANGE_PIXELS_PER_UNIT,
		"Ricochet Module did not supply a usable bounce range."
	):
		return
	if not _check(
		equipped_slinger.pierce_count == 1
		and equipped_slinger.has_bonus_tag(BaseTower.BONUS_PIERCE),
		"Penetrator Rounds did not add Pierce behavior and its tag."
	):
		return
	if not _check(
		not equipped_slinger.can_equip_item(&"targeting_computer"),
		"A non-Critical tower accepted the Common Critical stat item."
	):
		return
	if not _check(
		equipped_slinger.damage == maxi(roundi(
			float(untouched_slinger.damage) * 0.91
		), 1)
		and is_equal_approx(equipped_slinger.loaded_attack_interval, 0.78),
		"Overclocked Actuator did not apply its damage/attack-speed tradeoff."
	):
		return
	if not _check(
		untouched_slinger.get_equipped_item_ids()[0].is_empty()
		and untouched_slinger.bounce_count == 1
		and untouched_slinger.pierce_count == 0,
		"Items leaked to another copy of the same tower family."
	):
		return

	var removed_item := equipped_slinger.unequip_item(2)
	if not _check(
		removed_item == &"live_wire"
		and equipped_slinger.get_equipped_item_ids()[2].is_empty()
		and is_zero_approx(equipped_slinger.critical_chance),
		"Unequipping did not clear the slot and recalculate the tower."
	):
		return

	var longshot := await _create_tower(fake_main, &"longshot")
	if not _check(
		longshot.equip_item(&"targeting_computer")
		and is_equal_approx(longshot.critical_chance, 0.22),
		"Targeting Computer did not improve a tower with innate Critical."
	):
		return

	var spawner := await _create_tower(fake_main, &"dronedepot")
	var base_unit_stats: Dictionary = spawner.get_current_effective_stats()["unit_stats"]
	if not _check(
		spawner.equip_item(&"overclocked_actuator"),
		"A generic combat item could not be equipped to a spawner."
	):
		return
	var modified_unit_stats: Dictionary = (
		spawner.get_current_effective_stats()["unit_stats"]
	)
	if not _check(
		int(modified_unit_stats["damage"])
		== roundi(float(base_unit_stats["damage"]) * 0.91)
		and is_equal_approx(
			float(modified_unit_stats["attack_interval"]),
			float(base_unit_stats["attack_interval"]) * 0.78
		),
		"Spawner items did not modify their spawned-unit combat stats."
	):
		return

	var orbital := await _create_tower(fake_main, &"orbitalcannon")
	if not _check(orbital.equip_item(&"heavy_payload"), "Base Orbital Cannon rejected Heavy Payload."):
		return
	orbital.instance_progression.grant_xp(
		orbital.instance_progression.get_total_xp_required_for_level(
			GameStats.TOWER_EVOLUTION_DEFAULT_LEVEL
		)
	)
	orbital.select_evolution_choice(&"solar_lance")
	orbital.purchase_selected_evolution()
	if not _check(
		orbital.get_equipped_item_ids()[0] == &"heavy_payload",
		"Evolution did not preserve the tower's equipped item."
	):
		return
	if not _check(
		not orbital.item_controller.is_item_active_in_slot(0)
		and orbital.item_controller.get_incompatibility_reason(&"heavy_payload") == "Requires Explosive",
		"An evolution-incompatible item was not retained and marked inactive."
	):
		return

	print("Tower item smoke test passed: four slots, compatibility, per-instance ownership, stat/tag effects, unequip recalculation, and evolution preservation.")
	get_tree().quit(0)


func _create_tower(fake_main: Node, tower_id: StringName) -> BaseTower:
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = tower_id
	tower.main = fake_main
	add_child(tower)
	await get_tree().process_frame
	return tower


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false
