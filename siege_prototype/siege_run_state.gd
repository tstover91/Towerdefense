class_name SiegeRunState
extends RefCounted

const FIRST_TOWN_HALL := 2
const LAST_TOWN_HALL := 7
const TOTAL_ROUNDS := 12

var town_hall := 2
var round_number := 1
var currency := 16
var completed := false
var wall_plan_claims: Dictionary = {}
var blueprint: Array[Dictionary] = []
var precombat_blueprint: Array[Dictionary] = []


func begin_combat(current_blueprint: Array[Dictionary]) -> void:
	precombat_blueprint = current_blueprint.duplicate(true)


func record_victory(reward: int, current_blueprint: Array[Dictionary]) -> Dictionary:
	currency += maxi(reward, 0)
	blueprint = current_blueprint.duplicate(true)
	if round_number >= TOTAL_ROUNDS:
		completed = true
	else:
		round_number += 1
	return {"completed": completed}


func upgrade_town_hall() -> bool:
	if completed or town_hall >= LAST_TOWN_HALL:
		return false
	town_hall += 1
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


func has_claimed_wall_plan_for_current_rank() -> bool:
	return wall_plan_claims.has(get_fortress_rank())


func claim_wall_plan(plan_id: StringName) -> void:
	wall_plan_claims[get_fortress_rank()] = plan_id
