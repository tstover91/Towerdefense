class_name SlingerAttackComponent
extends TowerAttackComponent

var contact_explosions_enabled := false
var contact_explosion_radius_pixels := 0.0
var contact_explosion_damage_multiplier := 1.0
var return_flight_enabled := false
var return_damage_multiplier := 0.60


func reset_path_behaviors() -> void:
	contact_explosions_enabled = false
	contact_explosion_radius_pixels = 0.0
	contact_explosion_damage_multiplier = 1.0
	return_flight_enabled = false
	return_damage_multiplier = 0.60


func apply_path_behavior(flags: Dictionary, values: Dictionary) -> void:
	if flags.get("razor_return_flight", false):
		return_flight_enabled = true
		return_damage_multiplier = clampf(
			float(values.get("razor_return_damage_multiplier", 0.60)), 0.0, 1.0
		)
	if not flags.get("slinger_contact_explosions", false):
		return
	contact_explosions_enabled = true
	contact_explosion_radius_pixels = (
		maxf(float(values.get("contact_explosion_radius", 2.5)), 0.0)
		* BaseTower.RANGE_PIXELS_PER_UNIT
	)
	contact_explosion_damage_multiplier = maxf(
		float(values.get("contact_explosion_damage_multiplier", 1.0)), 0.0
	)


func finalize_path_behaviors() -> void:
	if contact_explosions_enabled and tower.has_damage_tag(BaseTower.DAMAGE_EXPLOSIVE):
		contact_explosion_radius_pixels *= tower.get_explosion_radius_multiplier()


func projectile_contact_explosions_enabled() -> bool:
	return contact_explosions_enabled


func projectile_contact_explosion_radius() -> float:
	return contact_explosion_radius_pixels


func projectile_contact_explosion_damage_multiplier() -> float:
	return (
		contact_explosion_damage_multiplier
		* tower.get_explosion_damage_multiplier()
	)


func projectile_return_flight_enabled() -> bool:
	return return_flight_enabled


func projectile_return_damage_multiplier() -> float:
	return return_damage_multiplier
