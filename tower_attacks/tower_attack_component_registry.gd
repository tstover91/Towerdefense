class_name TowerAttackComponentRegistry
extends RefCounted

const GameStats = preload("res://stat_database.gd")

const SPAWNER_ATTACK_COMPONENT = preload(
	"res://tower_attacks/spawner_attack_component.gd"
)

const COMPONENT_SCRIPTS: Dictionary = {
	&"fisherman": preload("res://tower_attacks/fisherman_attack_component.gd"),
	&"energycore": preload("res://tower_attacks/energy_core_attack_component.gd"),
	&"reaver": preload("res://tower_attacks/reaver_attack_component.gd"),
	&"brainiac": preload("res://tower_attacks/brainiac_attack_component.gd"),
	&"voidcaller": preload("res://tower_attacks/void_caller_attack_component.gd"),
	&"longshot": preload("res://tower_attacks/longshot_attack_component.gd"),
	&"gauss_repeater": preload(
		"res://tower_attacks/gauss_repeater_attack_component.gd"
	),
	&"beholder": preload("res://tower_attacks/beholder_attack_component.gd"),
	&"orbitalcannon": preload(
		"res://tower_attacks/orbital_cannon_attack_component.gd"
	),
	&"saucer": preload("res://tower_attacks/saucer_attack_component.gd"),
	&"slinger": preload("res://tower_attacks/slinger_attack_component.gd"),
	&"irradiator": preload("res://tower_attacks/irradiator_attack_component.gd"),
}

const EVOLUTION_COMPONENT_SCRIPTS: Dictionary = {
	&"invader": {
		&"railgunner": preload(
			"res://tower_attacks/invader_laser_attack_component.gd"
		),
		&"gauss_gunner": preload(
			"res://tower_attacks/gauss_repeater_attack_component.gd"
		),
	},
}


static func create_component(
	tower_id: StringName,
	tower_data: Dictionary,
	spawner_tag: StringName,
	evolution_id: StringName = &""
) -> TowerAttackComponent:
	var combat_tower_id: StringName = GameStats.get_tower_combat_source_id(tower_id)
	var evolution_scripts: Dictionary = EVOLUTION_COMPONENT_SCRIPTS.get(
		combat_tower_id, {}
	)
	if tower_id == &"laser_cannon":
		return EVOLUTION_COMPONENT_SCRIPTS[&"invader"][&"railgunner"].new() as TowerAttackComponent
	var evolution_script: Script = evolution_scripts.get(evolution_id)
	if evolution_script != null:
		return evolution_script.new() as TowerAttackComponent
	var component_script: Script = COMPONENT_SCRIPTS.get(combat_tower_id)
	if component_script != null:
		return component_script.new() as TowerAttackComponent
	if tower_data.get("bonus_tags", []).has(spawner_tag):
		return SPAWNER_ATTACK_COMPONENT.new() as TowerAttackComponent
	return null
