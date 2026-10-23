class_name SiegeRunState
extends RefCounted

const FIRST_TOWN_HALL := 2
const LAST_TOWN_HALL := 7
const TOTAL_ROUNDS := 12
const STARTING_WALL_RESERVE := 25
const WALLS_PER_VICTORY := 6
const WALLS_PER_TOWN_HALL := 10

var town_hall := 2
var round_number := 1
var currency := 16
var completed := false
var wall_reserve := STARTING_WALL_RESERVE
var opening_wall_plan_placed := false
var blueprint: Array[Dictionary] = []
var precombat_blueprint: Array[Dictionary] = []


func begin_combat(current_blueprint: Array[Dictionary]) -> void:
	precombat_blueprint = current_blueprint.duplicate(true)


func record_victory(reward: int, current_blueprint: Array[Dictionary]) -> Dictionary:
	currency += maxi(reward, 0)
	blueprint = current_blueprint.duplicate(true)
	var wall_reward := 0
	if round_number >= TOTAL_ROUNDS:
		completed = true
	else:
		wall_reward = WALLS_PER_VICTORY
		wall_reserve += wall_reward
		round_number += 1
	return {"completed": completed, "wall_reward": wall_reward}


func upgrade_town_hall() -> bool:
	if completed or town_hall >= LAST_TOWN_HALL:
		return false
	town_hall += 1
	wall_reserve += WALLS_PER_TOWN_HALL
	return true


func record_defeat() -> Array[Dictionary]:
	blueprint = precombat_blueprint.duplicate(true)
	return blueprint.duplicate(true)


func spend(amount: int) -> bool:
	if amount < 0 or currency < amount:
		return false
	currency -= amount
	return true


func get_round_number() -> int:
	return round_number


func get_total_rounds() -> int:
	return TOTAL_ROUNDS


func get_fortress_rank() -> int:
	return town_hall - FIRST_TOWN_HALL + 1


func get_total_ranks() -> int:
	return LAST_TOWN_HALL - FIRST_TOWN_HALL + 1


func can_spend_walls(amount: int) -> bool:
	return amount >= 0 and wall_reserve >= amount


func spend_walls(amount: int) -> bool:
	if not can_spend_walls(amount):
		return false
	wall_reserve -= amount
	return true


func mark_opening_wall_plan_placed() -> void:
	opening_wall_plan_placed = true
