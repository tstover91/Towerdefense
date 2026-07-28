extends CharacterBody2D

signal mob_killed(reward)

@export var health: int = 100
@onready var health_bar: TextureProgressBar = $HealthBar
@export var speed := 100.0
var path_follow: PathFollow2D

func set_path_follow(pf):
	path_follow = pf
	path_follow.progress = 0
	
func _process(delta):
	if path_follow:
		path_follow.progress += speed * delta
		global_position = path_follow.global_position
		$Sprite.rotation = path_follow.rotation
		
func _ready():
	health_bar.value = health

func die():
	emit_signal("mob_killed", 10)
	queue_free()

func apply_damage(amount: int) -> void:
	health -= amount
	health_bar.value = health

	if health <= 0:
		die()
