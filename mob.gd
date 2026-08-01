extends CharacterBody2D

const GameStats = preload("res://stat_database.gd")

signal mob_killed(reward: int)
signal reached_end(damage: int)


@export var enemy_id: StringName = GameStats.DEFAULT_ENEMY_ID
var health: int
@onready var health_bar: TextureProgressBar = $HealthBar
var speed: float
var cash_reward: int
var path_follow: PathFollow2D
var finished := false


func set_path_follow(pf: PathFollow2D):
	path_follow = pf
	path_follow.progress = 0
	position = Vector2.ZERO
	
func _process(delta):
	if path_follow == null or finished:
		return

	path_follow.progress += speed * delta

	if path_follow.progress_ratio >= 1.0:
		finished = true
		reached_end.emit(health)
		path_follow.queue_free()

func _ready():
	load_stats()

func load_stats() -> void:
	var stats: Dictionary = GameStats.get_enemy(enemy_id)
	health = stats["health"]
	speed = stats["move_speed"]
	cash_reward = stats["cash_reward"]
	health_bar.max_value = health
	health_bar.value = health

func die():
	if finished:
		return

	finished = true
	mob_killed.emit(cash_reward)

	if is_instance_valid(path_follow):
		path_follow.queue_free()
	else:
		queue_free()

func apply_damage(amount: int, _damage_type: StringName = &"physical") -> void:
	if finished:
		return

	health -= amount
	health_bar.value = health

	if health <= 0:
		die()
