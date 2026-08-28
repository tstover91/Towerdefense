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


func add_mob(path: Path2D, progress: float, enemy_id: StringName = &"normal") -> Node2D:
	var follow := PathFollow2D.new()
	path.add_child(follow)
	var mob := MOB_SCENE.instantiate()
	mob.enemy_id = enemy_id
	follow.add_child(mob)
	mob.set_path_follow(follow, progress)
	mob.max_health = 1_000_000
	mob.health = mob.max_health
	return mob


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var path := Path2D.new()
	var curve := Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(1000.0, 0.0))
	path.curve = curve
	add_child(path)
	var target_mob := add_mob(path, 500.0)
	var nearby_mob := add_mob(path, 520.0)

	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"brainiac"
	tower.tower_level = 3
	tower.main = fake_main
	tower.position = Vector2(500.0, 50.0)
	add_child(tower)
	tower.confirm_placement()
	tower.attack_on_cooldown = true
	tower.damage_timer.stop()
	tower.target = target_mob
	tower.mobs_in_range.assign([target_mob, nearby_mob])
	var component := tower.attack_component as BrainiacAttackComponent
	if not _check(component != null, "Psion attack component was not created."):
		return

	var evolutions := GameStats.get_tower_evolutions(&"brainiac")
	if not _check(evolutions.size() == 2, "Psion should expose exactly two evolutions."):
		return
	if not _check(evolutions.has(&"brainiac") and evolutions.has(&"temporal_eye"), "Psion evolution roster is incomplete."):
		return
	var level_10_stats := GameStats.get_tower_xp_level_stats(&"brainiac", 10)
	if not _check(int(level_10_stats["damage"]) == 165, "Psion's corrected level-10 damage was not loaded."):
		return
	if not _check(is_equal_approx(float(level_10_stats["firerate"]), 0.2), "Psion's level-10 tick interval changed unexpectedly."):
		return

	# Base Psion remains a straightforward focused beam with no evolution mechanics.
	if not _check(tower.uses_continuous_beam(), "Base Psion should use its focused beam."):
		return
	if not _check(not component.ramping_beam_enabled and not component.psionic_link_enabled and not component.temporal_eye_enabled, "Base Psion loaded an evolution mechanic early."):
		return

	# Brainiac begins at 75%, ramps to 200%, and has no Psionic Link before level 20.
	_load_path(tower, &"a")
	if not _check(component.ramping_beam_enabled and not component.psionic_link_enabled, "Brainiac's pre-capstone behavior is wrong."):
		return
	component.process_attack(0.0)
	if not _check(component.get_continuous_beam_damage(tower.damage) == roundi(float(tower.damage) * 0.75), "Brainiac did not start at 75% of current damage."):
		return
	component.process_attack(0.5)
	if not _check(component.get_continuous_beam_damage(tower.damage) == tower.damage, "Brainiac did not gain its first ramp step."):
		return
	component.beam_lock_elapsed = 20.0
	if not _check(component.get_continuous_beam_damage(tower.damage) == roundi(float(tower.damage) * 2.0), "Brainiac exceeded or missed its pre-capstone 200% limit."):
		return
	component.on_target_updated()
	if not _check(is_zero_approx(target_mob.brainiac_link_remaining), "Psionic Link activated before level 20."):
		return

	# Temporal Eye replaces the focused beam and casts one stationary control bubble.
	_load_path(tower, &"b")
	if not _check(component.temporal_eye_enabled and not tower.uses_continuous_beam(), "Temporal Eye did not replace the focused beam."):
		return
	if not _check(tower.has_bonus_tag(&"reveal"), "Temporal Eye did not gain Reveal."):
		return
	var target_cast_position := target_mob.global_position
	var target_health_before: int = target_mob.health
	if not _check(component.execute_attack(target_mob, 400), "Temporal Eye refused to create its Time Bubble."):
		return
	var bubble := component.active_temporal_bubble as TemporalEyeBubble
	if not _check(is_instance_valid(bubble), "Temporal Eye did not retain its active bubble."):
		return
	if not _check(bubble.global_position.is_equal_approx(target_cast_position), "Time Bubble was not centered at the selected location."):
		return
	if not _check(target_mob.health < target_health_before and target_mob.slow_remaining > 0.0, "Time Bubble did not apply Beam damage and Slow."):
		return
	var fixed_bubble_position := bubble.global_position
	(target_mob.get_parent() as PathFollow2D).progress += 80.0
	if not _check(bubble.global_position.is_equal_approx(fixed_bubble_position), "Time Bubble followed the enemy instead of remaining stationary."):
		return
	component.clear_temporal_bubble()
	if not _check(not is_instance_valid(component.active_temporal_bubble), "Time Bubble cleanup failed."):
		return

	# Both evolutions receive their distinct level-20 capstones.
	var level_20_xp: float = tower.instance_progression.get_total_xp_required_for_level(20)
	tower.instance_progression.grant_xp(level_20_xp)
	_load_path(tower, &"a")
	if not _check(component.psionic_link_enabled and is_equal_approx(component.beam_ramp_max_multiplier, 2.5), "Brainiac's level-20 Link and 250% cap were not loaded."):
		return
	tower.target = target_mob
	tower.mobs_in_range.assign([target_mob, nearby_mob])
	component.on_round_started()
	component.on_target_updated()
	if not _check(target_mob.brainiac_link_remaining > 0.0, "Level-20 Brainiac did not apply Psionic Link."):
		return

	_load_path(tower, &"b")
	if not _check(is_equal_approx(component.temporal_bubble_duration, 4.0) and is_equal_approx(component.temporal_final_stun_duration, 0.5), "Temporal Eye's level-20 bubble capstone was not loaded."):
		return
	target_mob.stun_remaining = 0.0
	target_mob.health = target_mob.max_health
	tower.target = target_mob
	if not _check(component.execute_attack(target_mob, 400), "Level-20 Temporal Eye failed to cast."):
		return
	bubble = component.active_temporal_bubble as TemporalEyeBubble
	bubble.finish(true)
	if not _check(target_mob.stun_remaining > 0.0, "Temporal Eye's final pulse did not stun enemies."):
		return

	print("Psion smoke test passed: base beam, Brainiac ramp/Link capstone, and Temporal Eye Time Bubble.")
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
