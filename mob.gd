extends CharacterBody2D

const GameStats = preload("res://stat_database.gd")
const RelicEffects = preload("res://relic_combat.gd")
const EXPLOSION_ZONE_SCENE = preload("res://explosion_zone.tscn")
const ELECTRIC_PROC_EFFECT = preload("res://electric_proc_effect.gd")
const ELECTRIC_ARC_EFFECT = preload("res://electric_arc_effect.gd")
const STUN_FATIGUE_MULTIPLIERS := [1.0, 0.65, 0.40, 0.25, 0.10]
const STUN_FATIGUE_RECOVERY_INTERVAL := 5.0
const FISHERMAN_MINIMUM_PROGRESS_RATIO := 0.25

signal mob_killed(reward: int)
signal mob_died(mob: Node2D)
signal reached_end(damage: int)
signal spawn_requested(
	enemy_id: StringName,
	path_progress: float,
	spawn_variant: StringName,
	requester: Node,
	request_kind: StringName
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
var armor := 0.0
var path_follow: PathFollow2D
var finished := false
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
var summon_request_pending := false
var cached_speed_aura_multiplier := 1.0
var hide_health_bar_while_full := false
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
var beholder_mark_remaining := 0.0
var beholder_mark_stacks := 0
var beholder_mark_damage_per_stack := 0.0
var beholder_mark_maximum_stacks := 0
var maximum_ablative_shield_points := 0
var ablative_shield_points := 0
var shield_aura_radius := 0.0
var fisherman_pull_immunity_remaining := 0.0
var fisherman_pull_active := false
var fisherman_minimum_progress := -1.0
var electric_hit_count := 0
var electric_proc_damage := 0.0


func _draw() -> void:
	if brainiac_link_remaining > 0.0 and brainiac_link_radius > 0.0:
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
	if beholder_mark_remaining > 0.0 and beholder_mark_stacks > 0:
		var strength := get_beholder_mark_damage_multiplier() - 1.0
		draw_arc(
			Vector2.ZERO,
			18.0,
			-PI * 0.75,
			PI * 0.75,
			24,
			Color(0.9, 0.35 + strength, 1.0, 0.85),
			2.0 + strength * 5.0,
			true
		)
	if ablative_shield_points > 0:
		var shield_ratio := (
			float(ablative_shield_points)
			/ float(maxi(maximum_ablative_shield_points, 1))
		)
		var shield_radius := get_projectile_hit_radius() + 7.0
		draw_circle(
			Vector2.ZERO,
			shield_radius,
			Color(0.15, 0.8, 1.0, 0.08 + shield_ratio * 0.08)
		)
		draw_arc(
			Vector2.ZERO,
			shield_radius,
			0.0,
			TAU,
			32,
			Color(0.45, 0.95, 1.0, 0.45 + shield_ratio * 0.45),
			1.5 + shield_ratio * 1.5,
			true
		)
		if shield_aura_radius > 0.0:
			draw_circle(
				Vector2.ZERO,
				shield_aura_radius,
				Color(0.1, 0.75, 0.9, 0.055)
			)
			draw_arc(
				Vector2.ZERO,
				shield_aura_radius,
				0.0,
				TAU,
				64,
				Color(0.35, 0.9, 1.0, 0.28),
				1.25,
				true
			)


func set_path_follow(pf: PathFollow2D, start_progress := 0.0) -> void:
	path_follow = pf
	path_follow.progress = maxf(start_progress, 0.0)
	fisherman_pull_active = false
	fisherman_pull_immunity_remaining = 0.0
	fisherman_minimum_progress = -1.0
	position = Vector2.ZERO
	update_health_bar_position()
	
func _process(delta: float) -> void:
	_process_brainiac_link(delta)
	_process_beholder_damage_mark(delta)
	if path_follow == null or finished:
		return

	_process_regeneration(delta)
	_process_summoning(delta)
	_process_control_effects(delta)
	if fisherman_minimum_progress >= 0.0:
		fisherman_minimum_progress += (
			get_effective_speed()
			* FISHERMAN_MINIMUM_PROGRESS_RATIO
			* delta
		)
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
	hide_health_bar_while_full = StringName(stats.get("role", &"")) == &"fodder"
	var variant_health_multiplier := 1.0
	var speed_multiplier := 1.0
	var reward_multiplier := 1.0
	var damage_multiplier := 1.0
	var armor_bonus := 0.0
	var visual_multiplier := 1.0
	match spawn_variant:
		&"horde":
			variant_health_multiplier = GameStats.HORDE_ENEMY_HEALTH_MULTIPLIER
			reward_multiplier = 0.55
			damage_multiplier = 0.7
			visual_multiplier = 0.9
			traits.append(&"horde")
		&"elite":
			variant_health_multiplier = GameStats.get_elite_enemy_health_multiplier(
				wave_number
			)
			speed_multiplier = GameStats.get_elite_enemy_speed_multiplier(wave_number)
			reward_multiplier = 3.0
			damage_multiplier = 1.5
			armor_bonus = 6.0
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
	health = maxi(
		1,
		roundi(
			scaled_health
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
	cash_reward = maxi(1, roundi(
		float(stats["cash_reward"])
		* reward_multiplier
		* GameStats.KILL_REWARD_MULTIPLIER
	))
	base_damage = maxi(
		1,
		roundi(float(stats.get("base_damage", health)) * damage_multiplier)
	)
	armor = maxf(float(stats.get("armor", 0.0)) + armor_bonus, 0.0)
	maximum_ablative_shield_points = maxi(
		int(stats.get("ablative_shield_points", 0)),
		0
	)
	ablative_shield_points = maximum_ablative_shield_points
	shield_aura_radius = maxf(float(stats.get("shield_aura_radius", 0.0)), 0.0)
	if shield_aura_radius > 0.0 and ablative_shield_points > 0:
		add_to_group("shield_projectors")
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
	update_health_bar_visibility()


func get_leak_damage() -> int:
	var health_ratio := clampf(float(health) / float(max_health), 0.0, 1.0)
	return maxi(1, ceili(base_damage * health_ratio))


func get_effective_speed() -> float:
	if stun_remaining > 0.0:
		return 0.0
	var result := speed

	if path_follow.progress_ratio >= rush_start_ratio:
		result *= rush_speed_multiplier

	if slow_remaining > 0.0:
		result *= GameStats.SLOW_SPEED_MULTIPLIER
	return result * cached_speed_aura_multiplier


func reset_cached_speed_aura() -> void:
	cached_speed_aura_multiplier = 1.0


func apply_cached_speed_aura_from(candidate: Node2D) -> void:
	if not candidate.has_method("get_speed_buff_for"):
		return
	cached_speed_aura_multiplier = maxf(
		cached_speed_aura_multiplier,
		candidate.get_speed_buff_for(self)
	)


func update_health_bar_visibility() -> void:
	health_bar_anchor.visible = not hide_health_bar_while_full or health < max_health


func _process_control_effects(delta: float) -> void:
	fisherman_pull_immunity_remaining = maxf(
		fisherman_pull_immunity_remaining - delta,
		0.0
	)
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
		slow_context = null
		return
	slow_remaining = maxf(slow_remaining - delta, 0.0)
	if slow_remaining <= 0.0:
		slow_context = null


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


func try_begin_fisherman_pull(_immunity_duration: float) -> bool:
	if (
		finished
		or path_follow == null
		or fisherman_pull_active
		or fisherman_pull_immunity_remaining > 0.0
	):
		return false
	fisherman_pull_active = true
	# Bank all progress earned since the previous hook. A new cast may reel from
	# here, but can never erase the ground gained during the protected window.
	fisherman_minimum_progress = maxf(
		fisherman_minimum_progress,
		path_follow.progress
	)
	return true


func end_fisherman_pull(immunity_duration: float) -> void:
	if not fisherman_pull_active:
		return
	fisherman_pull_active = false
	fisherman_pull_immunity_remaining = maxf(
		fisherman_pull_immunity_remaining,
		maxf(immunity_duration, 0.0)
	)


func apply_fisherman_pull_toward(
	tower_world_position: Vector2,
	pull_distance: float
) -> void:
	if finished or path_follow == null or pull_distance <= 0.0:
		return
	var path := path_follow.get_parent() as Path2D
	if path == null or path.curve == null:
		return
	var current_progress := path_follow.progress
	var current_position := path.to_global(
		path.curve.sample_baked(current_progress)
	)
	var current_distance := current_position.distance_to(tower_world_position)
	var minimum_progress := minf(
		maxf(fisherman_minimum_progress, 0.0),
		current_progress
	)
	var backward_progress := maxf(
		current_progress - pull_distance,
		minimum_progress
	)
	var backward_distance := path.to_global(
		path.curve.sample_baked(backward_progress)
	).distance_to(tower_world_position)
	# Fishing pulls may only reverse path progress. When the tower is ahead of
	# the enemy, the line still damages but cannot accelerate it toward the exit.
	if backward_distance + 0.001 < current_distance:
		path_follow.progress = backward_progress


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


func apply_beholder_damage_mark(
	duration: float,
	damage_per_stack: float,
	maximum_stacks: int
) -> void:
	if finished or duration <= 0.0 or damage_per_stack <= 0.0:
		return
	beholder_mark_remaining = maxf(beholder_mark_remaining, duration)
	beholder_mark_damage_per_stack = maxf(
		beholder_mark_damage_per_stack,
		damage_per_stack
	)
	beholder_mark_maximum_stacks = maxi(
		beholder_mark_maximum_stacks,
		maximum_stacks
	)
	beholder_mark_stacks = mini(
		beholder_mark_stacks + 1,
		beholder_mark_maximum_stacks
	)
	queue_redraw()


func _process_beholder_damage_mark(delta: float) -> void:
	if beholder_mark_remaining <= 0.0:
		return
	beholder_mark_remaining = maxf(beholder_mark_remaining - delta, 0.0)
	if beholder_mark_remaining <= 0.0:
		beholder_mark_stacks = 0
		beholder_mark_damage_per_stack = 0.0
		beholder_mark_maximum_stacks = 0
		queue_redraw()


func get_beholder_mark_damage_multiplier() -> float:
	return 1.0 + (
		float(beholder_mark_stacks) * beholder_mark_damage_per_stack
	)


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
		update_health_bar_visibility()


func _process_summoning(delta: float) -> void:
	if (
		summon_enemy_id.is_empty()
		or summon_interval <= 0.0
		or summons_created >= summon_limit
		or summon_request_pending
	):
		return

	summon_elapsed += delta
	if summon_elapsed < summon_interval:
		return

	summon_elapsed -= summon_interval
	summon_request_pending = true
	spawn_requested.emit(
		summon_enemy_id,
		path_follow.progress,
		get_inherited_spawn_variant(),
		self,
		&"summon"
	)


func resolve_spawn_request(request_kind: StringName, accepted: bool) -> void:
	if request_kind != &"summon":
		return
	summon_request_pending = false
	if accepted:
		summons_created += 1
	else:
		summon_elapsed = maxf(summon_interval - 0.2, 0.0)


func die(_context: AttackContext = null) -> void:
	if finished:
		return

	finished = true
	spawn_split_children()
	mob_died.emit(self)
	mob_killed.emit(cash_reward)

	if is_instance_valid(path_follow):
		path_follow.queue_free()
	else:
		queue_free()


func abduct(_context: AttackContext = null) -> void:
	if finished:
		return
	finished = true
	# Abduction grants the normal reward, but is removal rather than a death:
	# it does not trigger death observers or create split children.
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
			get_inherited_spawn_variant(),
			self,
			&"split"
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
	if amount > 0 and consume_ablative_shield_hit():
		return 0
	var is_electric_proc := (
		damage_type == &"electric"
		and attack_context != null
		and bool(attack_context.metadata.get("electric_proc", false))
	)
	if (
		damage_type == &"explosive"
		and attack_context != null
		and int(attack_context.metadata.get("charred_clothes", 0)) > 0
	):
		remove_hidden_trait()
	if not is_electric_proc:
		amount = apply_relic_damage_modifiers(amount, damage_type, attack_context)
	if beholder_mark_remaining > 0.0 and beholder_mark_stacks > 0:
		amount = maxi(
			roundi(float(amount) * get_beholder_mark_damage_multiplier()),
			1
		)
	if (
		attack_context != null
		and bool(attack_context.metadata.get("was_critical", false))
		and int(attack_context.metadata.get("pressure_point", 0)) > 0
	):
		ignores_armor = true
	if damage_type == &"beam":
		ignores_armor = true
	if (
		damage_type == &"explosive"
		and armor > 0.0
		and attack_context != null
		and int(attack_context.metadata.get("thermite_bombs", 0)) > 0
	):
		ignores_armor = true
	var should_spread := (
		not is_electric_proc
		and
		can_trigger_brainiac_link
		and brainiac_link_remaining > 0.0
		and brainiac_link_radius > 0.0
		and brainiac_link_damage_share > 0.0
	)
	var link_center := global_position

	var conductive_armor := (
		not is_electric_proc
		and
		damage_type == &"electric"
		and attack_context != null
		and int(attack_context.metadata.get("conductive", 0)) > 0
		and armor > 0.0
	)
	var armor_reduction := (
		0.0
		if (ignores_armor or is_electric_proc) and not conductive_armor
		else GameStats.get_armor_damage_reduction(armor, damage_type)
	)
	var final_damage := maxi(
		1,
		roundi(
			float(amount) * (1.0 + armor_reduction)
			if conductive_armor
			else float(amount) * (1.0 - armor_reduction)
		)
	)
	var received_damage := mini(final_damage, health)

	health -= final_damage
	health_bar.value = health
	update_health_bar_visibility()
	if damage_type == &"electric" and not is_electric_proc and received_damage > 0:
		register_electric_hit(received_damage, attack_context)
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


func consume_ablative_shield_hit() -> bool:
	if ablative_shield_points > 0:
		consume_projected_shield_hit()
		return true
	var provider := get_nearest_ablative_shield_provider()
	if provider == null:
		return false
	provider.consume_projected_shield_hit()
	return true


func consume_projected_shield_hit() -> void:
	if ablative_shield_points <= 0:
		return
	ablative_shield_points -= 1
	queue_redraw()


func get_nearest_ablative_shield_provider() -> Node2D:
	var nearest_provider: Node2D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("shield_projectors"):
		if (
			candidate == self
			or not is_instance_valid(candidate)
			or candidate.is_queued_for_deletion()
			or not candidate.has_method("can_project_ablative_shield_to")
			or not candidate.can_project_ablative_shield_to(self)
		):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_provider = candidate
	return nearest_provider


func can_project_ablative_shield_to(candidate: Node2D) -> bool:
	return (
		not finished
		and ablative_shield_points > 0
		and shield_aura_radius > 0.0
		and is_instance_valid(candidate)
		and global_position.distance_to(candidate.global_position)
			<= shield_aura_radius
	)


func register_electric_hit(
	received_damage: int,
	attack_context: AttackContext
) -> void:
	electric_hit_count += 1
	electric_proc_damage += (
		float(received_damage)
		* GameStats.ELECTRIC_PROC_DAMAGE_CONTRIBUTION
	)
	if electric_hit_count < get_electric_proc_hit_requirement(attack_context):
		return
	var lightning_damage := maxi(roundi(
		electric_proc_damage * get_electric_proc_damage_multiplier(attack_context)
	), 1)
	electric_hit_count = 0
	electric_proc_damage = 0.0
	trigger_electric_lightning_proc(lightning_damage, attack_context)


func get_electric_proc_hit_requirement(attack_context: AttackContext) -> int:
	var relic_count := get_attack_relic_count(
		attack_context, &"overcharged_capacitor"
	)
	return ceili(
		float(GameStats.ELECTRIC_HITS_TO_PROC)
		* pow(GameStats.OVERCHARGED_CAPACITOR_HIT_MULTIPLIER, relic_count)
	)


func get_electric_proc_damage_multiplier(attack_context: AttackContext) -> float:
	var relic_count := get_attack_relic_count(
		attack_context, &"overcharged_capacitor"
	)
	return pow(GameStats.OVERCHARGED_CAPACITOR_DAMAGE_MULTIPLIER, relic_count)


func get_attack_relic_count(
	attack_context: AttackContext,
	relic_id: StringName
) -> int:
	if attack_context == null:
		return 0
	return maxi(int(attack_context.metadata.get(relic_id, 0)), 0)


func trigger_electric_lightning_proc(
	lightning_damage: int,
	source_context: AttackContext
) -> void:
	var has_static_discharge := (
		get_attack_relic_count(source_context, &"static_discharge") > 0
	)
	spawn_electric_proc_effect(
		GameStats.STATIC_DISCHARGE_RADIUS if has_static_discharge else 0.0
	)
	if health <= 0 or finished:
		return
	var proc_context: AttackContext
	if source_context != null:
		proc_context = source_context.derive(
			self,
			&"enemy",
			&"electric_lightning_proc",
			true,
			{"electric_proc": true}
		)
	else:
		proc_context = AttackContext.legacy(&"", &"electric_lightning_proc")
		proc_context.metadata["electric_proc"] = true
	# The stored value is already based on final received damage. Bypass armor,
	# relic modifiers, and Brainiac sharing so the proc deals that exact amount
	# to this target only and cannot recursively build another proc.
	apply_damage(
		lightning_damage,
		&"electric",
		true,
		false,
		proc_context
	)
	if has_static_discharge:
		apply_static_discharge(lightning_damage, proc_context)
	if get_attack_relic_count(source_context, &"chain_lightning") > 0:
		apply_chain_lightning(lightning_damage, proc_context)


func apply_static_discharge(
	lightning_damage: int,
	proc_context: AttackContext
) -> void:
	var area_damage := maxi(roundi(
		float(lightning_damage) * GameStats.STATIC_DISCHARGE_DAMAGE_RATIO
	), 1)
	var area_context := proc_context.derive(
		self,
		&"enemy",
		&"electric_static_discharge",
		true,
		{"electric_proc": true, "area_damage": true}
	)
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_electric_proc_secondary_target(candidate):
			continue
		if global_position.distance_to(candidate.global_position) > GameStats.STATIC_DISCHARGE_RADIUS:
			continue
		candidate.apply_damage(area_damage, &"electric", true, false, area_context)


func apply_chain_lightning(
	lightning_damage: int,
	proc_context: AttackContext
) -> void:
	var closest_enemy: Node2D
	var closest_distance := INF
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_electric_proc_secondary_target(candidate):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = candidate
	if closest_enemy == null:
		return
	spawn_electric_arc_effect(global_position, closest_enemy.global_position)
	var chain_context := proc_context.derive(
		self,
		&"enemy",
		&"electric_chain_lightning",
		true,
		{"electric_proc": true}
	)
	closest_enemy.apply_damage(
		lightning_damage, &"electric", true, false, chain_context
	)


func is_valid_electric_proc_secondary_target(candidate: Node) -> bool:
	return (
		candidate != self
		and candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and not bool(candidate.get("finished"))
		and candidate.has_method("apply_damage")
	)


func spawn_electric_proc_effect(area_radius := 0.0) -> void:
	if not is_inside_tree():
		return
	var effect := ELECTRIC_PROC_EFFECT.new() as Node2D
	var effect_parent: Node = get_tree().current_scene
	if effect_parent == null:
		effect_parent = get_tree().root
	effect_parent.add_child(effect)
	effect.global_position = global_position
	effect.setup_area_radius(area_radius)


func spawn_electric_arc_effect(
	start_position: Vector2,
	end_position: Vector2
) -> void:
	if not is_inside_tree():
		return
	var effect := ELECTRIC_ARC_EFFECT.new() as Node2D
	var effect_parent: Node = get_tree().current_scene
	if effect_parent == null:
		effect_parent = get_tree().root
	effect_parent.add_child(effect)
	effect.setup(start_position, end_position)


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
		if hollow_point_count > 0 and float(health) > float(max_health) * 0.75:
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
		and armor > 0.0
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
	if not can_receive_tower_damage(resolved_context):
		return 0
	return apply_damage(amount, damage_type, ignores_armor, true, resolved_context)


func can_receive_tower_damage(attack_context: AttackContext) -> bool:
	if not traits.has(&"hidden") or is_revealed_for_all():
		return true
	if attack_context == null:
		return false
	return (
		bool(attack_context.metadata.get("source_can_reveal", false))
		or bool(attack_context.metadata.get("area_damage", false))
	)


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
