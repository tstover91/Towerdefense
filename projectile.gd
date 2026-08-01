class_name TowerProjectile
extends Node2D

var destination := Vector2.ZERO
var speed := 600.0


func setup(target_position: Vector2, move_speed: float) -> void:
	destination = target_position
	speed = move_speed
	rotation = (destination - global_position).angle()


func _physics_process(delta: float) -> void:
	var offset := destination - global_position
	var travel_distance := speed * delta

	if offset.length() <= travel_distance:
		global_position = destination
		queue_free()
		return

	global_position += offset.normalized() * travel_distance
