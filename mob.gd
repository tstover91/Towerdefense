extends CharacterBody2D

const GameStats = preload("res://stat_database.gd")

signal mob_killed(reward: int)
signal reached_end(damage: int)
signal spawn_requested(enemy_id: StringName, path_progress: float)


@export var enemy_id: StringName = GameStats.DEFAULT_ENEMY_ID
var wave_number := 1
var health_multiplier := 1.0
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


func set_path_follow(pf: PathFollow2D, start_progress := 0.0) -> void:
	path_follow = pf
	path_follow.progress = maxf(start_progress, 0.0)
	position = Vector2.ZERO
	update_health_bar_position()
	
func _process(delta: float) -> void:
	if path_follow == null or finished:
		return

	_process_regeneration(delta)
	_process_summoning(delta)
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
	var base_health: int = stats["health"]
	var health_per_wave: float = stats.get("health_per_wave", 0.0)
	var scaled_health := base_health + health_per_wave * maxi(wave_number - 1, 0)
	health = maxi(1, roundi(scaled_health * health_multiplier))
	max_health = health
	speed = stats["move_speed"]
	cash_reward = stats["cash_reward"]
	base_damage = stats.get("base_damage", health)
	defense = stats.get("defense", 0.0)
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
	var visual_scale: float = stats.get("visual_scale", 1.0)
	sprite.modulate = stats.get("color", Color.WHITE)
	sprite.scale = Vector2.ONE * 2.0 * visual_scale
	health_bar.max_value = health
	health_bar.value = health


func get_leak_damage() -> int:
	var health_ratio := clampf(float(health) / float(max_health), 0.0, 1.0)
	return maxi(1, ceili(base_damage * health_ratio))


func get_effective_speed() -> float:
	var result := speed

	if path_follow.progress_ratio >= rush_start_ratio:
		result *= rush_speed_multiplier

	var strongest_aura := 1.0
	for candidate in get_tree().get_nodes_in_group("speed_buffers"):
		if candidate == self or not candidate.has_method("get_speed_buff_for"):
			continue
		strongest_aura = maxf(strongest_aura, candidate.get_speed_buff_for(self))

	return result * strongest_aura


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
	spawn_requested.emit(summon_enemy_id, path_follow.progress)

func die() -> void:
	if finished:
		return

	finished = true
	spawn_split_children()
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
		spawn_requested.emit(split_enemy_id, maxf(child_progress, 0.0))

func apply_damage(amount: int, damage_type: StringName) -> void:
	if finished:
		return

	var effective_defense := defense
	if damage_type == &"explosive":
		effective_defense *= 0.5
	var final_damage := maxi(1, floori(amount * (1.0 - effective_defense)))

	health -= final_damage
	health_bar.value = health

	if health <= 0:
		die()
