extends Node

const GameStats = preload("res://stat_database.gd")
const TOWER_SCENE = preload("res://base_tower.tscn")

const VALID_TYPE_TAGS: Array[StringName] = [&"biological", &"technology"]
const VALID_DAMAGE_TAGS: Array[StringName] = [
	&"ballistic", &"beam", &"melee", &"explosive", &"electric", &"radiation",
]
const VALID_BONUS_TAGS: Array[StringName] = [
	&"pierce", &"stun", &"slow", &"reveal", &"spawner", &"psionic",
]


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := true
	var sandbox_mode := true
	var money := 1_000_000_000

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0


func _ready() -> void:
	call_deferred("run_audit")


func run_audit() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var checked := 0
	for family_id in GameStats.get_playable_tower_family_ids():
		if not await check_variant(fake_main, family_id, &"", 1):
			return
		checked += 1
		if not await check_variant(fake_main, family_id, &"", 9):
			return
		checked += 1
		for evolution_id in GameStats.get_tower_evolutions(family_id):
			if not await check_variant(fake_main, family_id, evolution_id, 10):
				return
			checked += 1
			if not await check_variant(fake_main, family_id, evolution_id, 20):
				return
			checked += 1
	print("Tower tag audit passed: %d base/evolution level states checked." % checked)
	get_tree().quit(0)


func check_variant(
	fake_main: Node,
	family_id: StringName,
	evolution_id: StringName,
	level: int
) -> bool:
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = family_id
	tower.main = fake_main
	add_child(tower)
	await get_tree().process_frame
	if not evolution_id.is_empty():
		var evolution := GameStats.get_tower_evolution(family_id, evolution_id)
		tower.instance_progression.choose_evolution(
			evolution_id, int(evolution.get("cost", 0))
		)
		tower.purchased_paths.assign([
			StringName(evolution.get("legacy_path_id", &""))
		])
	tower.instance_progression.set_level_for_sandbox(level)
	tower.configure_attack_component()
	tower.load_base_tags()
	tower.load_level_stats()
	var label := "%s/%s L%d" % [
		family_id,
		"base" if evolution_id.is_empty() else evolution_id,
		level,
	]
	if not check_unique_known(tower.type_tags, VALID_TYPE_TAGS, label + " type"):
		return false
	if not check_unique_known(tower.damage_tags, VALID_DAMAGE_TAGS, label + " damage"):
		return false
	if not check_unique_known(tower.bonus_tags, VALID_BONUS_TAGS, label + " bonus"):
		return false
	if not check(not tower.type_tags.is_empty(), label + " has no type tag"):
		return false
	if not check(not tower.damage_tags.is_empty(), label + " has no damage tag"):
		return false
	var primary := tower.get_primary_damage_type()
	if not check(tower.damage_tags.has(primary), label + " primary damage is absent"):
		return false
	if not check(
		(tower.pierce_count > 0) == tower.has_bonus_tag(&"pierce"),
		label + " Pierce tag/count disagree"
	):
		return false
	if tower.uses_standard_spawner_system():
		if not check(tower.has_bonus_tag(&"spawner"), label + " uses the spawner system without Spawner"):
			return false
		var unit_stats: Dictionary = tower.get_current_effective_stats().get("unit_stats", {})
		var unit_damage_tags: Array = unit_stats.get("damage_tags", tower.damage_tags)
		for extra_tag in unit_stats.get("additional_damage_tags", []):
			if not unit_damage_tags.has(extra_tag):
				unit_damage_tags.append(extra_tag)
		for damage_tag in tower.damage_tags:
			if not check(unit_damage_tags.has(damage_tag), "%s parent/unit damage tags disagree" % label):
				return false
	if (
		(family_id == &"dronedepot" and evolution_id == &"mech_bay")
		or (
			family_id == &"orbitalcannon"
			and evolution_id in [&"solar_lance", &"atomic_strike"]
		)
	):
		if not check(
			tower.delivery_type == GameStats.DELIVERY_HITSCAN,
			label + " resolves directly but is tagged as projectile delivery"
		):
			return false
	print("TAG %-36s type=%s damage=%s primary=%s bonus=%s delivery=%s" % [
		label, tower.type_tags, tower.damage_tags, primary, tower.bonus_tags,
		tower.delivery_type,
	])
	tower.queue_free()
	await get_tree().process_frame
	return true


func check_unique_known(
	tags: Array[StringName],
	valid_tags: Array[StringName],
	label: String
) -> bool:
	var seen: Dictionary = {}
	for tag in tags:
		if not check(valid_tags.has(tag), "%s contains unknown tag %s" % [label, tag]):
			return false
		if not check(not seen.has(tag), "%s repeats tag %s" % [label, tag]):
			return false
		seen[tag] = true
	return true


func check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false
