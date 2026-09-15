extends Node

const TOWER_SCENE = preload("res://base_tower.tscn")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := true
	var sandbox_mode := true
	var shop_open := false
	var game_ended := false
	var money := 1_000_000
	var owned_shop_items: Dictionary = {}

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)

	var gunslinger := await _create_tower(fake_main, &"gunslinger")
	assert(not gunslinger.has_bonus_tag(&"reveal"))
	_set_level(gunslinger, 1)
	assert(gunslinger.has_bonus_tag(&"reveal"))
	_set_level(gunslinger, 2)
	assert(gunslinger.damage == 75)
	_set_level(gunslinger, 3)
	assert(gunslinger.damage == 190)
	assert(float(gunslinger.damage) / gunslinger.loaded_attack_interval > 1100.0)

	var laser := await _create_tower(fake_main, &"laser_cannon")
	_set_level(laser, 2)
	assert(not laser.has_bonus_tag(&"reveal"))
	assert(laser.pierce_count == 4)
	var laser_component := laser.attack_component as InvaderLaserAttackComponent
	assert(laser_component != null)
	var ordered_targets: Array[Node2D] = []
	for index in 6:
		var target := Node2D.new()
		target.name = "Target%d" % index
		ordered_targets.append(target)
	var selected := laser_component._select_targets_before_endpoint(ordered_targets)
	assert(selected.size() == 5)
	assert(selected[0] == ordered_targets[0])
	assert(selected[3] == ordered_targets[3])
	assert(selected[4] == ordered_targets[5])
	assert(laser_component._get_beam_target_damage(100, 3, 5) == 40)
	assert(laser_component._get_beam_target_damage(100, 4, 5) == 100)

	var gauss := await _create_tower(fake_main, &"gauss_gunner")
	assert(gauss.damage == 16)
	_set_level(gauss, 3)
	assert(gauss.damage == 64)
	assert(gauss.attack_component.overclock_enabled)
	assert(is_equal_approx(gauss.attack_component.overclock_max_speed_bonus, 0.25))

	var anti_materiel := await _create_tower(fake_main, &"anti_materiel")
	assert(anti_materiel.pierce_count == 1)
	assert(is_equal_approx(anti_materiel.range_radius_pixels / BaseTower.RANGE_PIXELS_PER_UNIT, 11.5))
	_set_level(anti_materiel, 3)
	assert(anti_materiel.pierce_count == 1)
	assert(is_equal_approx(anti_materiel.range_radius_pixels / BaseTower.RANGE_PIXELS_PER_UNIT, 13.0))

	var kill_chain := await _create_tower(fake_main, &"kill_chain")
	assert(kill_chain.pierce_count == 0)
	assert(kill_chain.attack_component.kill_chain_enabled)
	_set_level(kill_chain, 3)
	assert(is_equal_approx(kill_chain.range_radius_pixels / BaseTower.RANGE_PIXELS_PER_UNIT, 12.5))

	var psionic := await _create_tower(fake_main, &"psionic")
	var psionic_component := psionic.attack_component as BrainiacAttackComponent
	assert(psionic_component.ramping_beam_enabled)
	assert(not psionic_component.psionic_link_enabled)
	_set_level(psionic, 3)
	assert(psionic_component.ramping_beam_enabled)
	assert(psionic_component.psionic_link_enabled)

	var ricochet := await _create_tower(fake_main, &"explosive_ricochet")
	assert(ricochet.bounce_count == 1)
	assert(not ricochet.has_damage_tag(&"explosive"))
	_set_level(ricochet, 2)
	assert(ricochet.bounce_count == 2)
	assert(not ricochet.has_damage_tag(&"explosive"))
	_set_level(ricochet, 3)
	assert(ricochet.has_damage_tag(&"explosive"))
	assert(ricochet.attack_component.contact_explosions_enabled)

	var razor := await _create_tower(fake_main, &"razor_disc")
	assert(razor.pierce_count == 4)
	assert(not razor.infinite_pierce)
	_set_level(razor, 2)
	assert(razor.pierce_count == 8)
	_set_level(razor, 3)
	assert(razor.pierce_count == 8)
	assert(razor.attack_component.return_flight_enabled)
	assert(is_equal_approx(razor.attack_component.return_damage_multiplier, 0.60))
	var returning_disc := TowerProjectile.new()
	add_child(returning_disc)
	returning_disc.global_position = Vector2(100.0, 0.0)
	returning_disc.damage = 100
	returning_disc.pierce_count = 8
	returning_disc.return_flight_enabled = true
	returning_disc.return_damage_multiplier = 0.60
	returning_disc.return_destination = Vector2.ZERO
	returning_disc.hit_target_ids[123] = true
	returning_disc._finish_projectile()
	assert(returning_disc.returning)
	assert(returning_disc.damage == 60)
	assert(returning_disc.remaining_pierce_hits == 9)
	assert(returning_disc.hit_target_ids.is_empty())
	returning_disc.queue_free()

	var tesla := await _create_tower(fake_main, &"tesla_core")
	assert(tesla.slow_duration > 0.0)
	assert(tesla.projectile_count == 1)
	assert(tesla.attack_component.branch_additional_targets == 1)
	_set_level(tesla, 1)
	assert(tesla.damage == 24)
	_set_level(tesla, 2)
	assert(tesla.damage == 45)
	assert(tesla.attack_component.branch_additional_targets == 2)
	_set_level(tesla, 3)
	assert(tesla.projectile_count == 2)

	var orb_barrage := await _create_tower(fake_main, &"orb_barrage")
	assert(orb_barrage.projectile_count == 1)
	_set_level(orb_barrage, 1)
	assert(orb_barrage.damage == 140)
	_set_level(orb_barrage, 2)
	assert(orb_barrage.projectile_count == 2)
	assert(orb_barrage.volley_stagger > 0.0)
	_set_level(orb_barrage, 3)
	assert(orb_barrage.projectile_count == 5)
	assert(is_zero_approx(orb_barrage.volley_stagger))

	var singularity := await _create_tower(fake_main, &"singularity")
	assert(singularity.attack_component.singularity_enabled)
	assert(singularity.attack_component.dedicated_singularity_attack)
	assert(is_equal_approx(singularity.loaded_attack_interval, 6.0))
	assert(is_equal_approx(singularity.attack_component.singularity_pull_duration, 1.5))
	assert(not singularity.attack_component.event_horizon_enabled)
	_set_level(singularity, 3)
	assert(is_equal_approx(singularity.loaded_attack_interval, 4.5))
	assert(singularity.attack_component.event_horizon_enabled)
	assert(is_equal_approx(singularity.attack_component.event_horizon_damage_per_enemy, 0.15))
	var event_horizon := VoidSingularity.new()
	event_horizon.damage_per_caught_enemy = 0.15
	event_horizon.maximum_damage_bonus = 1.50
	for enemy_index in 12:
		event_horizon.caught_target_ids[enemy_index] = true
	assert(is_equal_approx(event_horizon.get_collapse_damage_multiplier(), 2.50))

	var containment := await _create_tower(fake_main, &"containment_core")
	_set_level(containment, 2)
	assert(containment.damage == 36)
	assert(containment.attack_component.shockwave_enabled)

	print("Standalone weapon identity smoke checks passed")
	get_tree().quit(0)


func _create_tower(fake_main: Node, tower_id: StringName) -> BaseTower:
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = tower_id
	tower.main = fake_main
	add_child(tower)
	await get_tree().process_frame
	return tower


func _set_level(tower: BaseTower, level_index: int) -> void:
	tower.tower_level = level_index
	tower.load_base_tags()
	tower.load_level_stats()
