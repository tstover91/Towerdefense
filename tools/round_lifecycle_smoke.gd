extends Node

const MAIN_SCENE = preload("res://main.tscn")
const RoundControllerScript = preload("res://round_controller.gd")


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var gameplay := MAIN_SCENE.instantiate()
	add_child(gameplay)
	assert(gameplay.round_controller != null)
	assert(gameplay.round_number == 0)
	assert(not gameplay.round_active)

	var starting_money: int = gameplay.money
	gameplay.start_round()
	assert(gameplay.round_number == 1)
	assert(gameplay.round_active)
	assert(gameplay.round_controller.phase == RoundControllerScript.PHASE_ACTIVE)
	assert(gameplay.round_duration > 0.0)

	gameplay.end_round()
	assert(not gameplay.round_active)
	assert(gameplay.money > starting_money)
	assert(gameplay.shop_open)
	assert(gameplay.active_draft_type == &"relic")
	assert(gameplay.round_controller.phase == RoundControllerScript.PHASE_DRAFT)

	print("Round lifecycle smoke test passed: start, reward, end, and draft transition.")
	get_tree().quit(0)
