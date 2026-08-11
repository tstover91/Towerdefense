extends CharacterBody2D

const GameStats = preload("res://stat_database.gd")
const RelicEffects = preload("res://relic_combat.gd")
const EXPLOSION_ZONE_SCENE = preload("res://explosion_zone.tscn")
const STUN_FATIGUE_MULTIPLIERS := [1.0, 0.65, 0.40, 0.25, 0.10]
const STUN_FATIGUE_RECOVERY_INTERVAL := 5.0

signal mob_killed(reward: int)
signal mob_died(mob: Node2D)
signal damage_received(mob: Node2D, amount: int, context: AttackContext)
signal eliminated(
	mob: Node2D,
	reward: int,
	context: AttackContext,
	elimination_kind: StringName
)
signal reached_end(damage: int)
signal spawn_requested(
	enemy_id: StringName,
	path_progress: float,
	spawn_variant: StringName
)


@export var enemy_id: StringName = GameStats.DEFAULT_ENEMY_ID
var wave_number := 1
var health_multiplier := 1.0
var spawn_variant: StringName = &"normal"
var traits: Array[StringName] = []
var global_reveal_sources: Dictionary = {}
var health: int
var max_health: int
@onready var health_bar: ProgressBar = $HealthBarAnchor/HealthBar
@onready var health_bar_anchor: Node2D = $HealthBarAnchor
@onready var sprite: Sprite2D = $sprite
var speed: float
var cash_reward: int
var base_damage: int
var defense := 0.0
var path_follow: PathFollow2D
var finished := false
var last_attack_context: AttackContext
var split_enemy_id: StringName = &""
var split_count := 0
var regeneration_per_second := 0
var regeneration_elapsed := 0.0
var speed_aura_radius := 0.0
var speed_aura_multiplier := 1.0
var rush_start_ratio := 2.0
var rush_speed_multiplier := 1.0
var summon_enemy_id: StringName = &""
var summon_interval := 0.0
var summon_limit := 0
var summons_created := 0
var summon_elapsed := 0.0
var slow_remaining := 0.0
var slow_context: AttackContext
var stun_remaining := 0.0
var stun_context: AttackContext
var stun_fatigue_tier := 0
var stun_fatigue_recovery_elapsed := 0.0
var brainiac_link_remaining := 0.0
var brainiac_link_radius := 0.0
var brainiac_link_damage_share := 0.0
var brainiac_link_context: AttackContext


func _draw() -> void:
	if brainiac_link_remaining <= 0.0 or brainiac_link_radius <= 0.0:
		return
	draw_circle(Vector2.ZERO, brainiac_link_radius, Color(0.55, 0.2, 0.95, 0.08))
	draw_arc(
		Vector2.ZERO,
		brainiac_link_radius,
		0.0,
		TAU,
		64,
		Color(0.75, 0.4, 1.0, 0.65),
		1.5,
		true
	)


func set_path_follow(pf: PathFollow2D, start_progress := 0.0) -> void:
	path_follow = pf
	path_follow.progress = maxf(start_progress, 0.0)
	position = Vector2.ZERO
	update_health_bar_position()
	
func _process(delta: float) -> void:
	_process_brainiac_link(delta)
	if path_follow == null or finished:
		return

	_process_regeneration(delta)
	_process_summoning(delta)
	_process_control_effects(delta)
	path_follow.progress += get_effective_speed() * delta
	update_health_bar_position()

	if path_follow.progress_ratio >= 1.0:
		finished = true
		reached_end.emit(get_leak_damage())
		path_follow.queue_free()

func _ready() -> void:
	load_stats()
	update_health_bar_position()


func update_health_bar_position() -> void:
	health_bar_anchor.global_position = global_position + Vector2(0.0, -30.0)
	health_bar_anchor.global_rotation = 0.0
	health_bar_anchor.global_scale = Vector2.ONE

func load_stats() -> void:
	var stats: Dictionary = GameStats.get_enemy(enemy_id)
	traits.assign(stats.get("traits", []))
	var variant_health_multiplier := 1.0
	var speed_multiplier := 1.0
	var reward_multiplier := 1.0
	var damage_multiplier := 1.0
	var defense_bonus := 0.0
	var visual_multiplier := 1.0
	match spawn_variant:
		&"horde":
			variant_health_multiplier = GameStats.HORDE_ENEMY_HEALTH_MULTIPLIER
			reward_multiplier = 0.55
			damage_multiplier = 0.7
			visual_multiplier = 0.9
			traits.append(&"horde")
		&"elite":
			variant_health_multiplier = GameStats.ELITE_ENEMY_HEALTH_MULTIPLIER
			speed_multiplier = GameStats.ELITE_ENEMY_SPEED_MULTIPLIER
			reward_multiplier = 3.0
			damage_multiplier = 1.5
			defense_bonus = 0.15
			visual_multiplier = 1.25
			traits.append(&"elite")
		&"payday":
			variant_health_multiplier = GameStats.PAYDAY_ENEMY_HEALTH_MULTIPLIER
			damage_multiplier = 0.5
			visual_multiplier = 0.85
			traits.append(&"payday")
	var base_health: int = stats["health"]
	var health_per_wave: float = stats.get("health_per_wave", 0.0)
	var scaled_health := base_health + health_per_wave * maxi(wave_number - 1, 0)
	var standard_health_multiplier := (
		1.0
		if bool(stats.get("boss", false))
		else GameStats.STANDARD_ENEMY_HEALTH_MULTIPLIER
	)
	health = maxi(
		1,
		roundi(
			scaled_health
			* standard_health_multiplier
			* health_multiplier
			* variant_health_multiplier
		)
	)
	max_health = health
	var standard_speed_multiplier := (
		1.0
		if bool(stats.get("boss", false))
		else GameStats.STANDARD_ENEMY_SPEED_MULTIPLIER
	)
	speed = float(stats["move_speed"]) * standard_speed_multiplier * speed_multiplier
	cash_reward = maxi(1, roundi(float(stats["cash_reward"]) * reward_multiplier))
	base_damage = maxi(
		1,
		roundi(float(stats.get("base_damage", health)) * damage_multiplier)
	)
	defense = minf(float(stats.get("defense", 0.0)) + defense_bonus, 0.95)
	split_enemy_id = stats.get("split_enemy_id", &"")
	split_count = stats.get("split_count", 0)
	regeneration_per_second = stats.get("regeneration_per_second", 0)
	speed_aura_radius = stats.get("speed_aura_radius", 0.0)
	speed_aura_multiplier = stats.get("speed_aura_multiplier", 1.0)
	if speed_aura_multiplier > 1.0 and speed_aura_radius > 0.0:
		add_to_group("speed_buffers")
	rush_start_ratio = stats.get("rush_start_ratio", 2.0)
	rush_speed_multiplier = stats.get("rush_speed_multiplier", 1.0)
	summon_enemy_id = stats.get("summon_enemy_id", &"")
	summon_interval = stats.get("summon_interval", 0.0)
	summon_limit = stats.get("summon_limit", 0)
	var visual_scale: float = stats.get("visual_scale", 1.0) * visual_multiplier
	sprite.modulate = stats.get("color", Color.WHITE)
	if spawn_variant == &"elite":
		sprite.modulate = sprite.modulate.lerp(Color(1.0, 0.78, 0.2), 0.45)
	sprite.scale = Vector2.ONE * 2.0 * visual_scale
	health_bar.max_value = health
	health_bar.value = health


func get_leak_damage() -> int:
	var health_ratio := clampf(float(health) / float(max_health), 0.0, 1.0)
	return maxi(1, ceili(base_damage * health_ratio))


func get_effective_speed() -> float:
	if stun_remaining > 0.0:
		return 0.0
	var result := speed

	if path_follow.progress_ratio >= rush_start_ratio:
		result *= rush_speed_multiplier

	var strongest_aura := 1.0
	for candidate in get_tree().get_nodes_in_group("speed_buffers"):
		if candidate == self or not candidate.has_method("get_speed_buff_for"):
			continue
		strongest_aura = maxf(strongest_aura, candidate.get_speed_buff_for(self))

	if slow_remaining > 0.0:
		result *= GameStats.SLOW_SPEED_MULTIPLIER
	return result * strongest_aura


func _process_control_effects(delta: float) -> void:
	stun_remaining = maxf(stun_remaining - delta, 0.0)
	if stun_fatigue_tier > 0:
		stun_fatigue_recovery_elapsed += delta
		while (
			stun_fatigue_tier > 0
			and stun_fatigue_recovery_elapsed
			>= STUN_FATIGUE_RECOVERY_INTERVAL
		):
			stun_fatigue_recovery_elapsed -= STUN_FATIGUE_RECOVERY_INTERVAL
			stun_fatigue_tier -= 1
	else:
		stun_fatigue_recovery_elapsed = 0.0
	if slow_remaining <= 0.0:
		return
	slow_remaining = maxf(slow_remaining - delta, 0.0)


func apply_slow(duration: float, attack_context: AttackContext = null) -> void:
	if finished or duration <= 0.0:
		return
	if duration >= slow_remaining:
		slow_context = attack_context
	slow_remaining = maxf(slow_remaining, duration)


func clear_slow_from_context(attack_context: AttackContext) -> void:
	if attack_context == null or slow_context != attack_context:
		return
	slow_remaining = 0.0
	slow_context = null


func apply_brainiac_link(
	duration: float,
	radius: float,
	damage_share: float,
	attack_context: AttackContext = null
) -> void:
	if finished or duration <= 0.0 or radius <= 0.0 or damage_share <= 0.0:
		return
	brainiac_link_remaining = maxf(brainiac_link_remaining, duration)
	brainiac_link_radius = maxf(brainiac_link_radius, radius)
	brainiac_link_damage_share = maxf(brainiac_link_damage_share, damage_share)
	brainiac_link_context = attack_context
	queue_redraw()


func _process_brainiac_link(delta: float) -> void:
	if brainiac_link_remaining <= 0.0:
		return
	brainiac_link_remaining = maxf(brainiac_link_remaining - delta, 0.0)
	if brainiac_link_remaining <= 0.0:
		brainiac_link_radius = 0.0
		brainiac_link_damage_share = 0.0
		brainiac_link_context = null
		queue_redraw()


func apply_stun(
	duration: float,
	affects_bosses := false,
	attack_context: AttackContext = null
) -> void:
	if finished or duration <= 0.0:
		return
	if traits.has(&"boss") and not affects_bosses:
		return
	if attack_context != null:
		var big_game_count := int(
			attack_context.metadata.get("big_game_control", 0)
		)
		if big_game_count > 0:
			if traits.has(&"elite"):
				duration *= pow(
					GameStats.BIG_GAME_CONTROL_ELITE_DURATION_PER_STACK,
					big_game_count
				)
			elif not traits.has(&"boss"):
				duration *= pow(
					GameStats.BIG_GAME_CONTROL_NORMAL_DURATION_PER_STACK,
					big_game_count
				)
		var emergency_brake_count := int(
			attack_context.metadata.get("emergency_brake", 0)
		)
		if emergency_brake_count > 0 and speed >= 130.0:
			duration *= pow(
				GameStats.EMERGENCY_BRAKE_DURATION_PER_STACK,
				emergency_brake_count
			)
	var boss_duration_multiplier := (
		GameStats.BOSS_STUN_DURATION_MULTIPLIER
		if traits.has(&"boss")
		else 1.0
	)
	var multiplier_index := mini(
		stun_fatigue_tier,
		STUN_FATIGUE_MULTIPLIERS.size() - 1
	)
	var effective_duration: float = (
		duration
		* boss_duration_multiplier
		* STUN_FATIGUE_MULTIPLIERS[multiplier_index]
	)
	if effective_duration <= stun_remaining:
		return
	stun_remaining = effective_duration
	stun_context = attack_context
	stun_fatigue_tier = mini(
		stun_fatigue_tier + 1,
		STUN_FATIGUE_MULTIPLIERS.size() - 1
	)
	stun_fatigue_recovery_elapsed = 0.0


func get_speed_buff_for(other_mob: Node2D) -> float:
	if finished or speed_aura_multiplier <= 1.0:
		return 1.0
	if global_position.distance_to(other_mob.global_position) > speed_aura_radius:
		return 1.0
	return speed_aura_multiplier


func _process_regeneration(delta: float) -> void:
	if regeneration_per_second <= 0 or health >= max_health:
		return

	regeneration_elapsed += delta
	while regeneration_elapsed >= 1.0:
		regeneration_elapsed -= 1.0
		health = mini(health + regeneration_per_second, max_health)
		health_bar.value = health


func _process_summoning(delta: float) -> void:
	if (
		summon_enemy_id.is_empty()
		or summon_interval <= 0.0
		or summons_created >= summon_limit
	):
		return

	summon_elapsed += delta
	if summon_elapsed < summon_interval:
		return

	summon_elapsed -= summon_interval
	summons_created += 1
	spawn_requested.emit(
		summon_enemy_id,
		path_follow.progress,
		get_inherited_spawn_variant()
	)

func die(context: AttackContext = null) -> void:
	if finished:
		return

	finished = true
	last_attack_context = context
	spawn_split_children()
	mob_died.emit(self)
	eliminated.emit(self, cash_reward, context, &"death")
	mob_killed.emit(cash_reward)

	if is_instance_valid(path_follow):
		path_follow.queue_free()
	else:
		queue_free()


func abduct(context: AttackContext = null) -> void:
	if finished:
		return
	finished = true
	last_attack_context = context
	# Abduction grants the normal reward, but is removal rather than a death:
	# it does not trigger death observers or create split children.
	eliminated.emit(self, cash_reward, context, &"abduction")
	mob_killed.emit(cash_reward)
	if is_instance_valid(path_follow):
		path_follow.queue_free()
	else:
		queue_free()


func spawn_split_children() -> void:
	if split_enemy_id.is_empty() or split_count <= 0 or not is_instance_valid(path_follow):
		return

	var spacing := 6.0
	for index in split_count:
		var child_progress := path_follow.progress - spacing * float(index + 1)
		spawn_requested.emit(
			split_enemy_id,
			maxf(child_progress, 0.0),
			get_inherited_spawn_variant()
		)


func get_inherited_spawn_variant() -> StringName:
	if spawn_variant in [&"horde", &"payday"]:
		return spawn_variant
	return &"normal"

func apply_damage(
	amount: int,
	damage_type: StringName,
	ignores_armor := false,
	can_trigger_brainiac_link := true,
	attack_context: AttackContext = null
) -> int:
	if finished:
		return 0
	if (
		damage_type == &"explosive"
		and attack_context != null
		and int(attack_context.metadata.get("charred_clothes", 0)) > 0
	):
		remove_hidden_trait()
	amount = apply_relic_damage_modifiers(amount, damage_type, attack_context)
	if (
		attack_context != null
		and bool(attack_context.metadata.get("was_critical", false))
		and int(attack_context.metadata.get("pressure_point", 0)) > 0
	):
		ignores_armor = true
	var should_spread := (
		can_trigger_brainiac_link
		and brainiac_link_remaining > 0.0
		and brainiac_link_radius > 0.0
		and brainiac_link_damage_share > 0.0
	)
	var link_center := global_position

	var conductive_armor := (
		not ignores_armor
		and damage_type == &"electric"
		and attack_context != null
		and int(attack_context.metadata.get("conductive", 0)) > 0
	)
	var effective_defense := 0.0 if ignores_armor else defense
	if damage_type == &"explosive":
		effective_defense *= 0.5
	var armor_multiplier := (
		1.0 + effective_defense
		if conductive_armor
		else 1.0 - effective_defense
	)
	var final_damage := maxi(1, floori(amount * armor_multiplier))
	var received_damage := mini(final_damage, health)

	health -= final_damage
	health_bar.value = health
	last_attack_context = attack_context
	damage_received.emit(self, received_damage, attack_context)

	if health <= 0:
		if (
			damage_type == &"beam"
			and attack_context != null
			and int(attack_context.metadata.get("microwave", 0)) > 0
		):
			trigger_microwave_explosion(final_damage, attack_context)
		die(attack_context)
	if should_spread and received_damage > 0:
		spread_brainiac_damage(
			link_center,
			received_damage,
			damage_type,
			attack_context
		)
	return received_damage


func trigger_microwave_explosion(
	killing_beam_damage: int,
	beam_context: AttackContext
) -> void:
	var explosion_damage := mini(
		maxi(roundi(float(max_health) * GameStats.MICROWAVE_MAX_HEALTH_DAMAGE_RATIO), 1),
		maxi(roundi(
			float(killing_beam_damage)
			* GameStats.MICROWAVE_BEAM_DAMAGE_CAP_MULTIPLIER
		), 1)
	)
	var explosion_context := beam_context.derive(
		self,
		&"defeated_enemy",
		&"microwave_explosion",
		true
	)
	explosion_context = RelicEffects.prepare_explosion_context(
		explosion_context,
		get_tree(),
		global_position,
		GameStats.MICROWAVE_EXPLOSION_RADIUS,
		self
	)
	if EXPLOSION_ZONE_SCENE != null and get_tree().current_scene != null:
		var explosion_zone := EXPLOSION_ZONE_SCENE.instantiate() as Node2D
		get_tree().current_scene.add_child(explosion_zone)
		explosion_zone.global_position = global_position
		explosion_zone.setup(GameStats.MICROWAVE_EXPLOSION_RADIUS)
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if (
			candidate == self
			or not RelicEffects.is_valid_explosion_target(
				candidate,
				explosion_context
			)
		):
			continue
		var distance_from_center: float = global_position.distance_to(
			candidate.global_position
		)
		if distance_from_center > GameStats.MICROWAVE_EXPLOSION_RADIUS:
			continue
		var dealt_damage := GameStats.get_explosion_damage(
			explosion_damage,
			distance_from_center,
			GameStats.MICROWAVE_EXPLOSION_RADIUS
		)
		candidate.apply_damage_from_tower(
			dealt_damage,
			&"explosive",
			false,
			beam_context.root_tower_type,
			explosion_context
		)


func apply_relic_damage_modifiers(
	amount: int,
	damage_type: StringName,
	attack_context: AttackContext
) -> int:
	if (
		attack_context == null
		or amount <= 0
		or attack_context.attack_kind == &"brainiac_shared_damage"
	):
		return amount
	var metadata := attack_context.metadata
	var multiplier := 1.0
	var source_type_tags: Array = metadata.get("source_type_tags", [])
	var health_ratio := float(health) / float(maxi(max_health, 1))
	var pack_hunter_count := int(metadata.get("pack_hunter", 0))
	if (
		pack_hunter_count > 0
		and source_type_tags.has(&"biological")
		and is_targeted_by_other_biological_tower(
			attack_context.root_tower_instance_id
		)
	):
		multiplier *= 1.0 + GameStats.PACK_HUNTER_DAMAGE_PER_STACK * pack_hunter_count

	var predatory_count := int(metadata.get("predatory_instinct", 0))
	if (
		predatory_count > 0
		and source_type_tags.has(&"biological")
		and health_ratio <= GameStats.PREDATORY_INSTINCT_HEALTH_THRESHOLD
	):
		multiplier *= (
			1.0 + GameStats.PREDATORY_INSTINCT_DAMAGE_PER_STACK * predatory_count
		)

	if (
		damage_type == &"beam"
		and int(metadata.get("interference_beam", 0)) > 0
		and (slow_remaining > 0.0 or stun_remaining > 0.0)
	):
		multiplier *= GameStats.INTERFERENCE_BEAM_DAMAGE_MULTIPLIER

	if damage_type == &"ballistic":
		var hollow_point_count := int(metadata.get("hollow_point", 0))
		if hollow_point_count > 0 and health >= max_health:
			multiplier *= (
				1.0 + GameStats.HOLLOW_POINT_DAMAGE_PER_STACK * hollow_point_count
			)
		var source_range := float(metadata.get("source_range", 0.0))
		var source_position: Variant = metadata.get("source_position", null)
		if source_range > 0.0 and source_position is Vector2:
			var distance_ratio := clampf(
				(source_position as Vector2).distance_to(global_position) / source_range,
				0.0,
				1.0
			)
			multiplier *= (
				1.0
				+ GameStats.LONG_BARREL_MAX_DAMAGE_PER_STACK
					* int(metadata.get("long_barrel", 0))
					* distance_ratio
			)
			multiplier *= (
				1.0
				+ GameStats.POINT_BLANK_MAX_DAMAGE_PER_STACK
					* int(metadata.get("point_blank", 0))
					* (1.0 - distance_ratio)
			)

	if damage_type == &"melee" and int(metadata.get("giant_killer", 0)) > 0:
		multiplier *= (
			GameStats.GIANT_KILLER_SPECIAL_DAMAGE_MULTIPLIER
			if traits.has(&"elite") or traits.has(&"boss")
			else GameStats.GIANT_KILLER_NORMAL_DAMAGE_MULTIPLIER
		)
	if damage_type == &"melee":
		var enemy_count := int(metadata.get("enemies_in_range", 0))
		var duelist_count := int(metadata.get("duelist", 0))
		if duelist_count > 0:
			if enemy_count == 1:
				multiplier *= (
					1.0
					+ GameStats.DUELIST_ONE_ENEMY_DAMAGE_PER_STACK
						* float(duelist_count)
				)
			elif enemy_count == 2:
				multiplier *= (
					1.0
					+ GameStats.DUELIST_TWO_ENEMY_DAMAGE_PER_STACK
						* float(duelist_count)
				)
		if int(metadata.get("strength_in_numbers", 0)) > 0:
			multiplier *= (
				1.0
				+ GameStats.STRENGTH_IN_NUMBERS_DAMAGE_PER_NEIGHBOR
					* float(int(metadata.get("nearby_melee_towers", 0)))
			)

	if damage_type == &"explosive":
		var explosion_target_count := int(metadata.get("explosion_target_count", 0))
		if (
			explosion_target_count > 0
			and int(metadata.get("crowd_pleaser", 0)) > 0
		):
			multiplier *= (
				1.0
				+ minf(
					GameStats.CROWD_PLEASER_DAMAGE_PER_ENEMY
						* float(explosion_target_count),
					GameStats.CROWD_PLEASER_MAXIMUM_DAMAGE_BONUS
				)
			)
		if int(metadata.get("direct_hit", 0)) > 0:
			match explosion_target_count:
				1:
					multiplier *= 1.60
				2:
					multiplier *= 1.30
				3:
					multiplier *= 1.15

	if (
		damage_type == &"explosive"
		and defense > 0.0
		and int(metadata.get("thermite_bombs", 0)) > 0
	):
		multiplier *= GameStats.THERMITE_BOMBS_DAMAGE_MULTIPLIER

	return maxi(roundi(float(amount) * multiplier), 1)


func is_targeted_by_other_biological_tower(source_tower_instance_id: int) -> bool:
	for tower in get_tree().get_nodes_in_group("towers"):
		if (
			not is_instance_valid(tower)
			or tower.is_queued_for_deletion()
			or tower.get_instance_id() == source_tower_instance_id
			or not tower.has_method("has_type_tag")
			or not tower.has_type_tag(&"biological")
		):
			continue
		if tower.get("target") == self:
			return true
	return false


func apply_damage_from_tower(
	amount: int,
	damage_type: StringName,
	ignores_armor: bool,
	source_tower_id: StringName,
	attack_context: AttackContext = null
) -> int:
	var resolved_context := attack_context
	if resolved_context == null and not source_tower_id.is_empty():
		resolved_context = AttackContext.legacy(source_tower_id)
	return apply_damage(amount, damage_type, ignores_armor, true, resolved_context)


func spread_brainiac_damage(
	center: Vector2,
	received_damage: int,
	_damage_type: StringName,
	_original_context: AttackContext
) -> void:
	var shared_damage := maxi(
		roundi(float(received_damage) * brainiac_link_damage_share),
		1
	)
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if (
			candidate == self
			or candidate == null
			or not is_instance_valid(candidate)
			or candidate.is_queued_for_deletion()
			or candidate.finished
		):
			continue
		if (
			candidate.traits.has(&"hidden")
			and not (
				candidate.has_method("is_revealed_for_all")
				and candidate.is_revealed_for_all()
			)
		):
			continue
		if candidate.global_position.distance_to(center) > brainiac_link_radius:
			continue
		# This is already a share of damage received, so armor is not applied twice.
		var shared_context: AttackContext
		if brainiac_link_context != null:
			shared_context = brainiac_link_context.derive(
				self,
				&"brainiac_link",
				&"brainiac_shared_damage",
				true
			)
		candidate.apply_damage(
			shared_damage,
			&"",
			true,
			false,
			shared_context
		)


func get_projectile_hit_radius() -> float:
	var variant_radius_multiplier := 1.25 if spawn_variant == &"elite" else 1.0
	var collision_shape: Shape2D = $CollisionShape2D.shape
	if collision_shape is CircleShape2D:
		return collision_shape.radius * variant_radius_multiplier
	if collision_shape is RectangleShape2D:
		return collision_shape.size.length() * 0.5 * variant_radius_multiplier
	return 12.0 * variant_radius_multiplier


func add_global_reveal_source(source: Node) -> void:
	if not traits.has(&"hidden") or not is_instance_valid(source):
		return
	global_reveal_sources[source.get_instance_id()] = weakref(source)


func remove_global_reveal_source(source: Node) -> void:
	if source == null:
		return
	global_reveal_sources.erase(source.get_instance_id())


func is_revealed_for_all() -> bool:
	if not traits.has(&"hidden"):
		return true
	var stale_source_ids: Array[int] = []
	for source_id in global_reveal_sources:
		var source_reference: WeakRef = global_reveal_sources[source_id]
		var source: Variant = source_reference.get_ref()
		if (
			source == null
			or not is_instance_valid(source)
			or source.is_queued_for_deletion()
			or not bool(source.get("is_placed"))
		):
			stale_source_ids.append(int(source_id))
	for source_id in stale_source_ids:
		global_reveal_sources.erase(source_id)
	return not global_reveal_sources.is_empty()


func remove_hidden_trait() -> void:
	traits.erase(&"hidden")
	global_reveal_sources.clear()
