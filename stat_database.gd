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
		"health_per_wave": 0.25,
		"move_speed": 100.0,
		"cash_reward": 5,
		"base_damage": 4,
		"defense": 0.0,
		"first_wave": 1,
		"threat_cost": 1,
		"spawn_weight": 100,
		"spawn_style": &"steady",
		"color": Color(1.0, 1.0, 1.0),
		"visual_scale": 1.0,
	},
	"runner": {
		"display_name": "Runner",
		"health": 3,
		"health_per_wave": 0.75,
		"move_speed": 160.0,
		"cash_reward": 10,
		"base_damage": 3,
		"defense": 0.0,
		"first_wave": 2,
		"threat_cost": 2,
		"spawn_weight": 65,
		"spawn_style": &"burst",
		"color": Color(1.0, 0.85, 0.2),
		"visual_scale": 0.85,
	},
	"swarmling": {
		"display_name": "Swarmling",
		"health": 1,
		"health_per_wave": 0.25,
		"move_speed": 115.0,
		"cash_reward": 5,
		"base_damage": 1,
		"defense": 0.0,
		"first_wave": 3,
		"threat_cost": 1,
		"spawn_weight": 55,
		"spawn_style": &"stream",
		"color": Color(0.55, 1.0, 0.55),
		"visual_scale": 0.65,
	},
	"bruiser": {
		"display_name": "Bruiser",
		"health": 18,
		"health_per_wave": 2.0,
		"move_speed": 70.0,
		"cash_reward": 30,
		"base_damage": 10,
		"defense": 0.0,
		"first_wave": 4,
		"threat_cost": 6,
		"spawn_weight": 45,
		"spawn_style": &"spaced",
		"color": Color(0.75, 0.45, 0.25),
		"visual_scale": 1.25,
	},
	"splitter": {
		"display_name": "Splitter",
		"health": 14,
		"health_per_wave": 1.5,
		"move_speed": 95.0,
		"cash_reward": 25,
		"base_damage": 8,
		"defense": 0.0,
		"first_wave": 7,
		"threat_cost": 7,
		"spawn_weight": 35,
		"spawn_style": &"steady",
		"split_enemy_id": &"swarmling",
		"split_count": 2,
		"color": Color(0.65, 0.25, 0.9),
		"visual_scale": 1.1,
	},
	"armored": {
		"display_name": "Armored",
		"health": 30,
		"health_per_wave": 3.0,
		"move_speed": 75.0,
		"cash_reward": 50,
		"base_damage": 12,
		"defense": 0.25,
		"first_wave": 9,
		"threat_cost": 10,
		"spawn_weight": 30,
		"spawn_style": &"spaced",
		"color": Color(0.55, 0.62, 0.7),
		"visual_scale": 1.2,
	},
	"buffer": {
		"display_name": "Buffer",
		"health": 15,
		"health_per_wave": 2.0,
		"move_speed": 85.0,
		"cash_reward": 40,
		"base_damage": 7,
		"defense": 0.0,
		"first_wave": 11,
		"threat_cost": 8,
		"spawn_weight": 24,
		"spawn_style": &"steady",
		"speed_aura_radius": 100.0,
		"speed_aura_multiplier": 1.2,
		"color": Color(0.2, 0.9, 1.0),
		"visual_scale": 1.0,
	},
	"regenerator": {
		"display_name": "Regenerator",
		"health": 35,
		"health_per_wave": 3.0,
		"move_speed": 80.0,
		"cash_reward": 60,
		"base_damage": 15,
		"defense": 0.0,
		"first_wave": 13,
		"threat_cost": 12,
		"spawn_weight": 20,
		"spawn_style": &"spaced",
		"regeneration_per_second": 2,
		"color": Color(0.25, 1.0, 0.35),
		"visual_scale": 1.15,
	},
	"rusher": {
		"display_name": "Rusher",
		"health": 20,
		"health_per_wave": 2.5,
		"move_speed": 90.0,
		"cash_reward": 50,
		"base_damage": 15,
		"defense": 0.0,
		"first_wave": 15,
		"threat_cost": 10,
		"spawn_weight": 22,
		"spawn_style": &"burst",
		"rush_start_ratio": 0.7,
		"rush_speed_multiplier": 2.0,
		"color": Color(1.0, 0.25, 0.2),
		"visual_scale": 1.0,
	},
	"summoner": {
		"display_name": "Summoner",
		"health": 50,
		"health_per_wave": 4.0,
		"move_speed": 60.0,
		"cash_reward": 75,
		"base_damage": 20,
		"defense": 0.0,
		"first_wave": 17,
		"threat_cost": 18,
		"spawn_weight": 15,
		"spawn_style": &"spaced",
		"summon_enemy_id": &"swarmling",
		"summon_interval": 4.0,
		"summon_limit": 3,
		"color": Color(0.8, 0.2, 1.0),
		"visual_scale": 1.3,
	},
	"brute": {
		"display_name": "Brute",
		"health": 500,
		"health_per_wave": 20.0,
		"move_speed": 40.0,
		"cash_reward": 500,
		"base_damage": 100,
		"defense": 0.0,
		"first_wave": 20,
		"threat_cost": 0,
		"spawn_weight": 0,
		"spawn_style": &"boss",
		"boss": true,
		"color": Color(0.75, 0.08, 0.08),
		"visual_scale": 1.8,
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
				"projectile_speed": 600.0,
				"firerate": 1.0,
				"range": 12.0,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 50,
				"damage": 1,
				"damage_type": &"physical",
				"projectile_speed": 600.0,
				"firerate": 0.75,
				"range": 12.0,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 375,
				"damage": 3,
				"damage_type": &"physical",
				"projectile_speed": 650.0,
				"firerate": 0.75,
				"range": 14.0,
				"hidden_detection": true,
			},
			{
				"upgrade_cost": 1350,
				"damage": 8,
				"damage_type": &"physical",
				"projectile_speed": 700.0,
				"firerate": 0.65,
				"range": 16.0,
				"hidden_detection": true,
			},
			{
				"upgrade_cost": 2200,
				"damage": 8,
				"damage_type": &"physical",
				"projectile_speed": 750.0,
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
		"wave_bonus_growth": 100,
		"clear_bonus_multiplier": 0.35,
		"threat_budget_base": 6,
		"threat_budget_growth": 2,
		"threat_budget_curve": 0.15,
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
