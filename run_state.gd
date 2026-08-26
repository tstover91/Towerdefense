class_name RunState
extends RefCounted

const GameStats = preload("res://stat_database.gd")
const SANDBOX_MONEY := 1_000_000_000

var money := 0
var lives := 0
var max_lives := 0
var sandbox_mode := false
var tower_roster: Array[StringName] = []
var contraband_tower_id: StringName = &""
var holiday_sale_tower_id: StringName = &""
var owned_shop_items: Dictionary = {}
var run_bonuses: Dictionary = {}


func initialize(mode: Dictionary, is_sandbox: bool) -> void:
	sandbox_mode = is_sandbox
	money = SANDBOX_MONEY if sandbox_mode else int(mode.get("starting_cash", 0))
	lives = int(mode.get("starting_lives", 0))
	max_lives = lives
	tower_roster.clear()
	contraband_tower_id = &""
	holiday_sale_tower_id = &""
	owned_shop_items.clear()
	run_bonuses.clear()


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


func collect_relic(item_id: StringName, quantity: int = 1) -> bool:
	var item_stats: Dictionary = GameStats.get_relic(item_id)
	for exclusive_id in item_stats.get("exclusive_with", []):
		if int(owned_shop_items.get(StringName(exclusive_id), 0)) > 0:
			return false
	if (
		not item_stats.get("stackable", false)
		and int(owned_shop_items.get(item_id, 0)) > 0
	):
		return false
	owned_shop_items[item_id] = (
		int(owned_shop_items.get(item_id, 0))
		+ maxi(quantity, 1)
	)
	return true


func get_relic_count(relic_id: StringName) -> int:
	if not bool(GameStats.get_relic(relic_id).get("enabled", true)):
		return 0
	return maxi(int(owned_shop_items.get(relic_id, 0)), 0)


func get_run_bonus(effect: StringName) -> float:
	return float(run_bonuses.get(effect, 0.0))


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
	if not contraband_tower_id.is_empty():
		append_tower_base_tags(roster_tags, contraband_tower_id)
	return roster_tags


func append_tower_base_tags(tags: Array[StringName], tower_id: StringName) -> void:
	var tower_stats: Dictionary = GameStats.get_tower(tower_id)
	for tag_group in ["type_tags", "damage_tags", "bonus_tags"]:
		for tag in tower_stats.get(tag_group, []):
			var typed_tag := StringName(tag)
			if not tags.has(typed_tag):
				tags.append(typed_tag)


func activate_contraband_blueprint(rng: RandomNumberGenerator) -> StringName:
	if not contraband_tower_id.is_empty():
		return contraband_tower_id
	var available: Array[StringName] = []
	for tower_id in GameStats.get_playable_tower_family_ids():
		if not tower_roster.has(tower_id):
			available.append(tower_id)
	if available.is_empty():
		return &""
	contraband_tower_id = available[rng.randi_range(0, available.size() - 1)]
	return contraband_tower_id


func consume_contraband(tower_id: StringName) -> bool:
	if tower_id != contraband_tower_id or contraband_tower_id.is_empty():
		return false
	contraband_tower_id = &""
	return true


func roll_holiday_sale_tower(rng: RandomNumberGenerator) -> StringName:
	holiday_sale_tower_id = &""
	if get_relic_count(&"holiday_sale") <= 0 or tower_roster.is_empty():
		return &""
	holiday_sale_tower_id = tower_roster[rng.randi_range(0, tower_roster.size() - 1)]
	return holiday_sale_tower_id


func get_sidebar_tower_id(slot_index: int, contraband_slot_index: int) -> StringName:
	if slot_index >= 0 and slot_index < tower_roster.size():
		return tower_roster[slot_index]
	if slot_index == contraband_slot_index:
		return contraband_tower_id
	return &""


func get_tower_build_cost(
	tower_id: StringName,
	is_contraband: bool,
	_trade_agreement_tower_ids: Array[StringName]
) -> int:
	if is_contraband and tower_id == contraband_tower_id:
		return 0
	var cost := float(GameStats.get_tower(tower_id)["placement_cost"])
	if get_relic_count(&"holiday_sale") > 0:
		cost *= (
			GameStats.HOLIDAY_SALE_DISCOUNT_MULTIPLIER
			if tower_id == holiday_sale_tower_id
			else GameStats.HOLIDAY_SALE_OTHER_COST_MULTIPLIER
		)
	return maxi(roundi(cost), 0)
