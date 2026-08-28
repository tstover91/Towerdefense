class_name RunState
extends RefCounted

const GameStats = preload("res://stat_database.gd")
const SANDBOX_MONEY := 1_000_000_000

var money := 0
var lives := 0
var max_lives := 0
var sandbox_mode := false
var tower_roster: Array[StringName] = []
var run_bonuses: Dictionary = {}
var tower_item_inventory: Dictionary = {}
var locked_tower_item_offers: Array[StringName] = []


func initialize(mode: Dictionary, is_sandbox: bool) -> void:
	sandbox_mode = is_sandbox
	money = SANDBOX_MONEY if sandbox_mode else int(mode.get("starting_cash", 0))
	lives = int(mode.get("starting_lives", 0))
	max_lives = lives
	tower_roster.clear()
	run_bonuses.clear()
	tower_item_inventory.clear()
	locked_tower_item_offers.clear()


func add_money(amount: int) -> int:
	if sandbox_mode:
		money = SANDBOX_MONEY
	else:
		money += amount
	return money


func spend_money(amount: int) -> bool:
	if sandbox_mode:
		return true
	var safe_amount := maxi(amount, 0)
	if money < safe_amount:
		return false
	money -= safe_amount
	return true


func take_damage(amount: int) -> int:
	lives = maxi(lives - maxi(amount, 0), 0)
	return lives


func restore_health(amount: int) -> int:
	lives = mini(lives + maxi(amount, 0), max_lives)
	return lives


func restore_full_health() -> int:
	lives = max_lives
	return lives


func get_draft_health_recovery(maximum_recovery: int) -> int:
	return mini(maximum_recovery, maxi(max_lives - lives, 0))


func get_run_bonus(effect: StringName) -> float:
	return float(run_bonuses.get(effect, 0.0))


func add_tower_item(item_id: StringName, quantity: int = 1) -> bool:
	if not GameStats.has_tower_item(item_id) or quantity <= 0:
		return false
	tower_item_inventory[item_id] = (
		get_tower_item_count(item_id) + quantity
	)
	return true


func remove_tower_item(item_id: StringName, quantity: int = 1) -> bool:
	var safe_quantity := maxi(quantity, 0)
	if safe_quantity <= 0 or get_tower_item_count(item_id) < safe_quantity:
		return false
	var remaining := get_tower_item_count(item_id) - safe_quantity
	if remaining <= 0:
		tower_item_inventory.erase(item_id)
	else:
		tower_item_inventory[item_id] = remaining
	return true


func get_tower_item_count(item_id: StringName) -> int:
	return maxi(int(tower_item_inventory.get(item_id, 0)), 0)


func set_locked_tower_item_offers(item_ids: Array[StringName]) -> void:
	locked_tower_item_offers.clear()
	for item_id in item_ids:
		if (
			GameStats.has_tower_item(item_id)
			and not locked_tower_item_offers.has(item_id)
		):
			locked_tower_item_offers.append(item_id)
			break


func set_tower_roster(tower_ids: Array[StringName]) -> void:
	tower_roster.clear()
	for tower_id in tower_ids:
		var family_id := GameStats.get_canonical_tower_family_id(tower_id)
		if (
			GameStats.is_playable_tower_family(family_id)
			and not tower_roster.has(family_id)
		):
			tower_roster.append(family_id)


func collect_tower(tower_id: StringName, maximum_size: int) -> bool:
	var family_id := GameStats.get_canonical_tower_family_id(tower_id)
	if (
		not GameStats.is_playable_tower_family(family_id)
		or tower_roster.has(family_id)
		or tower_roster.size() >= maximum_size
	):
		return false
	GameStats.get_tower(family_id)
	tower_roster.append(family_id)
	return true


func get_tower_roster_dictionary() -> Dictionary:
	var roster: Dictionary = {}
	for tower_id in tower_roster:
		roster[tower_id] = 1
	return roster


func get_roster_base_tags() -> Array[StringName]:
	var roster_tags: Array[StringName] = []
	for tower_id in tower_roster:
		append_tower_base_tags(roster_tags, tower_id)
	return roster_tags


func append_tower_base_tags(tags: Array[StringName], tower_id: StringName) -> void:
	var tower_stats: Dictionary = GameStats.get_tower(tower_id)
	for tag_group in ["type_tags", "damage_tags", "bonus_tags"]:
		for tag in tower_stats.get(tag_group, []):
			var typed_tag := StringName(tag)
			if not tags.has(typed_tag):
				tags.append(typed_tag)


func get_sidebar_tower_id(slot_index: int) -> StringName:
	if slot_index >= 0 and slot_index < tower_roster.size():
		return tower_roster[slot_index]
	return &""


func get_tower_build_cost(tower_id: StringName) -> int:
	return maxi(int(GameStats.get_tower(tower_id)["placement_cost"]), 0)
