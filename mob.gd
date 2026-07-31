extends CharacterBody2D

signal mob_killed(reward: int)
signal reached_end(damage: int)


@export var health: int = 100
@onready var health_bar: TextureProgressBar = $HealthBar
@export var speed := 100.0
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
		reached_end.emit(1)
		path_follow.queue_free()

func _ready():
	health_bar.value = health

func die():
	mob_killed.emit(10)

	if is_instance_valid(path_follow):
		path_follow.queue_free()
	else:
		queue_free()

func apply_damage(amount: int) -> void:
	health -= amount
	health_bar.value = health

	if health <= 0:
		die()
