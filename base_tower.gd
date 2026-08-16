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
var relentless_target_instance_id := 0
var relentless_stacks := 0
var pierce_loses_no_power := false
var slow_duration := 0.0
var stun_duration := 0.0
var stun_affects_bosses := false
var bounce_count := 0
var bounce_range_pixels := 0.0
var infinite_pierce := false
var continuous_beam_enabled := false
var beam_aim_direction := Vector2.RIGHT
var beam_has_aim := false
var beam_turn_speed_radians := deg_to_rad(DEFAULT_BEAM_TURN_SPEED_DEGREES)
var beam_hit_half_width_pixels := BEAM_HIT_HALF_WIDTH
var projectile_count := 1
var volley_width_pixels := 0.0
var volley_stagger := 0.0
var purchased_paths: Array[StringName] = []
var dual_path_relic_source: StringName = &""
var pending_path_choice: StringName = &""
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
var aim_direction := Vector2.RIGHT
var main: Node
var spawn_rng := RandomNumberGenerator.new()
var attack_component: TowerAttackComponent
var menu_controller: TowerMenuController
var targeting_controller: TowerTargetingController
var attack_delivery_controller: TowerAttackDeliveryController


func _draw() -> void:
	draw_active_beam()
	if attack_component != null:
		attack_component.draw_attack_visuals()
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

	if upgrade_range_radius_pixels >= 0.0:
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
		if uses_tracking_cone():
			var half_cone := deg_to_rad(get_tracking_cone_degrees() * 0.5)
			for boundary_direction in [
				aim_direction.rotated(-half_cone),
				aim_direction.rotated(half_cone),
			]:
				draw_line(
					Vector2.ZERO,
					boundary_direction * get_max_distance_in_direction(
						boundary_direction,
						global_position
					),
					border_color,
					1.5,
					true
				)
		draw_line(
			Vector2.ZERO,
			aim_direction * get_directional_max_distance(),
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
	if main == null or not main.round_active:
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


func show_current_range_preview() -> void:
	range_preview_visible = true
	range_preview_valid = true
	upgrade_range_radius_pixels = -1.0
	queue_redraw()


func show_upgrade_range_preview() -> void:
	if uses_directional_aim():
		show_current_range_preview()
		return
	var tower_data: Dictionary = GameStats.get_tower(tower_id)
	var levels: Array = tower_data["levels"]
	var next_level := tower_level + 1

	if next_level >= levels.size():
		show_current_range_preview()
		return

	range_preview_visible = true
	range_preview_valid = true
	upgrade_range_radius_pixels = (
		get_effective_stats_for_level(next_level)["range"]
		* RANGE_PIXELS_PER_UNIT
	)
	queue_redraw()

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
	return not GameStats.get_tower_paths(tower_id).is_empty()


func get_path_unlock_level(path_id: StringName) -> int:
	var default_level: int = GameStats.get_tower(tower_id)["levels"].size() - 1
	return int(
		GameStats.get_tower_path(tower_id, path_id).get(
			"unlock_level",
			default_level
		)
	)


func can_purchase_multiple_paths() -> bool:
	return not dual_path_relic_source.is_empty()


func grant_dual_path_relic(relic_id: StringName) -> void:
	if not dual_path_relic_source.is_empty():
		return
	dual_path_relic_source = relic_id
	update_menu_buttons()
	if main != null and selected:
		main.show_tower_details(self)


func can_purchase_path(path_id: StringName, check_money := true) -> bool:
	var paths := GameStats.get_tower_paths(tower_id)
	if not paths.has(path_id) or purchased_paths.has(path_id):
		return false
	if tower_level < get_path_unlock_level(path_id):
		return false
	if not purchased_paths.is_empty() and not can_purchase_multiple_paths():
		return false
	if check_money:
		var path_cost := int(paths[path_id].get("cost", 0))
		if main == null or main.money < path_cost:
			return false
	return true


func has_available_path_purchase() -> bool:
	for path_key in GameStats.get_tower_paths(tower_id):
		if can_purchase_path(StringName(path_key), false):
			return true
	return false


func show_path_menu() -> void:
	if menu_controller != null:
		menu_controller.show_path_menu()


func update_path_menu() -> void:
	if menu_controller != null:
		menu_controller.update_path_menu()


func select_path_choice(path_id: StringName) -> void:
	if not can_purchase_path(path_id):
		return
	pending_path_choice = path_id
	update_path_menu()
	if main != null and selected:
		main.show_tower_details(self)


func purchase_selected_path() -> void:
	if pending_path_choice.is_empty() or not can_purchase_path(pending_path_choice):
		return
	var path := GameStats.get_tower_path(tower_id, pending_path_choice)
	if not main.spend_money(int(path.get("cost", 0))):
		return
	purchased_paths.append(pending_path_choice)
	pending_path_choice = &""
	load_base_tags()
	load_level_stats()
	update_menu_buttons()
	show_main_menu()
	if main != null and selected:
		main.show_tower_details(self)


func get_path_status_text() -> String:
	if not has_path_options():
		return ""
	if purchased_paths.is_empty():
		var paths := GameStats.get_tower_paths(tower_id)
		var earliest_unlock := 999
		for path_key in paths:
			earliest_unlock = mini(
				earliest_unlock,
				get_path_unlock_level(StringName(path_key))
			)
		if tower_level < earliest_unlock:
			return "Final paths unlock at Level %d" % (earliest_unlock + 1)
		return (
			"Both final paths available"
			if can_purchase_multiple_paths()
			else "Final path available"
		)
	var names: Array[String] = []
	for path_id in purchased_paths:
		names.append(GameStats.get_tower_path(tower_id, path_id)["display_name"])
	return "Path: %s" % " + ".join(names)

func close_menus() -> void:
	if menu_controller != null:
		menu_controller.close_menus()


func hide_action_menus() -> void:
	if menu_controller != null:
		menu_controller.hide_action_menus()


func get_sell_price() -> int:
	return get_static_sell_price()


func get_static_sell_price() -> int:
	if tower_level <= 0 and purchased_paths.is_empty():
		return (
			maxi(purchase_price, 0)
			if purchase_price >= 0
			else int(GameStats.get_tower(tower_id)["placement_cost"])
		)
	var level_values: Array = GameStats.TOWER_UPGRADED_SELL_VALUES.get(tower_id, [])
	if level_values.is_empty():
		return int(GameStats.get_tower(tower_id)["placement_cost"])
	var level_index := mini(tower_level, level_values.size() - 1)
	var sell_price := int(level_values[level_index])

	var path_sell_values: Variant = (
		GameStats.TOWER_PATH_SELL_VALUE_ADDITIONS.get(tower_id, {})
	)

	for path_id in purchased_paths:
		if path_sell_values is Dictionary:
			sell_price += int(path_sell_values.get(path_id, 0))
		else:
			sell_price += int(path_sell_values)

	return sell_price

func _ready() -> void:
	spawn_rng.randomize()
	configure_attack_component()
	attack_delivery_controller = TOWER_ATTACK_DELIVERY_CONTROLLER.new()
	attack_delivery_controller.name = "AttackDeliveryController"
	add_child(attack_delivery_controller)
	attack_delivery_controller.setup(self)
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
	tower_area.monitoring = true
	$Tower/CollisionShape2D.disabled = false
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
	if uses_standard_spawner_system() and main != null and main.round_active:
		call_deferred("_spawn_unit")


func load_level_stats() -> void:
	var stats := get_effective_stats_for_level(tower_level)
	var tower_data := GameStats.get_tower(tower_id)
	var tower_texture := tower_data.get("texture") as Texture2D
	if tower_texture != null:
		visual_sprite.texture = tower_texture
	footprint_size_pixels = (
		Vector2(tower_data.get("footprint_cells", Vector2i.ONE))
		* BUILD_CELL_SIZE
	)
	var click_shape := $clickarea/CollisionShape2D.shape.duplicate() as RectangleShape2D
	click_shape.size = footprint_size_pixels
	$clickarea/CollisionShape2D.shape = click_shape
	damage = stats["damage"]
	critical_chance = clampf(
		float(stats.get("critical_chance", GameStats.DEFAULT_CRITICAL_CHANCE)),
		0.0,
		1.0
	)
	critical_multiplier = maxf(
		float(stats.get(
			"critical_multiplier",
			GameStats.DEFAULT_CRITICAL_MULTIPLIER
		)),
		1.0
	)
	noncritical_damage_multiplier = clampf(
		float(stats.get("noncritical_damage_multiplier", 1.0)),
		0.0,
		1.0
	)
	pierce_loses_no_power = bool(stats.get("pierce_loses_no_power", false))
	slow_duration = maxf(float(stats.get("slow_duration", 0.0)), 0.0)
	stun_duration = maxf(float(stats.get("stun_duration", 0.0)), 0.0)
	stun_affects_bosses = bool(stats.get("stun_affects_bosses", false))
	bounce_count = maxi(int(stats.get("bounce_count", 0)), 0)
	bounce_range_pixels = (
		maxf(float(stats.get("bounce_range", 0.0)), 0.0)
		* RANGE_PIXELS_PER_UNIT
	)
	projectile_count = maxi(int(stats.get("projectile_count", 1)), 1)
	volley_width_pixels = (
		maxf(float(stats.get("volley_width", 0.0)), 0.0)
		* RANGE_PIXELS_PER_UNIT
	)
	volley_stagger = maxf(float(stats.get("volley_stagger", 0.0)), 0.0)
	damage_type = get_primary_damage_type()
	beam_turn_speed_radians = deg_to_rad(maxf(
		float(stats.get(
			"beam_turn_speed_degrees",
			DEFAULT_BEAM_TURN_SPEED_DEGREES
		)),
		0.0
	))
	beam_hit_half_width_pixels = maxf(
		float(stats.get("beam_half_width", BEAM_HIT_HALF_WIDTH)),
		0.1
	)
	projectile_speed = stats.get("projectile_speed", 600.0)
	splash_radius_pixels = float(stats.get("splash_radius", 0.0)) * RANGE_PIXELS_PER_UNIT
	if attack_component != null:
		attack_component.load_level_stats(stats)
	load_path_behaviors()
	if not uses_standard_spawner_system():
		loaded_attack_interval = maxf(float(stats["firerate"]), 0.01)
		damage_timer.wait_time = loaded_attack_interval
	var range_shape := $Tower/CollisionShape2D.shape.duplicate() as CircleShape2D
	range_radius_pixels = float(stats.get("range", 0.0)) * RANGE_PIXELS_PER_UNIT
	range_shape.radius = range_radius_pixels
	$Tower/CollisionShape2D.shape = range_shape
	refresh_reveal_relic_coverage()
	queue_redraw()


func get_effective_stats_for_level(level: int) -> Dictionary:
	var stats := GameStats.get_tower_level(tower_id, level)
	stats = apply_path_stat_modifiers(stats)
	if uses_standard_spawner_system():
		var unit_stats: Dictionary = stats["unit_stats"].duplicate(true)
		unit_stats["damage"] = roundi(
			float(unit_stats["damage"]) + get_main_bonus(&"tower_damage_flat")
		)
		unit_stats["attack_interval"] = maxf(
			float(unit_stats["attack_interval"])
			/ get_main_multiplier(&"tower_attack_speed"),
			0.01
		)
		unit_stats["aim_radius"] = (
			float(unit_stats["aim_radius"])
			* get_main_multiplier(&"tower_range")
		)
		unit_stats = apply_relic_combat_stat_modifiers(unit_stats, true)
		stats["unit_stats"] = unit_stats
		stats["damage"] = unit_stats["damage"]
		stats["firerate"] = unit_stats["attack_interval"]
		stats["range"] = (
			float(stats["deployment_radius"])
			* get_main_multiplier(&"tower_range")
		)
		return stats
	stats["damage"] = roundi(
		float(stats["damage"]) + get_main_bonus(&"tower_damage_flat")
	)
	stats["firerate"] = maxf(
		float(stats["firerate"]) / get_main_multiplier(&"tower_attack_speed"),
		0.01
	)
	if stats.has("range"):
		stats["range"] = float(stats["range"]) * get_main_multiplier(&"tower_range")
	stats = apply_relic_combat_stat_modifiers(stats, false)
	return stats


func apply_relic_combat_stat_modifiers(
	base_stats: Dictionary,
	for_spawned_unit: bool
) -> Dictionary:
	var stats := base_stats.duplicate(true)
	var damage_key := "damage"
	var interval_key := "attack_interval" if for_spawned_unit else "firerate"
	var range_key := "aim_radius" if for_spawned_unit else "range"
	var primary_type := get_primary_damage_type()
	if has_type_tag(TYPE_TECHNOLOGY):
		var network_stacks := get_owned_relic_count(&"network_upgrade")
		if network_stacks > 0:
			var network_speed_bonus := (
				GameStats.NETWORK_UPGRADE_SPEED_PER_NEIGHBOR_PER_STACK
				* float(get_nearby_type_tower_count(
					TYPE_TECHNOLOGY,
					BUILD_CELL_SIZE
				))
				* float(network_stacks)
			)
			stats[interval_key] = maxf(
				float(stats[interval_key]) / (1.0 + network_speed_bonus),
				0.01
			)
	if (
		has_damage_tag(DAMAGE_MELEE)
		and get_owned_relic_count(&"lone_wolf") > 0
		and not has_nearby_other_tower(2.5 * BUILD_CELL_SIZE)
	):
		stats[damage_key] = maxi(roundi(
			float(stats[damage_key]) * GameStats.LONE_WOLF_DAMAGE_MULTIPLIER
		), 1)
		stats[interval_key] = maxf(
			float(stats[interval_key]) / GameStats.LONE_WOLF_ATTACK_SPEED_MULTIPLIER,
			0.01
		)
		if stats.has(range_key):
			stats[range_key] = maxf(
				float(stats[range_key]) * GameStats.LONE_WOLF_RANGE_MULTIPLIER,
				0.1
			)

	if primary_type == DAMAGE_BEAM:
		var focused_count := get_owned_relic_count(&"focused_lens")
		var wide_count := get_owned_relic_count(&"wide_lens")
		stats[damage_key] = maxi(roundi(
			float(stats[damage_key])
			* (1.0 + GameStats.FOCUSED_LENS_DAMAGE_PER_STACK * focused_count)
			* pow(GameStats.WIDE_LENS_DAMAGE_MULTIPLIER, wide_count)
		), 1)
		if stats.has(range_key):
			stats[range_key] = maxf(
				float(stats[range_key])
				* pow(GameStats.FOCUSED_LENS_RANGE_MULTIPLIER, focused_count)
				* (1.0 + GameStats.WIDE_LENS_RANGE_PER_STACK * wide_count),
				0.1
			)
		if get_owned_relic_count(&"death_ray") > 0:
			stats["beam_turn_speed_degrees"] = GameStats.DEATH_RAY_TURN_SPEED_DEGREES
			stats["infinite_pierce"] = true

	if primary_type == DAMAGE_BALLISTIC:
		var heavy_count := get_owned_relic_count(&"heavy_rounds")
		var lightweight_count := get_owned_relic_count(&"lightweight_ammo")
		stats[damage_key] = maxi(roundi(
			float(stats[damage_key])
			* pow(GameStats.HEAVY_ROUNDS_DAMAGE_MULTIPLIER, heavy_count)
			* pow(GameStats.LIGHTWEIGHT_AMMO_DAMAGE_MULTIPLIER, lightweight_count)
		), 1)
		stats[interval_key] = maxf(
			float(stats[interval_key])
			* pow(GameStats.HEAVY_ROUNDS_INTERVAL_MULTIPLIER, heavy_count)
			* pow(GameStats.LIGHTWEIGHT_AMMO_INTERVAL_MULTIPLIER, lightweight_count),
			0.01
		)
		if get_owned_relic_count(&"suppressive_fire") > 0:
			stats["slow_duration"] = maxf(
				float(stats.get("slow_duration", 0.0)),
				GameStats.SUPPRESSIVE_FIRE_DURATION
			)
		if get_owned_relic_count(&"rubber_bullets") > 0:
			stats["bounce_count"] = maxi(int(stats.get("bounce_count", 0)), 1)
			stats["bounce_range"] = maxf(
				float(stats.get("bounce_range", 0.0)),
				GameStats.RUBBER_BULLETS_BOUNCE_RANGE
			)

	if primary_type == DAMAGE_EXPLOSIVE:
		stats[damage_key] = maxi(roundi(
			float(stats[damage_key]) * get_explosion_damage_multiplier()
		), 1)
		if stats.has("splash_radius"):
			stats["splash_radius"] = (
				float(stats["splash_radius"]) * get_explosion_radius_multiplier()
			)
		stats[interval_key] = maxf(
			float(stats[interval_key]) * get_explosion_interval_multiplier(),
			0.01
		)
	if for_spawned_unit and bool(stats.get("explode_on_damage_budget", false)):
		stats["budget_explosion_radius"] = (
			float(stats.get("budget_explosion_radius", 0.0))
			* get_explosion_radius_multiplier()
		)
		stats["budget_explosion_damage_multiplier"] = (
			float(stats.get("budget_explosion_damage_multiplier", 1.0))
			* get_explosion_damage_multiplier()
		)

	if has_bonus_tag(BONUS_CRITICAL):
		stats["critical_chance"] = clampf(
			float(stats.get("critical_chance", GameStats.DEFAULT_CRITICAL_CHANCE))
			+ GameStats.LUCKY_SHOT_CHANCE_PER_STACK
				* get_owned_relic_count(&"lucky_shot"),
			0.0,
			1.0
		)
		stats["critical_multiplier"] = maxf(
			float(stats.get("critical_multiplier", GameStats.DEFAULT_CRITICAL_MULTIPLIER))
			+ (
				GameStats.GLASS_CANNON_CRITICAL_MULTIPLIER_BONUS
				if get_owned_relic_count(&"glass_cannon") > 0
				else 0.0
			)
			+ (
				GameStats.DEADEYE_CRITICAL_MULTIPLIER_BONUS
				if get_owned_relic_count(&"deadeye") > 0
				else 0.0
			),
			1.0
		)
		if get_owned_relic_count(&"glass_cannon") > 0:
			stats["noncritical_damage_multiplier"] = (
				GameStats.GLASS_CANNON_NONCRITICAL_MULTIPLIER
			)

	if has_bonus_tag(BONUS_PIERCE):
		stats["pierce_count"] = pierce_count
		stats["pierce_loses_no_power"] = (
			get_owned_relic_count(&"follow_through") > 0
		)
	if has_bonus_tag(BONUS_STUN) and get_owned_relic_count(&"youre_not_special") > 0:
		stats["stun_affects_bosses"] = true
	if for_spawned_unit:
		var inherited_bonus_tags: Array = stats.get(
			"additional_bonus_tags",
			[]
		).duplicate()
		for inherited_tag in [BONUS_CRITICAL, BONUS_PIERCE, BONUS_STUN, BONUS_REVEAL]:
			if inherited_tag == BONUS_REVEAL and uses_drone_targeting():
				continue
			if has_bonus_tag(inherited_tag) and not inherited_bonus_tags.has(inherited_tag):
				inherited_bonus_tags.append(inherited_tag)
		stats["additional_bonus_tags"] = inherited_bonus_tags
	return stats


func get_explosion_damage_multiplier() -> float:
	return (
		pow(
			GameStats.HIGH_YIELD_DAMAGE_MULTIPLIER,
			get_owned_relic_count(&"high_yield")
		)
		* pow(
			GameStats.CONCENTRATED_CHARGE_DAMAGE_MULTIPLIER,
			get_owned_relic_count(&"concentrated_charge")
		)
		* (
			GameStats.MAXIMUM_PAYLOAD_DAMAGE_MULTIPLIER
			if get_owned_relic_count(&"maximum_payload") > 0
			else 1.0
		)
	)


func get_explosion_radius_multiplier() -> float:
	return (
		pow(
			GameStats.HIGH_YIELD_RADIUS_MULTIPLIER,
			get_owned_relic_count(&"high_yield")
		)
		* pow(
			GameStats.CONCENTRATED_CHARGE_RADIUS_MULTIPLIER,
			get_owned_relic_count(&"concentrated_charge")
		)
		* (
			GameStats.MAXIMUM_PAYLOAD_RADIUS_MULTIPLIER
			if get_owned_relic_count(&"maximum_payload") > 0
			else 1.0
		)
	)


func get_explosion_interval_multiplier() -> float:
	return (
		GameStats.MAXIMUM_PAYLOAD_INTERVAL_MULTIPLIER
		if get_owned_relic_count(&"maximum_payload") > 0
		else 1.0
	)


func get_sidebar_stats() -> Dictionary:
	var tower_data := GameStats.get_tower(tower_id)
	var levels: Array = tower_data["levels"]
	var next_level := tower_level + 1
	var result := {
		"display_name": tower_data["display_name"],
		"is_placed": is_placed,
		"level": tower_level,
		"maximum_level": levels.size() - 1,
		"type_tags": type_tags.duplicate(),
		"attack_tags": damage_tags.duplicate(),
		"bonus_tags": bonus_tags.duplicate(),
		"has_next_level": next_level < levels.size(),
		"show_upgrade_info": is_placed and pending_action == MenuAction.UPGRADE,
		"path_status": get_path_status_text(),
	}

	if next_level < levels.size():
		result["next_level"] = next_level
	return result


func apply_path_stat_modifiers(base_stats: Dictionary) -> Dictionary:
	var stats := base_stats.duplicate(true)
	for path_id in purchased_paths:
		var path := GameStats.get_tower_path(tower_id, path_id)
		apply_numeric_modifiers(stats, path.get("stat_multipliers", {}), true)
		apply_numeric_modifiers(stats, path.get("stat_additions", {}), false)
		for conditional in path.get("conditional_stat_multipliers", []):
			var required_absent_path := StringName(conditional.get("unless_path", &""))
			if not required_absent_path.is_empty() and purchased_paths.has(required_absent_path):
				continue
			apply_numeric_modifiers(stats, conditional.get("values", {}), true)
		for key in path.get("stat_overrides", {}):
			stats[key] = path["stat_overrides"][key]
		for conditional in path.get("conditional_stat_overrides", []):
			var required_absent_path := StringName(conditional.get("unless_path", &""))
			if not required_absent_path.is_empty() and purchased_paths.has(required_absent_path):
				continue
			for key in conditional.get("values", {}):
				stats[key] = conditional["values"][key]

		if stats.has("unit_stats"):
			var unit_stats: Dictionary = stats["unit_stats"]
			apply_numeric_modifiers(unit_stats, path.get("unit_stat_multipliers", {}), true)
			apply_numeric_modifiers(unit_stats, path.get("unit_stat_additions", {}), false)
			for key in path.get("unit_stat_overrides", {}):
				unit_stats[key] = path["unit_stat_overrides"][key]
			stats["unit_stats"] = unit_stats
	return stats


func apply_numeric_modifiers(
	stats: Dictionary,
	modifiers: Dictionary,
	is_multiplier: bool
) -> void:
	for key in modifiers:
		if not stats.has(key):
			continue
		var original: Variant = stats[key]
		if original is int:
			stats[key] = (
				roundi(float(original) * float(modifiers[key]))
				if is_multiplier
				else int(original) + roundi(float(modifiers[key]))
			)
		elif original is float:
			stats[key] = (
				float(original) * float(modifiers[key])
				if is_multiplier
				else float(original) + float(modifiers[key])
			)


func get_main_bonus(effect: StringName) -> float:
	if main == null:
		return 0.0
	return main.get_run_bonus(effect)


func get_main_multiplier(effect: StringName) -> float:
	return 1.0 + get_main_bonus(effect)


func get_owned_relic_count(relic_id: StringName) -> int:
	if main == null or not main.has_method("get_relic_count"):
		return 0
	return int(main.get_relic_count(relic_id))


func _spawn_unit() -> void:
	if attack_component != null:
		attack_component.spawn_unit()


func schedule_spawned_unit_replacement(delay: float) -> void:
	if attack_component != null:
		attack_component.schedule_unit_replacement(delay)


func _on_round_started(_round_number: int) -> void:
	if attack_component != null:
		attack_component.on_round_started()
	if is_placed and uses_standard_spawner_system():
		_spawn_unit()
		damage_timer.start()


func _on_round_ended(_round_number: int) -> void:
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
	var interval := loaded_attack_interval
	if attack_component != null:
		interval = attack_component.modify_attack_interval(interval)

	var frenzy_stacks := get_owned_relic_count(&"frenzy")
	if has_damage_tag(DAMAGE_MELEE) and frenzy_stacks > 0:
		var enemy_count := mini(
			count_valid_enemies_near(global_position, range_radius_pixels),
			GameStats.FRENZY_MAXIMUM_ENEMY_COUNT
		)
		var speed_bonus := (
			GameStats.FRENZY_SPEED_PER_ENEMY_PER_STACK
			* float(enemy_count)
			* float(frenzy_stacks)
		)
		interval /= 1.0 + speed_bonus
	if (
		has_damage_tag(DAMAGE_MELEE)
		and get_owned_relic_count(&"relentless") > 0
		and relentless_stacks > 0
	):
		interval /= (
			1.0 + GameStats.RELENTLESS_SPEED_PER_STACK * float(relentless_stacks)
		)
	return maxf(interval, 0.01)


func register_relentless_primary_attack(current_target: Node2D) -> void:
	if (
		not has_damage_tag(DAMAGE_MELEE)
		or get_owned_relic_count(&"relentless") <= 0
		or not is_valid_target(current_target)
	):
		reset_relentless()
		return
	var current_target_id := current_target.get_instance_id()
	if current_target_id != relentless_target_instance_id:
		relentless_target_instance_id = current_target_id
		relentless_stacks = 1
	else:
		relentless_stacks = mini(
			relentless_stacks + 1,
			GameStats.RELENTLESS_MAXIMUM_STACKS
		)


func reset_relentless() -> void:
	relentless_target_instance_id = 0
	relentless_stacks = 0


func attack(current_target: Node2D) -> void:
	# Revalidate at the firing boundary. Target selection normally performs this
	# check already, but reveal can be lost between targeting updates and an
	# attack callback. In that case Hidden enemies must not produce a shot that
	# will only be rejected later by the projectile damage gate.
	if not is_valid_target(current_target):
		return
	if uses_continuous_beam():
		var beam_damage := damage
		if attack_component != null:
			beam_damage = attack_component.get_continuous_beam_damage(beam_damage)
		apply_continuous_beam_tick(
			current_target,
			roll_critical_damage(beam_damage, current_target),
			0.0
		)
		return

	if attack_component != null and attack_component.execute_raw_attack(
		current_target, damage
	):
		return
	var base_attack_damage := damage
	if attack_component != null:
		base_attack_damage = attack_component.modify_base_attack_damage(
			current_target, base_attack_damage
		)
	var attack_damage := roll_critical_damage(base_attack_damage, current_target)
	if attack_component != null and attack_component.execute_attack(
		current_target, attack_damage
	):
		return
	if delivery_type == GameStats.DELIVERY_PROJECTILE:
		launch_projectile(current_target, attack_damage)
	else:
		apply_hitscan_damage(current_target, attack_damage)


func apply_tower_damage(
	current_target: Node,
	attack_damage: int,
	attack_damage_type: StringName,
	ignores_armor: bool,
	attack_context: AttackContext = null
) -> void:
	var resolved_context := attack_context
	if resolved_context == null:
		resolved_context = create_attack_context(&"direct")
	if current_target.has_method("apply_damage_from_tower"):
		current_target.apply_damage_from_tower(
			attack_damage,
			attack_damage_type,
			ignores_armor,
			tower_id,
			resolved_context
		)
	else:
		current_target.apply_damage(
			attack_damage,
			attack_damage_type,
			ignores_armor,
			true,
			resolved_context
		)


func create_attack_context(
	attack_kind: StringName,
	immediate_source: Object = null,
	source_kind: StringName = &"tower",
	parent_context: AttackContext = null,
	secondary := false,
	include_critical_roll := false
) -> AttackContext:
	var source: Object = immediate_source if immediate_source != null else self
	if parent_context != null:
		return parent_context.derive(
			source,
			source_kind,
			attack_kind,
			secondary,
			{"was_critical": last_attack_roll_was_critical}
				if include_critical_roll
				else {}
		)
	var metadata := get_attack_relic_metadata(
		global_position,
		range_radius_pixels,
		type_tags
	)
	if include_critical_roll:
		metadata["was_critical"] = last_attack_roll_was_critical
	return AttackContext.from_tower(
		self,
		source,
		source_kind,
		attack_kind,
		metadata
	)


func get_attack_relic_metadata(
	source_position: Vector2,
	source_range: float,
	source_type_tags: Array
) -> Dictionary:
	return {
		"source_position": source_position,
		"source_range": maxf(source_range, 0.0),
		"source_type_tags": source_type_tags.duplicate(),
		"source_can_reveal": has_bonus_tag(BONUS_REVEAL),
		"enemies_in_range": count_valid_enemies_near(source_position, source_range),
		"nearby_melee_towers": mini(
			get_nearby_tower_count(DAMAGE_MELEE, 1.5 * BUILD_CELL_SIZE),
			GameStats.STRENGTH_IN_NUMBERS_MAXIMUM_NEIGHBORS
		),
		"pack_hunter": get_owned_relic_count(&"pack_hunter"),
		"predatory_instinct": get_owned_relic_count(&"predatory_instinct"),
		"interference_beam": get_owned_relic_count(&"interference_beam"),
		"microwave": get_owned_relic_count(&"microwave"),
		"hollow_point": get_owned_relic_count(&"hollow_point"),
		"long_barrel": get_owned_relic_count(&"long_barrel"),
		"point_blank": get_owned_relic_count(&"point_blank"),
		"giant_killer": get_owned_relic_count(&"giant_killer"),
		"duelist": get_owned_relic_count(&"duelist"),
		"strength_in_numbers": get_owned_relic_count(&"strength_in_numbers"),
		"crowd_pleaser": get_owned_relic_count(&"crowd_pleaser"),
		"direct_hit": get_owned_relic_count(&"direct_hit"),
		"thermite_bombs": get_owned_relic_count(&"thermite_bombs"),
		"charred_clothes": get_owned_relic_count(&"charred_clothes"),
		"conductive": get_owned_relic_count(&"conductive"),
		"pressure_point": get_owned_relic_count(&"pressure_point"),
		"big_game_control": get_owned_relic_count(&"big_game_control"),
		"emergency_brake": get_owned_relic_count(&"emergency_brake"),
	}


func get_nearby_type_tower_count(
	required_type_tag: StringName,
	maximum_footprint_gap: float
) -> int:
	var count := 0
	for candidate in get_tree().get_nodes_in_group("towers"):
		if not is_valid_neighbor_tower(candidate):
			continue
		if not candidate.has_type_tag(required_type_tag):
			continue
		var candidate_footprint := Vector2(candidate.get("footprint_size_pixels"))
		var combined_half_extents := (
			footprint_size_pixels + candidate_footprint
		) * 0.5
		var center_offset: Vector2 = (
			candidate.global_position - global_position
		).abs()
		var footprint_gap := Vector2(
			maxf(center_offset.x - combined_half_extents.x, 0.0),
			maxf(center_offset.y - combined_half_extents.y, 0.0)
		)
		if footprint_gap.length() <= maximum_footprint_gap + 1.0:
			count += 1
	return count


func get_nearby_tower_count(required_damage_tag: StringName, radius: float) -> int:
	var count := 0
	for candidate in get_tree().get_nodes_in_group("towers"):
		if not is_valid_neighbor_tower(candidate):
			continue
		if not candidate.has_damage_tag(required_damage_tag):
			continue
		if global_position.distance_to(candidate.global_position) <= radius:
			count += 1
	return count


func has_nearby_other_tower(radius: float) -> bool:
	for candidate in get_tree().get_nodes_in_group("towers"):
		if (
			is_valid_neighbor_tower(candidate)
			and global_position.distance_to(candidate.global_position) <= radius
		):
			return true
	return false


func is_valid_neighbor_tower(candidate: Variant) -> bool:
	return (
		candidate != null
		and candidate != self
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and bool(candidate.get("is_placed"))
	)


func count_valid_enemies_near(origin: Vector2, radius: float) -> int:
	var count := 0
	for mob in get_tree().get_nodes_in_group("mobs"):
		if is_valid_target(mob) and origin.distance_to(mob.global_position) <= radius:
			count += 1
	return count


func roll_attack_damage(current_target: Node2D = null) -> int:
	return roll_critical_damage(damage, current_target)


func roll_critical_damage(base_damage: int, current_target: Node2D = null) -> int:
	last_attack_roll_was_critical = false
	var current_critical_chance := critical_chance
	if (
		has_bonus_tag(BONUS_CRITICAL)
		and spawn_rng.randf() < current_critical_chance
	):
		last_attack_roll_was_critical = true
		return maxi(roundi(float(base_damage) * critical_multiplier), 1)
	return maxi(roundi(float(base_damage) * noncritical_damage_multiplier), 1)


func launch_projectile(current_target: Node2D, attack_damage: int) -> void:
	if projectile_scene == null:
		push_error("Projectile tower %s has no projectile scene." % tower_id)
		return
	if not is_valid_target(current_target):
		return

	var impact_radius := splash_radius_pixels if damage_type == DAMAGE_EXPLOSIVE else 0.0
	var projectile_target_position := current_target.global_position
	var maximum_projectile_distance := range_radius_pixels
	if infinite_pierce and impact_mode == GameStats.IMPACT_FIRST_CONTACT:
		var shot_direction := (
			current_target.global_position - muzzle.global_position
		).normalized()
		projectile_target_position = (
			muzzle.global_position
			+ shot_direction * maximum_projectile_distance
		)
	launch_projectile_from_position(
		current_target,
		muzzle.global_position,
		projectile_target_position,
		maximum_projectile_distance,
		attack_damage,
		impact_radius
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
	if projectile_scene == null:
		return null
	var projectile := projectile_scene.instantiate() as TowerProjectile
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = launch_position
	var resolved_context := attack_ownership_context
	if resolved_context == null:
		resolved_context = create_attack_context(
			&"projectile", projectile, &"projectile", null, false, true
		)
	elif resolved_context.get_immediate_source() != projectile:
		resolved_context = resolved_context.derive(
			projectile,
			&"projectile",
			resolved_context.attack_kind,
			resolved_context.is_secondary
		)
	projectile.setup(
		current_target,
		destination,
		projectile_speed,
		maximum_projectile_distance,
		attack_damage,
		damage_type,
		impact_mode,
		impact_radius,
		pierce_count,
		slow_duration,
		stun_duration,
		stun_affects_bosses,
		bounce_count,
		bounce_range_pixels,
		attack_component != null
			and attack_component.projectile_contact_explosions_enabled(),
		attack_component.projectile_contact_explosion_radius()
			if attack_component != null
			else 0.0,
		infinite_pierce,
		has_bonus_tag(BONUS_REVEAL),
		tower_id,
		false,
		pierce_loses_no_power,
		attack_component.projectile_contact_explosion_damage_multiplier()
			if attack_component != null
			else 1.0,
		resolved_context
	)
	return projectile


func apply_hitscan_damage(
	current_target: Node2D,
	attack_damage: int,
	provided_context: AttackContext = null
) -> void:
	var origin := muzzle.global_position
	var primary_position := current_target.global_position
	spawn_hitscan_effect(origin, primary_position, damage_type)
	var attack_context := provided_context
	if attack_context == null:
		attack_context = create_attack_context(
			&"hitscan", null, &"tower", null, false, true
		)
	apply_control_effects(current_target, attack_context)
	apply_tower_damage(
		current_target,
		attack_damage,
		damage_type,
		pierce_count > 0,
		attack_context
	)
	var hit_target_ids: Dictionary = {current_target.get_instance_id(): true}
	var bounce_result := apply_hitscan_bounces(
		current_target,
		origin,
		attack_damage,
		attack_context,
		hit_target_ids
	)
	var last_hit_target: Node2D = bounce_result["target"]
	var final_leg_origin: Vector2 = bounce_result["origin"]
	var final_leg_distance: float = bounce_result["maximum_distance"]
	var final_aim_offset := last_hit_target.global_position - final_leg_origin
	if pierce_count > 0 and not final_aim_offset.is_zero_approx():
		var direction := final_aim_offset.normalized()
		var pierce_origin := last_hit_target.global_position + direction * 0.01
		var end := final_leg_origin + direction * final_leg_distance
		spawn_hitscan_effect(last_hit_target.global_position, end, damage_type)
		var targets := get_targets_along_line(
			pierce_origin,
			end,
			last_hit_target
		)
		var pierced_hits := 0
		for pierced_target: Node2D in targets:
			if hit_target_ids.has(pierced_target.get_instance_id()):
				continue
			if pierced_hits >= pierce_count:
				break
			hit_target_ids[pierced_target.get_instance_id()] = true
			var pierce_context := create_attack_context(
				&"pierce",
				self,
				&"tower",
				attack_context,
				true
			)
			apply_control_effects(pierced_target, pierce_context)
			var pierced_damage := GameStats.get_piercing_damage(
				attack_damage,
				pierced_hits + 1,
				pierce_loses_no_power
			)
			apply_tower_damage(
				pierced_target,
				pierced_damage,
				damage_type,
				true,
				pierce_context
			)
			pierced_hits += 1
func apply_hitscan_bounces(
	starting_target: Node2D,
	starting_origin: Vector2,
	attack_damage: int,
	parent_context: AttackContext,
	hit_target_ids: Dictionary
) -> Dictionary:
	var result := {
		"target": starting_target,
		"origin": starting_origin,
		"maximum_distance": range_radius_pixels,
	}
	if bounce_count < 1 or bounce_range_pixels <= 0.0:
		return result
	var bounce_source := starting_target
	for _bounce_index in bounce_count:
		var bounce_target := get_nearest_bounce_target(
			bounce_source.global_position,
			hit_target_ids
		)
		if bounce_target == null:
			break
		var bounce_context := create_attack_context(
			&"bounce",
			self,
			&"tower",
			parent_context,
			true
		)
		spawn_hitscan_effect(
			bounce_source.global_position,
			bounce_target.global_position,
			damage_type
		)
		apply_control_effects(bounce_target, bounce_context)
		apply_tower_damage(
			bounce_target,
			attack_damage,
			damage_type,
			pierce_count > 0 or infinite_pierce,
			bounce_context
		)
		hit_target_ids[bounce_target.get_instance_id()] = true
		result["origin"] = bounce_source.global_position
		result["maximum_distance"] = bounce_range_pixels
		bounce_source = bounce_target
		result["target"] = bounce_source
	return result


func get_nearest_bounce_target(
	origin: Vector2,
	excluded_target_ids: Dictionary
) -> Node2D:
	var selected_target: Node2D
	var selected_distance := INF
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_target(candidate):
			continue
		if excluded_target_ids.has(candidate.get_instance_id()):
			continue
		var candidate_distance := origin.distance_to(candidate.global_position)
		if candidate_distance > bounce_range_pixels:
			continue
		if candidate_distance < selected_distance:
			selected_distance = candidate_distance
			selected_target = candidate
	return selected_target


func spawn_hitscan_effect(
	start_position: Vector2,
	end_position: Vector2,
	attack_type: StringName
) -> void:
	if HITSCAN_EFFECT_SCENE == null or get_tree().current_scene == null:
		return
	if get_tree().current_scene.has_method("spawn_hitscan_visual"):
		get_tree().current_scene.spawn_hitscan_visual(
			start_position, end_position, attack_type
		)
		return
	var effect := HITSCAN_EFFECT_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(effect)
	effect.setup(start_position, end_position, attack_type)


func apply_continuous_beam_tick(
	current_target: Node2D,
	attack_damage: int,
	beam_offset := 0.0
) -> void:
	ensure_continuous_beam_aim(current_target)
	if not beam_has_aim:
		return
	var direction := beam_aim_direction.normalized()
	var perpendicular := direction.orthogonal()
	var line_origin := get_continuous_beam_origin() + perpendicular * beam_offset
	var beam_length := get_continuous_beam_length(current_target, line_origin)
	var line_end := line_origin + direction * beam_length
	var beam_context := create_attack_context(
		&"beam_tick", null, &"tower", null, false, true
	)
	if pierce_count < 1 and not infinite_pierce:
		if not is_target_intersecting_line(
			current_target,
			line_origin,
			line_end,
			beam_hit_half_width_pixels
		):
			return
		apply_control_effects(current_target, beam_context)
		apply_tower_damage(
			current_target,
			attack_damage,
			damage_type,
			false,
			beam_context
		)
		return

	var intersected_targets := get_targets_along_line(
		line_origin,
		line_end,
		null,
		beam_hit_half_width_pixels
	)
	var maximum_hits := intersected_targets.size()
	if not infinite_pierce:
		maximum_hits = mini(maximum_hits, 1 + pierce_count)
	for index in maximum_hits:
		var hit_target := intersected_targets[index]
		apply_control_effects(hit_target)
		apply_tower_damage(
			hit_target,
			GameStats.get_piercing_damage(
				attack_damage,
				index,
				pierce_loses_no_power
			),
			damage_type,
			true,
			create_attack_context(
				&"beam_pierce",
				self,
				&"tower",
				beam_context,
				index > 0
			)
		)


func ensure_continuous_beam_aim(current_target: Node2D) -> void:
	if beam_has_aim or not is_valid_target(current_target):
		return
	var target_offset := (
		current_target.global_position - get_continuous_beam_origin()
	)
	if target_offset.is_zero_approx():
		return
	beam_aim_direction = target_offset.normalized()
	beam_has_aim = true


func process_continuous_beam_aim(delta: float) -> void:
	if not uses_continuous_beam() or not is_valid_target(target):
		return
	var target_offset := target.global_position - get_continuous_beam_origin()
	if target_offset.is_zero_approx():
		return
	var desired_direction := target_offset.normalized()
	if not beam_has_aim:
		beam_aim_direction = desired_direction
		beam_has_aim = true
	else:
		var turn_angle := beam_aim_direction.angle_to(desired_direction)
		var maximum_turn := beam_turn_speed_radians * delta
		beam_aim_direction = beam_aim_direction.rotated(
			clampf(turn_angle, -maximum_turn, maximum_turn)
		).normalized()
	rotator.rotation = beam_aim_direction.angle()


func get_continuous_beam_origin() -> Vector2:
	var default_origin := muzzle.global_position
	return (
		attack_component.get_continuous_beam_origin(default_origin)
		if attack_component != null
		else default_origin
	)


func get_continuous_beam_length(
	current_target: Node2D,
	beam_origin: Vector2
) -> float:
	if (
		pierce_count < 1
		and not infinite_pierce
		and is_valid_target(current_target)
	):
		return beam_origin.distance_to(current_target.global_position)
	return range_radius_pixels


func is_target_intersecting_line(
	candidate: Node2D,
	line_origin: Vector2,
	line_end: Vector2,
	line_half_width := 0.0
) -> bool:
	if not is_valid_target(candidate):
		return false
	var closest_point := Geometry2D.get_closest_point_to_segment(
		candidate.global_position,
		line_origin,
		line_end
	)
	var hit_radius := 12.0
	if candidate.has_method("get_projectile_hit_radius"):
		hit_radius = candidate.get_projectile_hit_radius()
	return (
		candidate.global_position.distance_to(closest_point)
		<= hit_radius + line_half_width
	)


func apply_control_effects(
	current_target: Node,
	attack_context: AttackContext = null
) -> void:
	var resolved_context := attack_context
	if resolved_context == null:
		resolved_context = create_attack_context(&"status_effect")
	if slow_duration > 0.0 and current_target.has_method("apply_slow"):
		current_target.apply_slow(slow_duration, resolved_context)
	if stun_duration > 0.0 and current_target.has_method("apply_stun"):
		current_target.apply_stun(
			stun_duration,
			stun_affects_bosses,
			resolved_context
		)


func get_targets_along_line(
	origin: Vector2,
	end: Vector2,
	excluded_target: Node = null,
	line_half_width := 0.0
) -> Array[Node2D]:
	var candidates: Array[Dictionary] = []
	var segment := end - origin
	var segment_length := segment.length()
	if segment_length <= 0.0:
		return []
	var direction := segment / segment_length

	for mob in get_tree().get_nodes_in_group("mobs"):
		if mob == excluded_target or not is_valid_target(mob):
			continue
		var distance_along_line: float = (
			mob.global_position - origin
		).dot(direction)
		if distance_along_line < 0.0 or distance_along_line > segment_length:
			continue
		var closest_point := Geometry2D.get_closest_point_to_segment(
			mob.global_position,
			origin,
			end
		)
		var hit_radius := 12.0
		if mob.has_method("get_projectile_hit_radius"):
			hit_radius = mob.get_projectile_hit_radius()
		if (
			mob.global_position.distance_to(closest_point)
			> hit_radius + line_half_width
		):
			continue
		candidates.append({
			"mob": mob,
			"distance": distance_along_line,
		})

	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["distance"]) < float(b["distance"])
	)
	var result: Array[Node2D] = []
	for candidate in candidates:
		result.append(candidate["mob"])
	return result

func _process(delta: float) -> void:
	update_menu_layout()
	if targeting_controller != null:
		targeting_controller.process(delta)


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
	var tower_data: Dictionary = GameStats.get_tower(tower_id)
	var levels: Array = tower_data["levels"]
	var next_level := tower_level + 1
	if next_level >= levels.size():
		if has_available_path_purchase():
			show_path_menu()
		return

	if pending_action != MenuAction.UPGRADE:
		pending_action = MenuAction.UPGRADE
		show_upgrade_range_preview()
		update_menu_buttons()
		if main != null and selected:
			main.show_tower_details(self)
		return

	var upgrade_cost: int = levels[next_level]["upgrade_cost"]

	if main.spend_money(upgrade_cost):
		tower_level = next_level
		load_base_tags()
		load_level_stats()

	pending_action = MenuAction.NONE
	show_current_range_preview()
	update_menu_buttons()
	if main != null and selected:
		main.show_tower_details(self)

func _on_selltower_pressed() -> void:
	if pending_action != MenuAction.SELL:
		pending_action = MenuAction.SELL
		show_current_range_preview()
		update_menu_buttons()
		if main != null and selected:
			main.show_tower_details(self)
		return

	main.add_money(get_sell_price())
	is_placed = false
	tower_sold.emit(self)
	close_menus()
	queue_free()

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


func get_drone_target_mode() -> DroneTargetMode:
	return (
		attack_component.get_drone_target_mode()
		if attack_component != null
		else DroneTargetMode.DISTRIBUTED
	)


func get_drone_command_radius_pixels() -> float:
	return range_radius_pixels if uses_drone_targeting() else 0.0


func is_valid_drone_command_target(candidate: Variant) -> bool:
	return (
		uses_drone_targeting()
		and is_valid_target(candidate)
		and global_position.distance_to(candidate.global_position)
			<= get_drone_command_radius_pixels()
	)


func get_drone_command_targets() -> Array[Node2D]:
	return (
		attack_component.get_drone_command_targets()
		if attack_component != null
		else []
	)


func add_type_tag(tag: StringName) -> void:
	if not type_tags.has(tag):
		type_tags.append(tag)


func add_damage_tag(tag: StringName) -> void:
	if not damage_tags.has(tag):
		damage_tags.append(tag)


func add_bonus_tag(tag: StringName) -> void:
	if not bonus_tags.has(tag):
		bonus_tags.append(tag)
	if tag == BONUS_PIERCE and pierce_count < 1:
		pierce_count = 1


func remove_type_tag(tag: StringName) -> void:
	type_tags.erase(tag)


func remove_damage_tag(tag: StringName) -> void:
	damage_tags.erase(tag)


func remove_bonus_tag(tag: StringName) -> void:
	bonus_tags.erase(tag)
	if tag == BONUS_PIERCE:
		pierce_count = 0


func set_pierce_count(value: int) -> void:
	pierce_count = maxi(value, 0)
	if pierce_count < 1:
		bonus_tags.erase(BONUS_PIERCE)
	elif not bonus_tags.has(BONUS_PIERCE):
		bonus_tags.append(BONUS_PIERCE)


func add_pierce(amount := 1) -> void:
	set_pierce_count(pierce_count + amount)


func load_path_behaviors() -> void:
	if attack_component != null:
		attack_component.reset_path_behaviors()
	for path_id in purchased_paths:
		var path := GameStats.get_tower_path(tower_id, path_id)
		var flags: Dictionary = path.get("behavior_flags", {})
		var values: Dictionary = path.get("behavior_values", {})
		if attack_component != null:
			attack_component.apply_path_behavior(flags, values)
		if flags.get("infinite_pierce", false):
			infinite_pierce = true
		if flags.get("continuous_beam", false):
			continuous_beam_enabled = true
	if has_damage_tag(DAMAGE_BEAM) and get_owned_relic_count(&"death_ray") > 0:
		infinite_pierce = true
	if attack_component != null:
		attack_component.finalize_path_behaviors()


func load_base_tags() -> void:
	var tower_data: Dictionary = GameStats.get_tower(tower_id)

	type_tags.clear()
	damage_tags.clear()
	bonus_tags.clear()

	for tag in tower_data.get("type_tags", []):
		type_tags.append(tag)

	for tag in tower_data.get("damage_tags", []):
		damage_tags.append(tag)

	for tag in tower_data.get("bonus_tags", []):
		bonus_tags.append(tag)

	# Apply tags gained or removed from regular tower levels.
	# These accumulate, so a tag gained at Level 3 remains active at Level 4.
	var levels: Array = tower_data.get("levels", [])

	for level_index in range(0, mini(tower_level + 1, levels.size())):
		var level_data: Dictionary = levels[level_index]

		for tag in level_data.get("add_type_tags", []):
			if not type_tags.has(tag):
				type_tags.append(tag)

		for tag in level_data.get("add_damage_tags", []):
			if not damage_tags.has(tag):
				damage_tags.append(tag)

		for tag in level_data.get("add_bonus_tags", []):
			if not bonus_tags.has(tag):
				bonus_tags.append(tag)

		for tag in level_data.get("remove_type_tags", []):
			type_tags.erase(tag)

		for tag in level_data.get("remove_damage_tags", []):
			damage_tags.erase(tag)

		for tag in level_data.get("remove_bonus_tags", []):
			bonus_tags.erase(tag)

	var loaded_pierce_count := int(tower_data.get(
		"pierce_count",
		1 if bonus_tags.has(BONUS_PIERCE) else 0
	))

	delivery_type = tower_data.get(
		"delivery_type",
		GameStats.DELIVERY_HITSCAN
	)
	impact_mode = tower_data.get(
		"impact_mode",
		GameStats.IMPACT_PRIMARY
	)

	for path_id in purchased_paths:
		var path := GameStats.get_tower_path(tower_id, path_id)

		for tag in path.get("add_type_tags", []):
			if not type_tags.has(tag):
				type_tags.append(tag)

		for tag in path.get("add_damage_tags", []):
			if not damage_tags.has(tag):
				damage_tags.append(tag)

		for tag in path.get("add_bonus_tags", []):
			if not bonus_tags.has(tag):
				bonus_tags.append(tag)

		for tag in path.get("remove_type_tags", []):
			type_tags.erase(tag)

		for tag in path.get("remove_damage_tags", []):
			damage_tags.erase(tag)

		for tag in path.get("remove_bonus_tags", []):
			bonus_tags.erase(tag)

		loaded_pierce_count += int(path.get("pierce_count_add", 0))

		if path.has("delivery_type"):
			delivery_type = path["delivery_type"]

		if path.has("impact_mode"):
			impact_mode = path["impact_mode"]

	set_pierce_count(loaded_pierce_count)

	if (
		has_damage_tag(DAMAGE_BEAM)
		and get_owned_relic_count(&"death_ray") > 0
	):
		set_pierce_count(maxi(pierce_count, 1))
		infinite_pierce = true

	if has_damage_tag(DAMAGE_BALLISTIC):
		if get_owned_relic_count(&"armor_piercing") > 0:
			add_pierce(1)

		if get_owned_relic_count(&"experimental_munitions") > 0:
			add_bonus_tag(BONUS_CRITICAL)


func get_primary_damage_type() -> StringName:
	var tower_data := GameStats.get_tower(tower_id)
	var primary_type := StringName(
		tower_data.get("primary_damage_type", damage_tags[0])
	)
	for path_id in purchased_paths:
		var path := GameStats.get_tower_path(tower_id, path_id)
		if path.has("primary_damage_type"):
			primary_type = StringName(path["primary_damage_type"])
	assert(
		damage_tags.has(primary_type),
		"Tower %s primary damage type must be one of its active tags." % tower_id
	)
	return primary_type
