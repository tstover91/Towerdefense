extends CharacterBody2D

const GameStats = preload("res://stat_database.gd")
const AreaDamage = preload("res://area_damage_helper.gd")
const EXPLOSION_ZONE_SCENE = preload("res://explosion_zone.tscn")
const ELECTRIC_PROC_EFFECT = preload("res://electric_proc_effect.gd")
const ELECTRIC_ARC_EFFECT = preload("res://electric_arc_effect.gd")
const TOWER_XP_CREDIT_SERVICE = preload(
	"res://tower_progression/tower_xp_credit_service.gd"
)
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
var xp_budget_multiplier := 1.0
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
var temporary_armor_reduction := 0.0
var temporary_armor_reduction_remaining := 0.0
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
var boss_item_stun_cooldown_remaining := 0.0
var brainiac_link_remaining := 0.0
var brainiac_link_radius := 0.0
var brainiac_link_damage_share := 0.0
var brainiac_link_context: AttackContext
var beholder_mark_remaining := 0.0
var beholder_mark_stacks := 0
var beholder_mark_damage_per_stack := 0.0
var beholder_mark_maximum_stacks := 0
var beholder_mark_context: AttackContext
var external_vulnerability_remaining := 0.0
var external_vulnerability_bonus := 0.0
var external_vulnerability_context: AttackContext
var maximum_ablative_shield_points := 0
var ablative_shield_points := 0
var shield_aura_radius := 0.0
var fisherman_pull_immunity_remaining := 0.0
var fisherman_pull_active := false
var fisherman_minimum_progress := -1.0
var electric_hit_count := 0
var electric_proc_damage := 0.0
var radiation_stack_entries: Array[Dictionary] = []
var radiation_tick_remaining := 0.0
var radiation_tick_interval := 1.0
var radiation_debug_events: Array[Dictionary] = []
var active_slow_speed_multiplier := 1.0
var support_xp_awarded_by_source: Dictionary = {}


func _draw() -> void:
	if not radiation_stack_entries.is_empty():
		var stack_count := radiation_stack_entries.size()
		var radiation_radius := get_projectile_hit_radius() + 10.0
		draw_circle(Vector2.ZERO, radiation_radius, Color(0.58, 1.0, 0.08, 0.10))
		draw_arc(
			Vector2.ZERO, radiation_radius, -PI * 0.5,
			-PI * 0.5 + TAU * minf(float(stack_count) / 12.0, 1.0),
			32, Color(0.78, 1.0, 0.12, 0.9), 2.5, true
		)
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
	if external_vulnerability_remaining > 0.0 and external_vulnerability_bonus > 0.0:
		draw_arc(
			Vector2.ZERO,
			22.0,
			0.0,
			TAU,
			32,
			Color(0.35, 0.9, 1.0, 0.72),
			2.0 + external_vulnerability_bonus * 6.0,
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
	temporary_armor_reduction_remaining = maxf(
		temporary_armor_reduction_remaining - delta, 0.0
	)
	if temporary_armor_reduction_remaining <= 0.0:
		temporary_armor_reduction = 0.0
	_process_brainiac_link(delta)
	_process_beholder_damage_mark(delta)
	_process_external_vulnerability(delta)
	_process_radiation(delta)
	if path_follow == null or finished:
		return

	_process_regeneration(delta)
	_process_summoning(delta)
	_process_control_effects(delta)
	if fisherman_minimum_progress >= 0.0 and not fisherman_pull_active:
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
		result *= active_slow_speed_multiplier
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
	boss_item_stun_cooldown_remaining = maxf(
		boss_item_stun_cooldown_remaining - delta, 0.0
	)
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
		active_slow_speed_multiplier = 1.0
		return
	slow_remaining = maxf(slow_remaining - delta, 0.0)
	if slow_remaining <= 0.0:
		slow_context = null
		active_slow_speed_multiplier = 1.0


func apply_radiation(
	stack_count: int,
	damage_per_stack: int,
	attack_context: AttackContext = null,
	tick_interval := 1.0
) -> void:
	if finished or stack_count <= 0 or damage_per_stack <= 0:
		return
	if (
		attack_context != null
		and int(attack_context.metadata.get("radiation_conversion", 0)) > 0
		and not bool(attack_context.metadata.get(
			"radiation_conversion_applied", false
		))
	):
		damage_per_stack = maxi(roundi(
			float(damage_per_stack)
			* GameStats.ISOTOPE_CONVERTER_NATIVE_RADIATION_MULTIPLIER
		), 1)
	var was_empty := radiation_stack_entries.is_empty()
	radiation_tick_interval = maxf(tick_interval, 0.05)
	for _stack in stack_count:
		radiation_stack_entries.append({
			"damage": damage_per_stack,
			"context": attack_context,
		})
	if was_empty:
		radiation_tick_remaining = radiation_tick_interval
	_record_radiation_debug_event(&"apply", {
		"added_stacks": stack_count,
		"stacks_after": radiation_stack_entries.size(),
		"damage_per_stack": damage_per_stack,
	})
	var source_tower := (
		attack_context.get_root_tower() if attack_context != null else null
	)
	if is_instance_valid(source_tower) and source_tower.has_method("notify_status_applied"):
		source_tower.notify_status_applied(self, &"radiation", attack_context)
	queue_redraw()


func _process_radiation(delta: float) -> void:
	if finished or radiation_stack_entries.is_empty():
		return
	radiation_tick_remaining -= delta
	while radiation_tick_remaining <= 0.0 and not radiation_stack_entries.is_empty():
		radiation_tick_remaining += radiation_tick_interval
		_trigger_radiation_tick()


func _trigger_radiation_tick() -> void:
	var stacks_before := radiation_stack_entries.size()
	var damage_by_source: Dictionary = {}
	for entry in radiation_stack_entries:
		var context: AttackContext = entry.get("context") as AttackContext
		var source_key := context.root_tower_instance_id if context != null else 0
		if not damage_by_source.has(source_key):
			damage_by_source[source_key] = {
				"damage": 0,
				"stack_count": 0,
				"context": context,
			}
		var source_data: Dictionary = damage_by_source[source_key]
		source_data["damage"] = int(source_data["damage"]) + int(entry["damage"])
		source_data["stack_count"] = int(source_data["stack_count"]) + 1
		damage_by_source[source_key] = source_data
	var total_tick_damage := 0
	for source_key in damage_by_source:
		if finished:
			break
		var source_data: Dictionary = damage_by_source[source_key]
		var context: AttackContext = source_data["context"] as AttackContext
		var tick_context := context
		if context != null:
			tick_context = context.derive(
				self, &"status", &"radiation_tick", true,
				{
					"radiation_tick": true,
					"radiation_stacks": int(source_data["stack_count"]),
				}
			)
		var requested_damage := int(source_data["damage"])
		total_tick_damage += apply_damage(
			requested_damage, &"radiation", false, false, tick_context
		)
	# Decay each source independently so a newer tower cannot push an older
	# tower's stacks out of the shared Radiation pool. Within each source, keep
	# the newest half of its stacks.
	var stacks_to_keep_by_source: Dictionary = {}
	for source_key in damage_by_source:
		stacks_to_keep_by_source[source_key] = floori(
			float(int(damage_by_source[source_key]["stack_count"])) * 0.5
		)
	var surviving_entries: Array[Dictionary] = []
	for entry_index in range(radiation_stack_entries.size() - 1, -1, -1):
		var entry: Dictionary = radiation_stack_entries[entry_index]
		var entry_context: AttackContext = entry.get("context") as AttackContext
		var entry_source_key := (
			entry_context.root_tower_instance_id
			if entry_context != null else 0
		)
		var remaining_to_keep := int(
			stacks_to_keep_by_source.get(entry_source_key, 0)
		)
		if remaining_to_keep <= 0:
			continue
		surviving_entries.push_front(entry)
		stacks_to_keep_by_source[entry_source_key] = remaining_to_keep - 1
	var removed_stacks := stacks_before - surviving_entries.size()
	radiation_stack_entries = surviving_entries
	_record_radiation_debug_event(&"tick", {
		"stacks_before": stacks_before,
		"damage": total_tick_damage,
		"stacks_after": radiation_stack_entries.size(),
	})
	_record_radiation_debug_event(&"decay", {
		"removed_stacks": removed_stacks,
		"stacks_after": radiation_stack_entries.size(),
	})
	queue_redraw()


func get_radiation_stacks() -> int:
	return radiation_stack_entries.size()


func get_radiation_debug_state() -> Dictionary:
	return {
		"stacks": radiation_stack_entries.size(),
		"seconds_until_tick": radiation_tick_remaining,
		"tick_interval": radiation_tick_interval,
		"events": radiation_debug_events.duplicate(true),
	}


func record_radiation_spread_event(details: Dictionary = {}) -> void:
	_record_radiation_debug_event(&"spread", details)


func record_critical_mass_trigger(details: Dictionary = {}) -> void:
	_record_radiation_debug_event(&"critical_mass", details)


func _record_radiation_debug_event(
	event_type: StringName,
	details: Dictionary
) -> void:
	var event := details.duplicate(true)
	event["type"] = event_type
	event["time_msec"] = Time.get_ticks_msec()
	radiation_debug_events.append(event)
	while radiation_debug_events.size() > 24:
		radiation_debug_events.pop_front()


func apply_slow(
	duration: float,
	attack_context: AttackContext = null,
	speed_multiplier := GameStats.SLOW_SPEED_MULTIPLIER
) -> void:
	if finished or duration <= 0.0:
		return
	speed_multiplier = clampf(speed_multiplier, 0.0, 1.0)
	var previous_duration := slow_remaining
	if duration >= slow_remaining:
		slow_context = attack_context
	active_slow_speed_multiplier = minf(
		active_slow_speed_multiplier, speed_multiplier
	)
	slow_remaining = maxf(slow_remaining, duration)
	TOWER_XP_CREDIT_SERVICE.award_control_xp(
		self,
		attack_context,
		&"slow",
		maxf(slow_remaining - previous_duration, 0.0)
	)


func clear_slow_from_context(attack_context: AttackContext) -> void:
	if attack_context == null or slow_context != attack_context:
		return
	slow_remaining = 0.0
	slow_context = null
	active_slow_speed_multiplier = 1.0


func try_begin_fisherman_pull(
	_immunity_duration: float,
	maximum_reel_distance: float = 0.0
) -> bool:
	if (
		finished
		or path_follow == null
		or fisherman_pull_active
		or fisherman_pull_immunity_remaining > 0.0
	):
		return false
	fisherman_pull_active = true
	# Preserve the protected floor from previous casts while allowing this hook
	# to reel backward by its configured maximum distance.
	fisherman_minimum_progress = maxf(
		maxf(
			fisherman_minimum_progress,
			path_follow.progress - maxf(maximum_reel_distance, 0.0)
		),
		0.0
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
	pull_distance: float,
	attack_context: AttackContext = null
) -> float:
	if finished or path_follow == null or pull_distance <= 0.0:
		return 0.0
	var path := path_follow.get_parent() as Path2D
	if path == null or path.curve == null:
		return 0.0
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
		var actual_pull := maxf(current_progress - backward_progress, 0.0)
		TOWER_XP_CREDIT_SERVICE.award_control_xp(
			self,
			attack_context,
			&"displacement",
			actual_pull / BaseTower.BUILD_CELL_SIZE
		)
		return actual_pull
	return 0.0


func apply_backward_displacement(
	distance: float,
	attack_context: AttackContext = null
) -> float:
	if finished or path_follow == null or distance <= 0.0:
		return 0.0
	var current_progress := path_follow.progress
	var new_progress := maxf(current_progress - distance, 0.0)
	path_follow.progress = new_progress
	var actual_displacement := current_progress - new_progress
	TOWER_XP_CREDIT_SERVICE.award_control_xp(
		self,
		attack_context,
		&"displacement",
		actual_displacement / BaseTower.BUILD_CELL_SIZE
	)
	return actual_displacement


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
	maximum_stacks: int,
	attack_context: AttackContext = null
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
	if attack_context != null:
		beholder_mark_context = attack_context
	queue_redraw()


func _process_beholder_damage_mark(delta: float) -> void:
	if beholder_mark_remaining <= 0.0:
		return
	beholder_mark_remaining = maxf(beholder_mark_remaining - delta, 0.0)
	if beholder_mark_remaining <= 0.0:
		beholder_mark_stacks = 0
		beholder_mark_damage_per_stack = 0.0
		beholder_mark_maximum_stacks = 0
		beholder_mark_context = null
		queue_redraw()


func get_beholder_mark_damage_multiplier() -> float:
	return 1.0 + (
		float(beholder_mark_stacks) * beholder_mark_damage_per_stack
	)


func apply_external_vulnerability(
	duration: float,
	bonus_damage: float,
	support_context: AttackContext
) -> void:
	if finished or duration <= 0.0 or bonus_damage <= 0.0 or support_context == null:
		return
	var same_source := (
		external_vulnerability_context != null
		and external_vulnerability_context.root_tower_instance_id
			== support_context.root_tower_instance_id
	)
	if (
		not same_source
		and external_vulnerability_remaining > 0.0
		and bonus_damage <= external_vulnerability_bonus + 0.0001
	):
		return
	external_vulnerability_bonus = bonus_damage
	external_vulnerability_remaining = maxf(external_vulnerability_remaining, duration)
	external_vulnerability_context = support_context
	queue_redraw()


func _process_external_vulnerability(delta: float) -> void:
	if external_vulnerability_remaining <= 0.0:
		return
	external_vulnerability_remaining = maxf(
		external_vulnerability_remaining - delta, 0.0
	)
	if external_vulnerability_remaining <= 0.0:
		external_vulnerability_bonus = 0.0
		external_vulnerability_context = null
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
		if (
			traits.has(&"boss")
			and int(attack_context.metadata.get("youre_not_special", 0)) > 0
		):
			if boss_item_stun_cooldown_remaining > 0.0:
				apply_slow(
					GameStats.BOSS_ITEM_STUN_FALLBACK_SLOW_DURATION,
					attack_context
				)
				return
			boss_item_stun_cooldown_remaining = GameStats.BOSS_ITEM_STUN_COOLDOWN
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
		if (
			emergency_brake_count > 0
			and traits.has(&"fast")
		):
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
	var added_duration := effective_duration - stun_remaining
	stun_remaining = effective_duration
	stun_context = attack_context
	stun_fatigue_tier = mini(
		stun_fatigue_tier + 1,
		STUN_FATIGUE_MULTIPLIERS.size() - 1
	)
	stun_fatigue_recovery_elapsed = 0.0
	TOWER_XP_CREDIT_SERVICE.award_control_xp(
		self, attack_context, &"stun", added_duration
	)


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
	if _context != null:
		var root_tower := _context.get_root_tower()
		if (
			is_instance_valid(root_tower)
			and root_tower.has_method("notify_enemy_killed")
		):
			root_tower.notify_enemy_killed(self, _context)
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
	if _context != null:
		var root_tower := _context.get_root_tower()
		if is_instance_valid(root_tower) and root_tower.has_method("notify_enemy_abducted"):
			root_tower.notify_enemy_abducted(self, health, _context)
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
	if (
		attack_context != null
		and bool(attack_context.metadata.get("shot_missed", false))
	):
		return 0
	var effective_armor := maxf(armor - temporary_armor_reduction, 0.0)
	var thermite_affects_armor := (
		amount > 0
		and damage_type == &"explosive"
		and effective_armor > 0.0
		and attack_context != null
		and int(attack_context.metadata.get("thermite_bombs", 0)) > 0
	)
	if amount > 0 and apply_thermite_protection_removal(
		damage_type, attack_context
	):
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
		remove_hidden_trait(attack_context)
	if (
		not is_electric_proc
		and not (
			damage_type == &"radiation"
			and attack_context != null
			and bool(attack_context.metadata.get(
				"radiation_conversion_applied", false
			))
		)
	):
		amount = apply_attack_effect_damage_modifiers(
			amount, damage_type, attack_context
		)
	if thermite_affects_armor:
		amount = maxi(roundi(
			float(amount) * GameStats.THERMITE_BOMBS_ARMORED_DAMAGE_MULTIPLIER
		), 1)
	amount = _apply_radiation_hybrid(amount, damage_type, attack_context)
	var beholder_mark_multiplier := 1.0
	if beholder_mark_remaining > 0.0 and beholder_mark_stacks > 0:
		beholder_mark_multiplier = get_beholder_mark_damage_multiplier()
		amount = maxi(
			roundi(float(amount) * beholder_mark_multiplier),
			1
		)
	var external_vulnerability_multiplier := 1.0
	if external_vulnerability_remaining > 0.0 and external_vulnerability_bonus > 0.0:
		external_vulnerability_multiplier = 1.0 + external_vulnerability_bonus
		amount = maxi(
			roundi(float(amount) * external_vulnerability_multiplier),
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
		and effective_armor > 0.0
	)
	var armor_reduction := (
		0.0
		if (ignores_armor or is_electric_proc) and not conductive_armor
		else GameStats.get_armor_damage_reduction(effective_armor, damage_type)
	)
	var final_damage := maxi(
		1,
		roundi(
			float(amount) * (
				1.0 + minf(
					effective_armor * GameStats.CONDUCTIVE_DAMAGE_PER_ARMOR,
					GameStats.CONDUCTIVE_MAXIMUM_DAMAGE_BONUS
				)
			)
			if conductive_armor
			else float(amount) * (1.0 - armor_reduction)
		)
	)
	var received_damage := mini(final_damage, health)

	health -= final_damage
	health_bar.value = health
	update_health_bar_visibility()
	credit_tower_damage(received_damage, attack_context, damage_type)
	if beholder_mark_multiplier > 1.0 and received_damage > 0:
		var assisted_damage := roundi(
			float(received_damage)
			* (beholder_mark_multiplier - 1.0)
			/ beholder_mark_multiplier
		)
		TOWER_XP_CREDIT_SERVICE.award_vulnerability_xp(
			self,
			beholder_mark_context,
			assisted_damage,
			attack_context
		)
	if external_vulnerability_multiplier > 1.0 and received_damage > 0:
		var external_assisted_damage := roundi(
			float(received_damage)
			* (external_vulnerability_multiplier - 1.0)
			/ external_vulnerability_multiplier
		)
		TOWER_XP_CREDIT_SERVICE.award_vulnerability_xp(
			self,
			external_vulnerability_context,
			external_assisted_damage,
			attack_context
		)
	if damage_type == &"electric" and not is_electric_proc and received_damage > 0:
		register_electric_hit(received_damage, attack_context)
	if health <= 0:
		if (
			(
				damage_type == &"beam"
				or (
					attack_context != null
					and StringName(attack_context.metadata.get(
						"radiation_original_damage_type", &""
					)) == &"beam"
				)
			)
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


func _apply_radiation_hybrid(
	amount: int,
	damage_type: StringName,
	attack_context: AttackContext
) -> int:
	if (
		amount <= 0
		or damage_type == &"radiation"
		or attack_context == null
		or int(attack_context.metadata.get("radiation_conversion", 0)) <= 0
		or bool(attack_context.metadata.get(
			"radiation_conversion_applied", false
		))
		# Lightning is a terminal proc. It keeps its original Electric damage
		# and cannot be converted or used to build another Lightning proc.
		or bool(attack_context.metadata.get("electric_proc", false))
		or attack_context.immediate_source_kind not in [
			&"tower", &"projectile", &"spawned_unit", &"item_proc"
		]
	):
		return amount
	var radiation_damage := maxi(roundi(
		float(amount) * GameStats.ISOTOPE_CONVERTER_RADIATION_DAMAGE_RATIO
	), 1)
	attack_context.metadata["radiation_hybrid_hit"] = true
	var radiation_context := attack_context.derive(
		self,
		&"status",
		&"converted_radiation",
		true,
		{
			"radiation_conversion_applied": true,
			"radiation_original_damage_type": damage_type,
			"radiation_original_source_kind": (
				attack_context.immediate_source_kind
			),
		}
	)
	apply_radiation(1, radiation_damage, radiation_context, 1.0)
	return maxi(roundi(
		float(amount) * GameStats.ISOTOPE_CONVERTER_DIRECT_DAMAGE_RATIO
	), 1)


func credit_tower_damage(
	actual_damage: int,
	attack_context: AttackContext,
	damage_type: StringName = &""
) -> void:
	if actual_damage <= 0 or attack_context == null:
		return
	var root_tower := attack_context.get_root_tower()
	if (
		is_instance_valid(root_tower)
		and root_tower.has_method("notify_damage_dealt")
	):
		root_tower.notify_damage_dealt(
			self, actual_damage, attack_context, damage_type
		)


func apply_temporary_armor_reduction(amount: float, duration: float) -> void:
	if amount <= 0.0 or duration <= 0.0 or armor <= 0.0:
		return
	temporary_armor_reduction = minf(
		temporary_armor_reduction + amount, armor
	)
	temporary_armor_reduction_remaining = maxf(
		temporary_armor_reduction_remaining, duration
	)


func consume_ablative_shield_hit() -> bool:
	if ablative_shield_points > 0:
		consume_projected_shield_hit()
		return true
	var provider := get_nearest_ablative_shield_provider()
	if provider == null:
		return false
	provider.consume_projected_shield_hit()
	return true


func apply_thermite_protection_removal(
	damage_type: StringName,
	attack_context: AttackContext
) -> bool:
	if (
		damage_type != &"explosive"
		or attack_context == null
		or int(attack_context.metadata.get("thermite_bombs", 0)) <= 0
	):
		return false
	var shield_provider: Node = self if ablative_shield_points > 0 else null
	if shield_provider == null:
		shield_provider = get_nearest_ablative_shield_provider()
	if shield_provider != null:
		shield_provider.remove_ablative_shield_points(
			GameStats.THERMITE_BOMBS_SHIELD_REMOVAL
		)
		return true
	if armor <= 0.0:
		return false
	armor = maxf(
		armor - float(GameStats.THERMITE_BOMBS_ARMOR_REMOVAL),
		0.0
	)
	return false


func consume_projected_shield_hit() -> void:
	if ablative_shield_points <= 0:
		return
	ablative_shield_points -= 1
	queue_redraw()


func remove_ablative_shield_points(amount: int) -> void:
	ablative_shield_points = maxi(ablative_shield_points - maxi(amount, 0), 0)
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
	var lightning_damage := roundi(
		electric_proc_damage * get_electric_proc_damage_multiplier(attack_context)
	)
	electric_hit_count = 0
	electric_proc_damage = 0.0
	if lightning_damage <= 0:
		return
	trigger_electric_lightning_proc(lightning_damage, attack_context)


func get_electric_proc_hit_requirement(attack_context: AttackContext) -> int:
	var effect_count := get_attack_effect_count(
		attack_context, &"overcharged_capacitor"
	)
	return ceili(
		float(GameStats.ELECTRIC_HITS_TO_PROC)
		* pow(GameStats.OVERCHARGED_CAPACITOR_HIT_MULTIPLIER, effect_count)
	)


func get_electric_proc_damage_multiplier(attack_context: AttackContext) -> float:
	var effect_count := get_attack_effect_count(
		attack_context, &"overcharged_capacitor"
	)
	return pow(GameStats.OVERCHARGED_CAPACITOR_DAMAGE_MULTIPLIER, effect_count)


func get_attack_effect_count(
	attack_context: AttackContext,
	effect_id: StringName
) -> int:
	if attack_context == null:
		return 0
	return maxi(int(attack_context.metadata.get(effect_id, 0)), 0)


func trigger_electric_lightning_proc(
	lightning_damage: int,
	source_context: AttackContext
) -> void:
	var has_static_discharge := (
		get_attack_effect_count(source_context, &"static_discharge") > 0
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
	# item modifiers and Brainiac sharing so the proc deals that exact amount
	# to this target only and cannot recursively build another proc.
	var primary_damage := (
		maxi(roundi(
			float(lightning_damage)
			* GameStats.STATIC_DISCHARGE_PRIMARY_DAMAGE_RATIO
		), 1)
		if has_static_discharge
		else lightning_damage
	)
	apply_damage(
		primary_damage,
		&"electric",
		true,
		false,
		proc_context
	)
	if has_static_discharge:
		apply_static_discharge(lightning_damage, proc_context)
	var chain_lightning_count := get_attack_effect_count(
		source_context, &"chain_lightning"
	)
	if chain_lightning_count > 0:
		apply_chain_lightning(
			lightning_damage, proc_context, chain_lightning_count
		)


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
	proc_context: AttackContext,
	jump_count := 1
) -> void:
	var visited_ids: Dictionary = {get_instance_id(): true}
	var previous_enemy: Node2D = self
	var jump_damage := lightning_damage
	for _jump_index in maxi(jump_count, 0):
		jump_damage = maxi(roundi(
			float(jump_damage) * GameStats.CHAIN_LIGHTNING_DAMAGE_FALLOFF
		), 1)
		var closest_enemy: Node2D
		var closest_distance := INF
		for candidate in get_tree().get_nodes_in_group("mobs"):
			if (
				visited_ids.has(candidate.get_instance_id())
				or not is_valid_electric_proc_secondary_target(candidate)
			):
				continue
			var distance := previous_enemy.global_position.distance_to(
				candidate.global_position
			)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = candidate
		if closest_enemy == null:
			break
		spawn_electric_arc_effect(
			previous_enemy.global_position, closest_enemy.global_position
		)
		var chain_context := proc_context.derive(
			previous_enemy,
			&"enemy",
			&"electric_chain_lightning",
			true,
			{"electric_proc": true}
		)
		closest_enemy.apply_damage(
			jump_damage, &"electric", true, false, chain_context
		)
		visited_ids[closest_enemy.get_instance_id()] = true
		previous_enemy = closest_enemy


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
	var source_tower := beam_context.get_root_tower()
	if (
		not is_instance_valid(source_tower)
		or not source_tower.has_method("try_trigger_microwave")
		or not source_tower.try_trigger_microwave()
	):
		return
	var explosion_damage := maxi(roundi(
		float(killing_beam_damage)
		* GameStats.MICROWAVE_KILLING_HIT_DAMAGE_MULTIPLIER
	), 1)
	var explosion_context := beam_context.derive(
		self,
		&"defeated_enemy",
		&"microwave_explosion",
		true
	)
	explosion_context = AreaDamage.prepare_explosion_context(
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
			or not AreaDamage.is_valid_explosion_target(
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


func apply_attack_effect_damage_modifiers(
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

	if damage_type == &"melee":
		var giant_killer_count := int(metadata.get("giant_killer", 0))
		if giant_killer_count > 0:
			multiplier *= (
				1.0 + (
					GameStats.GIANT_KILLER_SPECIAL_DAMAGE_MULTIPLIER - 1.0
				) * float(giant_killer_count)
				if traits.has(&"elite") or traits.has(&"boss")
				else pow(
					GameStats.GIANT_KILLER_NORMAL_DAMAGE_MULTIPLIER,
					giant_killer_count
				)
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
		var strength_count := int(metadata.get("strength_in_numbers", 0))
		if strength_count > 0:
			multiplier *= (
				1.0
				+ GameStats.STRENGTH_IN_NUMBERS_DAMAGE_PER_NEIGHBOR
					* float(int(metadata.get("nearby_melee_towers", 0)))
					* float(strength_count)
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
		damage_type == &"electric"
		and armor <= 0.0
		and int(metadata.get("conductive", 0)) > 0
	):
		multiplier *= GameStats.CONDUCTIVE_UNARMORED_DAMAGE_MULTIPLIER

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


func add_global_reveal_source(
	source: Node,
	attack_context: AttackContext = null
) -> void:
	if not traits.has(&"hidden") or not is_instance_valid(source):
		return
	var was_already_revealed := global_reveal_sources.has(source.get_instance_id())
	global_reveal_sources[source.get_instance_id()] = weakref(source)
	if not was_already_revealed:
		TOWER_XP_CREDIT_SERVICE.award_reveal_xp(self, attack_context)


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


func remove_hidden_trait(attack_context: AttackContext = null) -> void:
	if traits.has(&"hidden"):
		TOWER_XP_CREDIT_SERVICE.award_reveal_xp(self, attack_context)
	traits.erase(&"hidden")
	global_reveal_sources.clear()


func claim_support_xp(
	tower_instance_id: int,
	effect_id: StringName,
	requested_xp: float,
	maximum_xp: float
) -> float:
	if tower_instance_id <= 0 or requested_xp <= 0.0 or maximum_xp <= 0.0:
		return 0.0
	var key := "%d:%s" % [tower_instance_id, effect_id]
	var previously_awarded := float(support_xp_awarded_by_source.get(key, 0.0))
	var awarded := minf(requested_xp, maxf(maximum_xp - previously_awarded, 0.0))
	if awarded <= 0.0:
		return 0.0
	support_xp_awarded_by_source[key] = previously_awarded + awarded
	return awarded
