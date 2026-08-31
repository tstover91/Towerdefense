extends Node

const GameStats = preload("res://stat_database.gd")
const TOWER_SCENE = preload("res://base_tower.tscn")
const MOB_SCENE = preload("res://mob.tscn")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := true
	var sandbox_mode := true
	var money := 1_000_000_000
	var relics: Dictionary = {}

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(relic_id: StringName) -> int:
		return int(relics.get(relic_id, 0))


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var path := Path2D.new()
	var curve := Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(1000.0, 0.0))
	path.curve = curve
	add_child(path)
	var follow := PathFollow2D.new()
	path.add_child(follow)
	var mob := MOB_SCENE.instantiate()
	mob.enemy_id = &"normal"
	follow.add_child(mob)
	mob.set_path_follow(follow, 500.0)
	mob.max_health = 1_000_000
	mob.health = mob.max_health

	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"reaver"
	tower.tower_level = 3
	tower.main = fake_main
	tower.position = Vector2(500.0, 100.0)
	add_child(tower)
	tower.confirm_placement()
	tower.attack_on_cooldown = true
	tower.damage_timer.stop()
	tower.critical_chance = 0.0
	var component := tower.attack_component as ReaverAttackComponent
	if not _check(component != null, "Reaver attack component was not created."):
		return

	var evolutions := GameStats.get_tower_evolutions(&"reaver")
	if not _check(evolutions.size() == 3, "Reaver should expose three evolutions."):
		return
	if not _check(evolutions.has(&"assassin") and evolutions.has(&"champion") and evolutions.has(&"enforcer"), "Reaver evolution roster is incomplete."):
		return
	var levels: Array = GameStats.get_tower(&"reaver")["levels"]
	if not _check(float(levels[0]["melee_arc_degrees"]) == 120.0 and int(levels[3]["melee_max_targets"]) == 3, "Base Reaver sweep progression is wrong."):
		return
	if not _check(is_equal_approx(float(levels[3]["range"]), 7.5), "Base Reaver did not receive its shorter melee range."):
		return

	# Base attacks resolve immediately as one sweep rather than delayed combo hits.
	var starting_health: int = mob.health
	component.execute_raw_attack(mob, tower.damage)
	if not _check(mob.health < starting_health, "Base Reaver sweep did not deal immediate damage."):
		return
	if not _check(component.melee_arc_degrees == 120.0 and component.melee_max_targets == 3, "Base sweep geometry was not loaded."):
		return

	# Assassin is single-target and makes every third completed attack a guaranteed crit.
	_load_path(tower, &"b")
	tower.critical_chance = 0.0
	if not _check(component.assassinate_enabled and component.melee_max_targets == 1, "Assassin behavior was not loaded."):
		return
	mob.health = mob.max_health
	var first_start: int = mob.health
	component.execute_raw_attack(mob, tower.damage)
	var normal_loss: int = first_start - int(mob.health)
	component.execute_raw_attack(mob, tower.damage)
	var third_start: int = mob.health
	component.execute_raw_attack(mob, tower.damage)
	var assassinate_loss: int = third_start - int(mob.health)
	if not _check(assassinate_loss > normal_loss, "Assassin's third attack was not an empowered guaranteed critical."):
		return
	if not _check(component.assassinate_attack_counter == 0, "Assassin cadence did not reset after its third attack."):
		return

	# Champion keeps normal sweeps and changes every fourth attack into a 360-degree spin.
	_load_path(tower, &"c")
	if not _check(component.champion_enabled and component.champion_spin_interval == 4, "Champion behavior was not loaded."):
		return
	component.execute_raw_attack(mob, tower.damage)
	component.execute_raw_attack(mob, tower.damage)
	component.execute_raw_attack(mob, tower.damage)
	component.execute_raw_attack(mob, tower.damage)
	if not _check(component.champion_attack_counter == 0 and component.sweep_visual_arc_degrees == 360.0, "Champion's fourth attack was not a spin."):
		return

	# Enforcer's fourth attack applies both control effects and walks path progress backward.
	_load_path(tower, &"a")
	if not _check(component.enforcer_enabled and component.melee_arc_degrees == 180.0, "Enforcer behavior was not loaded."):
		return
	mob.health = mob.max_health
	mob.stun_remaining = 0.0
	follow.progress = 500.0
	component.execute_raw_attack(mob, tower.damage)
	component.execute_raw_attack(mob, tower.damage)
	component.execute_raw_attack(mob, tower.damage)
	var progress_before_slam := follow.progress
	component.execute_raw_attack(mob, tower.damage)
	if not _check(follow.progress < progress_before_slam, "Enforcer slam did not displace its target backward."):
		return
	if not _check(mob.stun_remaining > 0.0, "Enforcer slam did not stun its target."):
		return

	# Level-20 path definitions replace the cadence values with each capstone.
	var level_20_xp: float = tower.instance_progression.get_total_xp_required_for_level(20)
	tower.instance_progression.grant_xp(level_20_xp)
	_load_path(tower, &"b")
	if not _check(is_equal_approx(component.assassinate_critical_multiplier_bonus, 1.0), "Assassin Deathblow capstone was not loaded."):
		return
	_load_path(tower, &"c")
	if not _check(component.champion_spin_interval == 4 and component.champion_spin_max_targets == 10 and is_equal_approx(component.champion_spin_damage_multiplier, 1.65), "Champion capstone was not loaded."):
		return
	_load_path(tower, &"a")
	if not _check(component.melee_max_targets == 6 and component.enforcer_slam_max_targets == 10 and is_equal_approx(component.enforcer_secondary_damage_multiplier, 0.75) and is_equal_approx(component.enforcer_stun_duration, 1.0), "Enforcer capstone was not loaded."):
		return

	print("Reaver smoke test passed: immediate sweep, Assassin, Champion, Enforcer, control, and capstones.")
	get_tree().quit(0)


func _load_path(tower: BaseTower, path_id: StringName) -> void:
	tower.purchased_paths.assign([path_id])
	tower.load_base_tags()
	tower.load_level_stats()


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false
