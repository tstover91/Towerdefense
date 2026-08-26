class_name BaseTower
extends Node2D

const GameStats = preload("res://stat_database.gd")
const DEFAULT_PROJECTILE_SCENE = preload("res://projectile.tscn")
const ATTACK_COMPONENT_REGISTRY = preload(
	"res://tower_attacks/tower_attack_component_registry.gd"
)
const TOWER_MENU_CONTROLLER = preload(
	"res://tower_ui/tower_menu_controller.gd"
)
const TOWER_TARGETING_CONTROLLER = preload(
	"res://tower_combat/tower_targeting_controller.gd"
)
const TOWER_ATTACK_DELIVERY_CONTROLLER = preload(
	"res://tower_combat/tower_attack_delivery_controller.gd"
)
const TOWER_STATS_CONTROLLER = preload(
	"res://tower_stats/tower_stats_controller.gd"
)
const TOWER_PROGRESSION_CONTROLLER = preload(
	"res://tower_progression/tower_progression_controller.gd"
)
const TOWER_INSTANCE_PROGRESSION = preload(
	"res://tower_progression/tower_instance_progression.gd"
)
const TOWER_XP_CREDIT_SERVICE = preload(
	"res://tower_progression/tower_xp_credit_service.gd"
)
const TOWER_ITEM_CONTROLLER = preload(
	"res://tower_items/tower_item_controller.gd"
)
const RANGE_PIXELS_PER_UNIT := 12.9
const BUILD_CELL_SIZE := GameStats.BUILD_CELL_SIZE
const BEAM_HIT_HALF_WIDTH := 2.5
const DEFAULT_BEAM_TURN_SPEED_DEGREES := 720.0
const TYPE_TECHNOLOGY: StringName = &"technology"
const TYPE_BIOLOGICAL: StringName = &"biological"

const DAMAGE_BALLISTIC: StringName = &"ballistic"
const DAMAGE_BEAM: StringName = &"beam"
const DAMAGE_EXPLOSIVE: StringName = &"explosive"
const DAMAGE_MELEE: StringName = &"melee"
const DAMAGE_ELECTRIC: StringName = &"electric"

const BONUS_CRITICAL: StringName = &"critical"
const BONUS_PSIONIC: StringName = &"psionic"
const BONUS_REVEAL: StringName = &"reveal"
const BONUS_PIERCE: StringName = &"pierce"
const BONUS_STUN: StringName = &"stun"
const BONUS_SPAWNER: StringName = &"spawner"

enum TargetMode {
	FIRST,
	LAST,
	LOWEST_HEALTH,
	HIGHEST_HEALTH,
}

enum DroneTargetMode {
	DISTRIBUTED,
	FOCUS_MAX_HEALTH,
}

enum MenuAction {
	NONE,
	UPGRADE,
	SELL,
}



signal tower_confirmed(tower: Node2D)
signal tower_cancelled(tower: Node2D)
signal tower_sold(tower: Node2D)

var type_tags: Array[StringName] = []
var damage_tags: Array[StringName] = []
var bonus_tags: Array[StringName] = []
var pierce_count := 0
@export var target_mode: TargetMode = TargetMode.FIRST
var drone_target_mode: DroneTargetMode:
	get:
		return get_drone_target_mode()
	set(value):
		if attack_component != null:
			attack_component.set_drone_target_mode(value)
@export var tower_id: StringName = GameStats.DEFAULT_TOWER_ID
@export var projectile_scene: PackedScene = DEFAULT_PROJECTILE_SCENE
@onready var tower_area: Area2D = $Tower
@onready var visual_sprite: Sprite2D = $Sprite2D
@onready var rotator: Node2D = $Rotator
@onready var muzzle: Marker2D = $Rotator/Muzzle
@onready var damage_timer: Timer = $Timer
var loaded_attack_interval := 1.0
var tower_level := 0
var purchase_price := -1
var damage: int
var damage_type: StringName = &""
var critical_chance := GameStats.DEFAULT_CRITICAL_CHANCE
var critical_multiplier := GameStats.DEFAULT_CRITICAL_MULTIPLIER
var noncritical_damage_multiplier := 1.0
var last_attack_roll_was_critical := false
var last_attack_roll_missed := false
var miss_chance := 0.0
var relentless_target_instance_id := 0
var relentless_stacks := 0
var pierce_loses_no_power := false
var slow_duration := 0.0
var stun_duration := 0.0
var stun_affects_bosses := false
var bounce_count := 0
var bounce_range_pixels := 0.0
var infinite_pierce := false
var inherent_infinite_pierce := false
var continuous_beam_enabled := false
var beam_aim_direction := Vector2.RIGHT
var beam_has_aim := false
var beam_turn_speed_radians := deg_to_rad(DEFAULT_BEAM_TURN_SPEED_DEGREES)
var beam_hit_half_width_pixels := BEAM_HIT_HALF_WIDTH
var base_beam_hit_half_width_pixels := BEAM_HIT_HALF_WIDTH
var death_ray_overcharge_enabled := false
var death_ray_cycle_elapsed := 0.0
var death_ray_overcharge_active := false
var projectile_count := 1
var volley_width_pixels := 0.0
var volley_stagger := 0.0
var purchased_paths: Array[StringName] = []
var dual_path_relic_source: StringName = &""
var pending_path_choice: StringName = &""
var pending_evolution_choice: StringName = &""
var delivery_type: StringName = GameStats.DELIVERY_HITSCAN
var impact_mode: StringName = GameStats.IMPACT_PRIMARY
var projectile_speed := 600.0
var splash_radius_pixels := 0.0
var footprint_size_pixels := Vector2(BUILD_CELL_SIZE, BUILD_CELL_SIZE)
var target: Node2D = null
var mobs_in_range: Array = []
var attack_on_cooldown := false
var immediate_attack_pending := false
var selected := false
var is_placed := false
var pending_action: MenuAction = MenuAction.NONE
var range_radius_pixels := 0.0
var upgrade_range_radius_pixels := -1.0
var range_preview_visible := false
var range_preview_valid := true
var relic_highlight_active := false
var relic_highlight_affected := false
var aim_direction := Vector2.RIGHT
var main: Node
var spawn_rng := RandomNumberGenerator.new()
var attack_component: TowerAttackComponent
var menu_controller: TowerMenuController
var targeting_controller: TowerTargetingController
var attack_delivery_controller: TowerAttackDeliveryController
var stats_controller: TowerStatsController
var progression_controller: Node
var item_controller: Node
var instance_progression: RefCounted
var progression_ui_refresh_pending := false


func _draw() -> void:
	draw_active_beam()
	if attack_component != null:
		attack_component.draw_attack_visuals()
	if death_ray_overcharge_active and is_placed:
		draw_arc(
			Vector2.ZERO,
			maxf(footprint_size_pixels.length() * 0.32, 14.0),
			0.0,
			TAU,
			32,
			Color(0.35, 0.9, 1.0, 0.95),
			3.0,
			true
		)
	if relic_highlight_active and relic_highlight_affected and is_placed:
		var highlight_radius := maxf(
			footprint_size_pixels.length() * 0.56,
			28.0
		)
		draw_arc(
			Vector2.ZERO,
			highlight_radius + 3.0,
			0.0,
			TAU,
			40,
			Color("20213a"),
			8.0,
			true
		)
		draw_arc(
			Vector2.ZERO,
			highlight_radius,
			0.0,
			TAU,
			40,
			Color("9be33b"),
			5.0,
			true
		)
	if not range_preview_visible:
		return

	if not is_placed:
		var footprint_rect := Rect2(-footprint_size_pixels * 0.5, footprint_size_pixels)
		var footprint_fill := Color(0.2, 0.85, 0.3, 0.2)
		var footprint_border := Color(0.25, 1.0, 0.35, 0.95)
		if not range_preview_valid:
			footprint_fill = Color(1.0, 0.15, 0.15, 0.22)
			footprint_border = Color(1.0, 0.2, 0.2, 0.95)
		draw_rect(footprint_rect, footprint_fill, true)
		draw_rect(footprint_rect, footprint_border, false, 2.0)

	if (
		upgrade_range_radius_pixels >= 0.0
		and not uses_finite_directional_range()
	):
		draw_circle(
			Vector2.ZERO,
			upgrade_range_radius_pixels,
			Color(1.0, 0.75, 0.15, 0.12)
		)
		draw_arc(
			Vector2.ZERO,
			upgrade_range_radius_pixels,
			0.0,
			TAU,
			96,
			Color(1.0, 0.8, 0.2, 0.9),
			2.0,
			true
		)

	var fill_color := Color(0.2, 0.85, 0.3, 0.16)
	var border_color := Color(0.25, 1.0, 0.35, 0.8)

	if not range_preview_valid:
		fill_color = Color(1.0, 0.15, 0.15, 0.16)
		border_color = Color(1.0, 0.2, 0.2, 0.8)
	if uses_directional_aim():
		var directional_distance := get_directional_max_distance()
		if uses_finite_directional_range():
			directional_distance = (
				upgrade_range_radius_pixels
				if upgrade_range_radius_pixels >= 0.0
				else range_radius_pixels
			)
		if uses_tracking_cone():
			var half_cone := deg_to_rad(get_tracking_cone_degrees() * 0.5)
			if uses_finite_directional_range():
				var cone_points := PackedVector2Array([Vector2.ZERO])
				for point_index in range(33):
					var point_ratio := float(point_index) / 32.0
					cone_points.append(
						aim_direction.rotated(lerpf(
							-half_cone, half_cone, point_ratio
						)) * directional_distance
					)
				draw_colored_polygon(cone_points, fill_color)
				draw_arc(
					Vector2.ZERO,
					directional_distance,
					aim_direction.angle() - half_cone,
					aim_direction.angle() + half_cone,
					32,
					border_color,
					2.0,
					true
				)
			for boundary_direction in [
				aim_direction.rotated(-half_cone),
				aim_direction.rotated(half_cone),
			]:
				draw_line(
					Vector2.ZERO,
					boundary_direction * (
						directional_distance
						if uses_finite_directional_range()
						else get_max_distance_in_direction(
							boundary_direction,
							global_position
						)
					),
					border_color,
					1.5,
					true
				)
		draw_line(
			Vector2.ZERO,
			aim_direction * directional_distance,
			border_color,
			3.0,
			true
		)
		return

	draw_circle(Vector2.ZERO, range_radius_pixels, fill_color)
	draw_arc(Vector2.ZERO, range_radius_pixels, 0.0, TAU, 96, border_color, 2.0, true)


func draw_active_beam() -> void:
	if not uses_continuous_beam() or not is_placed:
		return
	if not is_combat_active():
		return
	if not is_valid_target(target) or not mobs_in_range.has(target):
		return
	if not beam_has_aim:
		return
	var beam_start_world := get_continuous_beam_origin()
	var beam_direction := beam_aim_direction.normalized()
	var beam_length := get_continuous_beam_length(target, beam_start_world)
	var beam_end_world := beam_start_world + beam_direction * beam_length
	draw_beam_segment(to_local(beam_start_world), to_local(beam_end_world))


func draw_beam_segment(beam_start: Vector2, beam_end: Vector2) -> void:
	var width_multiplier := beam_hit_half_width_pixels / BEAM_HIT_HALF_WIDTH
	draw_line(
		beam_start,
		beam_end,
		Color(0.55, 0.1, 0.85, 0.35),
		7.0 * width_multiplier,
		true
	)
	draw_line(
		beam_start,
		beam_end,
		Color(0.95, 0.55, 1.0, 0.95),
		2.5 * width_multiplier,
		true
	)
	draw_circle(
		beam_end,
		4.0 * width_multiplier,
		Color(1.0, 0.75, 1.0, 0.9)
	)


func set_range_preview(value: bool, placement_is_valid := true) -> void:
	if (
		range_preview_visible == value
		and range_preview_valid == placement_is_valid
		and upgrade_range_radius_pixels < 0.0
	):
		return

	range_preview_visible = value
	range_preview_valid = placement_is_valid
	upgrade_range_radius_pixels = -1.0
	queue_redraw()


func set_relic_highlight(is_active: bool, is_affected: bool = false) -> void:
	relic_highlight_active = is_active
	relic_highlight_affected = is_active and is_affected
	if is_placed:
		visual_sprite.modulate = (
			Color.WHITE
			if not is_active or is_affected
			else Color(0.38, 0.38, 0.46, 0.58)
		)
	queue_redraw()


func show_current_range_preview() -> void:
	range_preview_visible = true
	range_preview_valid = true
	upgrade_range_radius_pixels = -1.0
	queue_redraw()


func show_upgrade_range_preview() -> void:
	if progression_controller != null:
		progression_controller.show_upgrade_range_preview()

func set_selected(value: bool) -> void:
	if menu_controller != null:
		menu_controller.set_selected(value)

func show_main_menu() -> void:
	if menu_controller != null:
		menu_controller.show_main_menu()

func show_target_menu() -> void:
	if menu_controller != null:
		menu_controller.show_target_menu()

func update_menu_buttons() -> void:
	if menu_controller != null:
		menu_controller.update_menu_buttons()


func has_path_options() -> bool:
	return progression_controller.has_path_options()


func get_path_unlock_level(path_id: StringName) -> int:
	return progression_controller.get_path_unlock_level(path_id)


func can_purchase_multiple_paths() -> bool:
	return progression_controller.can_purchase_multiple_paths()


func grant_dual_path_relic(relic_id: StringName) -> void:
	progression_controller.grant_dual_path_relic(relic_id)


func can_purchase_path(path_id: StringName, check_money := true) -> bool:
	return progression_controller.can_purchase_path(path_id, check_money)


func has_available_path_purchase() -> bool:
	return progression_controller.has_available_path_purchase()


func show_path_menu() -> void:
	if menu_controller != null:
		menu_controller.show_path_menu()


func update_path_menu() -> void:
	if menu_controller != null:
		menu_controller.update_path_menu()


func select_path_choice(path_id: StringName) -> void:
	progression_controller.select_path_choice(path_id)


func purchase_selected_path() -> void:
	progression_controller.purchase_selected_path()


func has_evolution_options() -> bool:
	return progression_controller.has_evolution_options()


func get_evolution_unlock_level(evolution_id: StringName) -> int:
	return progression_controller.get_evolution_unlock_level(evolution_id)


func can_purchase_evolution(
	evolution_id: StringName,
	check_money := true
) -> bool:
	return progression_controller.can_purchase_evolution(evolution_id, check_money)


func select_evolution_choice(evolution_id: StringName) -> void:
	progression_controller.select_evolution_choice(evolution_id)


func purchase_selected_evolution() -> void:
	progression_controller.purchase_selected_evolution()


func can_equip_item(item_id: StringName, slot_index := -1) -> bool:
	return item_controller.can_equip_item(item_id, slot_index)


func equip_item(item_id: StringName, slot_index := -1) -> bool:
	return item_controller.equip_item(item_id, slot_index)


func unequip_item(slot_index: int) -> StringName:
	return item_controller.unequip_item(slot_index)


func get_equipped_item_ids() -> Array[StringName]:
	return item_controller.get_equipped_item_ids()


func request_upgrade() -> void:
	progression_controller.handle_upgrade_pressed()


func request_sell() -> void:
	progression_controller.handle_sell_pressed()


func select_sidebar_target_mode(mode: int) -> void:
	if menu_controller != null:
		menu_controller.select_target_option(mode)


func select_aim_direction(direction_index: int) -> void:
	if menu_controller != null:
		menu_controller.select_aim_direction(direction_index)


func get_path_status_text() -> String:
	return progression_controller.get_path_status_text()

func close_menus() -> void:
	if menu_controller != null:
		menu_controller.close_menus()


func hide_action_menus() -> void:
	if menu_controller != null:
		menu_controller.hide_action_menus()


func get_sell_price() -> int:
	return progression_controller.get_sell_price()


func get_static_sell_price() -> int:
	return progression_controller.get_sell_price()

func _ready() -> void:
	spawn_rng.randomize()
	instance_progression = TOWER_INSTANCE_PROGRESSION.new(tower_id)
	instance_progression.progression_changed.connect(_on_instance_progression_changed)
	instance_progression.level_changed.connect(_on_xp_level_changed)
	configure_attack_component()
	attack_delivery_controller = TOWER_ATTACK_DELIVERY_CONTROLLER.new()
	attack_delivery_controller.name = "AttackDeliveryController"
	add_child(attack_delivery_controller)
	attack_delivery_controller.setup(self)
	stats_controller = TOWER_STATS_CONTROLLER.new()
	stats_controller.name = "StatsController"
	add_child(stats_controller)
	stats_controller.setup(self)
	progression_controller = TOWER_PROGRESSION_CONTROLLER.new()
	progression_controller.name = "ProgressionController"
	add_child(progression_controller)
	progression_controller.setup(self)
	item_controller = TOWER_ITEM_CONTROLLER.new()
	item_controller.name = "ItemController"
	add_child(item_controller)
	item_controller.setup(self)
	targeting_controller = TOWER_TARGETING_CONTROLLER.new()
	targeting_controller.name = "TargetingController"
	add_child(targeting_controller)
	targeting_controller.setup(self)
	load_base_tags()
	load_level_stats()
	menu_controller = TOWER_MENU_CONTROLLER.new()
	menu_controller.name = "MenuController"
	add_child(menu_controller)
	menu_controller.setup(self)
	if main != null:
		main.money_changed.connect(_on_main_money_changed)
		main.round_started.connect(_on_round_started)
		main.round_ended.connect(_on_round_ended)
	tower_area.body_entered.connect(_on_body_entered)
	tower_area.body_exited.connect(_on_body_exited)
	if uses_standard_spawner_system():
		damage_timer.timeout.connect(_spawn_unit)
	elif uses_shared_attack_scheduler():
		damage_timer.timeout.connect(_on_attack_timer_timeout)
	begin_placement()
	add_to_group("towers")


func configure_attack_component() -> void:
	if attack_component != null:
		attack_component.queue_free()
		attack_component = null
	attack_component = ATTACK_COMPONENT_REGISTRY.create_component(
		tower_id,
		GameStats.get_tower(tower_id),
		BONUS_SPAWNER
	)
	if attack_component == null:
		return
	attack_component.name = "AttackComponent"
	add_child(attack_component)
	attack_component.setup(self)


func uses_directional_aim() -> bool:
	return attack_component != null and attack_component.uses_directional_aim()


func uses_manual_ground_targeting() -> bool:
	return (
		attack_component != null
		and attack_component.uses_manual_ground_targeting()
	)


func begin_manual_targeting() -> void:
	if not uses_manual_ground_targeting() or main == null:
		return
	if attack_component != null:
		attack_component.begin_manual_targeting()


func cancel_manual_targeting() -> void:
	if attack_component != null:
		attack_component.cancel_manual_targeting()


func confirm_manual_target_position(world_position: Vector2) -> bool:
	return (
		attack_component.confirm_manual_target_position(world_position)
		if attack_component != null
		else false
	)


func is_valid_orbital_target_position(world_position: Vector2) -> bool:
	return (
		attack_component.is_valid_manual_target_position(world_position)
		if attack_component != null
		else false
	)


func uses_tracking_cone() -> bool:
	return (
		uses_directional_aim()
		and attack_component != null
		and attack_component.uses_tracking_cone()
	)


func uses_finite_directional_range() -> bool:
	return (
		uses_directional_aim()
		and attack_component != null
		and attack_component.uses_finite_directional_range()
	)


func get_tracking_cone_degrees() -> float:
	return (
		attack_component.get_tracking_cone_degrees()
		if attack_component != null
		else 0.0
	)


func uses_continuous_beam() -> bool:
	return (
		continuous_beam_enabled
		or (
			attack_component != null
			and attack_component.uses_continuous_beam()
		)
	)


func _on_main_money_changed(_new_amount: int) -> void:
	update_menu_buttons()


func begin_placement() -> void:
	is_placed = false
	damage_timer.stop()
	tower_area.monitoring = false
	$Tower/CollisionShape2D.disabled = true
	$clickarea.monitoring = false
	$clickarea.input_pickable = false
	$clickarea/CollisionShape2D.disabled = true


func confirm_placement() -> void:
	is_placed = true
	refresh_range_monitoring_state()
	$clickarea.monitoring = true
	$clickarea.input_pickable = true
	$clickarea/CollisionShape2D.disabled = false
	if attack_component != null:
		attack_component.on_placement_confirmed()
	refresh_reveal_relic_coverage()
	if uses_shared_attack_scheduler():
		attack_on_cooldown = false
		immediate_attack_pending = false
		damage_timer.stop()
		request_attack_if_ready()
	elif uses_standard_spawner_system():
		damage_timer.start()
	if uses_standard_spawner_system() and is_combat_active():
		call_deferred("_spawn_unit")


func load_level_stats() -> void:
	if stats_controller != null:
		stats_controller.load_level_stats()
	if attack_delivery_controller != null:
		attack_delivery_controller.invalidate_relic_metadata_cache()
	refresh_range_monitoring_state()


func get_effective_stats_for_level(level: int) -> Dictionary:
	return stats_controller.get_effective_stats_for_level(level)


func get_current_effective_stats() -> Dictionary:
	return stats_controller.get_current_effective_stats()


func apply_relic_combat_stat_modifiers(
	base_stats: Dictionary,
	for_spawned_unit: bool
) -> Dictionary:
	return stats_controller.apply_relic_combat_stat_modifiers(
		base_stats, for_spawned_unit
	)


func get_explosion_damage_multiplier() -> float:
	return stats_controller.get_explosion_damage_multiplier()


func get_explosion_radius_multiplier() -> float:
	return stats_controller.get_explosion_radius_multiplier()


func get_explosion_interval_multiplier() -> float:
	return stats_controller.get_explosion_interval_multiplier()


func get_sidebar_stats() -> Dictionary:
	return stats_controller.get_sidebar_stats()


func apply_path_stat_modifiers(base_stats: Dictionary) -> Dictionary:
	return stats_controller.apply_path_stat_modifiers(base_stats)


func apply_numeric_modifiers(
	stats: Dictionary,
	modifiers: Dictionary,
	is_multiplier: bool
) -> void:
	stats_controller.apply_numeric_modifiers(stats, modifiers, is_multiplier)


func get_main_bonus(effect: StringName) -> float:
	return stats_controller.get_main_bonus(effect)


func get_main_multiplier(effect: StringName) -> float:
	return stats_controller.get_main_multiplier(effect)


func get_owned_relic_count(relic_id: StringName) -> int:
	return stats_controller.get_owned_relic_count(relic_id)


func get_active_relic_effect_ids() -> Array[StringName]:
	return stats_controller.get_active_relic_effect_ids()


func receives_relic_effect(relic_id: StringName) -> bool:
	return stats_controller.receives_relic_effect(relic_id)


func _spawn_unit() -> void:
	if attack_component != null:
		attack_component.spawn_unit()


func schedule_spawned_unit_replacement(delay: float) -> void:
	if attack_component != null:
		attack_component.schedule_unit_replacement(delay)


func _on_round_started(_round_number: int) -> void:
	death_ray_cycle_elapsed = 0.0
	refresh_death_ray_overcharge_state()
	if attack_delivery_controller != null:
		attack_delivery_controller.invalidate_relic_metadata_cache()
	if item_controller != null:
		item_controller.reset_runtime_state()
	if attack_component != null:
		attack_component.on_round_started()
	if is_placed and uses_standard_spawner_system():
		_spawn_unit()
		damage_timer.start()


func _on_round_ended(_round_number: int) -> void:
	death_ray_cycle_elapsed = 0.0
	refresh_death_ray_overcharge_state()
	update_menu_buttons()
	if attack_component != null:
		attack_component.on_round_ended()
	queue_redraw()


func _exit_tree() -> void:
	remove_reveal_source_from_all_mobs()
	if main != null and main.has_method("finish_manual_tower_targeting"):
		main.finish_manual_tower_targeting(self)


func _apply_damage() -> void:
	if targeting_controller != null:
		targeting_controller.apply_damage()


func _on_attack_timer_timeout() -> void:
	if targeting_controller != null:
		targeting_controller.on_attack_timer_timeout()


func complete_shared_attack_cycle(did_attack: bool) -> void:
	if targeting_controller != null:
		targeting_controller.complete_shared_attack_cycle(did_attack)


func get_current_attack_interval() -> float:
	return stats_controller.get_current_attack_interval()


func add_microwave_attack_cooldown() -> void:
	call_deferred("_apply_microwave_attack_cooldown")


func notify_enemy_killed(enemy: Node, attack_context: AttackContext) -> void:
	if instance_progression != null:
		instance_progression.record_kill(
			TOWER_XP_CREDIT_SERVICE.get_kill_xp(enemy, attack_context)
		)
	if attack_component != null:
		attack_component.on_enemy_killed(enemy, attack_context)
	if item_controller != null:
		item_controller.notify_enemy_killed(enemy, attack_context)


func notify_damage_dealt(
	enemy: Node,
	actual_damage: int,
	attack_context: AttackContext
) -> void:
	if instance_progression == null or actual_damage <= 0:
		return
	instance_progression.record_damage(
		actual_damage,
		TOWER_XP_CREDIT_SERVICE.get_damage_xp(actual_damage, attack_context)
	)
	if item_controller != null:
		item_controller.notify_damage_dealt(enemy, actual_damage, attack_context)


func notify_attack_started(current_target: Node = null) -> void:
	if item_controller != null:
		item_controller.notify_attack_started(current_target)


func notify_spawned_unit_created(spawned_unit: Node) -> void:
	if item_controller != null:
		item_controller.notify_spawned_unit_created(spawned_unit)


func notify_spawned_unit_removed(
	spawned_unit: Node,
	wave_cleanup := false
) -> void:
	if item_controller != null:
		item_controller.notify_spawned_unit_removed(spawned_unit, wave_cleanup)


func notify_status_applied(
	enemy: Node,
	status_id: StringName,
	attack_context: AttackContext
) -> void:
	if item_controller != null:
		item_controller.notify_status_applied(enemy, status_id, attack_context)


func _on_instance_progression_changed() -> void:
	if not selected or progression_ui_refresh_pending:
		return
	progression_ui_refresh_pending = true
	call_deferred("_refresh_progression_ui")


func _on_xp_level_changed(new_level: int, previous_level: int) -> void:
	# A few compatibility tests and legacy tools intentionally set the old stat
	# rank directly. Do not overwrite that explicit override when XP is recorded.
	if tower_level != GameStats.get_stat_rank_for_xp_level(previous_level):
		return
	tower_level = GameStats.get_stat_rank_for_xp_level(new_level)
	load_base_tags()
	load_level_stats()


func _refresh_progression_ui() -> void:
	progression_ui_refresh_pending = false
	if (
		selected
		and main != null
		and main.has_method("show_tower_details")
	):
		main.show_tower_details(self)


func _apply_microwave_attack_cooldown() -> void:
	if not is_inside_tree() or not is_placed:
		return
	var remaining_cooldown := (
		damage_timer.time_left if not damage_timer.is_stopped() else 0.0
	)
	attack_on_cooldown = true
	damage_timer.start(remaining_cooldown + GameStats.MICROWAVE_ATTACK_COOLDOWN)


func register_relentless_primary_attack(current_target: Node2D) -> void:
	if attack_delivery_controller != null:
		attack_delivery_controller.register_relentless_primary_attack(
			current_target
		)


func reset_relentless() -> void:
	if attack_delivery_controller != null:
		attack_delivery_controller.reset_relentless()


func attack(current_target: Node2D) -> void:
	if attack_delivery_controller != null:
		attack_delivery_controller.attack(current_target)


func apply_tower_damage(
	current_target: Node,
	attack_damage: int,
	attack_damage_type: StringName,
	ignores_armor: bool,
	attack_context: AttackContext = null
) -> void:
	if attack_delivery_controller != null:
		attack_delivery_controller.apply_tower_damage(
			current_target,
			attack_damage,
			attack_damage_type,
			ignores_armor,
			attack_context
		)


func create_attack_context(
	attack_kind: StringName,
	immediate_source: Object = null,
	source_kind: StringName = &"tower",
	parent_context: AttackContext = null,
	secondary := false,
	include_critical_roll := false
) -> AttackContext:
	return attack_delivery_controller.create_attack_context(
		attack_kind,
		immediate_source,
		source_kind,
		parent_context,
		secondary,
		include_critical_roll
	)


func get_attack_relic_metadata(
	source_position: Vector2,
	source_range: float,
	source_type_tags: Array,
	source_damage_tags: Array = []
) -> Dictionary:
	return attack_delivery_controller.get_attack_relic_metadata(
		source_position, source_range, source_type_tags, source_damage_tags
	)


func get_nearby_type_tower_count(
	required_type_tag: StringName,
	maximum_footprint_gap: float
) -> int:
	return stats_controller.get_nearby_type_tower_count(
		required_type_tag, maximum_footprint_gap
	)


func get_nearby_tower_count(required_damage_tag: StringName, radius: float) -> int:
	return stats_controller.get_nearby_tower_count(required_damage_tag, radius)


func has_nearby_other_tower(radius: float) -> bool:
	return stats_controller.has_nearby_other_tower(radius)


func is_valid_neighbor_tower(candidate: Variant) -> bool:
	return stats_controller.is_valid_neighbor_tower(candidate)


func count_valid_enemies_near(origin: Vector2, radius: float) -> int:
	return attack_delivery_controller.count_valid_enemies_near(origin, radius)


func roll_attack_damage(current_target: Node2D = null) -> int:
	return attack_delivery_controller.roll_attack_damage(current_target)


func roll_critical_damage(base_damage: int, current_target: Node2D = null) -> int:
	return attack_delivery_controller.roll_critical_damage(
		base_damage, current_target
	)


func roll_guaranteed_critical_damage(base_damage: int) -> int:
	return attack_delivery_controller.roll_guaranteed_critical_damage(base_damage)


func launch_projectile(current_target: Node2D, attack_damage: int) -> void:
	if attack_delivery_controller != null:
		attack_delivery_controller.launch_projectile(
			current_target, attack_damage
		)


func launch_projectile_from_position(
	current_target: Node2D,
	launch_position: Vector2,
	destination: Vector2,
	maximum_projectile_distance: float,
	attack_damage: int,
	impact_radius: float,
	attack_ownership_context: AttackContext = null
) -> TowerProjectile:
	return attack_delivery_controller.launch_projectile_from_position(
		current_target,
		launch_position,
		destination,
		maximum_projectile_distance,
		attack_damage,
		impact_radius,
		attack_ownership_context
	)


func apply_hitscan_damage(
	current_target: Node2D,
	attack_damage: int,
	provided_context: AttackContext = null
) -> void:
	if attack_delivery_controller != null:
		attack_delivery_controller.apply_hitscan_damage(
			current_target, attack_damage, provided_context
		)


func apply_hitscan_bounces(
	starting_target: Node2D,
	starting_origin: Vector2,
	attack_damage: int,
	parent_context: AttackContext,
	hit_target_ids: Dictionary
) -> Dictionary:
	return attack_delivery_controller.apply_hitscan_bounces(
		starting_target,
		starting_origin,
		attack_damage,
		parent_context,
		hit_target_ids
	)


func get_nearest_bounce_target(
	origin: Vector2,
	excluded_target_ids: Dictionary
) -> Node2D:
	return attack_delivery_controller.get_nearest_bounce_target(
		origin, excluded_target_ids
	)


func spawn_hitscan_effect(
	start_position: Vector2,
	end_position: Vector2,
	attack_type: StringName
) -> void:
	if attack_delivery_controller != null:
		attack_delivery_controller.spawn_hitscan_effect(
			start_position, end_position, attack_type
		)


func apply_continuous_beam_tick(
	current_target: Node2D,
	attack_damage: int,
	beam_offset := 0.0
) -> void:
	if attack_delivery_controller != null:
		attack_delivery_controller.apply_continuous_beam_tick(
			current_target, attack_damage, beam_offset
		)


func ensure_continuous_beam_aim(current_target: Node2D) -> void:
	if attack_delivery_controller != null:
		attack_delivery_controller.ensure_continuous_beam_aim(current_target)


func process_continuous_beam_aim(delta: float) -> void:
	if attack_delivery_controller != null:
		attack_delivery_controller.process_continuous_beam_aim(delta)


func get_continuous_beam_origin() -> Vector2:
	return attack_delivery_controller.get_continuous_beam_origin()


func get_continuous_beam_length(
	current_target: Node2D,
	beam_origin: Vector2
) -> float:
	return attack_delivery_controller.get_continuous_beam_length(
		current_target, beam_origin
	)


func is_target_intersecting_line(
	candidate: Node2D,
	line_origin: Vector2,
	line_end: Vector2,
	line_half_width := 0.0
) -> bool:
	return attack_delivery_controller.is_target_intersecting_line(
		candidate, line_origin, line_end, line_half_width
	)


func apply_control_effects(
	current_target: Node,
	attack_context: AttackContext = null
) -> void:
	if attack_delivery_controller != null:
		attack_delivery_controller.apply_control_effects(
			current_target, attack_context
		)


func get_targets_along_line(
	origin: Vector2,
	end: Vector2,
	excluded_target: Node = null,
	line_half_width := 0.0
) -> Array[Node2D]:
	return attack_delivery_controller.get_targets_along_line(
		origin, end, excluded_target, line_half_width
	)

func _process(delta: float) -> void:
	if death_ray_overcharge_enabled:
		process_death_ray_overcharge(delta)
	update_menu_layout()
	if targeting_controller != null:
		targeting_controller.process(delta)


func is_combat_active() -> bool:
	return GameStats.is_combat_active(main)


func process_death_ray_overcharge(delta: float) -> void:
	if death_ray_overcharge_enabled and is_placed and is_combat_active():
		death_ray_cycle_elapsed = fmod(
			death_ray_cycle_elapsed + delta,
			GameStats.DEATH_RAY_CYCLE_DURATION
		)
	refresh_death_ray_overcharge_state()


func refresh_death_ray_overcharge_state() -> void:
	var was_active := death_ray_overcharge_active
	death_ray_overcharge_active = (
		death_ray_overcharge_enabled
		and is_placed
		and is_combat_active()
		and death_ray_cycle_elapsed < GameStats.DEATH_RAY_OVERCHARGE_DURATION
	)
	infinite_pierce = inherent_infinite_pierce or death_ray_overcharge_active
	beam_hit_half_width_pixels = base_beam_hit_half_width_pixels * (
		GameStats.DEATH_RAY_WIDTH_MULTIPLIER
		if death_ray_overcharge_active
		else 1.0
	)
	if death_ray_overcharge_active != was_active:
		queue_redraw()


func get_death_ray_damage_multiplier() -> float:
	return (
		GameStats.DEATH_RAY_DAMAGE_MULTIPLIER
		if death_ray_overcharge_active
		else 1.0
	)


func get_death_ray_cycle_elapsed() -> float:
	return death_ray_cycle_elapsed


func update_menu_layout() -> void:
	if menu_controller != null:
		menu_controller.update_layout()

func _on_body_entered(body: Node2D) -> void:
	if targeting_controller != null:
		targeting_controller.on_body_entered(body)

func _on_body_exited(body: Node2D) -> void:
	if targeting_controller != null:
		targeting_controller.on_body_exited(body)


func uses_shared_attack_scheduler() -> bool:
	return (
		attack_component == null
		or attack_component.uses_shared_attack_scheduler()
	)


func request_attack_if_ready() -> void:
	if targeting_controller != null:
		targeting_controller.request_attack_if_ready()


func _perform_pending_attack() -> void:
	if targeting_controller != null:
		targeting_controller.perform_pending_attack()

func is_valid_target(candidate: Variant) -> bool:
	return (
		targeting_controller.is_valid_target(candidate)
		if targeting_controller != null
		else false
	)


func is_valid_area_target(candidate: Variant) -> bool:
	return (
		targeting_controller.is_valid_area_target(candidate)
		if targeting_controller != null
		else false
	)


func refresh_reveal_relic_coverage() -> void:
	if targeting_controller != null:
		targeting_controller.refresh_reveal_relic_coverage()


func apply_reveal_relics_to_mob(mob: Node) -> void:
	if targeting_controller != null:
		targeting_controller.apply_reveal_relics_to_mob(mob)


func remove_reveal_source_from_all_mobs() -> void:
	if targeting_controller != null:
		targeting_controller.remove_reveal_source_from_all_mobs()


func _select_target() -> void:
	if targeting_controller != null:
		targeting_controller.select_target()


func select_standard_target() -> Node2D:
	return (
		targeting_controller.select_standard_target()
		if targeting_controller != null
		else null
	)


func _select_directional_target() -> void:
	if targeting_controller != null:
		targeting_controller.select_directional_target()


func get_directional_max_distance() -> float:
	return get_max_distance_in_direction(aim_direction, global_position)


func get_max_distance_in_direction(direction: Vector2, origin: Vector2) -> float:
	var viewport_size := get_viewport_rect().size
	var right_edge := viewport_size.x
	if main != null and main.has_method("get_playable_right_edge"):
		right_edge = main.get_playable_right_edge()
	var distances: Array[float] = []
	if direction.x > 0.0:
		distances.append((right_edge - origin.x) / direction.x)
	elif direction.x < 0.0:
		distances.append((0.0 - origin.x) / direction.x)
	if direction.y > 0.0:
		distances.append((viewport_size.y - origin.y) / direction.y)
	elif direction.y < 0.0:
		distances.append((0.0 - origin.y) / direction.y)
	var result := viewport_size.length()
	for distance in distances:
		if distance >= 0.0:
			result = minf(result, distance)
	return maxf(result + 32.0, 32.0)

func _on_clickarea_input_event(_viewport, event, _shape_idx) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and main != null
		and main.can_select_tower()
	):
		if (
			main.has_method("is_selecting_path_relic_tower")
			and main.is_selecting_path_relic_tower()
		):
			main.try_assign_path_relic_to_tower(self)
			return
		main.close_all_tower_menus()
		set_selected(true)

func _on_button_first_pressed() -> void:
	if menu_controller != null:
		menu_controller.select_target_option(
			DroneTargetMode.DISTRIBUTED
			if uses_drone_targeting()
			else TargetMode.FIRST
		)

func _on_button_last_pressed() -> void:
	if menu_controller != null:
		menu_controller.select_target_option(
			DroneTargetMode.FOCUS_MAX_HEALTH
			if uses_drone_targeting()
			else TargetMode.LAST
		)

func _on_button_low_pressed() -> void:
	if menu_controller != null:
		menu_controller.select_target_option(TargetMode.LOWEST_HEALTH)

func _on_button_high_pressed() -> void:
	if menu_controller != null:
		menu_controller.select_target_option(TargetMode.HIGHEST_HEALTH)

func _on_confirm_pressed() -> void:
	set_range_preview(false)
	visual_sprite.modulate = Color.WHITE
	confirm_placement()
	if menu_controller != null:
		menu_controller.hide_confirmation_menu()
	tower_confirmed.emit(self)
	
func _on_cancel_pressed() -> void:
	if menu_controller != null:
		menu_controller.hide_confirmation_menu()
	tower_cancelled.emit(self)
	queue_free()

func _on_targetmode_pressed() -> void:
	if menu_controller != null:
		menu_controller.handle_target_mode_pressed()


func _on_path_a_pressed() -> void:
	select_path_choice(&"a")


func _on_path_b_pressed() -> void:
	select_path_choice(&"b")


func _on_confirm_path_pressed() -> void:
	purchase_selected_path()


func _on_cancel_path_pressed() -> void:
	show_main_menu()
	if main != null and selected:
		main.show_tower_details(self)

func _on_upgradetower_pressed() -> void:
	if progression_controller != null:
		progression_controller.handle_upgrade_pressed()

func _on_selltower_pressed() -> void:
	if progression_controller != null:
		progression_controller.handle_sell_pressed()

func has_type_tag(tag: StringName) -> bool:
	return type_tags.has(tag)

func has_damage_tag(tag: StringName) -> bool:
	return damage_tags.has(tag)

func has_bonus_tag(tag: StringName) -> bool:
	return bonus_tags.has(tag)


func uses_standard_spawner_system() -> bool:
	return (
		attack_component != null
		and attack_component.uses_standard_spawner_system()
	)


func uses_drone_targeting() -> bool:
	return attack_component != null and attack_component.uses_drone_targeting()


func requires_range_monitoring() -> bool:
	return (
		not uses_standard_spawner_system()
		or uses_drone_targeting()
		or has_bonus_tag(BONUS_REVEAL)
	)


func refresh_range_monitoring_state() -> void:
	if not is_node_ready():
		return
	var should_monitor := is_placed and requires_range_monitoring()
	tower_area.monitoring = should_monitor
	$Tower/CollisionShape2D.disabled = not should_monitor
	if not should_monitor and not mobs_in_range.is_empty():
		remove_reveal_source_from_all_mobs()
		mobs_in_range.clear()


func get_drone_target_mode() -> DroneTargetMode:
	return (
		attack_component.get_drone_target_mode()
		if attack_component != null
		else DroneTargetMode.DISTRIBUTED
	)


func get_drone_command_radius_pixels() -> float:
	return range_radius_pixels if uses_drone_targeting() else 0.0


func is_valid_drone_command_target(candidate: Variant) -> bool:
	var command_radius := get_drone_command_radius_pixels()
	return (
		uses_drone_targeting()
		and is_valid_target(candidate)
		and global_position.distance_squared_to(candidate.global_position)
			<= command_radius * command_radius
	)


func get_drone_command_targets() -> Array[Node2D]:
	return (
		attack_component.get_drone_command_targets()
		if attack_component != null
		else []
	)


func add_type_tag(tag: StringName) -> void:
	stats_controller.add_type_tag(tag)


func add_damage_tag(tag: StringName) -> void:
	stats_controller.add_damage_tag(tag)


func add_bonus_tag(tag: StringName) -> void:
	stats_controller.add_bonus_tag(tag)


func remove_type_tag(tag: StringName) -> void:
	stats_controller.remove_type_tag(tag)


func remove_damage_tag(tag: StringName) -> void:
	stats_controller.remove_damage_tag(tag)


func remove_bonus_tag(tag: StringName) -> void:
	stats_controller.remove_bonus_tag(tag)


func set_pierce_count(value: int) -> void:
	stats_controller.set_pierce_count(value)


func add_pierce(amount := 1) -> void:
	stats_controller.set_pierce_count(pierce_count + amount)


func load_path_behaviors() -> void:
	stats_controller.load_path_behaviors()


func load_base_tags() -> void:
	stats_controller.load_base_tags()


func get_primary_damage_type() -> StringName:
	return stats_controller.get_primary_damage_type()
