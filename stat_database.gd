class_name StatDatabase
extends RefCounted

## Central gameplay reference. IDs are lowercase strings so scenes and save data
## can refer to entries without depending on node names.

const DEFAULT_ENEMY_ID := "normal"
const DEFAULT_TOWER_ID := "invader"
const BUILD_CELL_SIZE := 32.0
const ELECTRIC_HITS_TO_PROC := 5
const ELECTRIC_PROC_DAMAGE_CONTRIBUTION := 0.30
const STATIC_DISCHARGE_DAMAGE_RATIO := 0.35
const STATIC_DISCHARGE_PRIMARY_DAMAGE_RATIO := 0.50
const STATIC_DISCHARGE_RADIUS := BUILD_CELL_SIZE * 1.25
const OVERCHARGED_CAPACITOR_HIT_MULTIPLIER := 1.50
const OVERCHARGED_CAPACITOR_DAMAGE_MULTIPLIER := 3.0

# Shared Normal-mode progression data. General-family enemies keep fixed beats;
# three other families and two upgrades are selected separately for each run.
const FIXED_ENEMY_DEBUT_ROUNDS := {
	&"normal": 1,
	&"striker": 17,
	&"heavy_enforcer": 17,
	&"bulwark": 22,
	&"brute": 24,
}
const ENEMY_DEBUT_GROUPS := [
	{"family_tier": 1, "count": 3, "rounds": [4, 6, 10]},
	{"family_tier": 2, "count": 2, "rounds": [14, 18]},
]

# Set pieces are eligible only when their required roster is already revealed.
# Their lower weights keep them memorable without making every group scripted.
const WAVE_STYLE_RULES := {
	&"standard": {"minimum_round": 1, "weight": 1.5},
	&"burst": {"minimum_round": 2, "required_roles": [&"pressure"], "weight": 1.0},
	&"stream": {"minimum_round": 2, "required_roles": [&"fodder"], "weight": 1.0},
	&"pulses": {"minimum_round": 3, "weight": 1.0},
	&"spaced": {"minimum_round": 5, "required_roles": [&"tank"], "weight": 1.0},
	&"swarm_batch": {"minimum_round": 4, "required_roles": [&"fodder"], "weight": 0.9},
	&"convoy": {"minimum_round": 5, "required_roles": [&"tank"], "weight": 0.9},
	&"elite_escort": {"minimum_round": 5, "required_roles": [&"tank"], "weight": 0.45},
	&"hidden_probe": {"minimum_round": 11, "required_all": [&"hidden"], "weight": 0.75},
	&"splitter_pack": {"minimum_round": 8, "required_all": [&"splitter"], "weight": 0.75},
	&"support_column": {"minimum_round": 8, "required_roles": [&"support"], "weight": 0.75},
	&"escalation": {"minimum_round": 9, "weight": 0.85},
	&"second_wind": {"minimum_round": 14, "weight": 0.7},
	&"rush_screen": {"minimum_round": 14, "required_all": [&"rusher"], "weight": 0.75},
	&"summoner_escort": {"minimum_round": 14, "required_all": [&"summoner"], "weight": 0.65},
	&"mixed_roster": {"minimum_round": 12, "maximum_round": 13, "weight": 0.0},
	&"layered_assault": {"minimum_round": 14, "minimum_distinct_roles": 2, "weight": 0.9},
	&"boss_rehearsal": {"minimum_round": 22, "maximum_round": 23, "required_any": [&"regenerator", &"summoner"], "weight": 0.8},
}
const WAVE_ROLE_WEIGHTS := [
	{
		"maximum_wave": 3,
		"weights": {
			&"fodder": 80.0, &"pressure": 20.0,
			&"tank": 0.0, &"support": 0.0,
		},
	},
	{
		"maximum_wave": 8,
		"weights": {
			&"fodder": 50.0, &"pressure": 25.0,
			&"tank": 15.0, &"support": 10.0,
		},
	},
	{
		"maximum_wave": 13,
		"weights": {
			&"fodder": 45.0, &"pressure": 25.0,
			&"tank": 20.0, &"support": 10.0,
		},
	},
	{
		"maximum_wave": 17,
		"weights": {
			&"fodder": 35.0, &"pressure": 25.0,
			&"tank": 30.0, &"support": 10.0,
		},
	},
	{
		"maximum_wave": 21,
		"weights": {
			&"fodder": 25.0, &"pressure": 25.0,
			&"tank": 40.0, &"support": 10.0,
		},
	},
	{
		"maximum_wave": 999,
		"weights": {
			&"fodder": 15.0, &"pressure": 20.0,
			&"tank": 50.0, &"support": 15.0,
		},
	},
]
const FORMATION_ROLE_WEIGHTS := {
	&"steady": {&"fodder": 60.0, &"pressure": 20.0, &"tank": 15.0, &"support": 5.0},
	&"stream": {&"fodder": 75.0, &"pressure": 20.0, &"tank": 0.0, &"support": 5.0},
	&"burst": {&"fodder": 40.0, &"pressure": 50.0, &"tank": 10.0, &"support": 0.0},
	&"spaced": {&"fodder": 25.0, &"pressure": 20.0, &"tank": 45.0, &"support": 10.0},
	&"pulses": {&"fodder": 65.0, &"pressure": 25.0, &"tank": 10.0, &"support": 0.0},
	&"swarm_batch": {&"fodder": 70.0, &"pressure": 20.0, &"tank": 10.0, &"support": 0.0},
	&"convoy": {&"fodder": 50.0, &"pressure": 30.0, &"tank": 15.0, &"support": 5.0},
	&"elite_escort": {&"fodder": 45.0, &"pressure": 25.0, &"tank": 25.0, &"support": 5.0},
	&"hidden_probe": {&"fodder": 45.0, &"pressure": 45.0, &"tank": 10.0, &"support": 0.0},
	&"splitter_pack": {&"fodder": 55.0, &"pressure": 35.0, &"tank": 10.0, &"support": 0.0},
	&"support_column": {&"fodder": 35.0, &"pressure": 20.0, &"tank": 25.0, &"support": 20.0},
	&"escalation": {&"fodder": 45.0, &"pressure": 25.0, &"tank": 20.0, &"support": 10.0},
	&"second_wind": {&"fodder": 30.0, &"pressure": 30.0, &"tank": 30.0, &"support": 10.0},
	&"rush_screen": {&"fodder": 25.0, &"pressure": 55.0, &"tank": 20.0, &"support": 0.0},
	&"summoner_escort": {&"fodder": 35.0, &"pressure": 15.0, &"tank": 25.0, &"support": 25.0},
	&"mixed_roster": {&"fodder": 35.0, &"pressure": 25.0, &"tank": 25.0, &"support": 15.0},
	&"layered_assault": {&"fodder": 35.0, &"pressure": 30.0, &"tank": 25.0, &"support": 10.0},
	&"boss_rehearsal": {&"fodder": 20.0, &"pressure": 25.0, &"tank": 30.0, &"support": 25.0},
}

const DELIVERY_PROJECTILE: StringName = &"projectile"
const DELIVERY_HITSCAN: StringName = &"hitscan"
const IMPACT_PRIMARY: StringName = &"primary"
const IMPACT_FIRST_CONTACT: StringName = &"first_contact"
const IMPACT_DESTINATION: StringName = &"destination"
const DEFAULT_CRITICAL_CHANCE := 0.10
const DEFAULT_CRITICAL_MULTIPLIER := 2.0
const SLOW_SPEED_MULTIPLIER := 0.65
const PIERCE_DAMAGE_LOSS_PER_ENEMY := 0.30
const PIERCE_MINIMUM_DAMAGE_MULTIPLIER := 0.40
const EXPLOSION_INNER_RADIUS_RATIO := 0.50
const EXPLOSION_OUTER_DAMAGE_MULTIPLIER := 0.50
const EXPLOSIVE_ARMOR_MULTIPLIER := 1.25
const ARMOR_RATING_CONSTANT := 50.0
const MAXIMUM_ARMOR_DAMAGE_REDUCTION := 0.60

# Enemy bounties remain composition-dependent. This value compensates for the
# denser director budgets so added enemies do not also inflate the economy.
const KILL_REWARD_MULTIPLIER := 0.104

const ROUND_CASH_REWARDS := {
	1: 200,
	2: 225,
	3: 275,
	4: 325,
	5: 400,
	6: 450,
	7: 525,
	8: 575,
	9: 675,
	10: 750,
	11: 975,
	12: 1200,
	13: 1425,
	14: 1750,
	15: 2150,
	16: 2400,
	17: 5000,
	18: 2500,
	19: 2800,
	20: 3100,
	21: 3400,
	22: 3800,
	23: 4300,
	24: 0,
}

# Explicit round scaling profiles. Standard health follows a deliberately flat
# curve so late enemy identity comes primarily from base stats and composition.
#
# threat_budget is the nominal amount generated during timed spawning and is
# used to derive the director's per-second rate. Chunk timing can leave a small
# reserve unspent. The mode's starting_spawn_threat is a separate reserve.
const ROUND_PROFILES := {
	1: {"duration": 20.0, "threat_budget": 18, "standard_health_multiplier": 1.50, "boss_health_multiplier": 1.2650},
	2: {"duration": 25.0, "threat_budget": 29, "standard_health_multiplier": 2.00, "boss_health_multiplier": 1.2925},
	3: {"duration": 30.0, "threat_budget": 43, "standard_health_multiplier": 2.50, "boss_health_multiplier": 1.3200},
	4: {"duration": 35.0, "threat_budget": 56, "standard_health_multiplier": 3.00, "boss_health_multiplier": 1.3475},
	5: {"duration": 40.0, "threat_budget": 75.0, "standard_health_multiplier": 3.50, "boss_health_multiplier": 1.3750},
	6: {"duration": 45.0, "threat_budget": 90.0, "standard_health_multiplier": 4.00, "boss_health_multiplier": 1.4025},
	7: {"duration": 50.0, "threat_budget": 120.0, "standard_health_multiplier": 4.50, "boss_health_multiplier": 1.4300},
	8: {"duration": 55.0, "threat_budget": 160.0, "standard_health_multiplier": 5.00, "boss_health_multiplier": 1.4575},
	9: {"duration": 60.0, "threat_budget": 210.0, "standard_health_multiplier": 5.50, "boss_health_multiplier": 1.4850},
	10: {"duration": 60.0, "threat_budget": 260.4000, "standard_health_multiplier": 6.00, "boss_health_multiplier": 1.5125},
	11: {"duration": 60.0, "threat_budget": 286.3560, "standard_health_multiplier": 6.50, "boss_health_multiplier": 1.5400},
	12: {"duration": 60.0, "threat_budget": 313.8240, "standard_health_multiplier": 7.00, "boss_health_multiplier": 1.5675},
	13: {"duration": 60.0, "threat_budget": 342.8040, "standard_health_multiplier": 7.40, "boss_health_multiplier": 1.5950},
	14: {"duration": 60.0, "threat_budget": 373.2960, "standard_health_multiplier": 7.70, "boss_health_multiplier": 1.6225},
	15: {"duration": 60.0, "threat_budget": 405.3000, "standard_health_multiplier": 8.00, "boss_health_multiplier": 1.6500},
	16: {"duration": 60.0, "threat_budget": 438.8160, "standard_health_multiplier": 8.30, "boss_health_multiplier": 1.6775},
	17: {"duration": 60.0, "threat_budget": 473.8440, "standard_health_multiplier": 8.60, "boss_health_multiplier": 1.7050},
	18: {"duration": 60.0, "threat_budget": 510.3840, "standard_health_multiplier": 9.00, "boss_health_multiplier": 1.7325},
	19: {"duration": 60.0, "threat_budget": 548.4360, "standard_health_multiplier": 9.40, "boss_health_multiplier": 1.7600},
	20: {"duration": 60.0, "threat_budget": 600, "standard_health_multiplier": 9.80, "boss_health_multiplier": 1.7875},
	21: {"duration": 60.0, "threat_budget": 650, "standard_health_multiplier": 10.20, "boss_health_multiplier": 1.8150},
	22: {"duration": 60.0, "threat_budget": 705, "standard_health_multiplier": 10.60, "boss_health_multiplier": 1.8425},
	23: {"duration": 60.0, "threat_budget": 765, "standard_health_multiplier": 11.00, "boss_health_multiplier": 1.8700},
	24: {"duration": 90.0, "threat_budget": 1150, "standard_health_multiplier": 11.00, "boss_health_multiplier": 1.8975},
	
}

const ENEMY_LATE_HEALTH_FACTORS := {
	&"normal": 0.65,
	&"runner": 0.75,
	&"swarmling": 0.45,
	&"bruiser": 1.20,
	&"splitter": 0.90,
	&"hidden": 0.80,
	&"armored": 1.10,
	&"buffer": 1.00,
	&"regenerator": 1.15,
	&"rusher": 0.85,
	&"summoner": 1.00,
	&"swat_enforcer": 1.20,
	&"heavy_enforcer": 1.15,
	&"shielded": 1.00,
	&"shield_projector": 1.00,
	&"juggernaut": 1.10,
	&"bulwark": 1.05,
	&"brute": 1.00,
}

# Variants remain independent layers because they define special-round enemy
# behavior rather than ordinary round progression.
const STANDARD_ENEMY_SPEED_MULTIPLIER := 0.53
const HORDE_ENEMY_HEALTH_MULTIPLIER := 0.55
const ELITE_ENEMY_HEALTH_MULTIPLIER := 2.25
const ELITE_ENEMY_SPEED_MULTIPLIER := 1.30
const EARLY_ELITE_ENEMY_HEALTH_MULTIPLIER := 1.75
const EARLY_ELITE_ENEMY_SPEED_MULTIPLIER := 1.15
const PAYDAY_ENEMY_HEALTH_MULTIPLIER := 0.50

# Provisional relic balance values. These are centralized so later tuning does
# not require changing combat code.
const DIVIDENDS_INTEREST_RATE := 0.05
const DIVIDENDS_INTEREST_CAP := 500

const FOCUSED_LENS_DAMAGE_PER_STACK := 0.30
const FOCUSED_LENS_RANGE_MULTIPLIER := 0.90
const WIDE_LENS_RANGE_PER_STACK := 0.30
const WIDE_LENS_DAMAGE_MULTIPLIER := 0.90
const DEATH_RAY_TURN_SPEED_DEGREES := 90.0

const HEAVY_ROUNDS_DAMAGE_MULTIPLIER := 1.35
const HEAVY_ROUNDS_INTERVAL_MULTIPLIER := 1.15
const LIGHTWEIGHT_AMMO_DAMAGE_MULTIPLIER := 0.90
const LIGHTWEIGHT_AMMO_INTERVAL_MULTIPLIER := 0.75
const SUPPRESSIVE_FIRE_DURATION := 1.00

const HIGH_YIELD_RADIUS_MULTIPLIER := 1.35
const HIGH_YIELD_DAMAGE_MULTIPLIER := 0.90
const CONCENTRATED_CHARGE_RADIUS_MULTIPLIER := 0.80
const CONCENTRATED_CHARGE_DAMAGE_MULTIPLIER := 1.40

const MAXIMUM_PAYLOAD_RADIUS_MULTIPLIER := 1.50
const MAXIMUM_PAYLOAD_DAMAGE_MULTIPLIER := 1.50
const MAXIMUM_PAYLOAD_INTERVAL_MULTIPLIER := 1.75

const LUCKY_SHOT_CHANCE_PER_STACK := 0.20
const GLASS_CANNON_CRITICAL_MULTIPLIER_BONUS := 2.0
const GLASS_CANNON_NONCRITICAL_MULTIPLIER := 0.70
const DEADEYE_CRITICAL_MULTIPLIER_BONUS := 2.0
const DEADEYE_MISS_CHANCE := 0.20
const EXPERIMENTAL_MUNITIONS_CRITICAL_MULTIPLIER := 1.50

const BOSS_STUN_DURATION_MULTIPLIER := 0.50

const PREDATORY_INSTINCT_HEALTH_THRESHOLD := 0.25
const PREDATORY_INSTINCT_DAMAGE_PER_STACK := 0.50
const PACK_HUNTER_DAMAGE_PER_STACK := 0.25

const INTERFERENCE_BEAM_DAMAGE_MULTIPLIER := 1.60

const HOLLOW_POINT_DAMAGE_PER_STACK := 0.25
const LONG_BARREL_MAX_DAMAGE_PER_STACK := 0.40
const POINT_BLANK_MAX_DAMAGE_PER_STACK := 0.40

const GIANT_KILLER_SPECIAL_DAMAGE_MULTIPLIER := 1.75
const GIANT_KILLER_NORMAL_DAMAGE_MULTIPLIER := 0.75

const THERMITE_BOMBS_PROTECTION_REMOVAL := 5
const CONDUCTIVE_UNARMORED_DAMAGE_MULTIPLIER := 0.85

const BIG_GAME_CONTROL_ELITE_DURATION_PER_STACK := 1.40
const BIG_GAME_CONTROL_NORMAL_DURATION_PER_STACK := 0.80
const EMERGENCY_BRAKE_DURATION_PER_STACK := 1.50

const NETWORK_UPGRADE_SPEED_PER_NEIGHBOR_PER_STACK := 0.12

const FRENZY_SPEED_PER_ENEMY_PER_STACK := 0.06
const FRENZY_MAXIMUM_ENEMY_COUNT := 10

const DUELIST_ONE_ENEMY_DAMAGE_PER_STACK := 0.45
const DUELIST_TWO_ENEMY_DAMAGE_PER_STACK := 0.25

const STRENGTH_IN_NUMBERS_DAMAGE_PER_NEIGHBOR := 0.20
const STRENGTH_IN_NUMBERS_MAXIMUM_NEIGHBORS := 4

const LONE_WOLF_DAMAGE_MULTIPLIER := 1.50
const LONE_WOLF_ATTACK_SPEED_MULTIPLIER := 1.35
const LONE_WOLF_RANGE_MULTIPLIER := 1.25

const CROWD_PLEASER_DAMAGE_PER_ENEMY := 0.12
const CROWD_PLEASER_MAXIMUM_DAMAGE_BONUS := 1.50

const LINGERING_THOUGHTS_DURATION_MULTIPLIER := 1.35
const QUICK_THINKING_DURATION_MULTIPLIER := 0.70
const QUICK_THINKING_COOLDOWN_MULTIPLIER := 0.70

const RELENTLESS_SPEED_PER_STACK := 0.15
const RELENTLESS_MAXIMUM_STACKS := 5

const MICROWAVE_MAX_HEALTH_DAMAGE_RATIO := 0.30
const MICROWAVE_BEAM_DAMAGE_CAP_MULTIPLIER := 5.0
const MICROWAVE_EXPLOSION_RADIUS := BUILD_CELL_SIZE * 1.5
const MICROWAVE_ATTACK_COOLDOWN := 1.0


const MOVEMENT_STATIONARY: StringName = &"stationary"
const MOVEMENT_DRONE: StringName = &"drone"
const MOVEMENT_PATH_ASSAULT: StringName = &"path_assault"
const MOVEMENT_GUARD: StringName = &"guard"

const SPAWNED_UNITS := {
	"spore_turret": {
		"display_name": "Spore Turret",
		"type_tags": [&"biological"],
		"damage_tags": [&"ballistic"],
		"bonus_tags": [&"pierce"],
		"pierce_count": 1,
		"movement_type": MOVEMENT_STATIONARY,
		"delivery_type": DELIVERY_PROJECTILE,
		"impact_mode": IMPACT_FIRST_CONTACT,
	},
	"drone": {
		"display_name": "Drone",
		"type_tags": [&"technology"],
		"damage_tags": [&"ballistic"],
		"bonus_tags": [],
		"pierce_count": 0,
		"movement_type": MOVEMENT_DRONE,
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_PRIMARY,
	},
	"mech": {
		"display_name": "Mech",
		"type_tags": [&"technology"],
		"damage_tags": [&"melee"],
		"bonus_tags": [],
		"pierce_count": 0,
		"movement_type": MOVEMENT_PATH_ASSAULT,
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_PRIMARY,
	},
	"abducted_monster": {
		"display_name": "Abducted Monster",
		"type_tags": [&"biological"],
		"damage_tags": [&"melee"],
		"bonus_tags": [],
		"pierce_count": 0,
		"movement_type": MOVEMENT_GUARD,
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_PRIMARY,
	},
	"reinforcement_alien": {
		"display_name": "Reinforcement Grunt",
		"type_tags": [&"biological"],
		"damage_tags": [&"melee"],
		"bonus_tags": [&"slow"],
		"pierce_count": 0,
		"movement_type": MOVEMENT_GUARD,
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_PRIMARY,
	},
}

const REINFORCEMENT_OPTIONS := {
	"grunt_squad": {
		"display_name": "Grunt Squad",
		"description": "Deploys three alien grunts that pursue and slow nearby enemies.",
		"cooldown": 25.0,
		"unit_id": &"reinforcement_alien",
		"unit_count": 3,
		"deployment_spread": 18.0,
		"command_radius": 7.5,
		"unit_stats": {
			"damage": 5,
			"damage_per_round": 1.0,
			"attack_interval": 0.9,
			"aim_radius": 1.25,
			"acquisition_radius": 7.5,
			"leash_radius": 7.5,
			"move_speed": 80.0,
			"slow_duration": 1.1,
			"lifetime": 14.0,
		},
	},
}

const RELICS := {
	"dividends": {"display_name": "Dividends", "description": "Gain 5% interest at the end of each round, up to $500.", "rarity": &"rare", "category": &"global", "stackable": false},
	"holiday_sale": {"display_name": "Holiday Sale", "description": "Each round, one tower's build price is reduced by 35%; all others increase by 15%.", "rarity": &"rare", "category": &"global", "stackable": false},
	"contraband_blueprint": {"display_name": "Contraband Blueprint", "description": "Adds one random tower outside your five-tower roster beneath the normal tower slots. It costs $0 to build and is removed after placement.", "rarity": &"legendary", "category": &"global", "stackable": false},
	"network_upgrade": {"display_name": "Network Upgrade", "description": "Technology towers gain 12% attack speed per stack for each other Technology tower within one tile of their footprint.", "rarity": &"common", "category": &"technology", "stackable": true},
	"singularity_core": {"display_name": "Singularity Core", "description": "Choose one already-built Technology tower. That tower can purchase both final paths.", "rarity": &"legendary", "category": &"technology", "stackable": false},
	"pack_hunter": {"display_name": "Pack Hunter", "description": "Biological attacks deal 25% more damage per stack when another Biological tower is targeting that enemy.", "rarity": &"common", "category": &"biological", "stackable": true},
	"predatory_instinct": {"display_name": "Predatory Instinct", "description": "Biological attacks deal 50% more damage per stack to enemies at or below 25% health.", "rarity": &"common", "category": &"biological", "stackable": true},
	"perfect_mutation": {"display_name": "Perfect Mutation", "description": "Choose one already-built Biological tower. That tower can purchase both final paths.", "rarity": &"legendary", "category": &"biological", "stackable": false},
	"focused_lens": {"display_name": "Focused Lens", "description": "Beam damage increases by 30% per stack, but range is reduced by 10% per stack.", "rarity": &"common", "category": &"beam", "stackable": true},
	"wide_lens": {"display_name": "Wide Lens", "description": "Beam range increases by 30% per stack, but damage is reduced by 10% per stack.", "rarity": &"common", "category": &"beam", "stackable": true},
	"interference_beam": {"display_name": "Interference Beam", "description": "Beams deal 60% more damage to slowed or stunned enemies.", "rarity": &"rare", "category": &"beam", "stackable": false},
	"microwave": {"display_name": "Microwave", "description": "An enemy killed by Beam damage explodes for 30% of its maximum health, capped at five times the killing damage. The source tower pauses briefly after each explosion.", "rarity": &"rare", "category": &"beam", "stackable": false},
	"death_ray": {"display_name": "Death Ray", "description": "Beams gain infinite Pierce, but turn speed is reduced to 90 degrees per second.", "rarity": &"legendary", "category": &"beam", "stackable": false},
	"hollow_point": {"display_name": "Hollow Point", "description": "Ballistic attacks deal 25% more damage per stack to enemies above 75% health.", "rarity": &"common", "category": &"ballistic", "stackable": true},
	"heavy_rounds": {"display_name": "Heavy Rounds", "description": "Ballistic damage increases by 35% per stack, but attacks take 15% longer per stack.", "rarity": &"common", "category": &"ballistic", "stackable": true},
	"lightweight_ammo": {"display_name": "Lightweight Ammo", "description": "Ballistic attacks are 25% faster per stack, but deal 10% less damage per stack.", "rarity": &"common", "category": &"ballistic", "stackable": true},
	"long_barrel": {"display_name": "Long Barrel", "description": "Ballistic damage gains up to 40% per stack based on distance from its source.", "rarity": &"common", "category": &"ballistic", "stackable": true},
	"point_blank": {"display_name": "Point Blank", "description": "Ballistic damage gains up to 40% per stack at close range.", "rarity": &"common", "category": &"ballistic", "stackable": true},
	"armor_piercing": {"display_name": "Armor Piercing", "description": "Ballistic attacks gain Pierce 1.", "rarity": &"rare", "category": &"ballistic", "stackable": false},
	"suppressive_fire": {"display_name": "Suppressive Fire", "description": "Ballistic attacks slow enemies for at least 1 second.", "rarity": &"rare", "category": &"ballistic", "stackable": false},
	"rubber_bullets": {"display_name": "Rubber Bullets", "description": "Ballistic attacks bounce once to another enemy within 3 tiles.", "rarity": &"legendary", "category": &"ballistic", "stackable": false},
	"experimental_munitions": {"display_name": "Experimental Munitions", "description": "All Ballistic weapons can critically hit, but their base critical multiplier is 1.5x before other relic modifiers.", "rarity": &"rare", "category": &"ballistic", "stackable": false, "latest_draft_round": 11},
	"frenzy": {"display_name": "Frenzy", "description": "Melee attacks become 6% faster per enemy in range per stack, counting up to 10 enemies.", "rarity": &"common", "category": &"melee", "stackable": true},
	"duelist": {"display_name": "Duelist", "description": "Melee damage gains 45% per stack with one enemy in range or 25% per stack with two.", "rarity": &"common", "category": &"melee", "stackable": true},
	"relentless": {"display_name": "Relentless", "description": "Gain 15% Melee attack speed after each attack against the same primary target, up to five stacks. Changing targets resets it.", "rarity": &"rare", "category": &"melee", "stackable": false},
	"giant_killer": {"display_name": "Giant Killer", "description": "Melee attacks deal 75% more damage to elites and bosses, but 25% less to normal enemies.", "rarity": &"rare", "category": &"melee", "stackable": false},
	"strength_in_numbers": {"display_name": "Strength in Numbers", "description": "Gain 20% Melee damage per nearby Melee tower, counting up to four.", "rarity": &"rare", "category": &"melee", "stackable": false},
	"lone_wolf": {"display_name": "Lone Wolf", "description": "A Melee tower gains 50% damage, 35% attack speed, and 25% range while it is the only copy of that specific tower built. Mech Bay counts per bay, not per active mech.", "rarity": &"legendary", "category": &"melee", "stackable": false},
	"high_yield": {"display_name": "High Yield", "description": "Explosion radius increases by 35% per stack, but damage is reduced by 10% per stack.", "rarity": &"common", "category": &"explosive", "stackable": true},
	"concentrated_charge": {"display_name": "Concentrated Charge", "description": "Explosion radius is reduced by 20% per stack, but damage increases by 40% per stack.", "rarity": &"common", "category": &"explosive", "stackable": true},
	"crowd_pleaser": {"display_name": "Crowd Pleaser", "description": "Explosions gain 12% damage per enemy caught, up to 150% bonus damage.", "rarity": &"rare", "category": &"explosive", "stackable": false},
	"direct_hit": {"display_name": "Direct Hit", "description": "Explosions gain 60% damage against one target, 30% against two, or 15% against three.", "rarity": &"rare", "category": &"explosive", "stackable": false},
	"thermite_bombs": {"display_name": "Thermite Bombs", "description": "Explosive hits deal no health damage to armored or shielded enemies, but remove 5 Armor or Shield instead.", "rarity": &"rare", "category": &"explosive", "stackable": false},
	"maximum_payload": {"display_name": "Maximum Payload", "description": "Explosion damage and radius increase by 50%, but explosive cooldowns take 75% longer.", "rarity": &"rare", "category": &"explosive", "stackable": false, "enabled": false},
	"charred_clothes": {"display_name": "Charred Clothes", "description": "Explosions permanently remove Hidden from enemies they hit.", "rarity": &"rare", "category": &"explosive", "stackable": false},
	"conductive": {"display_name": "Conductive", "description": "Armor increases Electric damage instead of reducing it, but Electric damage is reduced by 15% against unarmored enemies.", "rarity": &"common", "category": &"electric", "stackable": false},
	"overcharged_capacitor": {"display_name": "Overcharged Capacitor", "description": "Lightning procs take 1.5x as many hits to activate per stack, but deal 3x damage per stack.", "rarity": &"common", "category": &"electric", "stackable": true},
	"static_discharge": {"display_name": "Static Discharge", "description": "Lightning procs deal only 50% damage to the primary target, but deal 35% of the full strike to enemies in a small radius.", "rarity": &"rare", "category": &"electric", "stackable": false},
	"chain_lightning": {"display_name": "Chain Lightning", "description": "Lightning procs jump to the closest other enemy for full damage.", "rarity": &"rare", "category": &"electric", "stackable": false},
	"lucky_shot": {"display_name": "Lucky Shot", "description": "Critical-hit chance increases by 20 percentage points per stack.", "rarity": &"common", "category": &"critical", "stackable": true},
	"glass_cannon": {"display_name": "Glass Cannon", "description": "Adds +2x critical damage, but non-critical attacks deal 30% less damage.", "rarity": &"rare", "category": &"critical", "stackable": false},
	"pressure_point": {"display_name": "Pressure Point", "description": "Critical hits ignore armor.", "rarity": &"rare", "category": &"critical", "stackable": false, "enabled": false},
	"deadeye": {"display_name": "Deadeye", "description": "Adds +2x to the critical-hit multiplier, but every attack has a 20% chance to miss.", "rarity": &"rare", "category": &"critical", "stackable": false},
	"lingering_thoughts": {"display_name": "Lingering Thoughts", "description": "Psionic abilities last 35% longer per stack.", "rarity": &"common", "category": &"psionic", "stackable": true},
	"quick_thinking": {"display_name": "Quick Thinking", "description": "Psionic duration and cooldown are both reduced by 30% per stack.", "rarity": &"common", "category": &"psionic", "stackable": true},
	"spotter": {"display_name": "Spotter", "description": "Hidden enemies inside any Reveal tower's range can be targeted by all towers until they leave every Reveal range.", "rarity": &"common", "category": &"reveal", "stackable": false},
	"perfect_intelligence": {"display_name": "Perfect Intelligence", "description": "A Hidden enemy permanently loses Hidden when it enters any Reveal tower's range.", "rarity": &"rare", "category": &"reveal", "stackable": false},
	"deep_penetration": {"display_name": "Deep Penetration", "description": "Adds +1 Pierce.", "rarity": &"common", "category": &"pierce", "stackable": true},
	"follow_through": {"display_name": "Follow Through", "description": "Piercing attacks lose no power after each hit.", "rarity": &"rare", "category": &"pierce", "stackable": false},
	"big_game_control": {"display_name": "Big Game Control", "description": "Stuns last 40% longer per stack against elites and 20% less per stack against normal enemies.", "rarity": &"common", "category": &"stun", "stackable": true},
	"emergency_brake": {"display_name": "Emergency Brake", "description": "Stuns last 50% longer per stack against enemies with at least 130 movement speed.", "rarity": &"common", "category": &"stun", "stackable": true},
	"youre_not_special": {"display_name": "You're Not Special", "description": "Bosses can be stunned for 50% of the normal duration.", "rarity": &"legendary", "category": &"stun", "stackable": false},
	"trade_agreement": {"display_name": "Trade Agreement", "description": "Hive Mother, Drone Depot, and Mech Bay deploy two units at a time and gain double spawn limits, but their spawned units deal 30% less damage. Saucer is unaffected.", "rarity": &"legendary", "category": &"spawner", "stackable": false},
}

const HOLIDAY_SALE_DISCOUNT_MULTIPLIER := 0.65
const HOLIDAY_SALE_OTHER_COST_MULTIPLIER := 1.15
const RUBBER_BULLETS_BOUNCE_RANGE := 3.0
const TRADE_AGREEMENT_SPAWN_LIMIT_MULTIPLIER := 2
const TRADE_AGREEMENT_SPAWN_BATCH_SIZE := 2
const TRADE_AGREEMENT_UNIT_DAMAGE_MULTIPLIER := 0.70

const TOWER_TEXTURES := {
	&"invader": preload("res://assets/towers/invader.png"),
	&"fisherman": preload("res://assets/towers/fisherman.png"),
	&"gauss_repeater": preload("res://assets/towers/gauss_repeater.png"),
	&"beholder": preload("res://assets/towers/brainiac.png"),
	&"reaver": preload("res://assets/towers/reaver.png"),
	&"brainiac": preload("res://assets/towers/beholder.png"),
	&"longshot": preload("res://assets/towers/longshot.png"),
	&"slinger": preload("res://assets/towers/slinger.png"),
	&"voidcaller": preload("res://assets/towers/voidcaller.png"),
	&"orbitalcannon": preload("res://assets/towers/orbitalcannon.png"),
	&"energycore": preload("res://assets/towers/energycore.png"),
	&"saucer": preload("res://assets/towers/saucer.png"),
	&"hivemother": preload("res://assets/towers/hivemother.png"),
	&"dronedepot": preload("res://assets/towers/dronedepot.png"),
	&"mechbay": preload("res://assets/towers/mechbay.png"),
}

# Fixed upgraded sell values preserve the previous normal-price economy without
# allowing temporary build-price effects to alter refunds. Level 0 is handled
# separately using the price actually paid for that tower instance.
const TOWER_UPGRADED_SELL_VALUES := {
	&"invader": [200, 233, 327, 633],
	&"fisherman": [167, 223, 390, 946],
	&"gauss_repeater": [800, 911, 1444, 2611],
	&"beholder": [2000, 2222, 2888, 3888],
	&"reaver": [175, 216, 450, 933],
	&"brainiac": [400, 475, 650, 1316],
	&"longshot": [1675, 1841, 2450, 3450],
	&"slinger": [225, 325, 515, 965],
	&"voidcaller": [675, 741, 941, 1608],
	&"orbitalcannon": [350, 408, 658, 1408],
	&"energycore": [225, 256, 366, 833],
	&"saucer": [1675, 2033, 2366, 2900],
	&"hivemother": [200, 300, 600, 1466],
	&"dronedepot": [500, 650, 1016, 1849],
	&"mechbay": [900, 1050, 1350, 2400],
}

const TOWER_PATH_SELL_VALUE_ADDITIONS := {
	&"invader": {&"a": 1533, &"b": 1516},
	&"fisherman": {&"a": 1000, &"b": 1167},
	&"gauss_repeater": {&"a": 4222, &"b": 4227,},
	&"beholder": {&"a": 5574, &"b": 5668},
	&"reaver": {&"a": 1599, &"b": 1633},
	&"brainiac": {&"a": 3333, &"b": 3366},
	&"longshot": {&"a": 3600, &"b": 3723},
	&"slinger": {&"a": 2215, &"b": 2215},
	&"voidcaller": {&"a": 3274, &"b": 3108},
	&"orbitalcannon": {&"a": 3074, &"b": 3241},
	&"energycore": {&"a": 1666, &"b": 1833},
	&"saucer": {&"a": 4066, &"b": 3966},
	&"hivemother": {&"a": 2662, &"b": 2662},
	&"dronedepot": {&"a": 2946, &"b": 3009},
	&"mechbay": {&"a": 4480, &"b": 4480},
}

const ENEMIES := {
	"normal": {
		"display_name": "Normal",
		"health": 50,
		"health_per_wave": 0.0,
		"move_speed": 100.0,
		"cash_reward": 4,
		"base_damage": 4,
		"armor": 0,
		"earliest_debut_round": 1,
		"formation_strength": 1,
		"director_cost": 1,
		"spawn_weight": 100,
		"spawn_style": &"steady",
		"role": &"fodder",
		"family": &"general",
		"family_tier": 1,
		"traits": [&"basic"],
		"color": Color(1.0, 1.0, 1.0),
		"visual_scale": 1.0,
	},
	"runner": {
		"display_name": "Runner",
		"health": 35,
		"health_per_wave": 0.0,
		"move_speed": 160.0,
		"cash_reward": 8,
		"base_damage": 3,
		"armor": 0,
		"earliest_debut_round": 2,
		"formation_strength": 2,
		"director_cost": 1,
		"spawn_weight": 65,
		"spawn_style": &"burst",
		"role": &"pressure",
		"family": &"speed",
		"family_tier": 1,
		"traits": [&"fast"],
		"color": Color(1.0, 0.85, 0.2),
		"visual_scale": 0.85,
	},
	"swarmling": {
		"display_name": "Swarmling",
		"health": 18,
		"health_per_wave": 0.0,
		"move_speed": 115.0,
		"cash_reward": 4,
		"base_damage": 1,
		"armor": 0,
		"earliest_debut_round": 2,
		"formation_strength": 1,
		"director_cost": 1,
		"spawn_weight": 55,
		"spawn_style": &"stream",
		"role": &"fodder",
		"family": &"swarms",
		"family_tier": 1,
		"traits": [&"small", &"swarm"],
		"color": Color(0.55, 1.0, 0.55),
		"visual_scale": 0.65,
	},
	"bruiser": {
		"display_name": "Bruiser",
		"health": 220,
		"health_per_wave": 0.0,
		"move_speed": 70.0,
		"cash_reward": 23,
		"base_damage": 10,
		"armor": 0,
		"earliest_debut_round": 5,
		"formation_strength": 6,
		"director_cost": 4,
		"spawn_weight": 45,
		"spawn_style": &"spaced",
		"role": &"tank",
		"family": &"tank",
		"family_tier": 1,
		"traits": [&"slow", &"high_health"],
		"color": Color(0.75, 0.45, 0.25),
		"visual_scale": 1.25,
	},
	"splitter": {
		"display_name": "Splitter",
		"health": 145,
		"health_per_wave": 0.0,
		"move_speed": 95.0,
		"cash_reward": 19,
		"base_damage": 8,
		"armor": 0,
		"earliest_debut_round": 8,
		"formation_strength": 7,
		"director_cost": 4,
		"spawn_weight": 35,
		"spawn_style": &"steady",
		"role": &"pressure",
		"family": &"swarms",
		"family_tier": 2,
		"traits": [&"splits"],
		"split_enemy_id": &"swarmling",
		"split_count": 2,
		"color": Color(0.65, 0.25, 0.9),
		"visual_scale": 1.1,
	},
	"hidden": {
		"display_name": "Hidden",
		"health": 75,
		"health_per_wave": 0.0,
		"move_speed": 95.0,
		"cash_reward": 15,
		"base_damage": 4,
		"armor": 0,
		"earliest_debut_round": 11,
		"formation_strength": 4,
		"director_cost": 4,
		"spawn_weight": 16,
		"spawn_style": &"burst",
		"role": &"pressure",
		"family": &"hidden",
		"family_tier": 1,
		"traits": [&"hidden"],
		"color": Color(0.42, 0.32, 0.62),
		"visual_scale": 0.9,
	},
	"armored": {
		"display_name": "Armored",
		"health": 280,
		"health_per_wave": 0.0,
		"move_speed": 75.0,
		"cash_reward": 38,
		"base_damage": 12,
		"armor": 20,
		"earliest_debut_round": 5,
		"formation_strength": 10,
		"director_cost": 6,
		"spawn_weight": 30,
		"spawn_style": &"spaced",
		"role": &"tank",
		"family": &"armor",
		"family_tier": 1,
		"traits": [&"armored"],
		"color": Color(0.55, 0.62, 0.7),
		"visual_scale": 1.2,
	},
	"buffer": {
		"display_name": "Buffer",
		"health": 190,
		"health_per_wave": 0.0,
		"move_speed": 85.0,
		"cash_reward": 30,
		"base_damage": 7,
		"armor": 0,
		"earliest_debut_round": 8,
		"formation_strength": 8,
		"director_cost": 5,
		"spawn_weight": 24,
		"spawn_style": &"steady",
		"role": &"support",
		"family": &"buffs",
		"family_tier": 1,
		"traits": [&"speed_aura"],
		"speed_aura_radius": 100.0,
		"speed_aura_multiplier": 1.2,
		"color": Color(0.2, 0.9, 1.0),
		"visual_scale": 1.0,
	},
	"regenerator": {
		"display_name": "Regenerator",
		"health": 320,
		"health_per_wave": 0.0,
		"move_speed": 80.0,
		"cash_reward": 45,
		"base_damage": 15,
		"armor": 0,
		"earliest_debut_round": 14,
		"formation_strength": 12,
		"director_cost": 7,
		"spawn_weight": 20,
		"spawn_style": &"spaced",
		"role": &"tank",
		"family": &"healer",
		"family_tier": 1,
		"traits": [&"regenerates"],
		"regeneration_per_second": 20,
		"color": Color(0.25, 1.0, 0.35),
		"visual_scale": 1.15,
	},
	"rusher": {
		"display_name": "Rusher",
		"health": 200,
		"health_per_wave": 0.0,
		"move_speed": 90.0,
		"cash_reward": 38,
		"base_damage": 15,
		"armor": 0,
		"earliest_debut_round": 14,
		"formation_strength": 10,
		"director_cost": 6,
		"spawn_weight": 22,
		"spawn_style": &"burst",
		"role": &"pressure",
		"family": &"speed",
		"family_tier": 2,
		"traits": [&"fast", &"rushes"],
		"rush_start_ratio": 0.7,
		"rush_speed_multiplier": 2.0,
		"color": Color(1.0, 0.25, 0.2),
		"visual_scale": 1.0,
	},
	"summoner": {
		"display_name": "Summoner",
		"health": 400,
		"health_per_wave": 0.0,
		"move_speed": 60.0,
		"cash_reward": 56,
		"base_damage": 20,
		"armor": 0,
		"earliest_debut_round": 14,
		"formation_strength": 18,
		"director_cost": 10,
		"spawn_weight": 15,
		"spawn_style": &"spaced",
		"role": &"support",
		"family": &"summon",
		"family_tier": 1,
		"traits": [&"summons"],
		"summon_enemy_id": &"swarmling",
		"summon_interval": 4.0,
		"summon_limit": 3,
		"color": Color(0.8, 0.2, 1.0),
		"visual_scale": 1.3,
	},
	"swat_enforcer": {
		"display_name": "SWAT Enforcer",
		"health": 900,
		"health_per_wave": 0.0,
		"move_speed": 55.0,
		"cash_reward": 80,
		"base_damage": 30,
		"armor": 25,
		"earliest_debut_round": 14,
		"formation_strength": 30,
		"director_cost": 22,
		"spawn_weight": 8,
		"spawn_style": &"spaced",
		"role": &"tank",
		"family": &"armor",
		"family_tier": 2,
		"traits": [&"armored", &"high_health"],
		"color": Color(0.18, 0.22, 0.28),
		"visual_scale": 1.45,
	},
	"heavy_enforcer": {
		"display_name": "Heavy Enforcer",
		"health": 1800,
		"health_per_wave": 0.0,
		"move_speed": 50.0,
		"cash_reward": 128,
		"base_damage": 45,
		"armor": 20,
		"earliest_debut_round": 17,
		"formation_strength": 45,
		"director_cost": 35,
		"spawn_weight": 6,
		"spawn_style": &"spaced",
		"role": &"tank",
		"family": &"general",
		"family_tier": 2,
		"traits": [&"armored", &"high_health"],
		"color": Color(0.28, 0.32, 0.38),
		"visual_scale": 1.55,
	},
	"striker": {
		"display_name": "Striker",
		"health": 425,
		"health_per_wave": 0.0,
		"move_speed": 110.0,
		"cash_reward": 48,
		"base_damage": 14,
		"armor": 0,
		"earliest_debut_round": 17,
		"formation_strength": 10,
		"director_cost": 8,
		"spawn_weight": 22,
		"spawn_style": &"burst",
		"role": &"pressure",
		"family": &"general",
		"family_tier": 2,
		"traits": [&"basic"],
		"color": Color(0.95, 0.42, 0.18),
		"visual_scale": 1.05,
	},
	"shielded": {
		"display_name": "Shielded",
		"health": 450,
		"health_per_wave": 0.0,
		"move_speed": 78.0,
		"cash_reward": 58,
		"base_damage": 16,
		"armor": 0,
		"earliest_debut_round": 17,
		"formation_strength": 16,
		"director_cost": 11,
		"spawn_weight": 14,
		"spawn_style": &"spaced",
		"role": &"tank",
		"family": &"shields",
		"family_tier": 1,
		"traits": [&"shielded"],
		"ablative_shield_points": 5,
		"color": Color(0.25, 0.72, 1.0),
		"visual_scale": 1.15,
	},
	"shield_projector": {
		"display_name": "Shield Projector",
		"health": 525,
		"health_per_wave": 0.0,
		"move_speed": 68.0,
		"cash_reward": 82,
		"base_damage": 18,
		"armor": 0,
		"earliest_debut_round": 20,
		"formation_strength": 20,
		"director_cost": 14,
		"spawn_weight": 10,
		"spawn_style": &"steady",
		"role": &"support",
		"family": &"shields",
		"family_tier": 2,
		"traits": [&"shielded", &"shield_aura"],
		"ablative_shield_points": 12,
		"shield_aura_radius": 96.0,
		"color": Color(0.18, 0.9, 0.85),
		"visual_scale": 1.25,
	},
	"juggernaut": {
		"display_name": "Juggernaut",
		"health": 3500,
		"health_per_wave": 0.0,
		"move_speed": 38.0,
		"cash_reward": 236,
		"base_damage": 65,
		"armor": 0,
		"earliest_debut_round": 20,
		"formation_strength": 75,
		"director_cost": 65,
		"spawn_weight": 4,
		"spawn_style": &"spaced",
		"role": &"tank",
		"family": &"tank",
		"family_tier": 2,
		"traits": [&"high_health", &"slow"],
		"color": Color(0.42, 0.30, 0.22),
		"visual_scale": 1.7,
	},
	"bulwark": {
		"display_name": "Bulwark",
		"health": 6000,
		"health_per_wave": 0.0,
		"move_speed": 32.0,
		"cash_reward": 400,
		"base_damage": 90,
		"armor": 30,
		"earliest_debut_round": 22,
		"formation_strength": 120,
		"director_cost": 110,
		"spawn_weight": 2,
		"spawn_style": &"spaced",
		"role": &"tank",
		"family": &"general",
		"family_tier": 2,
		"traits": [&"armored", &"high_health", &"slow"],
		"color": Color(0.20, 0.28, 0.42),
		"visual_scale": 1.9,
	},
	"brute": {
		"display_name": "Brute",
		"health": 90000,
		"health_per_wave": 0.0,
		"move_speed": 18.0,
		"cash_reward": 375,
		"base_damage": 100,
		"armor": 0,
		"earliest_debut_round": 24,
		"formation_strength": 0,
		"director_cost": 0,
		"spawn_weight": 0,
		"spawn_style": &"boss",
		"role": &"boss",
		"family": &"general",
		"family_tier": 2,
		"traits": [&"boss", &"high_health"],
		"boss": true,
		"color": Color(0.75, 0.08, 0.08),
		"visual_scale": 1.8,
	},
}

const TOWERS := {
	"invader": {
	"display_name": "Invader",
	"placement_cost": 200,
	"footprint_cells": Vector2i(2, 2),
	"type_tags": [&"biological"],
	"damage_tags": [&"ballistic"],
	"primary_damage_type": &"ballistic",
	"delivery_type": DELIVERY_HITSCAN,
	"impact_mode": IMPACT_PRIMARY,

	# Invader no longer has Critical at base.
	"bonus_tags": [],

	"paths": {
		"a": {
			"display_name": "Dual Pistols",
			"description": "Adds a second pistol, greatly increasing attack speed and granting Critical.",
			"cost": 2700,
			"unlock_level": 3,
			"add_bonus_tags": [&"critical"],

			"stat_multipliers": {
				"firerate": 0.42,
			},
		},

		"b": {
			"display_name": "Piercing Blaster",
			"description": "Fires slower, heavier shots that bypass armor and pierce through an additional enemy.",
			"cost": 2650,
			"unlock_level": 3,

			"add_bonus_tags": [&"pierce"],
			"pierce_count_add": 1,

			"stat_multipliers": {
				"damage": 1.7,
				"firerate": 1.2,
			},
		},
	},

	"levels": [
		{
			"upgrade_cost": 0,
			"damage": 30,
			"firerate": 0.50,
			"range": 9.35,
		},
		{
			"upgrade_cost": 100,
			"damage": 36,
			"firerate": 0.462,
			"range": 9.775,
		},
		{
			"upgrade_cost": 283,
			"damage": 65,
			"firerate": 0.462,
			"range": 10.625,
			"add_bonus_tags": [&"reveal"],
		},
		{
			"upgrade_cost": 917,
			"damage": 140,
			"firerate": 0.396,
			"range": 11.9,
		},
	],
},
	"fisherman": {
		"display_name": "Alien Fisherman",
		"description": "Casts into a forward cone, hooking one enemy for four damage ticks while reeling it backward. After release, that enemy cannot be pulled again for 2.5 seconds, but can still take hook damage.",
		"placement_cost": 167,
		"footprint_cells": Vector2i(2, 2),
		"type_tags": [&"biological"],
		"damage_tags": [&"melee"],
		"primary_damage_type": &"melee",
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_PRIMARY,
		"bonus_tags": [],
		"paths": {
			"a": {
				"display_name": "Live Wire",
				"description": "Electrifies the fishing line, converting its damage to Electric so every hook tick contributes to shared Electric buildup.",
				"cost": 3000,
				"unlock_level": 3,
				"add_damage_tags": [&"electric"],
				"primary_damage_type": &"electric",
				"stat_multipliers": {"damage": 1.40},
				"behavior_flags": {"fisherman_electric_line": true},
			},
			"b": {
				"display_name": "Minefield",
				"description": "Periodically places up to three Explosive mines on nearby path cells. Mines clear after each round.",
				"cost": 3500,
				"unlock_level": 3,
				"add_damage_tags": [&"explosive"],
				"behavior_flags": {"fisherman_mines": true},
				"behavior_values": {
					"mine_interval": 6.0,
					"mine_maximum_count": 3,
					"mine_placement_radius": 6.0,
					"mine_trigger_radius": 1.0,
					"mine_explosion_radius": 2.5,
					"mine_damage_multiplier": 1.25,
				},
			},
		},
		# Cost and stat progression use the same TDS conversion as Invader:
		# gameplay costs are one third of the source curve and damage is 30x.
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 150,
				"firerate": 2.0,
				"range": 12.75,
				"hook_tick_count": 4,
				"hook_duration": 1.2,
				"hook_pull_speed": 80.0,
				"hook_pull_immunity": 2.5,
			},
			{
				"upgrade_cost": 167,
				"damage": 300,
				"firerate": 2.0,
				"range": 13.5,
				"hook_tick_count": 4,
				"hook_duration": 1.2,
				"hook_pull_speed": 85.0,
				"hook_pull_immunity": 2.5,
			},
			{
				"upgrade_cost": 500,
				"damage": 375,
				"firerate": 2.0,
				"range": 15.0,
				"hook_tick_count": 4,
				"hook_duration": 1.2,
				"hook_pull_speed": 90.0,
				"hook_pull_immunity": 2.5,
			},
			{
				"upgrade_cost": 1667,
				"damage": 600,
				"firerate": 1.75,
				"range": 16.5,
				"hook_tick_count": 4,
				"hook_duration": 1.2,
				"hook_pull_speed": 100.0,
				"hook_pull_immunity": 2.5,
			},
		],
	},
	"gauss_repeater": {
		"display_name": "Gauss Repeater",
		"placement_cost": 800,
		"footprint_cells": Vector2i(2, 2),
		"type_tags": [&"technology"],
		"damage_tags": [&"electric"],
		"primary_damage_type": &"electric",
		"delivery_type": DELIVERY_PROJECTILE,
		"impact_mode": IMPACT_FIRST_CONTACT,
		"bonus_tags": [],
		"pierce_count": 0,
		"paths": {
			"a": {
				"display_name": "Heavy Accelerator",
				"description": "Periodically fires a zero-spread heavy round straight along Gauss's current aim. The heavy round has unlimited Pierce.",
				"cost": 6500,
				"unlock_level": 3,
				"stat_multipliers": {
					"projectile_speed": 1.10,
				},
				"behavior_flags": {
					"gauss_heavy_shot": true,
				},
				"behavior_values": {
					"heavy_shot_interval": 4.0,
					"heavy_shot_damage_multiplier": 3.0,
					"heavy_shot_speed_multiplier": 0.60,
				},
			},
			"b": {
				"display_name": "Threat Tracker",
				"description": "Tracks and fires at the strongest enemy inside the selected 45-degree cone. Changing cone direction resets spread.",
				"cost": 6400,
				"unlock_level": 3,
				"stat_multipliers": {
					"firerate": 0.7,
				},
				"behavior_flags": {
					"gauss_tracking_cone": true,
				},
				"behavior_values": {
					"tracking_cone_degrees": 45.0,
				},
			},
		},
		
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 16,
				"projectile_speed": 900.0,
				"firerate": 0.080,
				"maximum_spread_degrees": 18.0,
				"minimum_spread_degrees": 4.5,
				"spread_tighten_duration": 5.0,
				"spread_recovery_delay": 1.0,
				"spread_recovery_per_second": 10.0,
			},
			{
				"upgrade_cost": 333,
				"damage": 16,
				"projectile_speed": 950.0,
				"firerate": 0.060,
				"maximum_spread_degrees": 18.0,
				"minimum_spread_degrees": 4.5,
				"spread_tighten_duration": 4.25,
				"spread_recovery_delay": 1.0,
				"spread_recovery_per_second": 10.0,
			},
			{
				"upgrade_cost": 1600,
				"damage": 32,
				"projectile_speed": 1050.0,
				"firerate": 0.05,
				"maximum_spread_degrees": 16.0,
				"minimum_spread_degrees": 4.0,
				"spread_tighten_duration": 3.25,
				"spread_recovery_delay": 1.0,
				"spread_recovery_per_second": 10.0,
			},
			{
				"upgrade_cost": 3500,
				"damage": 56,
				"projectile_speed": 1200.0,
				"firerate": 0.05,
				"maximum_spread_degrees": 14.0,
				"minimum_spread_degrees": 3.0,
				"spread_tighten_duration": 2.0,
				"spread_recovery_delay": 1.0,
				"spread_recovery_per_second": 10.0,
				"gauss_overclock_enabled": true,
				"gauss_overclock_max_speed_bonus": 0.25,
				"gauss_overclock_ramp_duration": 3.0,
				"gauss_overclock_decay_duration": 1.0,
			},
		],
	},
	"beholder": {
		"display_name": "Brainiac",
		"placement_cost": 2000,
		"footprint_cells": Vector2i(2, 2),
		"type_tags": [&"biological"],
		"damage_tags": [&"beam"],
		"primary_damage_type": &"beam",
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_PRIMARY,
		"bonus_tags": [],
		"paths": {
			"a": {
				"display_name": "Psionic Link",
				"description": "Every 6 seconds, links Brainiac's current target for 2 seconds. Thirty-five percent of the damage it receives from all towers is spread to enemies around it.",
				"cost": 6500,
				"unlock_level": 3,
				"add_bonus_tags": [&"psionic"],
				"behavior_flags": {"brainiac_psionic_link": true},
				"behavior_values": {
					"brainiac_link_duration": 2.0,
					"brainiac_link_cooldown": 6.0,
					"brainiac_link_radius": 3.5,
					"brainiac_link_damage_share": 0.35,
				},
			},
			"b": {
				"display_name": "Escalating Beam",
				"description": "Starts at 50% of the previous level's damage and gains 25% every 0.5 seconds of uninterrupted fire, up to 250%.",
				"cost": 6700,
				"unlock_level": 3,
				"behavior_flags": {
					"beholder_ramping_beam": true,
				},
				"behavior_values": {
					"beam_ramp_start_multiplier": 0.50,
					"beam_ramp_step_multiplier": 0.25,
					"beam_ramp_step_interval": 0.50,
					"beam_ramp_max_multiplier": 2.50,
				},
			},
		},
		
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 130,
				"firerate": 0.2,
				"range": 7.5,
				"beam_turn_speed_degrees": 480.0,
				"beam_half_width": 2.5,
			},
			{
				"upgrade_cost": 667,
				"damage": 160,
				"firerate": 0.2,
				"range": 8.0,
				"beam_turn_speed_degrees": 720.0,
				"beam_half_width": 2.5,
			},
			{
				"upgrade_cost": 2000,
				"damage": 270,
				"firerate": 0.2,
				"range": 8.25,
				"beam_turn_speed_degrees": 720.0,
				"beam_half_width": 5.0,
			},
			{
				"upgrade_cost": 3000,
				"damage": 405,
				"firerate": 0.15,
				"range": 9.0,
				"beam_turn_speed_degrees": 900.0,
				"beam_half_width": 5.0,
			},
		],
	},
	"reaver": {
		"display_name": "Reaver",
		"placement_cost": 175,
		"footprint_cells": Vector2i(2, 2),
		"type_tags": [&"biological"],
		"damage_tags": [&"melee"],
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_PRIMARY,
		"bonus_tags": [],
		"paths": {
			"a": {
				"display_name": "Time Bubble",
				"description": "Activates a Psionic slow aura around Reaver for three seconds, followed by a seven-second cooldown.",
				"cost": 2000,
				"unlock_level": 3,
				"add_bonus_tags": [&"psionic"],
				"behavior_flags": {
					"reaver_time_bubble": true,
				},
				"behavior_values": {
					"time_bubble_active_duration": 3.0,
					"time_bubble_cooldown": 7.0,
					"time_bubble_refresh_interval": 0.20,
					"time_bubble_slow_duration": 0.30,
				},
			},
			"b": {
				"display_name": "Assassinate",
				"description": "Adds Critical. The combo's finishing strike is guaranteed to critically hit.",
				"cost": 2100,
				"unlock_level": 3,
				"add_bonus_tags": [&"critical"],
				"behavior_flags": {
					"reaver_assassinate": true,
				},
			},
		},
		
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 70,
				"firerate": 1.15,
				"range": 9.0,
				"combo_hit_count": 3,
				"combo_stagger": 0.16,
			},
			{
				"upgrade_cost": 125,
				"damage": 90,
				"firerate": .85,
				"range": 9.5,
				"combo_hit_count": 3,
				"combo_stagger": 0.16,
			},
			{
				"upgrade_cost": 700,
				"damage": 220,
				"firerate": 0.65,
				"range": 10.0,
				"combo_hit_count": 3,
				"combo_stagger": 0.12,
			},
			{
				"upgrade_cost": 1450,
				"damage": 400,
				"firerate": 0.50,
				"range": 11.0,
				"combo_hit_count": 3,
				"combo_stagger": 0.10,
			},
		],
	},
	"brainiac": {
		"display_name": "Beholder",
		"placement_cost": 400,
		"footprint_cells": Vector2i(2, 2),
		"type_tags": [&"biological", &"technology"],
		"damage_tags": [&"beam"],
		"primary_damage_type": &"beam",
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_FIRST_CONTACT,
		"bonus_tags": [&"reveal"],
		"paths": {
			"a": {
				"display_name": "Piercing Volley",
				"description": "Each fanned beam can pass through one enemy to damage the next enemy along its path.",
				"cost": 6150,
				"unlock_level": 3,
				"add_bonus_tags": [&"pierce"],
				"pierce_count_add": 1,
				"stat_multipliers": {
					"damage": 1.60,
				},
			},
			"b": {
				"display_name": "Withering Gaze",
				"description": "Enemies touched by a beam gain 2% increased damage taken per tick, up to 20%. The mark expires after 3 seconds without beam contact.",
				"cost": 6150,
				"unlock_level": 3,
				"behavior_flags": {
					"beholder_damage_mark": true,
				},
				"behavior_values": {
					"mark_duration": 3.0,
					"mark_damage_per_stack": 0.02,
					"mark_maximum_stacks": 10,
				},
			},
		},
		
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 110,
				"projectile_speed": 550.0,
				"firerate": 1.80,
				"range": 9.0,
				"projectile_count": 3,
				"volley_width": 5.5,
			},
			{
				"upgrade_cost": 225,
				"damage": 165,
				"projectile_speed": 600.0,
				"firerate": 1.80,
				"range": 9.5,
				"projectile_count": 3,
				"volley_width": 5.5,
			},
			{
				"upgrade_cost": 525,
				"damage": 170,
				"projectile_speed": 680.0,
				"firerate": 1.80,
				"range": 10.0,
				"projectile_count": 5,
				"volley_width": 5.5,
			},
			{
				"upgrade_cost": 2000,
				"damage": 380,
				"projectile_speed": 800.0,
				"firerate": 1.70,
				"range": 10.75,
				"projectile_count": 5,
				"volley_width": 5.5,
			},
		],
	},
	"longshot": {
		"display_name": "Longshot",
		"placement_cost": 1675,
		"footprint_cells": Vector2i(2, 2),
		"type_tags": [&"biological"],
		"damage_tags": [&"ballistic"],
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_PRIMARY,
		"bonus_tags": [&"critical"],
		"paths": {
			"a": {
				"display_name": "Anti-Materiel",
				"description": "Fires massively amplified shots with a 3x critical multiplier, but reloads 25% slower.",
				"cost": 4500,
				"unlock_level": 3,
				"stat_multipliers": {
					"damage": 2.07,
					"firerate": 1.25,
				},
				"stat_additions": {
					"critical_multiplier": 1.0,
				},
			},
			"b": {
				"display_name": "Kill Chain",
				"description": "Kills reduce Longshot's remaining reload by 50%. Critical kills reduce the remaining reload by 90% instead.",
				"cost": 4500,
				"unlock_level": 3,
				"behavior_flags": {"longshot_kill_chain": true},
				"behavior_values": {
					"kill_reload_remaining_multiplier": 0.50,
					"critical_kill_reload_remaining_multiplier": 0.10,
				},
			},
		},
		
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 500,
				"firerate": 2.20,
				"range": 23.0,
				"critical_multiplier": 2.0,
			},
			{
				"upgrade_cost": 500,
				"damage": 625,
				"firerate": 2.10,
				"range": 23.0,
				"critical_multiplier": 2.0,
			},
			{
				"upgrade_cost": 1825,
				"damage": 1050,
				"firerate": 1.95,
				"range": 23,
				"critical_multiplier": 2.0,
			},
			{
				"upgrade_cost": 3000,
				"damage": 2325,
				"firerate": 1.65,
				"range": 23.0,
				"critical_multiplier": 2.0,
			},
		],
	},
	"slinger": {
		"display_name": "Slinger",
		"placement_cost": 225,
		"footprint_cells": Vector2i(2, 2),
		"type_tags": [&"biological"],
		"damage_tags": [&"melee"],
		"primary_damage_type": &"melee",
		"delivery_type": DELIVERY_PROJECTILE,
		"impact_mode": IMPACT_PRIMARY,
		"bonus_tags": [],
		"paths": {
			"a": {
				"display_name": "Explosive Ricochet",
				"description": "Increases impact damage by 30%. The initial hit and every bounced impact create an Explosive blast dealing 55% of the impact's damage.",
				"cost": 3750,
				"unlock_level": 3,
				"add_damage_tags": [&"explosive"],
				"stat_multipliers": {
					"damage": 1.30,
				},
				"behavior_flags": {
					"slinger_contact_explosions": true,
				},
				"behavior_values": {
					"contact_explosion_radius": 2.5,
					"contact_explosion_damage_multiplier": 0.55,
				},
			},
			"b": {
				"display_name": "Razor Disc",
				"description": "Increases impact damage by 129%. The disc hits the first enemy in its line, then pierces every enemy behind it until maximum range.",
				"cost": 3750,
				"unlock_level": 3,
				"add_bonus_tags": [&"pierce"],
				"pierce_count_add": 1,
				"impact_mode": IMPACT_FIRST_CONTACT,
				"stat_multipliers": {
					"damage": 2.285714,
				},
				"stat_overrides": {"bounce_count": 0},
				"behavior_flags": {
					"infinite_pierce": true,
				},
			},
		},
		
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 24,
				"projectile_speed": 480.0,
				"firerate": 1.0,
				"range": 11.0,
				"bounce_count": 1,
				"bounce_range": 7.0,
			},
			{
				"upgrade_cost": 300,
				"damage": 48,
				"projectile_speed": 520.0,
				"firerate": 0.666667,
				"range": 11.5,
				"bounce_count": 1,
				"bounce_range": 7.0,
			},
			{
				"upgrade_cost": 570,
				"damage": 86,
				"projectile_speed": 570.0,
				"firerate": 0.666667,
				"range": 13.0,
				"bounce_count": 1,
				"bounce_range": 7.0,
			},
			{
				"upgrade_cost": 1350,
				"damage": 168,
				"projectile_speed": 570.0,
				"firerate": 0.666667,
				"range": 13.0,
				"bounce_count": 2,
				"bounce_range": 7.0,
			},
		],
	},
	"voidcaller": {
		"display_name": "Void Caller",
		"placement_cost": 675,
		"footprint_cells": Vector2i(2, 2),
		"type_tags": [&"biological"],
		"damage_tags": [&"explosive"],
		"delivery_type": DELIVERY_PROJECTILE,
		"impact_mode": IMPACT_FIRST_CONTACT,
		"bonus_tags": [],
		"paths": {
			"a": {
				"display_name": "Orb Barrage",
				"description": "Fires a simultaneous five-orb fan at a slower rate.",
				"cost": 5000,
				"unlock_level": 3,
				"stat_multipliers": {
					"damage": 0.80,
					"firerate": 1.25,
				},
				"stat_overrides": {
					"projectile_count": 5,
					"volley_width": 6.0,
					"volley_stagger": 0.0,
				},
			},
			"b": {
				"display_name": "Singularity",
				"description": "Creates a wide Singularity that slowly pulls enemies together for one second before exploding.",
				"cost": 4500,
				"unlock_level": 3,
				"add_bonus_tags": [&"psionic"],
				"behavior_flags": {"void_singularity": true},
				"behavior_values": {
					"singularity_cooldown": 10.0,
					"singularity_pull_duration": 1.0,
					"singularity_pull_radius": 7.0,
					"singularity_pull_speed": 80.0,
					"singularity_explosion_radius": 5.0,
					"singularity_damage_multiplier": 3.0,
				},
			},
		},
		
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 100,
				"projectile_speed": 440.0,
				"firerate": 1.8,
				"range": 8.0,
				"splash_radius": 2.0,
				"projectile_count": 2,
				"volley_width": 2.0,
				"volley_stagger": 0.14,
			},
			{
				"upgrade_cost": 200,
				"damage": 120,
				"projectile_speed": 470.0,
				"firerate": 1.8,
				"range": 8.0,
				"splash_radius": 2.5,
				"projectile_count": 2,
				"volley_width": 2.0,
				"volley_stagger": 0.14,
			},
			{
				"upgrade_cost": 600,
				"damage": 200,
				"projectile_speed": 520.0,
				"firerate": 1.8,
				"range": 8.75,
				"splash_radius": 2.5,
				"projectile_count": 2,
				"volley_width": 2.0,
				"volley_stagger": 0.14,
			},
			{
				"upgrade_cost": 2000,
				"damage": 400,
				"projectile_speed": 520.0,
				"firerate": 1.70,
				"range": 9.5,
				"splash_radius": 3.0,
				"projectile_count": 2,
				"volley_width": 2.0,
				"volley_stagger": 0.14,
			},
		],
	},
	"orbitalcannon": {
		"display_name": "Orbital Cannon",
		"placement_cost": 350,
		"footprint_cells": Vector2i(2, 2),
		"type_tags": [&"technology"],
		"damage_tags": [&"explosive"],
		"delivery_type": DELIVERY_PROJECTILE,
		"impact_mode": IMPACT_PRIMARY,
		"bonus_tags": [],
		"minimum_range": 5.0,
		"paths": {
			"a": {
				"display_name": "Solar Lance",
				"description": "Replaces the Explosive stunning strike with a 1.5-second, two-tile-wide Beam that intensifies as it repeatedly damages and slows every enemy inside.",
				"cost": 5000,
				"unlock_level": 3,
				"stat_multipliers": {"firerate": 1.40},
				"remove_damage_tags": [&"explosive"],
				"add_damage_tags": [&"beam"],
				"primary_damage_type": &"beam",
				"remove_bonus_tags": [&"stun"],
				"add_bonus_tags": [&"pierce"],
				"stat_overrides": {"stun_duration": 0.0},
				"behavior_flags": {
					"orbital_solar_lance": true,
					"infinite_pierce": true,
				},
				"behavior_values": {
					"solar_lance_duration": 1.5,
					"solar_lance_tick_interval": 0.2,
					"solar_lance_tick_damage_multiplier": 0.25,
					"solar_lance_tick_end_damage_multiplier": 0.50,
					"solar_lance_dual_tick_damage_multiplier": 0.10,
				},
			},
			"b": {
				"display_name": "Bombardment",
				"description": "Replaces each strike with five smaller staggered strikes around the selected location.",
				"cost": 5500,
				"unlock_level": 3,
				"behavior_flags": {"orbital_bombardment": true},
				"behavior_values": {
					"bombardment_strike_count": 5,
					"bombardment_stagger": 0.15,
					"bombardment_spread_radius": 3.0,
					"bombardment_damage_multiplier": 0.38,
					"bombardment_radius_multiplier": 0.70,
				},
			},
		},
		
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 150,
				"projectile_speed": 900.0,
				"firerate": 3.0,
				"range": 24.0,
				"splash_radius": 3.5,
				"stun_duration": 0.0,
			},
			{
				"upgrade_cost": 175,
				"damage": 225,
				"projectile_speed": 900.0,
				"firerate": 3.0,
				"range": 24.0,
				"splash_radius": 4.5,
				"stun_duration": 0.0,
			},
			{
				"upgrade_cost": 750,
				"damage": 500,
				"projectile_speed": 900.0,
				"firerate": 3.0,
				"range": 24.0,
				"splash_radius": 4.5,
				"stun_duration": 1.25,
				"add_bonus_tags": [&"stun"],
			},
			{
				"upgrade_cost": 2250,
				"damage": 1200,
				"projectile_speed": 900.0,
				"firerate": 2.8,
				"range": 24.0,
				"splash_radius": 5.5,
				"stun_duration": 1.60,
			},
		],
	},
	"energycore": {
		"display_name": "Energy Core",
		"placement_cost": 225,
		"footprint_cells": Vector2i(2, 2),
		"type_tags": [&"technology"],
		"damage_tags": [&"electric"],
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_PRIMARY,
		"bonus_tags": [],
		"paths": {
			"a": {
				"display_name": "Shockwave",
				"description": "Every five seconds, releases a weak electric pulse that damages and stuns every enemy in range.",
				"cost": 2500,
				"unlock_level": 3,
				"add_bonus_tags": [&"stun"],
				"behavior_flags": {"energy_shockwave": true},
				"behavior_values": {
					"shockwave_cooldown": 5.0,
					"shockwave_damage_multiplier": 0.35,
					"shockwave_stun_duration": 1.0,
				},
			},
			"b": {
				"display_name": "Branching Current",
				"description": "Each primary bolt splits on contact, striking two other nearby enemies for 30% damage and applying Slow.",
				"cost": 3000,
				"unlock_level": 3,
				"behavior_flags": {"energy_branching_current": true},
				"behavior_values": {
					"branch_additional_targets": 2,
					"branch_range": 4.0,
					"branch_damage_multiplier": 0.30,
				},
			},
		},
		
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 16,
				"firerate": 0.40,
				"range": 7.5,
				"projectile_count": 1,
				"slow_duration": 0.0,
			},
			{
				"upgrade_cost": 95,
				"damage": 22,
				"firerate": 0.40,
				"range": 7.5,
				"projectile_count": 2,
				"slow_duration": 0.0,
			},
			{
				"upgrade_cost": 330,
				"damage": 30,
				"firerate": 0.40,
				"range": 8.25,
				"projectile_count": 2,
				"slow_duration": 0.50,
			},
			{
				"upgrade_cost": 1400,
				"damage": 75,
				"firerate": 0.40,
				"range": 8.25,
				"projectile_count": 3,
				"slow_duration": 0.50,
			},
		],
	},
	"saucer": {
		"display_name": "Saucer",
		"placement_cost": 1675,
		"footprint_cells": Vector2i(2, 2),
		"type_tags": [&"technology"],
		"damage_tags": [&"electric"],
		"primary_damage_type": &"electric",
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_PRIMARY,
		"bonus_tags": [&"reveal"],
		"paths": {
			"a": {
				"display_name": "Homing Rockets",
				"description": "Adds Explosive. Launches two powerful homing rockets with a 3-tile splash radius every three seconds while continuing to fire the single-target Electric gun.",
				"cost": 3500,
				"unlock_level": 3,
				"add_damage_tags": [&"explosive"],
				"behavior_flags": {"saucer_twin_rockets": true},
				"behavior_values": {
					"saucer_rocket_damage_multiplier": 2.0,
					"saucer_rocket_interval": 3.0,
					"saucer_rocket_splash_radius": 3.0,
				},
			},
			"b": {
				"display_name": "Specimen Deployment",
				"description": "Successful abductions deploy a mobile melee monster for 10 seconds. Limited to one active monster per saucer.",
				"cost": 3200,
				"unlock_level": 3,
				"add_bonus_tags": [&"spawner"],
				"behavior_flags": {"saucer_monster_drop": true},
			},
		},
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 154,
				"projectile_speed": 650.0,
				"firerate": 0.65,
				"range": 15.0,
				"flyer_move_speed": 165.0,
				"flyer_attack_radius": 5.0,
				"abduction_cooldown": 16.0,
				"abduction_radius": 1.5,
				"abduction_health_threshold": 0.0,
				"monster_stats": {"damage": 750, "attack_interval": 1.0, "aim_radius": 1.25, "acquisition_radius": 8.0, "move_speed": 90.0, "lifetime": 10.0},
			},
			{
				"upgrade_cost": 1075,
				"damage": 218,
				"projectile_speed": 760.0,
				"firerate": 0.60,
				"range": 16.0,
				"flyer_move_speed": 190.0,
				"flyer_attack_radius": 5.5,
				"abduction_cooldown": 16.0,
				"abduction_radius": 1.5,
				"abduction_health_threshold": 0.0,
				"monster_stats": {"damage": 400, "attack_interval": 1.0, "aim_radius": 1.25, "acquisition_radius": 8.0, "move_speed": 90.0, "lifetime": 10.0},
			},
			{
				"upgrade_cost": 1000,
				"damage": 336,
				"projectile_speed": 760.0,
				"firerate": 0.60,
				"range": 16.0,
				"flyer_move_speed": 190.0,
				"flyer_attack_radius": 5.5,
				"abduction_cooldown": 13.0,
				"abduction_radius": 2.0,
				"abduction_health_threshold": 0.40,
				"monster_stats": {"damage": 400, "attack_interval": 1.0, "aim_radius": 1.25, "acquisition_radius": 8.0, "move_speed": 90.0, "lifetime": 10.0},
			},
			{
				"upgrade_cost": 1600,
				"damage": 378,
				"projectile_speed": 920.0,
				"firerate": 0.45,
				"range": 17.0,
				"flyer_move_speed": 210.0,
				"flyer_attack_radius": 6.0,
				"abduction_cooldown": 10.0,
				"abduction_radius": 2.25,
				"abduction_health_threshold": 0.40,
				"monster_stats": {"damage": 400, "attack_interval": 1.0, "aim_radius": 1.25, "acquisition_radius": 8.0, "move_speed": 90.0, "lifetime": 10.0},
			},
		],
	},
	"hivemother": {
		"display_name": "Hive Mother",
		"placement_cost": 200,
		"footprint_cells": Vector2i(2, 2),
		"type_tags": [&"biological"],
		"damage_tags": [&"ballistic"],
		"delivery_type": DELIVERY_PROJECTILE,
		"impact_mode": IMPACT_FIRST_CONTACT,
		"bonus_tags": [&"spawner"],
		"spawned_unit_id": &"spore_turret",
		"paths": {
			"a": {
				"display_name": "Triple Bloom",
				"description": "Each Spore Turret fires three projectiles simultaneously from one point. The shots fan outward with distance, with each projectile dealing 65% damage.",
				"cost": 4250,
				"unlock_level": 3,
				"unit_stat_multipliers": {
					"damage": 0.65,
				},
				"unit_stat_overrides": {
					"projectile_count": 3,
					"volley_width": 1.5,
				},
			},
			"b": {
				"display_name": "Mycelial Network",
				"description": "Reduces Spore Turret attack intervals by 35%. They can attack enemies locally targeted by a turret belonging to another Hive Mother, even beyond their own range.",
				"cost": 4250,
				"unlock_level": 3,
				"unit_stat_multipliers": {
					"attack_interval": 0.65,
				},
				"unit_stat_overrides": {
					"shared_spore_targeting": true,
				},
			},
		},
		"levels": [
			{
				"upgrade_cost": 0,
				"spawn_interval": 7.0,
				"spawn_limit": 1,
				"deployment_radius": 6.0,
				"unit_stats": {"damage": 60, "attack_interval": 0.90, "aim_radius": 8.0, "move_speed": 0.0, "projectile_speed": 480.0, "lifetime": 25.0},
			},
			{
				"upgrade_cost": 300,
				"spawn_interval": 6.5,
				"spawn_limit": 2,
				"deployment_radius": 6.5,
				"unit_stats": {"damage": 60, "attack_interval": 0.8, "aim_radius": 8.5, "move_speed": 0.0, "projectile_speed": 520.0, "lifetime": 25.0},
			},
			{
				"upgrade_cost": 900,
				"spawn_interval": 6.0,
				"spawn_limit": 3,
				"deployment_radius": 7.0,
				"unit_stats": {"damage": 110, "attack_interval": 0.73, "aim_radius": 9.0, "move_speed": 0.0, "projectile_speed": 560.0, "lifetime": 25.0},
			},
			{
				"upgrade_cost": 2600,
				"spawn_interval": 5,
				"spawn_limit": 4,
				"deployment_radius": 8.0,
				"unit_stats": {"damage": 165, "attack_interval": 0.55, "aim_radius": 11.0, "move_speed": 0.0, "projectile_speed": 680.0, "lifetime": 25.0},
			},
		],
	},
	"dronedepot": {
		"display_name": "Drone Depot",
		"placement_cost": 500,
		"footprint_cells": Vector2i(2, 2),
		"type_tags": [&"technology"],
		"damage_tags": [&"ballistic"],
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_PRIMARY,
		"bonus_tags": [&"reveal", &"spawner"],
		"spawned_unit_id": &"drone",
		"paths": {
			"a": {
				"display_name": "Laser Drones",
				"description": "Replaces each drone's Ballistic weapon with a continuous Beam that deals 25% more damage and has a 50% larger damage budget. The Beam must remain physically aligned with its primary target to deal tick damage.",
				"cost": 4000,
				"unlock_level": 3,
				"remove_damage_tags": [&"ballistic"],
				"add_damage_tags": [&"beam"],
				"primary_damage_type": &"beam",
				"unit_stat_multipliers": {
					"damage": 1.25,
					"damage_budget": 1.25,
				},
				"unit_stat_overrides": {
					"damage_tags": [&"beam"],
					"continuous_beam": true,
				},
			},
			"b": {
				"display_name": "Final Payload",
				"description": "Adds Explosive. When a drone exhausts its damage budget, it self-destructs and the depot rebuilds it after 0.5 seconds.",
				"cost": 4300,
				"unlock_level": 3,
				"add_damage_tags": [&"explosive"],

				"unit_stat_overrides": {
					"additional_damage_tags": [&"explosive"],
					"explode_on_damage_budget": true,
					"budget_replacement_delay": 0.5,
					"budget_explosion_radius": 2.75,
					"budget_explosion_damage_multiplier": 3.0,
				},
			},
		},
		"levels": [
			{
				"upgrade_cost": 0,
				"spawn_interval": 0.5,
				"spawn_limit": 1,
				"deployment_radius": 11.0,
				"unit_stats": {"damage": 100, "attack_interval": 0.35, "aim_radius": 2.5, "move_speed": 120.0, "damage_budget": 1300, "recharge_duration": 3.0},
			},
			{
				"upgrade_cost": 450,
				"spawn_interval": 0.5,
				"spawn_limit": 2,
				"deployment_radius": 11.0,
				"unit_stats": {"damage": 100, "attack_interval": 0.35, "aim_radius": 2.5, "move_speed": 120.0, "damage_budget": 1300, "recharge_duration": 3.0},
			},
			{
				"upgrade_cost": 1100,
				"spawn_interval": 0.5,
				"spawn_limit": 3,
				"deployment_radius": 11.0,
				"unit_stats": {"damage": 100, "attack_interval": 0.35, "aim_radius": 2.5, "move_speed": 120.0, "damage_budget": 1300, "recharge_duration": 3.0},
			},
			{
				"upgrade_cost": 2500,
				"spawn_interval": 0.5,
				"spawn_limit": 3,
				"deployment_radius": 13.0,
				"unit_stats": {"damage": 150, "attack_interval": 0.25, "aim_radius": 2.5, "move_speed": 120.0, "damage_budget": 5000, "recharge_duration": 2.0},
			},
		],
	},
	"mechbay": {
		"display_name": "Mech Bay",
		"placement_cost": 900,
		"footprint_cells": Vector2i(2, 2),
		"type_tags": [&"technology"],
		"damage_tags": [&"melee"],
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_PRIMARY,
		"bonus_tags": [&"spawner"],
		"spawned_unit_id": &"mech",
		"paths": {
			"a": {
				"display_name": "Juggernaut",
				"description": "Deploys larger, slower mechs whose area slams damage and stun every enemy around them.",
				"cost": 4800,
				"unlock_level": 3,
				"add_bonus_tags": [&"stun"],
				"unit_stat_multipliers": {
					"damage": 1.75,
					"attack_interval": 1.40,
					"move_speed": 0.60,
				},
				"unit_stat_overrides": {
					"mech_area_slam": true,
					"mech_slam_radius": 3.5,
					"stun_duration": 0.60,
					"visual_scale": 1.35,
				},
			},
			"b": {
				"display_name": "Hunter",
				"description": "Deploys faster mechs that pursue targets in either direction, prioritizing bosses and elites with increased critical chance.",
				"cost": 4800,
				"unlock_level": 3,
				"add_bonus_tags": [&"critical"],
				"unit_stat_multipliers": {
					"attack_interval": 0.75,
					"move_speed": 1.60,
				},
				"unit_stat_overrides": {
					"critical_chance": 0.10,
					"hunter_critical_chance": 0.30,
					"mech_hunter": true,
					"hunter_pursuit_radius": 12.0,
				},
			},
		},
		"levels": [
			{
				"upgrade_cost": 0,
				"spawn_interval": 14.0,
				"spawn_limit": 1,
				"deployment_radius": 3.0,
				"unit_stats": {"damage": 150, "attack_interval": 1.00, "aim_radius": 2.5, "move_speed": 45.0},
			},
			{
				"upgrade_cost": 450,
				"spawn_interval": 12.5,
				"spawn_limit": 1,
				"deployment_radius": 3.0,
				"unit_stats": {"damage": 210, "attack_interval": .95, "aim_radius": 2.75, "move_speed": 52.0},
			},
			{
				"upgrade_cost": 900,
				"spawn_interval": 11.0,
				"spawn_limit": 2,
				"deployment_radius": 3.0,
				"unit_stats": {"damage": 260, "attack_interval": 0.85, "aim_radius": 3.0, "move_speed": 60.0},
			},
			{
				"upgrade_cost": 3150,
				"spawn_interval": 8.0,
				"spawn_limit": 3,
				"deployment_radius": 3.0,
				"unit_stats": {"damage": 475, "attack_interval": 0.6, "aim_radius": 4.0, "move_speed": 78.0},
			},
		],
	},
}

const MODES := {
	"easy": {
		"display_name": "Easy",
		"starting_cash": 750,
		"starting_lives": 100,
		"max_rounds": 24,
		"starting_spawn_threat": 1.0,
		"threat_continuous_ratio": 0.7,
		"threat_chunk_ratio": 0.3,
		"threat_chunk_interval": 4.0,
		"active_enemy_cap": 160,
		"horde_active_enemy_cap": 200,
		"gauntlet_active_enemy_cap": 220,
		"absolute_enemy_cap": 240,
	},
}


static func get_enemy(enemy_id: StringName) -> Dictionary:
	assert(ENEMIES.has(enemy_id), "Unknown enemy ID: %s" % enemy_id)
	return ENEMIES[enemy_id].duplicate(true)


static func get_enemy_family(enemy_id: StringName) -> StringName:
	return StringName(get_enemy(enemy_id).get("family", &"general"))


static func get_enemy_family_tier(enemy_id: StringName) -> int:
	return clampi(int(get_enemy(enemy_id).get("family_tier", 1)), 1, 2)


static func get_enemy_family_ids(
	family: StringName,
	tier := 0
) -> Array[StringName]:
	var members: Array[StringName] = []
	for enemy_key in ENEMIES:
		var enemy_id := StringName(enemy_key)
		if get_enemy_family(enemy_id) != family:
			continue
		if tier > 0 and get_enemy_family_tier(enemy_id) != tier:
			continue
		members.append(enemy_id)
	return members


static func build_enemy_debut_plan(rng: RandomNumberGenerator) -> Dictionary:
	return build_normal_enemy_progression(rng)["debut_plan"]


static func build_normal_enemy_progression(
	rng: RandomNumberGenerator
) -> Dictionary:
	var tier_one_by_family := {}
	var tier_two_by_family := {}
	for enemy_key in ENEMIES:
		var enemy_id := StringName(enemy_key)
		var enemy: Dictionary = ENEMIES[enemy_key]
		if bool(enemy.get("boss", false)):
			continue
		var family := StringName(enemy.get("family", &"general"))
		if family == &"general":
			continue
		var family_tier := int(enemy.get("family_tier", 1))
		var family_members: Array = (
			tier_one_by_family.get(family, [])
			if family_tier == 1
			else tier_two_by_family.get(family, [])
		)
		family_members.append(enemy_id)
		if family_tier == 1:
			tier_one_by_family[family] = family_members
		else:
			tier_two_by_family[family] = family_members

	var family_pool: Array = tier_one_by_family.keys()
	shuffle_with_rng(family_pool, rng)
	var selected_families: Array[StringName] = []
	var selected_tier_one: Array[StringName] = []
	for index in mini(3, family_pool.size()):
		var family := StringName(family_pool[index])
		var tier_one_options: Array = tier_one_by_family[family].duplicate()
		shuffle_with_rng(tier_one_options, rng)
		selected_families.append(family)
		selected_tier_one.append(StringName(tier_one_options[0]))

	var upgrade_family_pool: Array = []
	for family in selected_families:
		if not Array(tier_two_by_family.get(family, [])).is_empty():
			upgrade_family_pool.append(family)
	shuffle_with_rng(upgrade_family_pool, rng)
	var selected_tier_two: Array[StringName] = []
	var advanced_families: Array[StringName] = []
	for family_value in upgrade_family_pool:
		if selected_tier_two.size() >= 2:
			break
		var family := StringName(family_value)
		var tier_two_options: Array = tier_two_by_family[family].duplicate()
		shuffle_with_rng(tier_two_options, rng)
		selected_tier_two.append(StringName(tier_two_options[0]))
		advanced_families.append(family)

	# A run can select families that do not have Tier 2 content yet. Fill any
	# missing upgrade beats from the remaining non-general Tier 2 roster.
	var fallback_tier_two: Array = []
	for family_key in tier_two_by_family:
		if advanced_families.has(StringName(family_key)):
			continue
		for enemy_id in Array(tier_two_by_family[family_key]):
			if not selected_tier_two.has(StringName(enemy_id)):
				fallback_tier_two.append(StringName(enemy_id))
	shuffle_with_rng(fallback_tier_two, rng)
	while selected_tier_two.size() < 2 and not fallback_tier_two.is_empty():
		var enemy_id := StringName(fallback_tier_two.pop_back())
		selected_tier_two.append(enemy_id)
		advanced_families.append(get_enemy_family(enemy_id))
	if selected_tier_two.size() < 2:
		var any_tier_two: Array = []
		for enemy_key in ENEMIES:
			var enemy_id := StringName(enemy_key)
			var enemy: Dictionary = ENEMIES[enemy_key]
			if (
				not bool(enemy.get("boss", false))
				and int(enemy.get("family_tier", 1)) == 2
				and not selected_tier_two.has(enemy_id)
			):
				any_tier_two.append(enemy_id)
		shuffle_with_rng(any_tier_two, rng)
		while selected_tier_two.size() < 2 and not any_tier_two.is_empty():
			var enemy_id := StringName(any_tier_two.pop_back())
			selected_tier_two.append(enemy_id)
			advanced_families.append(get_enemy_family(enemy_id))

	var plan := {}
	for enemy_key in ENEMIES:
		plan[StringName(enemy_key)] = 999
	# General-family enemies are progression fixtures rather than drafted roster
	# choices, so retain their established availability beats.
	for enemy_id in FIXED_ENEMY_DEBUT_ROUNDS:
		plan[enemy_id] = int(FIXED_ENEMY_DEBUT_ROUNDS[enemy_id])
	var tier_one_rounds := [4, 6, 10]
	for index in selected_tier_one.size():
		plan[selected_tier_one[index]] = tier_one_rounds[index]
	var tier_two_rounds := [14, 18]
	for index in selected_tier_two.size():
		plan[selected_tier_two[index]] = tier_two_rounds[index]
	return {
		"debut_plan": plan,
		"selected_families": selected_families,
		"selected_tier_one": selected_tier_one,
		"selected_tier_two": selected_tier_two,
		"advanced_families": advanced_families,
	}


static func shuffle_with_rng(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var previous: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = previous


static func get_available_enemy_ids(
	round_number: int,
	debut_plan: Dictionary
) -> Array[StringName]:
	var available: Array[StringName] = []
	for enemy_key in ENEMIES:
		var enemy_id := StringName(enemy_key)
		if bool(ENEMIES[enemy_key].get("boss", false)):
			continue
		if int(debut_plan.get(enemy_id, 999)) <= round_number:
			available.append(enemy_id)
	return available


static func get_debut_enemy_ids(
	round_number: int,
	debut_plan: Dictionary
) -> Array[StringName]:
	var debuts: Array[StringName] = []
	for enemy_key in debut_plan:
		var enemy_id := StringName(enemy_key)
		if enemy_id != &"brute" and int(debut_plan[enemy_key]) == round_number:
			debuts.append(enemy_id)
	return debuts


static func get_eligible_wave_styles(
	round_number: int,
	available: Array[StringName]
) -> Array[StringName]:
	var styles: Array[StringName] = []
	for style_key in WAVE_STYLE_RULES:
		var style_name := StringName(style_key)
		var rule: Dictionary = WAVE_STYLE_RULES[style_key]
		if round_number < int(rule.get("minimum_round", 1)):
			continue
		if round_number > int(rule.get("maximum_round", 999)):
			continue
		var requirements_met := true
		for required_id in Array(rule.get("required_all", [])):
			if StringName(required_id) not in available:
				requirements_met = false
				break
		if not requirements_met:
			continue
		var required_any: Array = rule.get("required_any", [])
		if not required_any.is_empty():
			var found_required_enemy := false
			for required_id in required_any:
				if StringName(required_id) in available:
					found_required_enemy = true
					break
			if not found_required_enemy:
				continue
		var available_roles := {}
		for enemy_id in available:
			available_roles[StringName(
				get_enemy(enemy_id).get("role", &"fodder")
			)] = true
		var required_roles: Array = rule.get("required_roles", [])
		for required_role in required_roles:
			if not available_roles.has(StringName(required_role)):
				requirements_met = false
				break
		if not requirements_met:
			continue
		if available_roles.size() < int(rule.get("minimum_distinct_roles", 1)):
			continue
		styles.append(style_name)
	return styles


static func choose_weighted_wave_style(
	styles: Array[StringName],
	rng: RandomNumberGenerator,
	previous_style: StringName = &""
) -> StringName:
	if styles.is_empty():
		return &"standard"
	var candidates := styles.duplicate()
	if candidates.size() > 1:
		candidates.erase(previous_style)
	var total_weight := 0.0
	for style_name in candidates:
		total_weight += float(WAVE_STYLE_RULES[style_name].get("weight", 1.0))
	var roll := rng.randf_range(0.0, total_weight)
	for style_name in candidates:
		roll -= float(WAVE_STYLE_RULES[style_name].get("weight", 1.0))
		if roll <= 0.0:
			return style_name
	return candidates.back()


static func build_round_style_plan(
	rng: RandomNumberGenerator,
	debut_plan: Dictionary
) -> Dictionary:
	var plan := {}
	var previous_style: StringName = &""
	for round_number in range(1, 25):
		if round_number == 1:
			plan[round_number] = &"standard"
			previous_style = &"standard"
			continue
		if round_number == 24:
			plan[round_number] = &"final_escort"
			continue
		var available := get_available_enemy_ids(round_number, debut_plan)
		var styles := get_eligible_wave_styles(round_number, available)
		var selected := choose_weighted_wave_style(
			styles,
			rng,
			previous_style
		)
		if round_number in [12, 13]:
			selected = &"mixed_roster"
		elif round_number in [19, 21, 22, 23]:
			selected = &"layered_assault"
		plan[round_number] = selected
		previous_style = selected
	return plan


static func get_round_profile(round_number: int) -> Dictionary:
	assert(ROUND_PROFILES.has(round_number), "Missing round profile: %d" % round_number)
	return ROUND_PROFILES[round_number].duplicate(true)


static func get_round_duration(round_number: int) -> float:
	return float(get_round_profile(round_number)["duration"])


static func get_round_threat_budget(round_number: int) -> float:
	return float(get_round_profile(round_number)["threat_budget"])


static func get_round_health_multiplier(round_number: int, boss := false) -> float:
	var profile := get_round_profile(round_number)
	return float(profile[
		"boss_health_multiplier" if boss else "standard_health_multiplier"
	])


static func get_enemy_health_multiplier(
	round_number: int,
	enemy_id: StringName
) -> float:
	var enemy := get_enemy(enemy_id)
	if bool(enemy.get("boss", false)):
		return get_round_health_multiplier(round_number, true)
	var progress := clampf(float(round_number - 1) / 23.0, 0.0, 1.0)
	var late_factor := float(ENEMY_LATE_HEALTH_FACTORS.get(enemy_id, 1.0))
	return (
		get_round_health_multiplier(round_number, false)
		* lerpf(1.0, late_factor, progress)
	)


static func get_armor_damage_reduction(
	armor: float,
	damage_type: StringName = &""
) -> float:
	var effective_armor := maxf(armor, 0.0)
	if damage_type == &"explosive":
		effective_armor *= EXPLOSIVE_ARMOR_MULTIPLIER
	if effective_armor <= 0.0:
		return 0.0
	return minf(
		effective_armor / (effective_armor + ARMOR_RATING_CONSTANT),
		MAXIMUM_ARMOR_DAMAGE_REDUCTION
	)


static func get_armor_damage_multiplier(
	armor: float,
	damage_type: StringName = &""
) -> float:
	return 1.0 - get_armor_damage_reduction(armor, damage_type)


static func get_tower(tower_id: StringName) -> Dictionary:
	assert(TOWERS.has(tower_id), "Unknown tower ID: %s" % tower_id)
	var tower: Dictionary = TOWERS[tower_id].duplicate(true)
	tower["texture"] = TOWER_TEXTURES.get(tower_id)
	return tower


static func get_spawned_unit(unit_id: StringName) -> Dictionary:
	assert(SPAWNED_UNITS.has(unit_id), "Unknown spawned unit ID: %s" % unit_id)
	return SPAWNED_UNITS[unit_id].duplicate(true)


static func get_reinforcement_option(option_id: StringName) -> Dictionary:
	assert(
		REINFORCEMENT_OPTIONS.has(option_id),
		"Unknown reinforcement option ID: %s" % option_id
	)
	return REINFORCEMENT_OPTIONS[option_id].duplicate(true)


static func get_tower_paths(tower_id: StringName) -> Dictionary:
	return get_tower(tower_id).get("paths", {}).duplicate(true)


static func get_tower_path(tower_id: StringName, path_id: StringName) -> Dictionary:
	var paths := get_tower_paths(tower_id)
	assert(paths.has(path_id), "Unknown path %s for tower %s" % [path_id, tower_id])
	return paths[path_id].duplicate(true)


static func get_piercing_damage(
	base_damage: int,
	hit_number: int,
	preserve_full_damage := false
) -> int:
	if preserve_full_damage:
		return maxi(base_damage, 1)
	var damage_multiplier := maxf(
		1.0 - PIERCE_DAMAGE_LOSS_PER_ENEMY * float(maxi(hit_number, 0)),
		PIERCE_MINIMUM_DAMAGE_MULTIPLIER
	)
	return maxi(floori(float(base_damage) * damage_multiplier), 1)


static func get_explosion_damage(
	base_damage: int,
	distance_from_center: float,
	explosion_radius: float
) -> int:
	if distance_from_center <= explosion_radius * EXPLOSION_INNER_RADIUS_RATIO:
		return base_damage
	return maxi(
		floori(float(base_damage) * EXPLOSION_OUTER_DAMAGE_MULTIPLIER),
		1
	)


static func get_tower_level(tower_id: StringName, level: int) -> Dictionary:
	var tower := get_tower(tower_id)
	var levels: Array = tower["levels"]
	assert(level >= 0 and level < levels.size(), "Invalid level %d for %s" % [level, tower_id])
	return levels[level].duplicate(true)


static func get_tower_draft_entry(tower_id: StringName) -> Dictionary:
	var tower := get_tower(tower_id)
	var type_names := PackedStringArray()
	for type_tag in tower.get("type_tags", []):
		type_names.append(String(type_tag).capitalize())
	var damage_name := String(tower["damage_tags"][0]).capitalize()
	var delivery_name := String(tower["delivery_type"]).capitalize()
	var impact_name := String(tower["impact_mode"]).replace("_", " ").capitalize()
	var special_names := PackedStringArray()
	for bonus_tag in tower.get("bonus_tags", []):
		special_names.append(String(bonus_tag).capitalize())
	var description := String(tower.get("description", ""))
	if description.is_empty():
		description = "$%d build cost. %s %s attack with %s impact." % [
			int(tower["placement_cost"]),
			damage_name,
			delivery_name,
			impact_name,
		]
	if not special_names.is_empty():
		description += " Specials: %s." % ", ".join(special_names)
	return {
		"id": tower_id,
		"display_name": tower["display_name"],
		"description": description,
		"rarity": &"tower",
		"category": " + ".join(type_names),
		"stackable": false,
	}


static func get_mode(mode_id: StringName) -> Dictionary:
	assert(MODES.has(mode_id), "Unknown mode ID: %s" % mode_id)
	return MODES[mode_id].duplicate(true)


static func get_relic(relic_id: StringName) -> Dictionary:
	assert(RELICS.has(relic_id), "Unknown relic ID: %s" % relic_id)
	var relic: Dictionary = RELICS[relic_id].duplicate(true)
	relic["id"] = relic_id
	return relic

static func get_round_cash_reward(round_number: int) -> int:
	return int(ROUND_CASH_REWARDS.get(round_number, 0))


static func get_elite_enemy_health_multiplier(round_number: int) -> float:
	return (
		EARLY_ELITE_ENEMY_HEALTH_MULTIPLIER
		if round_number <= 6
		else ELITE_ENEMY_HEALTH_MULTIPLIER
	)


static func get_elite_enemy_speed_multiplier(round_number: int) -> float:
	return (
		EARLY_ELITE_ENEMY_SPEED_MULTIPLIER
		if round_number <= 6
		else ELITE_ENEMY_SPEED_MULTIPLIER
	)
