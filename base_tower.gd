class_name BaseTower
extends Node2D

const GameStats = preload("res://stat_database.gd")
const DEFAULT_PROJECTILE_SCENE = preload("res://projectile.tscn")
const SPAWNED_UNIT_SCENE = preload("res://spawned_unit.tscn")
const RANGE_PIXELS_PER_UNIT := 12.9
const BUILD_CELL_SIZE := GameStats.BUILD_CELL_SIZE
const MENU_HALF_WIDTH := 106.0
const MENU_EDGE_MARGIN := 8.0
const GAUSS_TOWER_ID: StringName = &"gauss_repeater"
const BRAINIAC_TOWER_ID: StringName = &"brainiac"
const VOID_CALLER_TOWER_ID: StringName = &"voidcaller"
const REAVER_TOWER_ID: StringName = &"reaver"
const BEHOLDER_TOWER_ID: StringName = &"beholder"
const SLINGER_TOWER_ID: StringName = &"slinger"
const GAUSS_LINE_HALF_WIDTH := 3.0
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
@export var tower_id: StringName = GameStats.DEFAULT_TOWER_ID
@export var projectile_scene: PackedScene = DEFAULT_PROJECTILE_SCENE
@onready var tower_area: Area2D = $Tower
@onready var rotator: Node2D = $Rotator
@onready var muzzle: Marker2D = $Rotator/Muzzle
@onready var damage_timer: Timer = $Timer
@onready var upgrade_button: Button = $HBoxContainer/upgradetower
var tower_level := 0
var damage: int
var damage_type: StringName = &""
var critical_chance := GameStats.DEFAULT_CRITICAL_CHANCE
var critical_multiplier := GameStats.DEFAULT_CRITICAL_MULTIPLIER
var slow_duration := 0.0
var stun_duration := 0.0
var stun_affects_bosses := false
var bounce_count := 0
var bounce_range_pixels := 0.0
var slinger_bounce_explosions_enabled := false
var slinger_bounce_explosion_radius_pixels := 0.0
var projectile_count := 1
var volley_width_pixels := 0.0
var volley_stagger := 0.0
var combo_hit_count := 1
var combo_stagger := 0.0
var active_combo_sequence := 0
var gauss_maximum_spread_degrees := 0.0
var gauss_current_spread_degrees := 0.0
var gauss_spread_tighten_per_shot := 0.0
var gauss_spread_tighten_duration := 0.0
var gauss_spread_recovery_delay := 0.0
var gauss_spread_recovery_per_second := 0.0
var gauss_time_since_last_shot := 0.0
var gauss_spread_initialized := false
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
	var beam_start := to_local(muzzle.global_position)
	var beam_end := to_local(target.global_position)
	draw_line(
		beam_start,
		beam_end,
		Color(0.55, 0.1, 0.85, 0.35),
		7.0,
		true
	)
	draw_line(
		beam_start,
		beam_end,
		Color(0.95, 0.55, 1.0, 0.95),
		2.5,
		true
	)
	draw_circle(beam_end, 4.0, Color(1.0, 0.75, 1.0, 0.9))


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
	$HBoxContainer.visible = true
	$targetui.visible = false
	if direction_ui != null:
		direction_ui.visible = false
	update_menu_buttons()

func show_target_menu() -> void:
	pending_action = MenuAction.NONE
	show_current_range_preview()
	$HBoxContainer.visible = false
	$targetui.visible = not uses_directional_aim()
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
	if is_spawner_tower():
		$HBoxContainer/targetmode.text = "Units\nAuto"
		$HBoxContainer/targetmode.disabled = true
	elif uses_directional_aim():
		$HBoxContainer/targetmode.disabled = false
		$HBoxContainer/targetmode.text = "Aim\nDirection"
	else:
		$HBoxContainer/targetmode.disabled = false
		$HBoxContainer/targetmode.text = "Target\n%s" % get_target_mode_name()

func close_menus() -> void:
	pending_action = MenuAction.NONE
	selected = false
	$HBoxContainer.visible = false
	$targetui.visible = false
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


func get_total_invested() -> int:
	var tower_data: Dictionary = GameStats.get_tower(tower_id)
	var levels: Array = tower_data["levels"]
	var total: int = tower_data["placement_cost"]

	for level in range(1, tower_level + 1):
		total += levels[level]["upgrade_cost"]

	return total

func get_sell_price() -> int:
	return floori(get_total_invested() / 3.0)

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
	if is_spawner_tower():
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


func uses_continuous_beam() -> bool:
	return tower_id == BEHOLDER_TOWER_ID


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
	damage_timer.start()


func load_level_stats() -> void:
	var stats := get_effective_stats_for_level(tower_level)
	var tower_data := GameStats.get_tower(tower_id)
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
	gauss_spread_tighten_duration = maxf(
		float(stats.get("spread_tighten_duration", 0.0)),
		0.0
	)
	gauss_spread_tighten_per_shot = 0.0
	if gauss_spread_tighten_duration > 0.0:
		gauss_spread_tighten_per_shot = (
			gauss_maximum_spread_degrees
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
	if uses_directional_aim() and not gauss_spread_initialized:
		gauss_current_spread_degrees = gauss_maximum_spread_degrees
		gauss_spread_initialized = true
	else:
		gauss_current_spread_degrees = minf(
			gauss_current_spread_degrees,
			gauss_maximum_spread_degrees
		)
	damage_type = get_primary_damage_type()
	projectile_speed = stats.get("projectile_speed", 600.0)
	splash_radius_pixels = float(stats.get("splash_radius", 0.0)) * RANGE_PIXELS_PER_UNIT
	if is_spawner_tower():
		spawned_unit_id = tower_data.get("spawned_unit_id", &"")
		spawn_limit = maxi(int(stats.get("spawn_limit", 1)), 1)
		deployment_radius_pixels = (
			float(stats.get("deployment_radius", 1.0))
			* RANGE_PIXELS_PER_UNIT
		)
		damage_timer.wait_time = maxf(float(stats.get("spawn_interval", 1.0)), 0.1)
		refresh_spawned_unit_stats(stats["unit_stats"])
	else:
		damage_timer.wait_time = stats["firerate"]
	var range_shape := $Tower/CollisionShape2D.shape.duplicate() as CircleShape2D
	range_radius_pixels = stats["range"] * RANGE_PIXELS_PER_UNIT
	range_shape.radius = range_radius_pixels
	$Tower/CollisionShape2D.shape = range_shape
	queue_redraw()


func get_effective_stats_for_level(level: int) -> Dictionary:
	var stats := GameStats.get_tower_level(tower_id, level)
	if is_spawner_tower():
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
	return stats


func get_sidebar_stats() -> Dictionary:
	var tower_data := GameStats.get_tower(tower_id)
	var levels: Array = tower_data["levels"]
	var next_level := tower_level + 1
	var result := {
		"display_name": tower_data["display_name"],
		"is_placed": is_placed,
		"level": tower_level,
		"maximum_level": levels.size() - 1,
		"has_next_level": next_level < levels.size(),
		"show_upgrade_info": is_placed and pending_action == MenuAction.UPGRADE,
	}

	if next_level < levels.size():
		result["next_level"] = next_level
	return result


func get_main_bonus(effect: StringName) -> float:
	if main == null:
		return 0.0
	return main.get_run_bonus(effect)


func get_main_multiplier(effect: StringName) -> float:
	return 1.0 + get_main_bonus(effect)


func _spawn_unit() -> void:
	if not is_placed or not is_spawner_tower() or spawned_unit_id.is_empty():
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


func _on_round_started(_round_number: int) -> void:
	if is_placed and is_spawner_tower():
		damage_timer.start()


func _on_round_ended(_round_number: int) -> void:
	if not is_spawner_tower():
		return
	damage_timer.stop()
	clear_spawned_units()


func _exit_tree() -> void:
	clear_spawned_units()


func _apply_damage() -> void:
	if not is_placed:
		return

	if (
		not uses_continuous_beam()
		or not is_valid_target(target)
		or not mobs_in_range.has(target)
	):
		_select_target()
	if is_valid_target(target):
		attack(target)


func attack(current_target: Node2D) -> void:
	if not is_instance_valid(current_target):
		return

	var attack_damage := roll_attack_damage()
	if tower_id == REAVER_TOWER_ID:
		launch_reaver_combo(current_target, attack_damage)
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


func roll_attack_damage() -> int:
	if (
		has_bonus_tag(BONUS_CRITICAL)
		and spawn_rng.randf() < critical_chance
	):
		return maxi(roundi(float(damage) * critical_multiplier), 1)
	return damage


func launch_reaver_combo(current_target: Node2D, attack_damage: int) -> void:
	active_combo_sequence += 1
	var combo_sequence := active_combo_sequence
	var target_reference: WeakRef = weakref(current_target)
	for hit_index in combo_hit_count:
		var hit_damage := get_combo_hit_damage(attack_damage, hit_index)
		var hit_delay := combo_stagger * float(hit_index)
		if hit_delay <= 0.0:
			apply_reaver_combo_hit(
				target_reference,
				hit_damage,
				combo_sequence
			)
		else:
			get_tree().create_timer(hit_delay, false).timeout.connect(
				apply_reaver_combo_hit.bind(
					target_reference,
					hit_damage,
					combo_sequence
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
	combo_sequence: int
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
	apply_hitscan_damage(combo_target, hit_damage)


func launch_projectile(current_target: Node2D, attack_damage: int) -> void:
	if projectile_scene == null:
		push_error("Projectile tower %s has no projectile scene." % tower_id)
		return

	var impact_radius := splash_radius_pixels if damage_type == DAMAGE_EXPLOSIVE else 0.0
	var projectile_target_position := current_target.global_position
	var maximum_projectile_distance := range_radius_pixels
	if uses_directional_aim():
		var spread_offset_degrees := spawn_rng.randf_range(
			-gauss_current_spread_degrees,
			gauss_current_spread_degrees
		)
		var projectile_direction := aim_direction.rotated(
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
			0.0
		)
		gauss_time_since_last_shot = 0.0
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
	var aim_offset := current_target.global_position - global_position
	if aim_offset.is_zero_approx():
		return
	var direction := aim_offset.normalized()
	var perpendicular := direction.orthogonal()
	var convergence_point := global_position + direction * range_radius_pixels
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
		launch_projectile_from_position(
			current_target,
			launch_position,
			convergence_point,
			launch_position.distance_to(convergence_point),
			attack_damage,
			0.0
		)


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
				attack_damage
			)
		else:
			get_tree().create_timer(release_delay, false).timeout.connect(
				launch_delayed_volley_projectile.bind(
					target_reference,
					destination,
					attack_damage
				)
			)


func launch_delayed_volley_projectile(
	target_reference: WeakRef,
	destination: Vector2,
	attack_damage: int
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
		splash_radius_pixels
	)


func launch_projectile_from_position(
	current_target: Node2D,
	launch_position: Vector2,
	destination: Vector2,
	maximum_projectile_distance: float,
	attack_damage: int,
	impact_radius: float
) -> void:
	if projectile_scene == null:
		return
	var projectile := projectile_scene.instantiate() as TowerProjectile
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = launch_position
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
		slinger_bounce_explosions_enabled,
		slinger_bounce_explosion_radius_pixels
	)


func apply_hitscan_damage(current_target: Node2D, attack_damage: int) -> void:
	var origin := muzzle.global_position
	var primary_position := current_target.global_position
	var aim_offset := primary_position - origin
	apply_control_effects(current_target)
	current_target.apply_damage(attack_damage, damage_type, pierce_count > 0)
	if pierce_count < 1:
		return
	if aim_offset.is_zero_approx():
		return

	var direction := aim_offset.normalized()
	var pierce_origin := primary_position + direction * 0.01
	var end := origin + direction * range_radius_pixels
	var targets := get_targets_along_line(
		pierce_origin,
		end,
		current_target
	)
	for index in mini(targets.size(), pierce_count):
		apply_control_effects(targets[index])
		var pierced_damage := GameStats.get_piercing_damage(
			attack_damage,
			index + 1
		)
		targets[index].apply_damage(pierced_damage, damage_type, true)


func apply_control_effects(current_target: Node) -> void:
	if slow_duration > 0.0 and current_target.has_method("apply_slow"):
		current_target.apply_slow(slow_duration)
	if stun_duration > 0.0 and current_target.has_method("apply_stun"):
		current_target.apply_stun(stun_duration, stun_affects_bosses)


func get_targets_along_line(
	origin: Vector2,
	end: Vector2,
	excluded_target: Node = null
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
		if mob.global_position.distance_to(closest_point) > hit_radius:
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
	process_gauss_spread(delta)
	if uses_continuous_beam():
		queue_redraw()
	if not is_placed:
		if uses_directional_aim():
			rotator.rotation = aim_direction.angle()
		return
	if uses_directional_aim():
		rotator.rotation = aim_direction.angle()
	if not is_instance_valid(target):
		target = null
	if not is_valid_target(target):
		_select_target()
	if is_valid_target(target) and not uses_directional_aim():
		var desired_angle = (target.global_position - rotator.global_position).angle()
		rotator.rotation = lerp_angle(rotator.rotation, desired_angle, 5.0 * delta)


func update_menu_layout() -> void:
	if (
		not $towerconfirm.visible
		and not $HBoxContainer.visible
		and not $targetui.visible
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

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("mobs") and not mobs_in_range.has(body):
		mobs_in_range.append(body)
		if not is_valid_target(target):
			_select_target()

func _on_body_exited(body: Node2D) -> void:
	mobs_in_range.erase(body)
	if body == target:
		target = null

func is_valid_target(candidate: Variant) -> bool:
	var valid_target: bool = (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and not candidate.finished
	)
	if not valid_target:
		return false
	if candidate.traits.has(&"hidden"):
		return has_bonus_tag(BONUS_REVEAL) or pierce_count > 0
	return true


func _select_target() -> void:
	if uses_directional_aim():
		_select_directional_target()
		return
	mobs_in_range = mobs_in_range.filter(
		func(mob):
			return is_valid_target(mob)
	)
	
	if mobs_in_range.is_empty():
		target = null
		return

	target = mobs_in_range[0]
	for candidate in mobs_in_range:
		match target_mode:
			TargetMode.FIRST:
				if candidate.path_follow.progress > target.path_follow.progress:
					target = candidate
			TargetMode.LAST:
				if candidate.path_follow.progress < target.path_follow.progress:
					target = candidate
			TargetMode.LOWEST_HEALTH:
				if candidate.health < target.health:
					target = candidate
			TargetMode.HIGHEST_HEALTH:
				if candidate.health > target.health:
					target = candidate


func _select_directional_target() -> void:
	target = null
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


func process_gauss_spread(delta: float) -> void:
	if not uses_directional_aim() or not is_placed:
		return
	gauss_time_since_last_shot += delta
	if gauss_time_since_last_shot <= gauss_spread_recovery_delay:
		return
	gauss_current_spread_degrees = minf(
		gauss_current_spread_degrees
		+ gauss_spread_recovery_per_second * delta,
		gauss_maximum_spread_degrees
	)


func reset_gauss_spread() -> void:
	gauss_current_spread_degrees = gauss_maximum_spread_degrees
	gauss_time_since_last_shot = 0.0

func _on_clickarea_input_event(_viewport, event, _shape_idx) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and main != null
		and main.can_select_tower()
	):
		main.close_all_tower_menus()
		set_selected(true)

func _on_button_first_pressed() -> void:
	target_mode = TargetMode.FIRST
	_select_target()
	close_menus()

func _on_button_last_pressed() -> void:
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
	var sprite = $Rotator
	set_range_preview(false)
	sprite.modulate = Color(1, 1, 1, 1)
	confirm_placement()
	$towerconfirm.visible = false
	tower_confirmed.emit(self)
	
func _on_cancel_pressed() -> void:
	$towerconfirm.visible = false
	tower_cancelled.emit(self)
	queue_free()

func _on_targetmode_pressed() -> void:
	if is_spawner_tower():
		return
	show_target_menu()
	if main != null and selected:
		main.show_tower_details(self)

func _on_upgradetower_pressed() -> void:
	if pending_action != MenuAction.UPGRADE:
		pending_action = MenuAction.UPGRADE
		show_upgrade_range_preview()
		update_menu_buttons()
		if main != null and selected:
			main.show_tower_details(self)
		return

	var tower_data: Dictionary = GameStats.get_tower(tower_id)
	var levels: Array = tower_data["levels"]
	var next_level := tower_level + 1

	if next_level >= levels.size():
		return

	var upgrade_cost: int = levels[next_level]["upgrade_cost"]

	if main.spend_money(upgrade_cost):
		tower_level = next_level
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


func set_slinger_bounce_explosions(
	enabled: bool,
	explosion_radius_units := 2.5
) -> void:
	if tower_id != SLINGER_TOWER_ID:
		return
	slinger_bounce_explosions_enabled = enabled
	slinger_bounce_explosion_radius_pixels = (
		maxf(explosion_radius_units, 0.0) * RANGE_PIXELS_PER_UNIT
		if enabled
		else 0.0
	)
	
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

	set_pierce_count(int(tower_data.get(
		"pierce_count",
		1 if bonus_tags.has(BONUS_PIERCE) else 0
	)))
	delivery_type = tower_data.get("delivery_type", GameStats.DELIVERY_HITSCAN)
	impact_mode = tower_data.get("impact_mode", GameStats.IMPACT_PRIMARY)

	assert(
		damage_tags.size() == 1,
		"Tower %s must have exactly one base damage tag." % tower_id
	)
	assert(
		delivery_type in [GameStats.DELIVERY_PROJECTILE, GameStats.DELIVERY_HITSCAN],
		"Tower %s has an invalid delivery type." % tower_id
	)
	assert(
		impact_mode in [
			GameStats.IMPACT_PRIMARY,
			GameStats.IMPACT_FIRST_CONTACT,
			GameStats.IMPACT_DESTINATION,
		],
		"Tower %s has an invalid impact mode." % tower_id
	)


func get_primary_damage_type() -> StringName:
	assert(
		damage_tags.size() == 1,
		"Tower %s must have exactly one active damage tag." % tower_id
	)
	return damage_tags[0]
