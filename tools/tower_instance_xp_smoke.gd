extends Node

const TOWER_SCENE = preload("res://base_tower.tscn")
const MOB_SCENE = preload("res://mob.tscn")
const TOWER_XP_CREDIT_SERVICE = preload(
	"res://tower_progression/tower_xp_credit_service.gd"
)
const TOWER_INSTANCE_PROGRESSION = preload(
	"res://tower_progression/tower_instance_progression.gd"
)
const MAIN_SCRIPT = preload("res://main.gd")


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


class FakeDescendantRequester:
	extends Node
	var enemy_id: StringName
	var split_count := 0
	var summon_limit := 0


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var first_tower := await _create_tower(fake_main)
	var second_tower := await _create_tower(fake_main)

	if not _check(first_tower.instance_progression != null, "Tower progression state was not created."):
		return
	if not _check(
		first_tower.instance_progression.instance_uid
		!= second_tower.instance_progression.instance_uid,
		"Two tower instances received the same progression UID."
	):
		return
	var expected_thresholds := {
		2: 14.0,
		5: 88.0,
		10: 415.0,
		15: 1467.0,
		20: 5000.0,
	}
	for expected_level in expected_thresholds:
		if not _check(
			is_equal_approx(
				first_tower.instance_progression.get_total_xp_required_for_level(
					expected_level
				),
				expected_thresholds[expected_level]
			),
			"Normalized RuneScape XP threshold was incorrect for level %d."
				% expected_level
		):
			return

	var enemy := MOB_SCENE.instantiate()
	add_child(enemy)
	enemy.health = 100
	enemy.max_health = 100
	enemy.armor = 0.0
	enemy.finished = false
	enemy.health_bar.max_value = 100
	enemy.health_bar.value = 100

	var direct_context := AttackContext.from_tower(first_tower)
	var received: int = enemy.apply_damage(20, &"ballistic", true, true, direct_context)
	if not _check(received == 20, "Enemy reported the wrong received damage."):
		return
	if not _check(
		is_equal_approx(first_tower.instance_progression.actual_damage_dealt, 20.0),
		"Actual damage was not credited to the root tower."
	):
		return
	if not _check(
		is_equal_approx(first_tower.instance_progression.xp, 0.26),
		"Damage XP was not credited at the configured rate."
	):
		return

	var derived_context := direct_context.derive(
		first_tower,
		&"test_secondary",
		&"secondary",
		true
	)
	enemy.apply_damage(10, &"ballistic", true, true, derived_context)
	if not _check(
		is_equal_approx(first_tower.instance_progression.actual_damage_dealt, 30.0),
		"Derived attacks did not preserve root-tower damage credit."
	):
		return
	if not _check(
		is_equal_approx(second_tower.instance_progression.xp, 0.0),
		"XP leaked between two copies of the same tower family."
	):
		return

	enemy.apply_damage(500, &"ballistic", true, true, direct_context)
	if not _check(
		is_equal_approx(first_tower.instance_progression.actual_damage_dealt, 100.0),
		"Overkill credited more damage than the enemy had remaining."
	):
		return
	if not _check(first_tower.instance_progression.kills == 1, "Kill credit was not recorded."):
		return
	if not _check(
		is_equal_approx(first_tower.instance_progression.xp, 1.495),
		"Combined damage and kill XP was incorrect."
	):
		return

	first_tower.instance_progression.grant_xp(
		first_tower.instance_progression.get_total_xp_required_for_level(2)
		- first_tower.instance_progression.xp
	)
	if not _check(first_tower.instance_progression.level == 2, "XP threshold did not raise the XP level."):
		return
	if not _check(first_tower.tower_level == 0, "XP changed the existing paid upgrade rank."):
		return

	var round_one_pacing = TOWER_INSTANCE_PROGRESSION.new(&"invader")
	enemy.max_health = 50
	for _enemy_index in 20:
		round_one_pacing.record_damage(
			25,
			TOWER_XP_CREDIT_SERVICE.get_damage_xp(25, enemy)
		)
	for _kill_index in 10:
		round_one_pacing.record_kill(
			TOWER_XP_CREDIT_SERVICE.get_kill_xp(enemy)
		)
	if not _check(
		is_equal_approx(round_one_pacing.xp, 20.125)
		and round_one_pacing.level == 2,
		"Representative round-one combat progressed beyond the intended early pace."
	):
		return

	enemy.enemy_id = &"splitter"
	enemy.traits.assign([&"basic"])
	enemy.xp_budget_multiplier = 1.0
	if not _check(
		is_equal_approx(
			TOWER_XP_CREDIT_SERVICE.get_enemy_damage_xp_budget(enemy), 5.25
		),
		"An enemy with descendants did not reserve part of its XP for them."
	):
		return
	enemy.xp_budget_multiplier = 0.5
	if not _check(
		is_equal_approx(
			TOWER_XP_CREDIT_SERVICE.get_enemy_damage_xp_budget(enemy), 2.625
		),
		"Instance-specific descendant XP scaling was not applied."
	):
		return
	var gameplay = MAIN_SCRIPT.new()
	var splitter := FakeDescendantRequester.new()
	splitter.enemy_id = &"splitter"
	splitter.split_count = 2
	if not _check(
		is_equal_approx(
			gameplay.get_descendant_xp_multiplier(
				&"swarmling", splitter, &"split"
			),
			0.5
		),
		"Splitter children did not receive the reserved family XP share."
	):
		return
	var summoner := FakeDescendantRequester.new()
	summoner.enemy_id = &"summoner"
	summoner.summon_limit = 3
	if not _check(
		is_equal_approx(
			gameplay.get_descendant_xp_multiplier(
				&"swarmling", summoner, &"summon"
			),
			2.5 / 3.0
		),
		"Summoned enemies did not receive the reserved family XP share."
	):
		return
	gameplay.free()
	splitter.free()
	summoner.free()

	print("Tower instance XP smoke test passed: unique state, normalized threat XP, descendants, overkill, kills, derived attribution, pacing, and automatic levels.")
	get_tree().quit(0)


func _create_tower(fake_main: Node) -> BaseTower:
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"energycore"
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
