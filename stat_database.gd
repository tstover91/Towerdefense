class_name StatDatabase
extends RefCounted

## Central gameplay reference. IDs are lowercase strings so scenes and save data
## can refer to entries without depending on node names.

const DEFAULT_ENEMY_ID := "normal"
const DEFAULT_TOWER_ID := "scout"

const ENEMIES := {
	"normal": {
		"display_name": "Normal",
		"health": 4,
		"move_speed": 100.0,
		"cash_reward": 5,
		"base_damage_from_remaining_health": true,
		"hidden": false,
		"defense": 0.0,
	},
}

const TOWERS := {
	"scout": {
		"display_name": "Scout",
		"placement_cost": 125,
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 1,
				"damage_type": &"physical",
				"firerate": 1.0,
				"range": 12.0,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 50,
				"damage": 1,
				"damage_type": &"physical",
				"firerate": 0.75,
				"range": 12.0,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 375,
				"damage": 3,
				"damage_type": &"physical",
				"firerate": 0.75,
				"range": 14.0,
				"hidden_detection": true,
			},
			{
				"upgrade_cost": 1350,
				"damage": 8,
				"damage_type": &"physical",
				"firerate": 0.65,
				"range": 16.0,
				"hidden_detection": true,
			},
			{
				"upgrade_cost": 2200,
				"damage": 8,
				"damage_type": &"physical",
				"firerate": 0.325,
				"range": 16.0,
				"hidden_detection": true,
			},
		],
	},
}

const MODES := {
	"easy": {
		"display_name": "Easy",
		"starting_cash": 500,
		"starting_lives": 100,
		"max_rounds": 20,
		"wave_bonus_base": 180,
		"wave_bonus_growth": 144,
		"clear_bonus_multiplier": 0.35,
		"waves": {
			1: [
				{"enemy_id": "normal", "amount": 4, "spawn_delay": 3.0},
			],
		},
	},
}


static func get_enemy(enemy_id: StringName) -> Dictionary:
	assert(ENEMIES.has(enemy_id), "Unknown enemy ID: %s" % enemy_id)
	return ENEMIES[enemy_id].duplicate(true)


static func get_tower(tower_id: StringName) -> Dictionary:
	assert(TOWERS.has(tower_id), "Unknown tower ID: %s" % tower_id)
	return TOWERS[tower_id].duplicate(true)


static func get_tower_level(tower_id: StringName, level: int) -> Dictionary:
	var tower := get_tower(tower_id)
	var levels: Array = tower["levels"]
	assert(level >= 0 and level < levels.size(), "Invalid level %d for %s" % [level, tower_id])
	return levels[level].duplicate(true)


static func get_mode(mode_id: StringName) -> Dictionary:
	assert(MODES.has(mode_id), "Unknown mode ID: %s" % mode_id)
	return MODES[mode_id].duplicate(true)


static func get_wave(mode_id: StringName, wave_number: int) -> Array:
	var mode := get_mode(mode_id)
	var waves: Dictionary = mode["waves"]
	assert(waves.has(wave_number), "Missing wave %d for mode %s" % [wave_number, mode_id])
	return waves[wave_number].duplicate(true)
