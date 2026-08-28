class_name FishermanMine
extends Node2D

const GameStats = preload("res://stat_database.gd")
const AreaDamage = preload("res://area_damage_helper.gd")
const EXPLOSION_ZONE_SCENE = preload("res://explosion_zone.tscn")
const FISHERMAN_TOWER_ID: StringName = &"fisherman"
const TARGET_SCAN_INTERVAL := 0.05

signal detonated(mine: Node2D)

var main: Node
var damage := 1
var trigger_radius := 12.9
var explosion_radius := 38.7
var arm_remaining := 0.15
var detonating := false
var attack_context: AttackContext
var target_scan_remaining := 0.0
var chain_reaction_radius := 0.0
var chain_damage_multiplier := 1.0


func setup(
	game_main: Node,
	mine_damage: int,
	mine_trigger_radius: float,
	mine_explosion_radius: float,
	ownership_context: AttackContext = null,
	mine_chain_reaction_radius := 0.0,
	mine_chain_damage_multiplier := 1.0
) -> void:
	main = game_main
	damage = maxi(mine_damage, 1)
	trigger_radius = maxf(mine_trigger_radius, 1.0)
	explosion_radius = maxf(mine_explosion_radius, trigger_radius)
	attack_context = ownership_context
	chain_reaction_radius = maxf(mine_chain_reaction_radius, 0.0)
	chain_damage_multiplier = maxf(mine_chain_damage_multiplier, 0.0)
	add_to_group("fisherman_mines")
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 8.0, Color(0.18, 0.2, 0.24, 1.0))
	draw_circle(Vector2.ZERO, 5.0, Color(0.9, 0.25, 0.15, 0.95))
	draw_arc(
		Vector2.ZERO,
		trigger_radius,
		0.0,
		TAU,
		32,
		Color(1.0, 0.3, 0.2, 0.35),
		1.0,
		true
	)


func _process(delta: float) -> void:
	if detonating or not GameStats.is_combat_active(main):
		return
	arm_remaining = maxf(arm_remaining - delta, 0.0)
	if arm_remaining > 0.0:
		return
	target_scan_remaining = maxf(target_scan_remaining - delta, 0.0)
	if target_scan_remaining > 0.0:
		return
	target_scan_remaining = TARGET_SCAN_INTERVAL
	for mob in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_mob(mob):
			continue
		if global_position.distance_to(mob.global_position) <= trigger_radius:
			detonate()
			return


func detonate(from_chain_reaction := false) -> void:
	if detonating:
		return
	detonating = true
	spawn_explosion_zone()
	var explosion_context := AreaDamage.prepare_explosion_context(
		attack_context,
		get_tree(),
		global_position,
		explosion_radius
	)
	for mob in get_tree().get_nodes_in_group("mobs"):
		if not AreaDamage.is_valid_explosion_target(mob, explosion_context):
			continue
		var distance_from_center: float = global_position.distance_to(
			mob.global_position
		)
		if distance_from_center > explosion_radius:
			continue
		var resolved_damage := (
			maxi(roundi(float(damage) * chain_damage_multiplier), 1)
			if from_chain_reaction
			else damage
		)
		var dealt_damage := GameStats.get_explosion_damage(
			resolved_damage,
			distance_from_center,
			explosion_radius
		)
		if mob.has_method("apply_damage_from_tower"):
			mob.apply_damage_from_tower(
				dealt_damage,
				&"explosive",
				false,
				FISHERMAN_TOWER_ID,
				explosion_context
			)
		else:
			mob.apply_damage(
				dealt_damage,
				&"explosive",
				false,
				true,
				explosion_context
			)
	_trigger_chain_reaction()
	detonated.emit(self)
	queue_free()


func _trigger_chain_reaction() -> void:
	if chain_reaction_radius <= 0.0:
		return
	for candidate in get_tree().get_nodes_in_group("fisherman_mines"):
		if (
			candidate == self
			or not is_instance_valid(candidate)
			or candidate.is_queued_for_deletion()
			or bool(candidate.get("detonating"))
		):
			continue
		var candidate_context: AttackContext = candidate.get("attack_context")
		if (
			attack_context == null
			or candidate_context == null
			or candidate_context.root_tower_instance_id
				!= attack_context.root_tower_instance_id
		):
			continue
		if global_position.distance_to(candidate.global_position) <= chain_reaction_radius:
			candidate.call_deferred("detonate", true)


func spawn_explosion_zone() -> void:
	if EXPLOSION_ZONE_SCENE == null or get_tree().current_scene == null:
		return
	if get_tree().current_scene.has_method("spawn_explosion_visual"):
		get_tree().current_scene.spawn_explosion_visual(
			global_position, explosion_radius
		)
		return
	var explosion_zone := EXPLOSION_ZONE_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(explosion_zone)
	explosion_zone.global_position = global_position
	explosion_zone.setup(explosion_radius)


func is_valid_mob(candidate: Variant) -> bool:
	var valid_mob: bool = (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and not candidate.finished
	)
	return valid_mob and (
		not candidate.traits.has(&"hidden")
		or (
			candidate.has_method("is_revealed_for_all")
			and candidate.is_revealed_for_all()
		)
	)
