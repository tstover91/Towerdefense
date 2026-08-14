class_name BaseTower
extends Node2D

const GameStats = preload("res://stat_database.gd")
const RelicEffects = preload("res://relic_combat.gd")
const DEFAULT_PROJECTILE_SCENE = preload("res://projectile.tscn")
const SPAWNED_UNIT_SCENE = preload("res://spawned_unit.tscn")
const EXPLOSION_ZONE_SCENE = preload("res://explosion_zone.tscn")
const LONGSHOT_MINE_SCENE = preload("res://longshot_mine.tscn")
const VOID_SINGULARITY_SCENE = preload("res://void_singularity.tscn")
const SOLAR_LANCE_SCENE = preload("res://solar_lance.tscn")
const SAUCER_FLYER_SCENE = preload("res://saucer_flyer.tscn")
const HITSCAN_EFFECT_SCENE = preload("res://hitscan_effect.tscn")
const RANGE_PIXELS_PER_UNIT := 12.9
const BUILD_CELL_SIZE := GameStats.BUILD_CELL_SIZE
const MENU_HALF_WIDTH := 120.0
const MENU_EDGE_MARGIN := 8.0
const GAUSS_TOWER_ID: StringName = &"gauss_repeater"
const BRAINIAC_TOWER_ID: StringName = &"brainiac"
const BRAINIAC_CONVERGENCE_RESOLVER = preload(
	"res://brainiac_convergence_resolver.gd"
)
const LONGSHOT_TOWER_ID: StringName = &"longshot"
const ORBITAL_CANNON_TOWER_ID: StringName = &"orbitalcannon"
const ENERGY_CORE_TOWER_ID: StringName = &"energycore"
const SAUCER_TOWER_ID: StringName = &"saucer"
const DRONE_DEPOT_TOWER_ID: StringName = &"dronedepot"
const VOID_CALLER_TOWER_ID: StringName = &"voidcaller"
const REAVER_TOWER_ID: StringName = &"reaver"
const BEHOLDER_TOWER_ID: StringName = &"beholder"
const SLINGER_TOWER_ID: StringName = &"slinger"
const GAUSS_LINE_HALF_WIDTH := 3.0
const BEAM_HIT_HALF_WIDTH := 2.5
const DEFAULT_BEAM_TURN_SPEED_DEGREES := 720.0
const DIRECTION_BUTTON_RADIUS := 72.0
const AIM_DIRECTIONS: Array[Vector2] = [
	Vector2(1.0, 0.0),
	Vector2(0.70710678, 0.70710678),
	Vector2(0.0, 1.0),
	Vector2(-0.70710678, 0.70710678),
	Vector2(-1.0, 0.0),
	Vector2(-0.70710678, -0.70710678),
	Vector2(0.0, -1.0),
	Vector2(0.70710678, -0.70710678),
]
const AIM_DIRECTION_ARROWS := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]

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
var drone_target_mode: DroneTargetMode = DroneTargetMode.DISTRIBUTED
@export var tower_id: StringName = GameStats.DEFAULT_TOWER_ID
@export var projectile_scene: PackedScene = DEFAULT_PROJECTILE_SCENE
@onready var tower_area: Area2D = $Tower
@onready var visual_sprite: Sprite2D = $Sprite2D
@onready var rotator: Node2D = $Rotator
@onready var muzzle: Marker2D = $Rotator/Muzzle
@onready var damage_timer: Timer = $Timer
var loaded_attack_interval := 1.0
@onready var upgrade_button: Button = $HBoxContainer/upgradetower
@onready var path_a_button: Button = $pathui/PathA
@onready var path_b_button: Button = $pathui/PathB
@onready var path_confirm_button: Button = $pathui/ConfirmPath
var tower_level := 0
var purchase_price := -1
var completed_rounds_active := 0
var qualified_for_investment_round := false
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
var dual_weapons_enabled := false
var slinger_contact_explosions_enabled := false
var slinger_contact_explosion_radius_pixels := 0.0
var slinger_contact_explosion_damage_multiplier := 1.0
var projectile_count := 1
var volley_width_pixels := 0.0
var volley_stagger := 0.0
var combo_hit_count := 1
var combo_stagger := 0.0
var active_combo_sequence := 0
var purchased_paths: Array[StringName] = []
var dual_path_relic_source: StringName = &""
var pending_path_choice: StringName = &""
var gauss_maximum_spread_degrees := 0.0
var gauss_minimum_spread_degrees := 0.0
var gauss_current_spread_degrees := 0.0
var gauss_spread_tighten_per_shot := 0.0
var gauss_spread_tighten_duration := 0.0
var gauss_spread_recovery_delay := 0.0
var gauss_spread_recovery_per_second := 0.0
var gauss_time_without_target := 0.0
var gauss_spread_initialized := false
var gauss_overclock_enabled := false
var gauss_overclock_elapsed := 0.0
var gauss_overclock_max_speed_bonus := 0.0
var gauss_overclock_ramp_duration := 3.0
var gauss_overclock_decay_duration := 1.0
var gauss_heavy_shot_enabled := false
var gauss_heavy_shot_interval := 0.0
var gauss_heavy_shot_remaining := 0.0
var gauss_heavy_shot_damage_multiplier := 1.0
var gauss_heavy_shot_speed_multiplier := 1.0
var gauss_tracking_cone_enabled := false
var gauss_tracking_cone_degrees := 45.0
var beholder_death_explosion_enabled := false
var beholder_death_explosion_radius_pixels := 0.0
var beholder_death_explosion_damage_multiplier := 1.0
var beholder_ramping_beam_enabled := false
var beholder_beam_ramp_start_multiplier := 1.0
var beholder_beam_ramp_step_multiplier := 0.0
var beholder_beam_ramp_step_interval := 0.5
var beholder_beam_ramp_max_multiplier := 1.0
var beholder_beam_lock_elapsed := 0.0
var beholder_beam_lock_target_id := 0
var beholder_observed_target: Node2D
var reaver_time_bubble_enabled := false
var reaver_time_bubble_active_duration := 3.0
var reaver_time_bubble_cooldown := 7.0
var reaver_time_bubble_active_remaining := 0.0
var reaver_time_bubble_cooldown_remaining := 0.0
var reaver_time_bubble_refresh_interval := 0.2
var reaver_time_bubble_slow_duration := 0.3
var reaver_time_bubble_refresh_remaining := 0.0
var reaver_assassinate_enabled := false
var brainiac_convergence_explosion_enabled := false
var brainiac_convergence_base_radius_pixels := 0.0
var brainiac_convergence_radius_per_arrival_pixels := 0.0
var brainiac_convergence_damage_per_arrival := 1.0
var brainiac_psionic_link_enabled := false
var brainiac_link_duration := 2.0
var brainiac_link_cooldown := 6.0
var brainiac_link_cooldown_remaining := 0.0
var brainiac_link_radius_pixels := 0.0
var brainiac_link_damage_share := 0.35
var longshot_distance_damage_enabled := false
var longshot_distance_minimum_multiplier := 1.0
var longshot_distance_midpoint_multiplier := 1.0
var longshot_distance_maximum_multiplier := 1.0
var longshot_mines_enabled := false
var longshot_mine_interval := 6.0
var longshot_mine_remaining := 0.0
var longshot_mine_maximum_count := 3
var longshot_mine_placement_radius_pixels := 0.0
var longshot_mine_trigger_radius_pixels := 0.0
var longshot_mine_explosion_radius_pixels := 0.0
var longshot_mine_damage_multiplier := 1.0
var active_longshot_mines: Array[Node] = []
var void_singularity_enabled := false
var void_singularity_cooldown := 10.0
var void_singularity_remaining := 0.0
var void_singularity_pull_duration := 1.0
var void_singularity_pull_radius_pixels := 0.0
var void_singularity_pull_speed := 80.0
var void_singularity_explosion_radius_pixels := 0.0
var void_singularity_damage_multiplier := 1.0
var active_void_singularities: Array[Node] = []
var orbital_minimum_range_pixels := 0.0
var orbital_has_target_position := false
var orbital_target_position := Vector2.ZERO
var orbital_targeting_active := false
var orbital_preview_position := Vector2.ZERO
var orbital_preview_valid := false
var orbital_solar_lance_enabled := false
var orbital_solar_lance_duration := 1.5
var orbital_solar_lance_tick_interval := 0.2
var orbital_solar_lance_tick_damage_multiplier := 0.25
var orbital_solar_lance_tick_end_damage_multiplier := 0.50
var orbital_solar_lance_dual_tick_damage_multiplier := 0.10
var orbital_bombardment_enabled := false
var orbital_bombardment_strike_count := 5
var orbital_bombardment_stagger := 0.15
var orbital_bombardment_spread_radius_pixels := 0.0
var orbital_bombardment_damage_multiplier := 0.38
var orbital_bombardment_radius_multiplier := 0.70
var active_solar_lances: Array[Node] = []
var energy_shockwave_enabled := false
var energy_shockwave_cooldown := 5.0
var energy_shockwave_remaining := 0.0
var energy_shockwave_damage_multiplier := 0.35
var energy_shockwave_stun_duration := 1.0
var energy_shockwave_visual_remaining := 0.0
var energy_branching_current_enabled := false
var energy_branch_additional_targets := 2
var energy_branch_range_pixels := 0.0
var energy_branch_damage_multiplier := 0.30
var energy_branch_visual_segments: Array[Dictionary] = []
var energy_branch_visual_remaining := 0.0
var saucer_twin_rockets_enabled := false
var saucer_rocket_damage_multiplier := 2.0
var saucer_rocket_interval := 3.0
var saucer_monster_drop_enabled := false
var saucer_flyer_move_speed := 165.0
var saucer_attack_radius_pixels := 0.0
var saucer_abduction_cooldown := 16.0
var saucer_abduction_radius_pixels := 0.0
var saucer_abduction_health_threshold := 0.35
var saucer_monster_stats: Dictionary = {}
var active_saucer_flyer: Node2D
var active_saucer_monster: Node
var delivery_type: StringName = GameStats.DELIVERY_HITSCAN
var impact_mode: StringName = GameStats.IMPACT_PRIMARY
var projectile_speed := 600.0
var splash_radius_pixels := 0.0
var footprint_size_pixels := Vector2(BUILD_CELL_SIZE, BUILD_CELL_SIZE)
var target: Node2D = null
var mobs_in_range: Array = []
var selected := false
var is_placed := false
var pending_action: MenuAction = MenuAction.NONE
var range_radius_pixels := 0.0
var upgrade_range_radius_pixels := -1.0
var range_preview_visible := false
var range_preview_valid := true
var aim_direction := Vector2.RIGHT
var direction_ui: Node2D
var main: Node
var spawned_unit_id: StringName = &""
var spawn_limit := 0
var deployment_radius_pixels := 0.0
var active_spawned_units: Array[Node] = []
var spawn_rng := RandomNumberGenerator.new()


func _draw() -> void:
	draw_active_beam()
	draw_reaver_time_bubble()
	draw_orbital_targeting()
	draw_energy_shockwave()
	draw_energy_branches()
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
		if uses_gauss_tracking_cone():
			var half_cone := deg_to_rad(gauss_tracking_cone_degrees * 0.5)
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
	if tower_id == ORBITAL_CANNON_TOWER_ID and orbital_minimum_range_pixels > 0.0:
		draw_circle(
			Vector2.ZERO,
			orbital_minimum_range_pixels,
			Color(1.0, 0.12, 0.12, 0.18)
		)
		draw_arc(
			Vector2.ZERO,
			orbital_minimum_range_pixels,
			0.0,
			TAU,
			64,
			Color(1.0, 0.25, 0.2, 0.9),
			2.0,
			true
		)


func draw_orbital_targeting() -> void:
	if tower_id != ORBITAL_CANNON_TOWER_ID or not is_placed:
		return
	if orbital_has_target_position:
		draw_orbital_target_symbol(
			to_local(orbital_target_position),
			Color(1.0, 0.45, 0.15, 0.75)
		)
	if orbital_targeting_active:
		var preview_color := (
			Color(0.25, 1.0, 0.35, 0.95)
			if orbital_preview_valid
			else Color(1.0, 0.15, 0.15, 0.95)
		)
		draw_orbital_target_symbol(to_local(orbital_preview_position), preview_color)


func draw_orbital_target_symbol(local_position: Vector2, color: Color) -> void:
	draw_arc(local_position, 12.0, 0.0, TAU, 32, color, 2.0, true)
	draw_line(
		local_position + Vector2(-18.0, 0.0),
		local_position + Vector2(18.0, 0.0),
		color,
		2.0,
		true
	)
	draw_line(
		local_position + Vector2(0.0, -18.0),
		local_position + Vector2(0.0, 18.0),
		color,
		2.0,
		true
	)


func draw_energy_shockwave() -> void:
	if energy_shockwave_visual_remaining <= 0.0:
		return
	var visual_duration := 0.3
	var progress_ratio := 1.0 - clampf(
		energy_shockwave_visual_remaining / visual_duration,
		0.0,
		1.0
	)
	var visual_radius := range_radius_pixels * progress_ratio
	draw_circle(Vector2.ZERO, visual_radius, Color(0.2, 0.8, 1.0, 0.10))
	draw_arc(
		Vector2.ZERO,
		visual_radius,
		0.0,
		TAU,
		64,
		Color(0.35, 0.9, 1.0, 0.9),
		3.0,
		true
	)


func draw_energy_branches() -> void:
	if energy_branch_visual_remaining <= 0.0:
		return
	for segment in energy_branch_visual_segments:
		draw_line(
			to_local(segment["start"]),
			to_local(segment["end"]),
			Color(0.35, 0.9, 1.0, 0.95),
			2.5,
			true
		)


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
	var beam_offsets: Array[float] = [0.0]
	if uses_dual_continuous_beams():
		beam_offsets.assign([-4.5, 4.5])
	var perpendicular := beam_direction.orthogonal()
	for beam_offset in beam_offsets:
		var offset_start := beam_start_world + perpendicular * beam_offset
		var beam_length := get_continuous_beam_length(target, offset_start)
		var offset_end := offset_start + beam_direction * beam_length
		draw_beam_segment(
			to_local(offset_start),
			to_local(offset_end)
		)


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


func draw_reaver_time_bubble() -> void:
	if (
		not reaver_time_bubble_enabled
		or not is_placed
		or reaver_time_bubble_active_remaining <= 0.0
	):
		return
	if main == null or not main.round_active:
		return
	draw_circle(
		Vector2.ZERO,
		range_radius_pixels,
		Color(0.20, 0.55, 1.0, 0.10)
	)
	draw_arc(
		Vector2.ZERO,
		range_radius_pixels,
		0.0,
		TAU,
		96,
		Color(0.45, 0.78, 1.0, 0.55),
		1.5,
		true
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
	selected = value
	$HBoxContainer.visible = value
	
	if value:
		show_main_menu()
		show_current_range_preview()
		if main != null:
			main.show_tower_details(self)
	else:
		close_menus()

func show_main_menu() -> void:
	pending_action = MenuAction.NONE
	pending_path_choice = &""
	$HBoxContainer.visible = true
	$targetui.visible = false
	$pathui.visible = false
	if direction_ui != null:
		direction_ui.visible = false
	update_menu_buttons()

func show_target_menu() -> void:
	pending_action = MenuAction.NONE
	pending_path_choice = &""
	show_current_range_preview()
	$HBoxContainer.visible = false
	$targetui.visible = not uses_directional_aim()
	configure_target_menu()
	$pathui.visible = false
	if direction_ui != null:
		direction_ui.visible = uses_directional_aim()

func update_sell_button() -> void:
	var sell_price := get_sell_price()

	if pending_action == MenuAction.SELL:
		$HBoxContainer/selltower.text = "Confirm\n$%d" % sell_price
	else:
		$HBoxContainer/selltower.text = "Sell\n$%d" % sell_price

func update_upgrade_button() -> void:
	var tower_data: Dictionary = GameStats.get_tower(tower_id)
	var levels: Array = tower_data["levels"]
	var next_level := tower_level + 1

	if next_level >= levels.size():
		if has_path_options() and has_available_path_purchase():
			upgrade_button.text = "Final\nPaths"
			upgrade_button.disabled = false
		else:
			upgrade_button.text = "MAX LEVEL"
			upgrade_button.disabled = true
		return

	var upgrade_cost: int = levels[next_level]["upgrade_cost"]

	if pending_action == MenuAction.UPGRADE:
		upgrade_button.text = "Confirm\n$%d" % upgrade_cost
	else:
		upgrade_button.text = "Upgrade\n$%d" % upgrade_cost

	upgrade_button.disabled = main == null or main.money < upgrade_cost


func update_menu_buttons() -> void:
	update_upgrade_button()
	update_sell_button()
	$HBoxContainer/targetmode.visible = tower_id != SAUCER_TOWER_ID
	if tower_id == SAUCER_TOWER_ID:
		$HBoxContainer/targetmode.text = "Target\nFirst"
		$HBoxContainer/targetmode.disabled = true
	elif uses_drone_targeting():
		$HBoxContainer/targetmode.text = "Drones\n%s" % get_drone_target_mode_name()
		$HBoxContainer/targetmode.disabled = false
	elif uses_standard_spawner_system():
		$HBoxContainer/targetmode.text = "Units\nAuto"
		$HBoxContainer/targetmode.disabled = true
	elif uses_manual_ground_targeting():
		$HBoxContainer/targetmode.disabled = false
		$HBoxContainer/targetmode.text = "Target\nGround"
	elif uses_directional_aim():
		$HBoxContainer/targetmode.disabled = false
		$HBoxContainer/targetmode.text = "Aim\nDirection"
	else:
		$HBoxContainer/targetmode.disabled = false
		$HBoxContainer/targetmode.text = "Target\n%s" % get_target_mode_name()


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
	if not has_path_options():
		return
	pending_action = MenuAction.NONE
	pending_path_choice = &""
	show_current_range_preview()
	$HBoxContainer.visible = false
	$targetui.visible = false
	if direction_ui != null:
		direction_ui.visible = false
	$pathui.visible = true
	update_path_menu()
	if main != null and selected:
		main.show_tower_details(self)


func update_path_menu() -> void:
	var path_ids: Array[StringName] = [&"a", &"b"]
	var buttons: Array[Button] = [path_a_button, path_b_button]
	var paths := GameStats.get_tower_paths(tower_id)
	for index in path_ids.size():
		var path_id := path_ids[index]
		var button := buttons[index]
		if not paths.has(path_id):
			button.hide()
			continue
		button.show()
		var path: Dictionary = paths[path_id]
		var path_name: String = path.get("display_name", "Path %s" % path_id.to_upper())
		var path_cost := int(path.get("cost", 0))
		button.tooltip_text = path.get("description", "")
		if purchased_paths.has(path_id):
			button.text = "%s\nOWNED" % path_name
			button.disabled = true
		elif not purchased_paths.is_empty() and not can_purchase_multiple_paths():
			button.text = "%s\nLOCKED" % path_name
			button.disabled = true
		else:
			button.text = "%s\n$%d" % [path_name, path_cost]
			button.disabled = not can_purchase_path(path_id)
		button.button_pressed = pending_path_choice == path_id
	path_confirm_button.disabled = pending_path_choice.is_empty()
	if pending_path_choice.is_empty():
		path_confirm_button.text = "Select a Path"
		$pathui/Description.text = "Select a path to view its effect."
	else:
		path_confirm_button.text = "Confirm"
		$pathui/Description.text = paths[pending_path_choice].get("description", "")


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
	pending_action = MenuAction.NONE
	pending_path_choice = &""
	selected = false
	$HBoxContainer.visible = false
	$targetui.visible = false
	$pathui.visible = false
	if direction_ui != null:
		direction_ui.visible = false
	set_range_preview(false)
	if main != null:
		main.clear_tower_details(self)


func get_target_mode_name() -> String:
	match target_mode:
		TargetMode.FIRST:
			return "First"
		TargetMode.LAST:
			return "Last"
		TargetMode.LOWEST_HEALTH:
			return "Lowest HP"
		TargetMode.HIGHEST_HEALTH:
			return "Highest HP"
	return "Unknown"


func get_drone_target_mode_name() -> String:
	return (
		"Focus"
		if drone_target_mode == DroneTargetMode.FOCUS_MAX_HEALTH
		else "Distributed"
	)


func configure_target_menu() -> void:
	var drone_menu := uses_drone_targeting()
	$targetui/button_first.text = "Distributed" if drone_menu else "First"
	$targetui/button_last.text = "Focus: Max HP" if drone_menu else "Last"
	$targetui/button_low.visible = not drone_menu
	$targetui/button_high.visible = not drone_menu


func get_sell_price() -> int:
	var normal_sell_price := get_static_sell_price()
	var investment_stacks := get_owned_relic_count(&"long_term_investment")
	var investment_bonus := floori(
		float(normal_sell_price)
		* GameStats.LONG_TERM_INVESTMENT_RATE_PER_ROUND
		* float(completed_rounds_active)
		* float(investment_stacks)
	)
	var investment_cap := floori(
		float(normal_sell_price)
		* GameStats.LONG_TERM_INVESTMENT_MAXIMUM_INVESTMENT_BONUS
	)
	return normal_sell_price + mini(investment_bonus, investment_cap)


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
	load_base_tags()
	load_level_stats()
	create_direction_ui()
	update_menu_buttons()
	if main != null:
		main.money_changed.connect(_on_main_money_changed)
		main.round_started.connect(_on_round_started)
		main.round_ended.connect(_on_round_ended)
	tower_area.body_entered.connect(_on_body_entered)
	tower_area.body_exited.connect(_on_body_exited)
	if uses_standard_spawner_system():
		damage_timer.timeout.connect(_spawn_unit)
	else:
		damage_timer.timeout.connect(_apply_damage)
	begin_placement()
	add_to_group("towers")


func create_direction_ui() -> void:
	if not uses_directional_aim():
		return
	direction_ui = Node2D.new()
	direction_ui.name = "DirectionUI"
	direction_ui.z_index = 101
	direction_ui.z_as_relative = false
	direction_ui.visible = false
	add_child(direction_ui)
	for index in AIM_DIRECTIONS.size():
		var button := Button.new()
		button.name = "Direction%d" % index
		button.text = AIM_DIRECTION_ARROWS[index]
		button.tooltip_text = get_direction_name(index)
		button.focus_mode = Control.FOCUS_NONE
		button.size = Vector2(36.0, 36.0)
		button.position = (
			AIM_DIRECTIONS[index] * DIRECTION_BUTTON_RADIUS
			- button.size * 0.5
		)
		button.pressed.connect(_on_direction_button_pressed.bind(index))
		direction_ui.add_child(button)


func _on_direction_button_pressed(index: int) -> void:
	if index < 0 or index >= AIM_DIRECTIONS.size():
		return
	aim_direction = AIM_DIRECTIONS[index]
	reset_gauss_spread()
	gauss_overclock_elapsed = 0.0
	target = null
	rotator.rotation = aim_direction.angle()
	queue_redraw()
	close_menus()


func get_direction_name(index: int) -> String:
	var names := [
		"East", "Southeast", "South", "Southwest",
		"West", "Northwest", "North", "Northeast",
	]
	return names[index]


func uses_directional_aim() -> bool:
	return tower_id == GAUSS_TOWER_ID


func uses_manual_ground_targeting() -> bool:
	return tower_id == ORBITAL_CANNON_TOWER_ID


func begin_manual_targeting() -> void:
	if not uses_manual_ground_targeting() or main == null:
		return
	orbital_targeting_active = true
	orbital_preview_position = get_global_mouse_position()
	orbital_preview_valid = is_valid_orbital_target_position(
		orbital_preview_position
	)
	$HBoxContainer.visible = false
	$targetui.visible = false
	$pathui.visible = false
	show_current_range_preview()
	main.begin_manual_tower_targeting(self)
	queue_redraw()


func cancel_manual_targeting() -> void:
	orbital_targeting_active = false
	queue_redraw()
	set_selected(false)


func confirm_manual_target_position(world_position: Vector2) -> bool:
	if not orbital_targeting_active or not is_valid_orbital_target_position(world_position):
		return false
	orbital_target_position = world_position
	orbital_has_target_position = true
	orbital_targeting_active = false
	queue_redraw()
	set_selected(false)
	return true


func is_valid_orbital_target_position(world_position: Vector2) -> bool:
	var distance_from_tower := global_position.distance_to(world_position)
	if (
		distance_from_tower < orbital_minimum_range_pixels
		or distance_from_tower > range_radius_pixels
	):
		return false
	return (
		main == null
		or not main.has_method("is_world_position_in_playable_area")
		or main.is_world_position_in_playable_area(world_position)
	)


func uses_gauss_tracking_cone() -> bool:
	return uses_directional_aim() and gauss_tracking_cone_enabled


func uses_continuous_beam() -> bool:
	return tower_id == BEHOLDER_TOWER_ID or continuous_beam_enabled


func uses_dual_continuous_beams() -> bool:
	return uses_continuous_beam() and dual_weapons_enabled


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
	ensure_saucer_flyer()
	refresh_reveal_relic_coverage()
	damage_timer.start()


func load_level_stats() -> void:
	var stats := get_effective_stats_for_level(tower_level)
	var tower_data := GameStats.get_tower(tower_id)
	var tower_texture := tower_data.get("texture") as Texture2D
	if tower_texture != null:
		visual_sprite.texture = tower_texture
	orbital_minimum_range_pixels = (
		maxf(float(tower_data.get("minimum_range", 0.0)), 0.0)
		* RANGE_PIXELS_PER_UNIT
		if tower_id == ORBITAL_CANNON_TOWER_ID
		else 0.0
	)
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
	combo_hit_count = maxi(int(stats.get("combo_hit_count", 1)), 1)
	combo_stagger = maxf(float(stats.get("combo_stagger", 0.0)), 0.0)
	if tower_id == REAVER_TOWER_ID:
		var base_level: Dictionary = tower_data["levels"][0]
		var base_attack_interval := maxf(float(base_level["firerate"]), 0.01)
		combo_stagger *= float(stats["firerate"]) / base_attack_interval
	gauss_maximum_spread_degrees = maxf(
		float(stats.get("maximum_spread_degrees", 0.0)),
		0.0
	)
	gauss_minimum_spread_degrees = clampf(
		float(stats.get("minimum_spread_degrees", 0.0)),
		0.0,
		gauss_maximum_spread_degrees
	)
	gauss_spread_tighten_duration = maxf(
		float(stats.get("spread_tighten_duration", 0.0)),
		0.0
	)
	gauss_spread_tighten_per_shot = 0.0
	if gauss_spread_tighten_duration > 0.0:
		gauss_spread_tighten_per_shot = (
			(
				gauss_maximum_spread_degrees
				- gauss_minimum_spread_degrees
			)
			* float(stats.get("firerate", 1.0))
			/ gauss_spread_tighten_duration
		)
	gauss_spread_recovery_delay = maxf(
		float(stats.get("spread_recovery_delay", 0.0)),
		0.0
	)
	gauss_spread_recovery_per_second = maxf(
		float(stats.get("spread_recovery_per_second", 0.0)),
		0.0
	)
	gauss_overclock_enabled = bool(
	stats.get("gauss_overclock_enabled", false)
)

	gauss_overclock_max_speed_bonus = maxf(
		float(stats.get("gauss_overclock_max_speed_bonus", 0.0)),
		0.0
	)

	gauss_overclock_ramp_duration = maxf(
		float(stats.get("gauss_overclock_ramp_duration", 3.0)),
		0.01
	)

	gauss_overclock_decay_duration = maxf(
		float(stats.get("gauss_overclock_decay_duration", 1.0)),
		0.01
	)

	if not gauss_overclock_enabled:
		gauss_overclock_elapsed = 0.0
	else:
		gauss_overclock_elapsed = minf(
			gauss_overclock_elapsed,
			gauss_overclock_ramp_duration
	)
	if uses_directional_aim() and not gauss_spread_initialized:
		gauss_current_spread_degrees = gauss_maximum_spread_degrees
		gauss_spread_initialized = true
	else:
		gauss_current_spread_degrees = minf(
			maxf(gauss_current_spread_degrees, gauss_minimum_spread_degrees),
			gauss_maximum_spread_degrees
		)
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
	if tower_id == SAUCER_TOWER_ID:
		saucer_flyer_move_speed = maxf(float(stats.get("flyer_move_speed", 165.0)), 0.0)
		saucer_attack_radius_pixels = (
			maxf(float(stats.get("flyer_attack_radius", 5.0)), 0.0)
			* RANGE_PIXELS_PER_UNIT
		)
		saucer_abduction_cooldown = maxf(
			float(stats.get("abduction_cooldown", 16.0)),
			0.1
		)
		saucer_abduction_radius_pixels = (
			maxf(float(stats.get("abduction_radius", 1.5)), 0.0)
			* RANGE_PIXELS_PER_UNIT
		)
		saucer_abduction_health_threshold = clampf(
			float(stats.get("abduction_health_threshold", 0.35)),
			0.0,
			1.0
		)
		saucer_monster_stats = stats.get("monster_stats", {}).duplicate(true)
	load_path_behaviors()
	if uses_standard_spawner_system():
		spawned_unit_id = tower_data.get("spawned_unit_id", &"")
		spawn_limit = maxi(int(stats.get("spawn_limit", 1)), 1)
		if get_owned_relic_count(&"trade_agreement") > 0:
			spawn_limit *= GameStats.TRADE_AGREEMENT_SPAWN_LIMIT_MULTIPLIER
		deployment_radius_pixels = (
			float(stats.get("deployment_radius", 1.0))
			* RANGE_PIXELS_PER_UNIT
		)
		var spawn_interval := float(stats.get("spawn_interval", 1.0))
		if get_owned_relic_count(&"trade_agreement") > 0:
			spawn_interval *= GameStats.TRADE_AGREEMENT_SPAWN_INTERVAL_MULTIPLIER
		damage_timer.wait_time = maxf(spawn_interval, 0.1)
		refresh_spawned_unit_stats(stats["unit_stats"])
	else:
		loaded_attack_interval = maxf(float(stats["firerate"]), 0.01)
		damage_timer.wait_time = loaded_attack_interval
	var range_shape := $Tower/CollisionShape2D.shape.duplicate() as CircleShape2D
	range_radius_pixels = stats["range"] * RANGE_PIXELS_PER_UNIT
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
				* float(get_cardinal_adjacent_tower_count(TYPE_TECHNOLOGY))
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
	if not is_placed or not uses_standard_spawner_system() or spawned_unit_id.is_empty():
		return
	if main == null or not main.round_active:
		damage_timer.stop()
		return
	prune_spawned_units()
	if active_spawned_units.size() >= spawn_limit:
		return

	var spawned_unit: Node = SPAWNED_UNIT_SCENE.instantiate()
	get_tree().current_scene.add_child(spawned_unit)
	spawned_unit.global_position = get_spawned_unit_position()
	var map_path: Path2D
	if main != null:
		map_path = main.get_node_or_null("path") as Path2D
	spawned_unit.setup(
		spawned_unit_id,
		get_effective_stats_for_level(tower_level)["unit_stats"],
		self,
		map_path
	)
	active_spawned_units.append(spawned_unit)
	spawned_unit.tree_exiting.connect(
		_on_spawned_unit_exiting.bind(spawned_unit)
	)


func get_spawned_unit_position() -> Vector2:
	var definition := GameStats.get_spawned_unit(spawned_unit_id)
	if definition["movement_type"] != GameStats.MOVEMENT_STATIONARY:
		return global_position
	var angle := spawn_rng.randf_range(0.0, TAU)
	var distance := sqrt(spawn_rng.randf()) * deployment_radius_pixels
	var spawn_position := global_position + Vector2.from_angle(angle) * distance
	var viewport_size := get_viewport_rect().size
	var playable_right_edge := viewport_size.x
	if main != null and main.has_method("get_playable_right_edge"):
		playable_right_edge = minf(
			playable_right_edge,
			float(main.get_playable_right_edge())
		)
	spawn_position.x = clampf(spawn_position.x, 8.0, playable_right_edge - 8.0)
	spawn_position.y = clampf(spawn_position.y, 8.0, viewport_size.y - 8.0)
	return spawn_position


func refresh_spawned_unit_stats(unit_stats: Dictionary) -> void:
	prune_spawned_units()
	for spawned_unit in active_spawned_units:
		if is_instance_valid(spawned_unit):
			spawned_unit.apply_stats(unit_stats)


func prune_spawned_units() -> void:
	active_spawned_units = active_spawned_units.filter(
		func(spawned_unit: Node) -> bool:
			return (
				is_instance_valid(spawned_unit)
				and not spawned_unit.is_queued_for_deletion()
			)
	)


func _on_spawned_unit_exiting(spawned_unit: Node) -> void:
	active_spawned_units.erase(spawned_unit)


func clear_spawned_units() -> void:
	for spawned_unit in active_spawned_units:
		if is_instance_valid(spawned_unit):
			spawned_unit.queue_free()
	active_spawned_units.clear()


func ensure_saucer_flyer() -> void:
	if tower_id != SAUCER_TOWER_ID or not is_placed:
		return
	if is_instance_valid(active_saucer_flyer):
		return
	if SAUCER_FLYER_SCENE == null or get_tree().current_scene == null:
		return
	active_saucer_flyer = SAUCER_FLYER_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(active_saucer_flyer)
	active_saucer_flyer.global_position = global_position
	active_saucer_flyer.setup(self)


func is_saucer_combat_active() -> bool:
	return (
		is_placed
		and main != null
		and main.round_active
		and not is_queued_for_deletion()
	)


func get_saucer_target() -> Node2D:
	if not is_saucer_combat_active():
		return null
	# Saucer is permanently locked to First for movement and its Electric gun.
	target_mode = TargetMode.FIRST
	_select_target()
	return target if is_valid_target(target) else null


func saucer_can_abduct_target(candidate: Variant) -> bool:
	if not is_valid_target(candidate):
		return false
	if candidate.traits.has(&"boss") or candidate.traits.has(&"elite"):
		return false
	if candidate.max_health <= 0:
		return false
	return (
		float(candidate.health) / float(candidate.max_health)
		<= saucer_abduction_health_threshold
	)


func get_saucer_abduction_target(saucer_position: Vector2) -> Node2D:
	if not is_saucer_combat_active():
		return null
	var selected_target: Node2D
	var selected_max_health := -1
	var selected_progress := -INF
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not saucer_can_abduct_target(candidate):
			continue
		if (
			saucer_position.distance_to(candidate.global_position)
			> saucer_abduction_radius_pixels
		):
			continue
		var candidate_max_health := int(candidate.max_health)
		var candidate_progress := -INF
		if is_instance_valid(candidate.path_follow):
			candidate_progress = float(candidate.path_follow.progress)
		if (
			candidate_max_health > selected_max_health
			or (
				candidate_max_health == selected_max_health
				and candidate_progress > selected_progress
			)
		):
			selected_max_health = candidate_max_health
			selected_progress = candidate_progress
			selected_target = candidate
	return selected_target


func get_saucer_rocket_target(
	saucer_position: Vector2,
	gun_target: Node2D
) -> Node2D:
	if not is_saucer_combat_active():
		return null
	var selected_target: Node2D
	var selected_health := -1
	var selected_progress := -INF
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if candidate == gun_target or not is_valid_target(candidate):
			continue
		if (
			saucer_position.distance_to(candidate.global_position)
			> saucer_attack_radius_pixels
		):
			continue
		var candidate_health := int(candidate.health)
		var candidate_progress := -INF
		if is_instance_valid(candidate.path_follow):
			candidate_progress = float(candidate.path_follow.progress)
		if (
			candidate_health > selected_health
			or (
				candidate_health == selected_health
				and candidate_progress > selected_progress
			)
		):
			selected_health = candidate_health
			selected_progress = candidate_progress
			selected_target = candidate
	if selected_target != null:
		return selected_target
	if (
		is_valid_target(gun_target)
		and saucer_position.distance_to(gun_target.global_position)
			<= saucer_attack_radius_pixels
	):
		return gun_target
	return null


func fire_saucer_weapon(
	launch_position: Vector2,
	current_target: Node2D
) -> void:
	if not is_saucer_combat_active() or not is_valid_target(current_target):
		return
	var attack_damage := roll_attack_damage(current_target)
	var gun_context := create_attack_context(
		&"electric_primary",
		null,
		&"tower",
		null,
		false,
		true
	)
	spawn_hitscan_effect(
		launch_position,
		current_target.global_position,
		DAMAGE_ELECTRIC
	)
	apply_control_effects(current_target, gun_context)
	apply_tower_damage(
		current_target,
		attack_damage,
		DAMAGE_ELECTRIC,
		false,
		gun_context
	)


func fire_saucer_rockets(
	launch_position: Vector2,
	gun_target: Node2D
) -> bool:
	if not saucer_twin_rockets_enabled:
		return false
	var rocket_target := get_saucer_rocket_target(launch_position, gun_target)
	if not is_valid_target(rocket_target):
		return false
	var rocket_damage := maxi(
		roundi(float(roll_attack_damage(rocket_target)) * saucer_rocket_damage_multiplier),
		1
	)
	fire_saucer_homing_rockets(launch_position, rocket_target, rocket_damage)
	return true


func fire_saucer_homing_rockets(
	launch_position: Vector2,
	current_target: Node2D,
	rocket_damage: int
) -> void:
	if projectile_scene == null or not is_valid_target(current_target):
		return
	var aim_offset := current_target.global_position - launch_position
	var perpendicular := (
		aim_offset.normalized().orthogonal()
		if not aim_offset.is_zero_approx()
		else Vector2.UP
	)
	for rocket_index in 2:
		var lateral_offset := -7.0 if rocket_index == 0 else 7.0
		var rocket_origin := launch_position + perpendicular * lateral_offset
		var destination := current_target.global_position
		var projectile := projectile_scene.instantiate() as TowerProjectile
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = rocket_origin
		projectile.setup(
			current_target,
			destination,
			projectile_speed,
			maxf(range_radius_pixels, rocket_origin.distance_to(destination) * 2.0),
			rocket_damage,
			DAMAGE_EXPLOSIVE,
			GameStats.IMPACT_PRIMARY,
			splash_radius_pixels * get_explosion_radius_multiplier(),
			0,
			0.0,
			0.0,
			false,
			0,
			0.0,
			false,
			0.0,
			false,
			has_bonus_tag(BONUS_REVEAL),
			tower_id,
			true,
			false,
			1.0,
			create_attack_context(
				&"homing_rocket",
				projectile,
				&"projectile",
				null,
				false,
				true
			)
		)


func try_saucer_abduction(current_target: Node2D, saucer_position: Vector2) -> bool:
	if (
		not is_saucer_combat_active()
		or not saucer_can_abduct_target(current_target)
		or saucer_position.distance_to(current_target.global_position)
			> saucer_abduction_radius_pixels
	):
		return false
	if current_target.has_method("abduct"):
		current_target.abduct(create_attack_context(&"abduction"))
	else:
		current_target.queue_free()
	if saucer_monster_drop_enabled:
		spawn_saucer_monster(saucer_position)
	if target == current_target:
		target = null
	return true


func spawn_saucer_monster(spawn_position: Vector2) -> void:
	if not saucer_monster_drop_enabled or main == null or not main.round_active:
		return
	if (
		is_instance_valid(active_saucer_monster)
		and not active_saucer_monster.is_queued_for_deletion()
	):
		return
	var monster_stats := saucer_monster_stats.duplicate(true)
	monster_stats["damage"] = maxi(
		roundi(float(monster_stats.get("damage", 1)) + get_main_bonus(&"tower_damage_flat")),
		1
	)
	monster_stats["attack_interval"] = maxf(
		float(monster_stats.get("attack_interval", 1.0))
			/ get_main_multiplier(&"tower_attack_speed"),
		0.01
	)
	monster_stats["aim_radius"] = (
		float(monster_stats.get("aim_radius", 4.0))
		* get_main_multiplier(&"tower_range")
	)
	monster_stats["acquisition_radius"] = (
		float(monster_stats.get("acquisition_radius", 8.0))
		* get_main_multiplier(&"tower_range")
	)
	var monster := SPAWNED_UNIT_SCENE.instantiate()
	get_tree().current_scene.add_child(monster)
	monster.global_position = spawn_position
	monster.setup(&"abducted_monster", monster_stats, self, null)
	active_saucer_monster = monster
	active_spawned_units.append(monster)
	monster.tree_exiting.connect(_on_saucer_monster_exiting.bind(monster))


func _on_saucer_monster_exiting(monster: Node) -> void:
	active_spawned_units.erase(monster)
	if active_saucer_monster == monster:
		active_saucer_monster = null


func _on_round_started(_round_number: int) -> void:
	qualified_for_investment_round = is_placed
	brainiac_link_cooldown_remaining = 0.0
	gauss_overclock_elapsed = 0.0
	if gauss_heavy_shot_enabled:
		gauss_heavy_shot_remaining = gauss_heavy_shot_interval
	if reaver_time_bubble_enabled:
		reaver_time_bubble_active_remaining = 0.0
		reaver_time_bubble_cooldown_remaining = 0.0
		reaver_time_bubble_refresh_remaining = 0.0
	if longshot_mines_enabled:
		longshot_mine_remaining = longshot_mine_interval
	if void_singularity_enabled:
		void_singularity_remaining = void_singularity_cooldown
	if energy_shockwave_enabled:
		energy_shockwave_remaining = energy_shockwave_cooldown
	if is_placed and uses_standard_spawner_system():
		_spawn_unit()
		damage_timer.start()


func _on_round_ended(_round_number: int) -> void:
	if qualified_for_investment_round and is_placed:
		completed_rounds_active += 1
	qualified_for_investment_round = false
	brainiac_link_cooldown_remaining = 0.0
	gauss_overclock_elapsed = 0.0
	update_sell_button()
	reaver_time_bubble_active_remaining = 0.0
	reaver_time_bubble_cooldown_remaining = 0.0
	reaver_time_bubble_refresh_remaining = 0.0
	clear_longshot_mines()
	longshot_mine_remaining = longshot_mine_interval
	clear_void_singularities()
	void_singularity_remaining = void_singularity_cooldown
	clear_solar_lances()
	energy_shockwave_remaining = energy_shockwave_cooldown
	energy_shockwave_visual_remaining = 0.0
	queue_redraw()
	if tower_id == SAUCER_TOWER_ID:
		clear_spawned_units()
		active_saucer_monster = null
	if not uses_standard_spawner_system():
		return
	damage_timer.stop()
	clear_spawned_units()


func _exit_tree() -> void:
	remove_reveal_source_from_all_mobs()
	disconnect_beholder_target_observer()
	clear_longshot_mines()
	clear_void_singularities()
	clear_solar_lances()
	if is_instance_valid(active_saucer_flyer):
		active_saucer_flyer.queue_free()
	if main != null and main.has_method("finish_manual_tower_targeting"):
		main.finish_manual_tower_targeting(self)
	clear_spawned_units()


func _apply_damage() -> void:
	if not uses_standard_spawner_system():
		damage_timer.wait_time = get_current_attack_interval()
	if not is_placed:
		return
	if tower_id == SAUCER_TOWER_ID:
		_select_target()
		return
	if uses_manual_ground_targeting():
		if (
			main != null
			and main.round_active
			and orbital_has_target_position
			and has_enemy_in_orbital_target_zone()
		):
			attack_orbital_target_position()
		return

	var sticky_health_mode := target_mode in [
		TargetMode.LOWEST_HEALTH,
		TargetMode.HIGHEST_HEALTH,
	]
	if (
		not is_valid_target(target)
		or not mobs_in_range.has(target)
		or (not uses_continuous_beam() and not sticky_health_mode)
	):
		_select_target()
	update_beholder_target_observer()
	if is_valid_target(target):
		attack(target)
		# Projectile Melee attacks confirm Relentless only when the originally
		# selected primary enemy is physically hit. This keeps Slinger pierce and
		# bounce contacts from changing its streak.
		if not (
			delivery_type == GameStats.DELIVERY_PROJECTILE
			and has_damage_tag(DAMAGE_MELEE)
		):
			register_relentless_primary_attack(target)
		damage_timer.wait_time = get_current_attack_interval()


func get_current_attack_interval() -> float:
	var interval := loaded_attack_interval
	
	if gauss_overclock_enabled and gauss_overclock_elapsed > 0.0:
		var overclock_progress := clampf(
			gauss_overclock_elapsed / gauss_overclock_ramp_duration,
			0.0,
			1.0
		)

		var attack_speed_bonus := (
			gauss_overclock_max_speed_bonus
			* overclock_progress
		)

		interval /= 1.0 + attack_speed_bonus
		
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


func has_enemy_in_orbital_target_zone() -> bool:
	var activation_radius := splash_radius_pixels
	if orbital_solar_lance_enabled:
		activation_radius = BUILD_CELL_SIZE
	if orbital_bombardment_enabled:
		activation_radius = (
			orbital_bombardment_spread_radius_pixels
			+ (
				BUILD_CELL_SIZE
				if orbital_solar_lance_enabled
				else splash_radius_pixels * orbital_bombardment_radius_multiplier
			)
		)
	for mob in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_target(mob):
			continue
		if mob.global_position.distance_to(orbital_target_position) <= activation_radius:
			return true
	return false


func attack_orbital_target_position() -> void:
	var strike_count := orbital_bombardment_strike_count if orbital_bombardment_enabled else 1
	var strike_damage := roll_attack_damage()
	var strike_radius := splash_radius_pixels
	if orbital_bombardment_enabled:
		strike_damage = maxi(
			roundi(float(strike_damage) * orbital_bombardment_damage_multiplier),
			1
		)
		strike_radius *= orbital_bombardment_radius_multiplier
	for strike_index in strike_count:
		var strike_position := orbital_target_position
		if strike_index > 0:
			var offset_angle := spawn_rng.randf_range(0.0, TAU)
			var offset_distance := (
				sqrt(spawn_rng.randf()) * orbital_bombardment_spread_radius_pixels
			)
			strike_position += Vector2.from_angle(offset_angle) * offset_distance
		var strike_delay := orbital_bombardment_stagger * float(strike_index)
		if strike_delay <= 0.0:
			resolve_orbital_strike(strike_position, strike_damage, strike_radius)
		else:
			get_tree().create_timer(strike_delay, false).timeout.connect(
				resolve_orbital_strike.bind(
					strike_position,
					strike_damage,
					strike_radius
				),
				CONNECT_ONE_SHOT
			)


func resolve_orbital_strike(
	strike_position: Vector2,
	strike_damage: int,
	strike_radius: float
) -> void:
	if not is_placed or main == null or not main.round_active:
		return
	if orbital_solar_lance_enabled:
		spawn_solar_lance(strike_position, strike_damage, strike_radius)
		return
	launch_projectile_from_position(
		null,
		muzzle.global_position,
		strike_position,
		muzzle.global_position.distance_to(strike_position),
		strike_damage,
		strike_radius
	)


func spawn_solar_lance(
	strike_position: Vector2,
	strike_damage: int,
	_strike_radius: float
) -> void:
	if SOLAR_LANCE_SCENE == null or get_tree().current_scene == null:
		return
	var tick_start_multiplier := orbital_solar_lance_tick_damage_multiplier
	var tick_end_multiplier := orbital_solar_lance_tick_end_damage_multiplier
	if orbital_bombardment_enabled:
		tick_start_multiplier = orbital_solar_lance_dual_tick_damage_multiplier
		tick_end_multiplier = orbital_solar_lance_dual_tick_damage_multiplier
	var lance := SOLAR_LANCE_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(lance)
	lance.global_position = strike_position
	lance.setup(
		main,
		BUILD_CELL_SIZE,
		maxi(roundi(float(strike_damage) * tick_start_multiplier), 1),
		maxi(roundi(float(strike_damage) * tick_end_multiplier), 1),
		orbital_solar_lance_duration,
		orbital_solar_lance_tick_interval,
		create_attack_context(
			&"solar_lance",
			lance,
			&"persistent_effect",
			null,
			false,
			true
		)
	)
	lance.finished.connect(_on_solar_lance_finished)
	active_solar_lances.append(lance)


func _on_solar_lance_finished(lance: Node2D) -> void:
	active_solar_lances.erase(lance)


func clear_solar_lances() -> void:
	for lance in active_solar_lances:
		if is_instance_valid(lance):
			lance.queue_free()
	active_solar_lances.clear()


func attack(current_target: Node2D) -> void:
	# Revalidate at the firing boundary. Target selection normally performs this
	# check already, but reveal can be lost between targeting updates and an
	# attack callback. In that case Hidden enemies must not produce a shot that
	# will only be rejected later by the projectile damage gate.
	if not is_valid_target(current_target):
		return
	if uses_continuous_beam():
		var beam_offsets: Array[float] = [0.0]
		if uses_dual_continuous_beams():
			beam_offsets.assign([-4.5, 4.5])
		for beam_offset in beam_offsets:
			var beam_damage := damage
			if beholder_ramping_beam_enabled:
				beam_damage = get_beholder_ramp_damage()
			apply_continuous_beam_tick(
				current_target,
				roll_critical_damage(beam_damage, current_target),
				beam_offset
			)
		return

	if tower_id == REAVER_TOWER_ID:
		launch_reaver_combo(current_target, damage)
		return
	var base_attack_damage := damage
	if tower_id == LONGSHOT_TOWER_ID and longshot_distance_damage_enabled:
		base_attack_damage = get_longshot_distance_damage(current_target)
	var attack_damage := roll_critical_damage(base_attack_damage, current_target)
	if beholder_ramping_beam_enabled:
		attack_damage = roll_critical_damage(get_beholder_ramp_damage(), current_target)
	if tower_id == ENERGY_CORE_TOWER_ID:
		apply_energy_core_attack(current_target, attack_damage)
		return
	if delivery_type == GameStats.DELIVERY_PROJECTILE:
		match tower_id:
			BRAINIAC_TOWER_ID:
				launch_brainiac_volley(current_target, attack_damage)
			VOID_CALLER_TOWER_ID:
				launch_void_caller_volley(current_target, attack_damage)
			_:
				launch_projectile(current_target, attack_damage)
	else:
		apply_hitscan_damage(current_target, attack_damage)


func apply_energy_core_attack(
	current_target: Node2D,
	attack_damage: int
) -> void:
	energy_branch_visual_segments.clear()
	var primary_targets := get_energy_primary_targets(current_target)
	var volley_context := create_attack_context(
		&"electric_volley", null, &"tower", null, false, true
	)
	var primary_strikes: Array[Dictionary] = []
	for primary_target in primary_targets:
		var primary_context := create_attack_context(
			&"electric_primary", self, &"tower", volley_context, false
		)
		energy_branch_visual_segments.append({
			"start": muzzle.global_position,
			"end": primary_target.global_position,
		})
		apply_control_effects(primary_target, primary_context)
		apply_tower_damage(
			primary_target,
			attack_damage,
			damage_type,
			false,
			primary_context
		)
		primary_strikes.append({
			"target": primary_target,
			"context": primary_context,
		})
	if energy_branching_current_enabled:
		for primary_strike in primary_strikes:
			apply_energy_branches(
				primary_strike["target"],
				attack_damage,
				primary_strike["context"]
			)
	energy_branch_visual_remaining = 0.12
	queue_redraw()


func get_energy_primary_targets(current_target: Node2D) -> Array[Node2D]:
	var primary_targets: Array[Node2D] = [current_target]
	var excluded_ids: Dictionary = {current_target.get_instance_id(): true}
	while primary_targets.size() < projectile_count:
		var next_target := get_preferred_energy_target(excluded_ids)
		if next_target == null:
			break
		primary_targets.append(next_target)
		excluded_ids[next_target.get_instance_id()] = true
	return primary_targets


func get_preferred_energy_target(excluded_ids: Dictionary) -> Node2D:
	var selected_target: Node2D
	for candidate in mobs_in_range:
		if (
			not is_valid_target(candidate)
			or excluded_ids.has(candidate.get_instance_id())
		):
			continue
		if selected_target == null or is_target_preferred(candidate, selected_target):
			selected_target = candidate
	return selected_target


func is_target_preferred(candidate: Node2D, selected_target: Node2D) -> bool:
	match target_mode:
		TargetMode.FIRST:
			return candidate.path_follow.progress > selected_target.path_follow.progress
		TargetMode.LAST:
			return candidate.path_follow.progress < selected_target.path_follow.progress
		TargetMode.LOWEST_HEALTH:
			return candidate.health < selected_target.health
		TargetMode.HIGHEST_HEALTH:
			return candidate.health > selected_target.health
	return false


func apply_energy_branches(
	primary_target: Node2D,
	attack_damage: int,
	primary_context: AttackContext
) -> void:
	var excluded_ids: Dictionary = {primary_target.get_instance_id(): true}
	var branch_damage := maxi(
		roundi(float(attack_damage) * energy_branch_damage_multiplier),
		1
	)
	for _branch_index in energy_branch_additional_targets:
		var branch_target := get_nearest_energy_branch_target(
			primary_target.global_position,
			excluded_ids
		)
		if branch_target == null:
			break
		excluded_ids[branch_target.get_instance_id()] = true
		var branch_context := create_attack_context(
			&"electric_branch", self, &"tower", primary_context, true
		)
		apply_control_effects(branch_target, branch_context)
		apply_tower_damage(
			branch_target, branch_damage, damage_type, false, branch_context
		)
		energy_branch_visual_segments.append({
			"start": primary_target.global_position,
			"end": branch_target.global_position,
		})


func get_nearest_energy_branch_target(
	origin: Vector2,
	excluded_ids: Dictionary
) -> Node2D:
	var nearest_target: Node2D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if (
			not is_valid_target(candidate)
			or excluded_ids.has(candidate.get_instance_id())
		):
			continue
		var candidate_distance: float = origin.distance_to(candidate.global_position)
		if candidate_distance > energy_branch_range_pixels:
			continue
		if candidate_distance < nearest_distance:
			nearest_distance = candidate_distance
			nearest_target = candidate
	return nearest_target


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


func get_cardinal_adjacent_tower_count(required_type_tag: StringName) -> int:
	var count := 0
	for candidate in get_tree().get_nodes_in_group("towers"):
		if not is_valid_neighbor_tower(candidate):
			continue
		if not candidate.has_type_tag(required_type_tag):
			continue
		var offset: Vector2 = candidate.global_position - global_position
		var horizontal := (
			absf(absf(offset.x) - BUILD_CELL_SIZE) <= 1.0
			and absf(offset.y) <= 1.0
		)
		var vertical := (
			absf(absf(offset.y) - BUILD_CELL_SIZE) <= 1.0
			and absf(offset.x) <= 1.0
		)
		if horizontal or vertical:
			count += 1
	return mini(count, 4)


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


func get_longshot_distance_damage(current_target: Node2D) -> int:
	if not is_instance_valid(current_target) or range_radius_pixels <= 0.0:
		return damage
	var distance_ratio := clampf(
		global_position.distance_to(current_target.global_position) / range_radius_pixels,
		0.0,
		1.0
	)
	var damage_multiplier := longshot_distance_midpoint_multiplier
	if distance_ratio <= 0.5:
		damage_multiplier = lerpf(
			longshot_distance_minimum_multiplier,
			longshot_distance_midpoint_multiplier,
			distance_ratio * 2.0
		)
	else:
		damage_multiplier = lerpf(
			longshot_distance_midpoint_multiplier,
			longshot_distance_maximum_multiplier,
			(distance_ratio - 0.5) * 2.0
		)
	return maxi(roundi(float(damage) * damage_multiplier), 1)


func roll_attack_damage(current_target: Node2D = null) -> int:
	return roll_critical_damage(damage, current_target)


func roll_critical_damage(base_damage: int, current_target: Node2D = null) -> int:
	last_attack_roll_was_critical = false
	var current_critical_chance := critical_chance
	if (
		has_bonus_tag(BONUS_CRITICAL)
		and is_valid_target(current_target)
		and current_target.health >= current_target.max_health
	):
		current_critical_chance = clampf(
			current_critical_chance
			+ GameStats.OPENING_SHOT_CHANCE_PER_STACK
				* get_owned_relic_count(&"opening_shot"),
			0.0,
			1.0
		)
	if (
		has_bonus_tag(BONUS_CRITICAL)
		and spawn_rng.randf() < current_critical_chance
	):
		last_attack_roll_was_critical = true
		return maxi(roundi(float(base_damage) * critical_multiplier), 1)
	return maxi(roundi(float(base_damage) * noncritical_damage_multiplier), 1)


func launch_reaver_combo(current_target: Node2D, attack_damage: int) -> void:
	active_combo_sequence += 1
	var combo_sequence := active_combo_sequence
	var target_reference: WeakRef = weakref(current_target)
	for hit_index in combo_hit_count:
		var hit_damage := get_combo_hit_damage(attack_damage, hit_index)
		if reaver_assassinate_enabled and hit_index == combo_hit_count - 1:
			hit_damage = maxi(
				roundi(float(hit_damage) * maxf(critical_multiplier, 1.0)),
				1
			)
			last_attack_roll_was_critical = true
		else:
			hit_damage = roll_critical_damage(hit_damage, current_target)
		var hit_context := create_attack_context(
			&"reaver_combo_hit", null, &"tower", null, false, true
		)
		var hit_delay := combo_stagger * float(hit_index)
		if hit_delay <= 0.0:
			apply_reaver_combo_hit(
				target_reference,
				hit_damage,
				combo_sequence,
				hit_context
			)
		else:
			get_tree().create_timer(hit_delay, false).timeout.connect(
				apply_reaver_combo_hit.bind(
					target_reference,
					hit_damage,
					combo_sequence,
					hit_context
				)
			)


func get_combo_hit_damage(total_damage: int, hit_index: int) -> int:
	if combo_hit_count <= 1:
		return total_damage
	var light_hit_damage := maxi(roundi(float(total_damage) * 0.25), 1)
	if hit_index < combo_hit_count - 1:
		return light_hit_damage
	return maxi(total_damage - light_hit_damage * (combo_hit_count - 1), 1)


func apply_reaver_combo_hit(
	target_reference: WeakRef,
	hit_damage: int,
	combo_sequence: int,
	hit_context: AttackContext
) -> void:
	if combo_sequence != active_combo_sequence:
		return
	if not is_placed or main == null or not main.round_active:
		active_combo_sequence += 1
		return
	var referenced_target: Variant = target_reference.get_ref()
	if not is_valid_target(referenced_target):
		active_combo_sequence += 1
		return
	var combo_target := referenced_target as Node2D
	if global_position.distance_to(combo_target.global_position) > range_radius_pixels:
		active_combo_sequence += 1
		return
	apply_hitscan_damage(combo_target, hit_damage, hit_context)


func launch_projectile(current_target: Node2D, attack_damage: int) -> void:
	if projectile_scene == null:
		push_error("Projectile tower %s has no projectile scene." % tower_id)
		return
	if not is_valid_target(current_target):
		return

	var impact_radius := splash_radius_pixels if damage_type == DAMAGE_EXPLOSIVE else 0.0
	var projectile_target_position := current_target.global_position
	var maximum_projectile_distance := range_radius_pixels
	if uses_directional_aim():
		var base_shot_direction := aim_direction
		if uses_gauss_tracking_cone():
			var target_offset := current_target.global_position - muzzle.global_position
			if not target_offset.is_zero_approx():
				base_shot_direction = target_offset.normalized()
		var spread_offset_degrees := spawn_rng.randf_range(
			-gauss_current_spread_degrees,
			gauss_current_spread_degrees
		)
		var projectile_direction := base_shot_direction.rotated(
			deg_to_rad(spread_offset_degrees)
		)
		maximum_projectile_distance = get_max_distance_in_direction(
			projectile_direction,
			muzzle.global_position
		)
		projectile_target_position = (
			muzzle.global_position
			+ projectile_direction * maximum_projectile_distance
		)
		gauss_current_spread_degrees = maxf(
			gauss_current_spread_degrees - gauss_spread_tighten_per_shot,
			gauss_minimum_spread_degrees
		)
		gauss_time_without_target = 0.0
	elif infinite_pierce and impact_mode == GameStats.IMPACT_FIRST_CONTACT:
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


func launch_brainiac_volley(
	current_target: Node2D,
	attack_damage: int
) -> void:
	if (
		brainiac_psionic_link_enabled
		and brainiac_link_cooldown_remaining <= 0.0
		and current_target.has_method("apply_brainiac_link")
	):
		current_target.apply_brainiac_link(
			brainiac_link_duration,
			brainiac_link_radius_pixels,
			brainiac_link_damage_share,
			create_attack_context(&"brainiac_link")
		)
		brainiac_link_cooldown_remaining = brainiac_link_cooldown
	var aim_offset := current_target.global_position - global_position
	if aim_offset.is_zero_approx():
		return
	var direction := aim_offset.normalized()
	var perpendicular := direction.orthogonal()
	var convergence_point := global_position + direction * range_radius_pixels
	var maximum_flight_duration := 0.0
	var convergence_resolver: Node
	var volley_context := create_attack_context(
		&"brainiac_volley", null, &"tower", null, false, true
	)
	if brainiac_convergence_explosion_enabled:
		convergence_resolver = BRAINIAC_CONVERGENCE_RESOLVER.new()
		get_tree().current_scene.add_child(convergence_resolver)
		convergence_resolver.setup(
			main,
			projectile_count,
			attack_damage,
			brainiac_convergence_damage_per_arrival,
			brainiac_convergence_base_radius_pixels,
			brainiac_convergence_radius_per_arrival_pixels,
			convergence_point,
			has_bonus_tag(BONUS_REVEAL),
			create_attack_context(
				&"brainiac_convergence",
				self,
				&"tower",
				volley_context,
				true
			)
		)
	for index in projectile_count:
		var spread_ratio := 0.0
		if projectile_count > 1:
			spread_ratio = (
				float(index) / float(projectile_count - 1) - 0.5
			)
		var launch_position := (
			muzzle.global_position
			+ perpendicular * volley_width_pixels * spread_ratio
		)
		var flight_distance := launch_position.distance_to(convergence_point)
		maximum_flight_duration = maxf(
			maximum_flight_duration,
			flight_distance / maxf(projectile_speed, 1.0)
		)
		var projectile := launch_projectile_from_position(
			current_target,
			launch_position,
			convergence_point,
			flight_distance,
			attack_damage,
			0.0,
			create_attack_context(
				&"brainiac_projectile",
				self,
				&"tower",
				volley_context,
				false
			)
		)
		if convergence_resolver != null and projectile != null:
			convergence_resolver.track_projectile(projectile)
	if convergence_resolver != null:
		convergence_resolver.arm_timeout(maximum_flight_duration + 0.05)


func launch_void_caller_volley(
	current_target: Node2D,
	attack_damage: int
) -> void:
	var volley_center := current_target.global_position
	var aim_offset := volley_center - muzzle.global_position
	if aim_offset.is_zero_approx():
		return
	var perpendicular := aim_offset.normalized().orthogonal()
	var target_reference: WeakRef = weakref(current_target)
	var volley_context := create_attack_context(
		&"void_caller_volley", null, &"tower", null, false, true
	)
	for index in projectile_count:
		var spread_ratio := 0.0
		if projectile_count > 1:
			spread_ratio = (
				float(index) / float(projectile_count - 1) - 0.5
			)
		var destination := (
			volley_center
			+ perpendicular * volley_width_pixels * spread_ratio
		)
		var release_delay := volley_stagger * float(index)
		if release_delay <= 0.0:
			launch_delayed_volley_projectile(
				target_reference,
				destination,
				attack_damage,
				volley_context
			)
		else:
			get_tree().create_timer(release_delay, false).timeout.connect(
				launch_delayed_volley_projectile.bind(
					target_reference,
					destination,
					attack_damage,
					volley_context
				)
			)


func launch_delayed_volley_projectile(
	target_reference: WeakRef,
	destination: Vector2,
	attack_damage: int,
	volley_context: AttackContext
) -> void:
	if not is_placed or main == null or not main.round_active:
		return
	var current_target: Node2D
	var referenced_target: Variant = target_reference.get_ref()
	if is_instance_valid(referenced_target):
		current_target = referenced_target as Node2D
	var launch_position := muzzle.global_position
	launch_projectile_from_position(
		current_target,
		launch_position,
		destination,
		launch_position.distance_to(destination),
		attack_damage,
		splash_radius_pixels,
		create_attack_context(
			&"void_caller_projectile",
			self,
			&"tower",
			volley_context,
			false
		)
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
		slinger_contact_explosions_enabled,
		slinger_contact_explosion_radius_pixels,
		infinite_pierce,
		has_bonus_tag(BONUS_REVEAL),
		tower_id,
		false,
		pierce_loses_no_power,
		slinger_contact_explosion_damage_multiplier
			* get_explosion_damage_multiplier(),
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
	if tower_id == BEHOLDER_TOWER_ID:
		return global_position
	return muzzle.global_position


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
	if (
		relentless_target_instance_id > 0
		and (
			not is_valid_target(target)
			or target.get_instance_id() != relentless_target_instance_id
		)
	):
		reset_relentless()
	if main != null and main.round_active:
		brainiac_link_cooldown_remaining = maxf(
			brainiac_link_cooldown_remaining - delta,
			0.0
		)
	process_gauss_spread(delta)
	process_gauss_overclock(delta)
	if orbital_targeting_active:
		orbital_preview_position = get_global_mouse_position()
		orbital_preview_valid = is_valid_orbital_target_position(
			orbital_preview_position
		)
		queue_redraw()
	if uses_continuous_beam() or reaver_time_bubble_enabled:
		queue_redraw()
	if not is_placed:
		if uses_directional_aim():
			rotator.rotation = aim_direction.angle()
		return
	if uses_directional_aim():
		rotator.rotation = aim_direction.angle()
	if uses_manual_ground_targeting():
		if orbital_has_target_position:
			rotator.rotation = (
				orbital_target_position - rotator.global_position
			).angle()
		return
	if not is_instance_valid(target):
		target = null
	if uses_gauss_tracking_cone() and not is_target_in_tracking_cone(target):
		target = null
	if not is_valid_target(target):
		_select_target()
	process_continuous_beam_aim(delta)
	update_beholder_target_observer()
	process_beholder_beam_ramp(delta)
	process_gauss_heavy_shot(delta)
	process_reaver_time_bubble(delta)
	process_longshot_mines(delta)
	process_void_singularity(delta)
	process_energy_shockwave(delta)
	if uses_gauss_tracking_cone() and is_valid_target(target):
		rotator.rotation = (
			target.global_position - rotator.global_position
		).angle()
	if (
		is_valid_target(target)
		and not uses_directional_aim()
		and not uses_continuous_beam()
	):
		var desired_angle = (target.global_position - rotator.global_position).angle()
		rotator.rotation = lerp_angle(rotator.rotation, desired_angle, 5.0 * delta)


func process_reaver_time_bubble(delta: float) -> void:
	if not reaver_time_bubble_enabled or not is_placed:
		return
	if main == null or not main.round_active:
		reaver_time_bubble_active_remaining = 0.0
		reaver_time_bubble_cooldown_remaining = 0.0
		reaver_time_bubble_refresh_remaining = 0.0
		return
	if reaver_time_bubble_active_remaining <= 0.0:
		reaver_time_bubble_cooldown_remaining = maxf(
			reaver_time_bubble_cooldown_remaining - delta,
			0.0
		)
		if reaver_time_bubble_cooldown_remaining > 0.0:
			return
		if not has_valid_enemy_in_reaver_bubble():
			return
		reaver_time_bubble_active_remaining = reaver_time_bubble_active_duration
		reaver_time_bubble_refresh_remaining = 0.0
	reaver_time_bubble_active_remaining = maxf(
		reaver_time_bubble_active_remaining - delta,
		0.0
	)
	if reaver_time_bubble_active_remaining <= 0.0:
		reaver_time_bubble_cooldown_remaining = reaver_time_bubble_cooldown
		return
	reaver_time_bubble_refresh_remaining -= delta
	if reaver_time_bubble_refresh_remaining > 0.0:
		return
	reaver_time_bubble_refresh_remaining = reaver_time_bubble_refresh_interval
	var bubble_context := create_attack_context(&"reaver_time_bubble")
	for mob in tower_area.get_overlapping_bodies():
		if (
			not is_valid_target(mob)
			or not mob.has_method("apply_slow")
		):
			continue
		mob.apply_slow(reaver_time_bubble_slow_duration, bubble_context)


func has_valid_enemy_in_reaver_bubble() -> bool:
	for mob in tower_area.get_overlapping_bodies():
		if is_valid_target(mob):
			return true
	return false


func process_longshot_mines(delta: float) -> void:
	if not longshot_mines_enabled or not is_placed:
		return
	if main == null or not main.round_active:
		return
	prune_longshot_mines()
	if active_longshot_mines.size() >= longshot_mine_maximum_count:
		return
	longshot_mine_remaining = maxf(longshot_mine_remaining - delta, 0.0)
	if longshot_mine_remaining > 0.0:
		return
	longshot_mine_remaining = longshot_mine_interval
	place_longshot_mine()


func place_longshot_mine() -> void:
	if (
		main == null
		or not main.has_method("get_path_cell_positions_near")
		or LONGSHOT_MINE_SCENE == null
		or get_tree().current_scene == null
	):
		return
	var candidates: Array = main.get_path_cell_positions_near(
		global_position,
		longshot_mine_placement_radius_pixels
	)
	for mine in active_longshot_mines:
		if not is_instance_valid(mine):
			continue
		candidates = candidates.filter(
			func(candidate_position: Vector2) -> bool:
				return candidate_position.distance_to(mine.global_position) > 1.0
		)
	if candidates.is_empty():
		return
	var mine_position: Vector2 = candidates[spawn_rng.randi_range(0, candidates.size() - 1)]
	var mine := LONGSHOT_MINE_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(mine)
	mine.global_position = mine_position
	mine.setup(
		main,
		maxi(roundi(float(damage) * longshot_mine_damage_multiplier), 1),
		longshot_mine_trigger_radius_pixels,
		longshot_mine_explosion_radius_pixels,
		create_attack_context(&"mine_explosion", mine, &"mine")
	)
	mine.detonated.connect(_on_longshot_mine_detonated)
	active_longshot_mines.append(mine)


func _on_longshot_mine_detonated(mine: Node2D) -> void:
	active_longshot_mines.erase(mine)
	longshot_mine_remaining = longshot_mine_interval


func prune_longshot_mines() -> void:
	active_longshot_mines = active_longshot_mines.filter(
		func(mine: Node) -> bool:
			return is_instance_valid(mine) and not mine.is_queued_for_deletion()
	)


func clear_longshot_mines() -> void:
	for mine in active_longshot_mines:
		if is_instance_valid(mine):
			mine.queue_free()
	active_longshot_mines.clear()


func process_void_singularity(delta: float) -> void:
	if not void_singularity_enabled or not is_placed:
		return
	if main == null or not main.round_active:
		return
	prune_void_singularities()
	void_singularity_remaining = maxf(void_singularity_remaining - delta, 0.0)
	if void_singularity_remaining > 0.0:
		return
	var singularity_target := select_standard_target()
	if (
		not is_valid_target(singularity_target)
		or not is_instance_valid(singularity_target.path_follow)
	):
		return
	void_singularity_remaining = void_singularity_cooldown
	spawn_void_singularity(singularity_target)


func spawn_void_singularity(current_target: Node2D) -> void:
	if VOID_SINGULARITY_SCENE == null or get_tree().current_scene == null:
		return
	var singularity := VOID_SINGULARITY_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(singularity)
	singularity.global_position = current_target.global_position
	singularity.setup(
		main,
		current_target.path_follow.progress,
		void_singularity_pull_duration,
		void_singularity_pull_radius_pixels,
		void_singularity_pull_speed,
		void_singularity_explosion_radius_pixels,
		maxi(roundi(float(damage) * void_singularity_damage_multiplier), 1),
		create_attack_context(
			&"void_singularity",
			singularity,
			&"persistent_effect"
		)
	)
	singularity.finished.connect(_on_void_singularity_finished)
	active_void_singularities.append(singularity)


func _on_void_singularity_finished(singularity: Node2D) -> void:
	active_void_singularities.erase(singularity)


func prune_void_singularities() -> void:
	active_void_singularities = active_void_singularities.filter(
		func(singularity: Node) -> bool:
			return (
				is_instance_valid(singularity)
				and not singularity.is_queued_for_deletion()
			)
	)


func clear_void_singularities() -> void:
	for singularity in active_void_singularities:
		if is_instance_valid(singularity):
			singularity.queue_free()
	active_void_singularities.clear()


func process_energy_shockwave(delta: float) -> void:
	if energy_branch_visual_remaining > 0.0:
		energy_branch_visual_remaining = maxf(
			energy_branch_visual_remaining - delta,
			0.0
		)
		if energy_branch_visual_remaining <= 0.0:
			energy_branch_visual_segments.clear()
		queue_redraw()
	if energy_shockwave_visual_remaining > 0.0:
		energy_shockwave_visual_remaining = maxf(
			energy_shockwave_visual_remaining - delta,
			0.0
		)
		queue_redraw()
	if not energy_shockwave_enabled or not is_placed:
		return
	if main == null or not main.round_active:
		return
	energy_shockwave_remaining = maxf(energy_shockwave_remaining - delta, 0.0)
	if energy_shockwave_remaining > 0.0:
		return
	var affected_mobs: Array[Node2D] = []
	var has_targetable_mob := false
	for mob in tower_area.get_overlapping_bodies():
		if not is_valid_area_target(mob):
			continue
		affected_mobs.append(mob)
		if is_valid_target(mob):
			has_targetable_mob = true
	# Hidden enemies can be caught in the pulse, but cannot trigger it by
	# themselves when this tower lacks Reveal.
	if not has_targetable_mob:
		return
	energy_shockwave_remaining = energy_shockwave_cooldown
	energy_shockwave_visual_remaining = 0.3
	queue_redraw()
	var shockwave_damage := roll_critical_damage(
		maxi(roundi(float(damage) * energy_shockwave_damage_multiplier), 1)
	)
	var shockwave_context := create_attack_context(
		&"energy_shockwave", null, &"tower", null, false, true
	)
	shockwave_context.metadata["area_damage"] = true
	for mob in affected_mobs:
		if mob.has_method("apply_stun"):
			mob.apply_stun(
				energy_shockwave_stun_duration,
				stun_affects_bosses,
				shockwave_context
			)
		apply_tower_damage(
			mob,
			shockwave_damage,
			damage_type,
			false,
			shockwave_context
		)


func update_menu_layout() -> void:
	if (
		not $towerconfirm.visible
		and not $HBoxContainer.visible
		and not $targetui.visible
		and not $pathui.visible
		and (direction_ui == null or not direction_ui.visible)
	):
		return

	var viewport_size := get_viewport_rect().size
	var screen_position := get_global_transform_with_canvas().origin
	var menu_right_edge := viewport_size.x
	if main != null and main.has_method("get_playable_right_edge"):
		menu_right_edge = minf(menu_right_edge, main.get_playable_right_edge())
	var menu_center_x := clampf(
		screen_position.x,
		MENU_HALF_WIDTH + MENU_EDGE_MARGIN,
		menu_right_edge - MENU_HALF_WIDTH - MENU_EDGE_MARGIN
	)
	var x_offset := menu_center_x - screen_position.x
	var place_below := screen_position.y < 240.0
	var target_y: float = 50.0 if place_below else -$targetui.size.y - MENU_EDGE_MARGIN
	target_y = clampf(
		target_y,
		MENU_EDGE_MARGIN - screen_position.y,
		viewport_size.y - MENU_EDGE_MARGIN - $targetui.size.y - screen_position.y
	)

	$towerconfirm.position = Vector2(-40.0 + x_offset, 50.0 if place_below else -106.0)
	$HBoxContainer.position = Vector2(-106.0 + x_offset, 50.0 if place_below else -90.0)
	$targetui.position = Vector2(-60.0 + x_offset, target_y)
	var path_y: float = 50.0 if place_below else -$pathui.size.y - MENU_EDGE_MARGIN
	path_y = clampf(
		path_y,
		MENU_EDGE_MARGIN - screen_position.y,
		viewport_size.y - MENU_EDGE_MARGIN - $pathui.size.y - screen_position.y
	)
	$pathui.position = Vector2(-120.0 + x_offset, path_y)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("mobs") and not mobs_in_range.has(body):
		mobs_in_range.append(body)
		apply_reveal_relics_to_mob(body)
		if not is_valid_target(target):
			_select_target()

func _on_body_exited(body: Node2D) -> void:
	mobs_in_range.erase(body)
	if body.has_method("remove_global_reveal_source"):
		body.remove_global_reveal_source(self)
	if body == target:
		target = null

func is_valid_target(candidate: Variant) -> bool:
	if not is_valid_area_target(candidate):
		return false
	if candidate.traits.has(&"hidden"):
		return (
			has_bonus_tag(BONUS_REVEAL)
			or (
				candidate.has_method("is_revealed_for_all")
				and candidate.is_revealed_for_all()
			)
		)
	return true


func is_valid_area_target(candidate: Variant) -> bool:
	return (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and not candidate.finished
	)


func refresh_reveal_relic_coverage() -> void:
	remove_reveal_source_from_all_mobs()
	if not is_placed or not has_bonus_tag(BONUS_REVEAL):
		return
	for mob in mobs_in_range:
		if (
			is_instance_valid(mob)
			and not mob.is_queued_for_deletion()
			and global_position.distance_to(mob.global_position) <= range_radius_pixels
		):
			apply_reveal_relics_to_mob(mob)


func apply_reveal_relics_to_mob(mob: Node) -> void:
	if (
		not is_instance_valid(mob)
		or not has_bonus_tag(BONUS_REVEAL)
		or not mob.get("traits").has(&"hidden")
	):
		return
	if get_owned_relic_count(&"perfect_intelligence") > 0:
		if mob.has_method("remove_hidden_trait"):
			mob.remove_hidden_trait()
		else:
			mob.get("traits").erase(&"hidden")
		return
	if (
		get_owned_relic_count(&"spotter") > 0
		and mob.has_method("add_global_reveal_source")
	):
		mob.add_global_reveal_source(self)


func remove_reveal_source_from_all_mobs() -> void:
	if not is_inside_tree():
		return
	for mob in get_tree().get_nodes_in_group("mobs"):
		if is_instance_valid(mob) and mob.has_method("remove_global_reveal_source"):
			mob.remove_global_reveal_source(self)


func _select_target() -> void:
	if uses_directional_aim():
		_select_directional_target()
		return
	target = select_standard_target()


func select_standard_target() -> Node2D:
	mobs_in_range = mobs_in_range.filter(
		func(mob):
			return (
				mob != null
				and is_instance_valid(mob)
				and not mob.is_queued_for_deletion()
				and not mob.finished
			)
	)
	var targetable_mobs := mobs_in_range.filter(
		func(mob):
			return is_valid_target(mob)
	)

	if targetable_mobs.is_empty():
		return null

	var selected_target: Node2D = targetable_mobs[0]
	for candidate in targetable_mobs:
		match target_mode:
			TargetMode.FIRST:
				if candidate.path_follow.progress > selected_target.path_follow.progress:
					selected_target = candidate
			TargetMode.LAST:
				if candidate.path_follow.progress < selected_target.path_follow.progress:
					selected_target = candidate
			TargetMode.LOWEST_HEALTH:
				if candidate.health < selected_target.health:
					selected_target = candidate
			TargetMode.HIGHEST_HEALTH:
				if candidate.health > selected_target.health:
					selected_target = candidate
	return selected_target


func _select_directional_target() -> void:
	target = null
	if uses_gauss_tracking_cone():
		select_strongest_gauss_cone_target()
		return
	var closest_distance := INF
	var origin := muzzle.global_position
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_target(candidate):
			continue
		var offset: Vector2 = candidate.global_position - origin
		var distance_along_line: float = offset.dot(aim_direction)
		if distance_along_line <= 0.0:
			continue
		var hit_radius := 12.0
		if candidate.has_method("get_projectile_hit_radius"):
			hit_radius = candidate.get_projectile_hit_radius()
		var distance_from_line: float = absf(aim_direction.cross(offset))
		if distance_from_line > hit_radius + GAUSS_LINE_HALF_WIDTH:
			continue
		if distance_along_line < closest_distance:
			closest_distance = distance_along_line
			target = candidate


func select_strongest_gauss_cone_target() -> void:
	var highest_health := -1
	var highest_progress := -INF
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not is_target_in_tracking_cone(candidate):
			continue
		var candidate_health := int(candidate.health)
		var candidate_progress := float(candidate.path_follow.progress)
		if (
			candidate_health > highest_health
			or (
				candidate_health == highest_health
				and candidate_progress > highest_progress
			)
		):
			highest_health = candidate_health
			highest_progress = candidate_progress
			target = candidate


func is_target_in_tracking_cone(candidate: Variant) -> bool:
	if not is_valid_target(candidate):
		return false
	var offset: Vector2 = candidate.global_position - muzzle.global_position
	if offset.is_zero_approx():
		return true
	var half_angle_radians := deg_to_rad(gauss_tracking_cone_degrees * 0.5)
	return offset.normalized().dot(aim_direction) >= cos(half_angle_radians)


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

func process_gauss_overclock(delta: float) -> void:
	if (
		not gauss_overclock_enabled
		or not uses_directional_aim()
		or not is_placed
	):
		gauss_overclock_elapsed = 0.0
		return

	if main == null or not main.round_active:
		gauss_overclock_elapsed = 0.0
		return

	# Having a valid target means Gauss is actively sustaining fire.
	if is_valid_target(target):
		gauss_overclock_elapsed = minf(
			gauss_overclock_elapsed + delta,
			gauss_overclock_ramp_duration
		)
		return

	# When firing stops, lose the accumulated Overclock over the
	# configured decay duration instead of resetting instantly.
	var decay_rate := (
		gauss_overclock_ramp_duration
		/ gauss_overclock_decay_duration
	)

	gauss_overclock_elapsed = maxf(
		gauss_overclock_elapsed - decay_rate * delta,
		0.0
	)
	
func process_gauss_spread(delta: float) -> void:
	if not uses_directional_aim() or not is_placed:
		return
	if is_valid_target(target):
		gauss_time_without_target = 0.0
		return
	var previous_time_without_target := gauss_time_without_target
	gauss_time_without_target += delta
	var recovery_delta := (
		maxf(gauss_time_without_target - gauss_spread_recovery_delay, 0.0)
		- maxf(previous_time_without_target - gauss_spread_recovery_delay, 0.0)
	)
	if recovery_delta <= 0.0:
		return
	gauss_current_spread_degrees = minf(
		gauss_current_spread_degrees
		+ gauss_spread_recovery_per_second * recovery_delta,
		gauss_maximum_spread_degrees
	)


func process_gauss_heavy_shot(delta: float) -> void:
	if not gauss_heavy_shot_enabled or not is_placed:
		return
	if main == null or not main.round_active:
		return
	gauss_heavy_shot_remaining = maxf(
		gauss_heavy_shot_remaining - delta,
		0.0
	)
	if gauss_heavy_shot_remaining > 0.0 or not is_valid_target(target):
		return
	launch_gauss_heavy_shot()
	gauss_heavy_shot_remaining = gauss_heavy_shot_interval


func launch_gauss_heavy_shot() -> void:
	if projectile_scene == null or not is_valid_target(target):
		return
	var shot_direction := aim_direction
	if uses_gauss_tracking_cone():
		var target_offset := target.global_position - muzzle.global_position
		if not target_offset.is_zero_approx():
			shot_direction = target_offset.normalized()
	var maximum_distance := get_max_distance_in_direction(
		shot_direction,
		muzzle.global_position
	)
	var destination := muzzle.global_position + shot_direction * maximum_distance
	var heavy_projectile := projectile_scene.instantiate() as TowerProjectile
	get_tree().current_scene.add_child(heavy_projectile)
	heavy_projectile.global_position = muzzle.global_position
	heavy_projectile.setup(
		target,
		destination,
		projectile_speed * gauss_heavy_shot_speed_multiplier,
		maximum_distance,
		maxi(roundi(float(roll_attack_damage(target)) * gauss_heavy_shot_damage_multiplier), 1),
		damage_type,
		GameStats.IMPACT_FIRST_CONTACT,
		0.0,
		pierce_count,
		slow_duration,
		stun_duration,
		stun_affects_bosses,
		0,
		0.0,
		false,
		0.0,
		true,
		has_bonus_tag(BONUS_REVEAL),
		tower_id,
		false,
		pierce_loses_no_power,
		1.0,
		create_attack_context(&"gauss_heavy_shot", heavy_projectile, &"projectile")
	)


func process_beholder_beam_ramp(delta: float) -> void:
	if not beholder_ramping_beam_enabled:
		beholder_beam_lock_elapsed = 0.0
		beholder_beam_lock_target_id = 0
		return
	if (
		main == null
		or not main.round_active
		or not is_valid_target(target)
		or not mobs_in_range.has(target)
	):
		beholder_beam_lock_elapsed = 0.0
		beholder_beam_lock_target_id = 0
		return
	var current_target_id := target.get_instance_id()
	if current_target_id != beholder_beam_lock_target_id:
		beholder_beam_lock_target_id = current_target_id
		beholder_beam_lock_elapsed = 0.0
		return
	beholder_beam_lock_elapsed += delta


func get_beholder_ramp_damage() -> int:
	if not beholder_ramping_beam_enabled:
		return damage
	var previous_level := maxi(tower_level - 1, 0)
	var previous_level_damage := int(
		get_effective_stats_for_level(previous_level)["damage"]
	)
	var completed_steps := floori(
		beholder_beam_lock_elapsed / beholder_beam_ramp_step_interval
	)
	var damage_multiplier := minf(
		beholder_beam_ramp_start_multiplier
		+ beholder_beam_ramp_step_multiplier * float(completed_steps),
		beholder_beam_ramp_max_multiplier
	)
	return maxi(roundi(float(previous_level_damage) * damage_multiplier), 1)


func update_beholder_target_observer() -> void:
	var desired_target: Node2D
	if beholder_death_explosion_enabled and is_valid_target(target):
		desired_target = target
	if desired_target == beholder_observed_target:
		return
	disconnect_beholder_target_observer()
	beholder_observed_target = desired_target
	if (
		is_instance_valid(beholder_observed_target)
		and beholder_observed_target.has_signal("mob_died")
	):
		beholder_observed_target.mob_died.connect(_on_beholder_target_died)


func disconnect_beholder_target_observer() -> void:
	if (
		is_instance_valid(beholder_observed_target)
		and beholder_observed_target.has_signal("mob_died")
		and beholder_observed_target.mob_died.is_connected(
			_on_beholder_target_died
		)
	):
		beholder_observed_target.mob_died.disconnect(_on_beholder_target_died)
	beholder_observed_target = null


func _on_beholder_target_died(killed_mob: Node2D) -> void:
	if not beholder_death_explosion_enabled or target != killed_mob:
		return
	if killed_mob.get_meta("beholder_death_explosion_triggered", false):
		return
	killed_mob.set_meta("beholder_death_explosion_triggered", true)
	var explosion_damage := maxi(
		roundi(
			float(damage)
			* beholder_death_explosion_damage_multiplier
		),
		1
	)
	trigger_beholder_death_explosion(killed_mob.global_position, explosion_damage)
	beholder_observed_target = null


func trigger_beholder_death_explosion(center: Vector2, explosion_damage: int) -> void:
	var explosion_context := RelicEffects.prepare_explosion_context(
		create_attack_context(&"beholder_death_explosion"),
		get_tree(),
		center,
		beholder_death_explosion_radius_pixels
	)
	if EXPLOSION_ZONE_SCENE != null and get_tree().current_scene != null:
		if get_tree().current_scene.has_method("spawn_explosion_visual"):
			get_tree().current_scene.spawn_explosion_visual(
				center, beholder_death_explosion_radius_pixels
			)
		else:
			var explosion_zone := EXPLOSION_ZONE_SCENE.instantiate() as Node2D
			get_tree().current_scene.add_child(explosion_zone)
			explosion_zone.global_position = center
			explosion_zone.setup(beholder_death_explosion_radius_pixels)
	for mob in get_tree().get_nodes_in_group("mobs"):
		if not RelicEffects.is_valid_explosion_target(mob, explosion_context):
			continue
		var distance_from_center: float = mob.global_position.distance_to(center)
		if distance_from_center > beholder_death_explosion_radius_pixels:
			continue
		var dealt_damage := GameStats.get_explosion_damage(
			explosion_damage,
			distance_from_center,
			beholder_death_explosion_radius_pixels
		)
		apply_tower_damage(
			mob,
			dealt_damage,
			DAMAGE_EXPLOSIVE,
			false,
			explosion_context
		)


func reset_gauss_spread() -> void:
	gauss_current_spread_degrees = gauss_maximum_spread_degrees
	gauss_time_without_target = 0.0

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
	if uses_drone_targeting():
		drone_target_mode = DroneTargetMode.DISTRIBUTED
		update_menu_buttons()
		close_menus()
		return
	target_mode = TargetMode.FIRST
	_select_target()
	close_menus()

func _on_button_last_pressed() -> void:
	if uses_drone_targeting():
		drone_target_mode = DroneTargetMode.FOCUS_MAX_HEALTH
		update_menu_buttons()
		close_menus()
		return
	target_mode = TargetMode.LAST
	_select_target()
	close_menus()
	
func _on_button_low_pressed() -> void:
	target_mode = TargetMode.LOWEST_HEALTH
	_select_target()
	close_menus()

func _on_button_high_pressed() -> void:
	target_mode = TargetMode.HIGHEST_HEALTH
	_select_target()
	close_menus()

func _on_confirm_pressed() -> void:
	set_range_preview(false)
	visual_sprite.modulate = Color.WHITE
	confirm_placement()
	$towerconfirm.visible = false
	tower_confirmed.emit(self)
	
func _on_cancel_pressed() -> void:
	$towerconfirm.visible = false
	tower_cancelled.emit(self)
	queue_free()

func _on_targetmode_pressed() -> void:
	if tower_id == SAUCER_TOWER_ID:
		return
	if uses_standard_spawner_system() and not uses_drone_targeting():
		return
	if uses_manual_ground_targeting():
		begin_manual_targeting()
		return
	show_target_menu()
	if main != null and selected:
		main.show_tower_details(self)


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


func is_spawner_tower() -> bool:
	return bonus_tags.has(BONUS_SPAWNER)


func uses_standard_spawner_system() -> bool:
	return is_spawner_tower() and tower_id != SAUCER_TOWER_ID


func uses_drone_targeting() -> bool:
	return tower_id == DRONE_DEPOT_TOWER_ID


func get_drone_target_mode() -> DroneTargetMode:
	return drone_target_mode


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


func set_slinger_contact_explosions(
	enabled: bool,
	explosion_radius_units := 2.5,
	explosion_damage_multiplier := 1.0
) -> void:
	if tower_id != SLINGER_TOWER_ID:
		return
	slinger_contact_explosions_enabled = enabled
	slinger_contact_explosion_radius_pixels = (
		maxf(explosion_radius_units, 0.0) * RANGE_PIXELS_PER_UNIT
		if enabled
		else 0.0
	)
	slinger_contact_explosion_damage_multiplier = (
		maxf(explosion_damage_multiplier, 0.0) if enabled else 1.0
	)


func load_path_behaviors() -> void:
	var previous_heavy_shot_remaining := gauss_heavy_shot_remaining
	var previous_longshot_mine_remaining := longshot_mine_remaining
	var previous_void_singularity_remaining := void_singularity_remaining
	var previous_energy_shockwave_remaining := energy_shockwave_remaining
	var previous_reaver_bubble_active := reaver_time_bubble_active_remaining
	var previous_reaver_bubble_cooldown := reaver_time_bubble_cooldown_remaining
	var previous_brainiac_link_cooldown := brainiac_link_cooldown_remaining
	infinite_pierce = false
	continuous_beam_enabled = false
	dual_weapons_enabled = false
	gauss_heavy_shot_enabled = false
	gauss_heavy_shot_interval = 0.0
	gauss_heavy_shot_damage_multiplier = 1.0
	gauss_heavy_shot_speed_multiplier = 1.0
	gauss_tracking_cone_enabled = false
	gauss_tracking_cone_degrees = 45.0
	beholder_death_explosion_enabled = false
	beholder_death_explosion_radius_pixels = 0.0
	beholder_death_explosion_damage_multiplier = 1.0
	beholder_ramping_beam_enabled = false
	beholder_beam_ramp_start_multiplier = 1.0
	beholder_beam_ramp_step_multiplier = 0.0
	beholder_beam_ramp_step_interval = 0.5
	beholder_beam_ramp_max_multiplier = 1.0
	reaver_time_bubble_enabled = false
	reaver_time_bubble_active_duration = 3.0
	reaver_time_bubble_cooldown = 7.0
	reaver_time_bubble_refresh_interval = 0.2
	reaver_time_bubble_slow_duration = 0.3
	reaver_assassinate_enabled = false
	brainiac_convergence_explosion_enabled = false
	brainiac_convergence_base_radius_pixels = 0.0
	brainiac_convergence_radius_per_arrival_pixels = 0.0
	brainiac_convergence_damage_per_arrival = 1.0
	brainiac_psionic_link_enabled = false
	brainiac_link_duration = 2.0
	brainiac_link_cooldown = 6.0
	brainiac_link_radius_pixels = 0.0
	brainiac_link_damage_share = 0.35
	longshot_distance_damage_enabled = false
	longshot_distance_minimum_multiplier = 1.0
	longshot_distance_midpoint_multiplier = 1.0
	longshot_distance_maximum_multiplier = 1.0
	longshot_mines_enabled = false
	longshot_mine_interval = 6.0
	longshot_mine_maximum_count = 3
	longshot_mine_placement_radius_pixels = 0.0
	longshot_mine_trigger_radius_pixels = 0.0
	longshot_mine_explosion_radius_pixels = 0.0
	longshot_mine_damage_multiplier = 1.0
	void_singularity_enabled = false
	void_singularity_cooldown = 10.0
	void_singularity_pull_duration = 1.0
	void_singularity_pull_radius_pixels = 0.0
	void_singularity_pull_speed = 80.0
	void_singularity_explosion_radius_pixels = 0.0
	void_singularity_damage_multiplier = 1.0
	orbital_solar_lance_enabled = false
	orbital_solar_lance_duration = 1.5
	orbital_solar_lance_tick_interval = 0.2
	orbital_solar_lance_tick_damage_multiplier = 0.25
	orbital_solar_lance_tick_end_damage_multiplier = 0.50
	orbital_solar_lance_dual_tick_damage_multiplier = 0.10
	orbital_bombardment_enabled = false
	orbital_bombardment_strike_count = 5
	orbital_bombardment_stagger = 0.15
	orbital_bombardment_spread_radius_pixels = 0.0
	orbital_bombardment_damage_multiplier = 0.38
	orbital_bombardment_radius_multiplier = 0.70
	energy_shockwave_enabled = false
	energy_shockwave_cooldown = 5.0
	energy_shockwave_damage_multiplier = 0.35
	energy_shockwave_stun_duration = 1.0
	energy_branching_current_enabled = false
	energy_branch_additional_targets = 2
	energy_branch_range_pixels = 0.0
	energy_branch_damage_multiplier = 0.30
	saucer_twin_rockets_enabled = false
	saucer_rocket_damage_multiplier = 2.0
	saucer_rocket_interval = 3.0
	saucer_monster_drop_enabled = false
	slinger_contact_explosions_enabled = false
	slinger_contact_explosion_radius_pixels = 0.0
	slinger_contact_explosion_damage_multiplier = 1.0
	for path_id in purchased_paths:
		var path := GameStats.get_tower_path(tower_id, path_id)
		var flags: Dictionary = path.get("behavior_flags", {})
		var values: Dictionary = path.get("behavior_values", {})
		if flags.get("infinite_pierce", false):
			infinite_pierce = true
		if flags.get("continuous_beam", false):
			continuous_beam_enabled = true
		if flags.get("dual_weapons", false):
			dual_weapons_enabled = true
		if flags.get("gauss_heavy_shot", false):
			gauss_heavy_shot_enabled = true
			gauss_heavy_shot_interval = maxf(
				float(values.get("heavy_shot_interval", 4.0)),
				0.1
			)
			gauss_heavy_shot_damage_multiplier = maxf(
				float(values.get("heavy_shot_damage_multiplier", 3.0)),
				1.0
			)
			gauss_heavy_shot_speed_multiplier = maxf(
				float(values.get("heavy_shot_speed_multiplier", 0.60)),
				0.1
			)
		if flags.get("gauss_tracking_cone", false):
			gauss_tracking_cone_enabled = true
			gauss_tracking_cone_degrees = clampf(
				float(values.get("tracking_cone_degrees", 45.0)),
				1.0,
				180.0
			)
		if flags.get("beholder_death_explosion", false):
			beholder_death_explosion_enabled = true
			beholder_death_explosion_radius_pixels = (
				maxf(float(values.get("death_explosion_radius", 3.0)), 0.0)
				* RANGE_PIXELS_PER_UNIT
			)
			beholder_death_explosion_damage_multiplier = maxf(
				float(values.get("death_explosion_damage_multiplier", 1.0)),
				0.0
			)
		if flags.get("beholder_ramping_beam", false):
			beholder_ramping_beam_enabled = true
			beholder_beam_ramp_start_multiplier = maxf(
				float(values.get("beam_ramp_start_multiplier", 0.5)),
				0.0
			)
			beholder_beam_ramp_step_multiplier = maxf(
				float(values.get("beam_ramp_step_multiplier", 0.25)),
				0.0
			)
			beholder_beam_ramp_step_interval = maxf(
				float(values.get("beam_ramp_step_interval", 0.5)),
				0.01
			)
			beholder_beam_ramp_max_multiplier = maxf(
				float(values.get("beam_ramp_max_multiplier", 2.5)),
				beholder_beam_ramp_start_multiplier
			)
		if flags.get("reaver_time_bubble", false):
			reaver_time_bubble_enabled = true
			reaver_time_bubble_active_duration = maxf(
				float(values.get("time_bubble_active_duration", 3.0)),
				0.01
			)
			reaver_time_bubble_cooldown = maxf(
				float(values.get("time_bubble_cooldown", 7.0)),
				0.0
			)
			reaver_time_bubble_refresh_interval = maxf(
				float(values.get("time_bubble_refresh_interval", 0.2)),
				0.05
			)
			reaver_time_bubble_slow_duration = maxf(
				float(values.get("time_bubble_slow_duration", 0.3)),
				0.01
			)
		if flags.get("reaver_assassinate", false):
			reaver_assassinate_enabled = true
		if flags.get("brainiac_convergence_explosion", false):
			brainiac_convergence_explosion_enabled = true
			brainiac_convergence_base_radius_pixels = (
				maxf(float(values.get("convergence_base_radius", 1.5)), 0.0)
				* RANGE_PIXELS_PER_UNIT
			)
			brainiac_convergence_radius_per_arrival_pixels = (
				maxf(float(values.get("convergence_radius_per_arrival", 0.65)), 0.0)
				* RANGE_PIXELS_PER_UNIT
			)
			brainiac_convergence_damage_per_arrival = maxf(
				float(values.get("convergence_damage_per_arrival", 1.0)),
				0.0
			)
		if flags.get("brainiac_psionic_link", false):
			brainiac_psionic_link_enabled = true
			brainiac_link_duration = maxf(
				float(values.get("brainiac_link_duration", 2.0)),
				0.01
			)
			brainiac_link_cooldown = maxf(
				float(values.get("brainiac_link_cooldown", 6.0)),
				0.01
			)
			brainiac_link_radius_pixels = (
				maxf(float(values.get("brainiac_link_radius", 3.5)), 0.0)
				* RANGE_PIXELS_PER_UNIT
			)
			brainiac_link_damage_share = maxf(
				float(values.get("brainiac_link_damage_share", 0.35)),
				0.0
			)
		if flags.get("longshot_distance_damage", false):
			longshot_distance_damage_enabled = true
			longshot_distance_minimum_multiplier = maxf(
				float(values.get("distance_minimum_multiplier", 1.0)),
				0.0
			)
			longshot_distance_midpoint_multiplier = clampf(
				float(values.get("distance_midpoint_multiplier", 1.0)),
				longshot_distance_minimum_multiplier,
				float(values.get("distance_maximum_multiplier", 2.0))
			)
			longshot_distance_maximum_multiplier = maxf(
				float(values.get("distance_maximum_multiplier", 2.0)),
				longshot_distance_midpoint_multiplier
			)
		if flags.get("longshot_mines", false):
			longshot_mines_enabled = true
			longshot_mine_interval = maxf(
				float(values.get("mine_interval", 6.0)),
				0.1
			)
			longshot_mine_maximum_count = maxi(
				int(values.get("mine_maximum_count", 3)),
				1
			)
			longshot_mine_placement_radius_pixels = (
				maxf(float(values.get("mine_placement_radius", 6.0)), 0.0)
				* RANGE_PIXELS_PER_UNIT
			)
			longshot_mine_trigger_radius_pixels = (
				maxf(float(values.get("mine_trigger_radius", 1.0)), 0.0)
				* RANGE_PIXELS_PER_UNIT
			)
			longshot_mine_explosion_radius_pixels = (
				maxf(float(values.get("mine_explosion_radius", 2.5)), 0.0)
				* RANGE_PIXELS_PER_UNIT
			)
			longshot_mine_damage_multiplier = maxf(
				float(values.get("mine_damage_multiplier", 1.25)),
				0.0
			)
		if flags.get("void_singularity", false):
			void_singularity_enabled = true
			void_singularity_cooldown = maxf(
				float(values.get("singularity_cooldown", 10.0)),
				0.1
			)
			void_singularity_pull_duration = maxf(
				float(values.get("singularity_pull_duration", 1.0)),
				0.01
			)
			void_singularity_pull_radius_pixels = (
				maxf(float(values.get("singularity_pull_radius", 7.0)), 0.0)
				* RANGE_PIXELS_PER_UNIT
			)
			void_singularity_pull_speed = maxf(
				float(values.get("singularity_pull_speed", 80.0)),
				0.0
			)
			void_singularity_explosion_radius_pixels = (
				maxf(float(values.get("singularity_explosion_radius", 5.0)), 0.0)
				* RANGE_PIXELS_PER_UNIT
			)
			void_singularity_damage_multiplier = maxf(
				float(values.get("singularity_damage_multiplier", 3.0)),
				0.0
			)
		if flags.get("orbital_solar_lance", false):
			orbital_solar_lance_enabled = true
			orbital_solar_lance_duration = maxf(
				float(values.get("solar_lance_duration", 1.5)),
				0.01
			)
			orbital_solar_lance_tick_interval = maxf(
				float(values.get("solar_lance_tick_interval", 0.2)),
				0.01
			)
			orbital_solar_lance_tick_damage_multiplier = maxf(
				float(values.get("solar_lance_tick_damage_multiplier", 0.25)),
				0.0
			)
			orbital_solar_lance_tick_end_damage_multiplier = maxf(
				float(values.get("solar_lance_tick_end_damage_multiplier", 0.50)),
				0.0
			)
			orbital_solar_lance_dual_tick_damage_multiplier = maxf(
				float(values.get("solar_lance_dual_tick_damage_multiplier", 0.10)),
				0.0
			)
		if flags.get("orbital_bombardment", false):
			orbital_bombardment_enabled = true
			orbital_bombardment_strike_count = maxi(
				int(values.get("bombardment_strike_count", 5)),
				1
			)
			orbital_bombardment_stagger = maxf(
				float(values.get("bombardment_stagger", 0.15)),
				0.0
			)
			orbital_bombardment_spread_radius_pixels = (
				maxf(float(values.get("bombardment_spread_radius", 3.0)), 0.0)
				* RANGE_PIXELS_PER_UNIT
			)
			orbital_bombardment_damage_multiplier = maxf(
				float(values.get("bombardment_damage_multiplier", 0.38)),
				0.0
			)
			orbital_bombardment_radius_multiplier = maxf(
				float(values.get("bombardment_radius_multiplier", 0.70)),
				0.0
			)
		if flags.get("energy_shockwave", false):
			energy_shockwave_enabled = true
			energy_shockwave_cooldown = maxf(
				float(values.get("shockwave_cooldown", 5.0)),
				0.1
			)
			energy_shockwave_damage_multiplier = maxf(
				float(values.get("shockwave_damage_multiplier", 0.35)),
				0.0
			)
			energy_shockwave_stun_duration = maxf(
				float(values.get("shockwave_stun_duration", 1.0)),
				0.0
			)
		if flags.get("energy_branching_current", false):
			energy_branching_current_enabled = true
			energy_branch_additional_targets = maxi(
				int(values.get("branch_additional_targets", 2)),
				0
			)
			energy_branch_range_pixels = (
				maxf(float(values.get("branch_range", 4.0)), 0.0)
				* RANGE_PIXELS_PER_UNIT
			)
			energy_branch_damage_multiplier = clampf(
				float(values.get("branch_damage_multiplier", 0.30)),
				0.0,
				1.0
			)
		if flags.get("saucer_twin_rockets", false):
			saucer_twin_rockets_enabled = true
			saucer_rocket_damage_multiplier = maxf(
				float(values.get("saucer_rocket_damage_multiplier", 2.0)),
				0.0
			)
			saucer_rocket_interval = maxf(
				float(values.get("saucer_rocket_interval", 3.0)),
				0.1
			)
		if flags.get("saucer_monster_drop", false):
			saucer_monster_drop_enabled = true
		if flags.get("slinger_contact_explosions", false):
			set_slinger_contact_explosions(
				true,
				float(values.get("contact_explosion_radius", 2.5)),
				float(values.get(
					"contact_explosion_damage_multiplier",
					1.0
				))
			)
	if has_damage_tag(DAMAGE_BEAM) and get_owned_relic_count(&"death_ray") > 0:
		infinite_pierce = true
	apply_psionic_relic_behavior_modifiers()
	apply_explosive_relic_behavior_modifiers()
	if brainiac_psionic_link_enabled:
		brainiac_link_cooldown_remaining = minf(
			previous_brainiac_link_cooldown,
			brainiac_link_cooldown
		)
	else:
		brainiac_link_cooldown_remaining = 0.0
	if gauss_heavy_shot_enabled:
		gauss_heavy_shot_remaining = (
			minf(previous_heavy_shot_remaining, gauss_heavy_shot_interval)
			if previous_heavy_shot_remaining > 0.0
			else gauss_heavy_shot_interval
		)
	else:
		gauss_heavy_shot_remaining = 0.0
	if reaver_time_bubble_enabled:
		if previous_reaver_bubble_active > 0.0:
			reaver_time_bubble_active_remaining = minf(
				previous_reaver_bubble_active,
				reaver_time_bubble_active_duration
			)
			reaver_time_bubble_cooldown_remaining = 0.0
		elif previous_reaver_bubble_cooldown > 0.0:
			reaver_time_bubble_active_remaining = 0.0
			reaver_time_bubble_cooldown_remaining = minf(
				previous_reaver_bubble_cooldown,
				reaver_time_bubble_cooldown
			)
		else:
			reaver_time_bubble_active_remaining = 0.0
			reaver_time_bubble_cooldown_remaining = 0.0
	else:
		reaver_time_bubble_active_remaining = 0.0
		reaver_time_bubble_cooldown_remaining = 0.0
		reaver_time_bubble_refresh_remaining = 0.0
	if longshot_mines_enabled:
		longshot_mine_remaining = (
			minf(previous_longshot_mine_remaining, longshot_mine_interval)
			if previous_longshot_mine_remaining > 0.0
			else longshot_mine_interval
		)
	else:
		longshot_mine_remaining = 0.0
	if void_singularity_enabled:
		void_singularity_remaining = (
			minf(previous_void_singularity_remaining, void_singularity_cooldown)
			if previous_void_singularity_remaining > 0.0
			else void_singularity_cooldown
		)
	else:
		void_singularity_remaining = 0.0
	if energy_shockwave_enabled:
		energy_shockwave_remaining = (
			minf(previous_energy_shockwave_remaining, energy_shockwave_cooldown)
			if previous_energy_shockwave_remaining > 0.0
			else energy_shockwave_cooldown
		)
	else:
		energy_shockwave_remaining = 0.0


func apply_psionic_relic_behavior_modifiers() -> void:
	if not has_bonus_tag(BONUS_PSIONIC):
		return
	var lingering_count := get_owned_relic_count(&"lingering_thoughts")
	var quick_count := get_owned_relic_count(&"quick_thinking")
	var duration_multiplier := (
		pow(GameStats.LINGERING_THOUGHTS_DURATION_MULTIPLIER, lingering_count)
		* pow(GameStats.QUICK_THINKING_DURATION_MULTIPLIER, quick_count)
	)
	var cooldown_multiplier := pow(
		GameStats.QUICK_THINKING_COOLDOWN_MULTIPLIER,
		quick_count
	)
	if reaver_time_bubble_enabled:
		reaver_time_bubble_active_duration *= duration_multiplier
		reaver_time_bubble_cooldown *= cooldown_multiplier
	if brainiac_psionic_link_enabled:
		brainiac_link_duration *= duration_multiplier
		brainiac_link_cooldown *= cooldown_multiplier
	if void_singularity_enabled:
		void_singularity_pull_duration *= duration_multiplier
		void_singularity_cooldown *= cooldown_multiplier


func apply_explosive_relic_behavior_modifiers() -> void:
	if not has_damage_tag(DAMAGE_EXPLOSIVE):
		return
	var radius_multiplier := get_explosion_radius_multiplier()
	var damage_multiplier := get_explosion_damage_multiplier()
	var interval_multiplier := get_explosion_interval_multiplier()

	# These are secondary or path-granted explosions, so their damage has not
	# already been adjusted through the tower's primary attack stats.
	if get_primary_damage_type() != DAMAGE_EXPLOSIVE:
		beholder_death_explosion_damage_multiplier *= damage_multiplier
		brainiac_convergence_damage_per_arrival *= damage_multiplier
		longshot_mine_damage_multiplier *= damage_multiplier
		saucer_rocket_damage_multiplier *= damage_multiplier

	beholder_death_explosion_radius_pixels *= radius_multiplier
	brainiac_convergence_base_radius_pixels *= radius_multiplier
	brainiac_convergence_radius_per_arrival_pixels *= radius_multiplier
	longshot_mine_explosion_radius_pixels *= radius_multiplier
	void_singularity_explosion_radius_pixels *= radius_multiplier
	slinger_contact_explosion_radius_pixels *= radius_multiplier

	longshot_mine_interval *= interval_multiplier
	void_singularity_cooldown *= interval_multiplier
	saucer_rocket_interval *= interval_multiplier
	
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
