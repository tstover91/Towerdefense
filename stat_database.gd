class_name StatDatabase
extends RefCounted

## Central gameplay reference. IDs are lowercase strings so scenes and save data
## can refer to entries without depending on node names.

const DEFAULT_ENEMY_ID := "normal"
const DEFAULT_TOWER_ID := "invader"
const BUILD_CELL_SIZE := 32.0

# Shared wave-director recipe data. Keeping this here lets gameplay and the
# balance optimizer consume the same role and formation weights.
# Enemy introductions are shuffled inside fair progression bands for each run.
# Each slot is used exactly once, so runs vary without stacking several new
# mechanics onto the same round or allowing counters before they are affordable.
const FIXED_ENEMY_DEBUT_ROUNDS := {
	&"normal": 1,
	&"brute": 20,
}
const ENEMY_DEBUT_GROUPS := [
	{"enemies": [&"runner", &"swarmling"], "rounds": [2, 3]},
	{"enemies": [&"bruiser", &"armored"], "rounds": [4, 5]},
	{
		"enemies": [&"hidden", &"splitter", &"buffer"],
		"rounds": [7, 8, 9],
	},
	{
		"enemies": [&"rusher", &"regenerator", &"summoner"],
		"rounds": [10, 11, 13],
	},
]

# Set pieces are eligible only when their required roster is already revealed.
# Their lower weights keep them memorable without making every group scripted.
const WAVE_STYLE_RULES := {
	&"standard": {"minimum_round": 1, "weight": 1.5},
	&"burst": {"minimum_round": 2, "required_any": [&"runner", &"rusher"], "weight": 1.0},
	&"stream": {"minimum_round": 3, "required_any": [&"swarmling", &"normal"], "weight": 1.0},
	&"pulses": {"minimum_round": 3, "weight": 1.0},
	&"spaced": {"minimum_round": 4, "required_any": [&"bruiser", &"armored", &"regenerator"], "weight": 1.0},
	&"swarm_batch": {"minimum_round": 4, "required_any": [&"swarmling", &"normal"], "weight": 0.9},
	&"convoy": {"minimum_round": 4, "required_any": [&"bruiser", &"armored", &"regenerator"], "weight": 0.9},
	&"elite_escort": {"minimum_round": 4, "required_any": [&"bruiser", &"armored", &"regenerator"], "weight": 0.45},
	&"hidden_probe": {"minimum_round": 7, "required_all": [&"hidden"], "weight": 0.75},
	&"splitter_pack": {"minimum_round": 7, "required_all": [&"splitter"], "weight": 0.75},
	&"support_column": {"minimum_round": 7, "required_any": [&"buffer", &"regenerator", &"summoner"], "weight": 0.75},
	&"rush_screen": {"minimum_round": 10, "required_all": [&"rusher"], "weight": 0.75},
	&"summoner_escort": {"minimum_round": 10, "required_all": [&"summoner"], "weight": 0.65},
	&"layered_assault": {"minimum_round": 14, "weight": 0.9},
	&"boss_rehearsal": {"minimum_round": 18, "maximum_round": 19, "required_any": [&"regenerator", &"summoner"], "weight": 0.8},
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
			&"fodder": 60.0, &"pressure": 25.0,
			&"tank": 15.0, &"support": 0.0,
		},
	},
	{
		"maximum_wave": 13,
		"weights": {
			&"fodder": 50.0, &"pressure": 20.0,
			&"tank": 20.0, &"support": 10.0,
		},
	},
	{
		"maximum_wave": 999,
		"weights": {
			&"fodder": 45.0, &"pressure": 25.0,
			&"tank": 20.0, &"support": 10.0,
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
	&"rush_screen": {&"fodder": 25.0, &"pressure": 55.0, &"tank": 20.0, &"support": 0.0},
	&"summoner_escort": {&"fodder": 35.0, &"pressure": 15.0, &"tank": 25.0, &"support": 25.0},
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

# Enemy bounties remain composition-dependent; this global multiplier is the
# single tuning point for their average contribution to the run economy.
const KILL_REWARD_MULTIPLIER := 0.80

const ROUND_CASH_REWARDS := {
	1: 500,
	2: 600,
	3: 750,
	4: 900,
	5: 1050,
	6: 1300,
	7: 1400,
	8: 1550,
	9: 1700,
	10: 1900,
	11: 2200,
	12: 2300,
	13: 2500,
	14: 2700,
	15: 3000,
	16: 3400,
	17: 5000,
	18: 4000,
	19: 4500,
	20: 0,
}

# Explicit round scaling profiles. These initially reproduce the previous
# formulas exactly; future round balance should modify this table instead of
# stacking new global curves in gameplay code.
#
# threat_budget is the nominal amount generated during timed spawning and is
# used to derive the director's per-second rate. Chunk timing can leave a small
# reserve unspent. The mode's starting_spawn_threat is a separate reserve.
const ROUND_PROFILES := {
	1: {"duration": 20.0, "threat_budget": 23.7090, "standard_health_multiplier": 2.2770, "boss_health_multiplier": 1.2650},
	2: {"duration": 25.0, "threat_budget": 35.7280, "standard_health_multiplier": 2.3265, "boss_health_multiplier": 1.2925},
	3: {"duration": 30.0, "threat_budget": 51.4437, "standard_health_multiplier": 2.3760, "boss_health_multiplier": 1.3200},
	4: {"duration": 35.0, "threat_budget": 71.6184, "standard_health_multiplier": 2.4255, "boss_health_multiplier": 1.3475},
	5: {"duration": 40.0, "threat_budget": 97.0900, "standard_health_multiplier": 2.4750, "boss_health_multiplier": 1.3750},
	6: {"duration": 45.0, "threat_budget": 128.7720, "standard_health_multiplier": 2.5245, "boss_health_multiplier": 1.4025},
	7: {"duration": 50.0, "threat_budget": 159.6700, "standard_health_multiplier": 2.5740, "boss_health_multiplier": 1.4300},
	8: {"duration": 55.0, "threat_budget": 195.2720, "standard_health_multiplier": 2.6235, "boss_health_multiplier": 1.4575},
	9: {"duration": 60.0, "threat_budget": 235.9560, "standard_health_multiplier": 2.6730, "boss_health_multiplier": 1.4850},
	10: {"duration": 60.0, "threat_budget": 260.4000, "standard_health_multiplier": 2.7225, "boss_health_multiplier": 1.5125},
	11: {"duration": 60.0, "threat_budget": 286.3560, "standard_health_multiplier": 2.7720, "boss_health_multiplier": 1.5400},
	12: {"duration": 60.0, "threat_budget": 313.8240, "standard_health_multiplier": 2.8215, "boss_health_multiplier": 1.5675},
	13: {"duration": 60.0, "threat_budget": 342.8040, "standard_health_multiplier": 2.8710, "boss_health_multiplier": 1.5950},
	14: {"duration": 60.0, "threat_budget": 373.2960, "standard_health_multiplier": 2.9205, "boss_health_multiplier": 1.6225},
	15: {"duration": 60.0, "threat_budget": 405.3000, "standard_health_multiplier": 2.9700, "boss_health_multiplier": 1.6500},
	16: {"duration": 60.0, "threat_budget": 438.8160, "standard_health_multiplier": 3.0195, "boss_health_multiplier": 1.6775},
	17: {"duration": 60.0, "threat_budget": 473.8440, "standard_health_multiplier": 3.0690, "boss_health_multiplier": 1.7050},
	18: {"duration": 60.0, "threat_budget": 510.3840, "standard_health_multiplier": 3.1185, "boss_health_multiplier": 1.7325},
	19: {"duration": 60.0, "threat_budget": 548.4360, "standard_health_multiplier": 3.1680, "boss_health_multiplier": 1.7600},
	20: {"duration": 90.0, "threat_budget": 882.0000, "standard_health_multiplier": 3.2175, "boss_health_multiplier": 1.7875},
}

# Variants remain independent layers because they define special-round enemy
# behavior rather than ordinary round progression.
const STANDARD_ENEMY_SPEED_MULTIPLIER := 0.70
const HORDE_ENEMY_HEALTH_MULTIPLIER := 0.55
const ELITE_ENEMY_HEALTH_MULTIPLIER := 2.25
const ELITE_ENEMY_SPEED_MULTIPLIER := 1.30
const PAYDAY_ENEMY_HEALTH_MULTIPLIER := 0.50

# Provisional relic balance values. These are centralized so later tuning does
# not require changing combat code.
const DIVIDENDS_INTEREST_RATE := 0.05
const DIVIDENDS_INTEREST_CAP := 500
const FOCUSED_LENS_DAMAGE_PER_STACK := 0.20
const FOCUSED_LENS_RANGE_MULTIPLIER := 0.90
const WIDE_LENS_RANGE_PER_STACK := 0.20
const WIDE_LENS_DAMAGE_MULTIPLIER := 0.90
const DEATH_RAY_TURN_SPEED_DEGREES := 90.0
const HEAVY_ROUNDS_DAMAGE_MULTIPLIER := 1.25
const HEAVY_ROUNDS_INTERVAL_MULTIPLIER := 1.15
const LIGHTWEIGHT_AMMO_DAMAGE_MULTIPLIER := 0.85
const LIGHTWEIGHT_AMMO_INTERVAL_MULTIPLIER := 0.80
const SUPPRESSIVE_FIRE_DURATION := 0.75
const HIGH_YIELD_RADIUS_MULTIPLIER := 1.25
const HIGH_YIELD_DAMAGE_MULTIPLIER := 0.85
const CONCENTRATED_CHARGE_RADIUS_MULTIPLIER := 0.80
const CONCENTRATED_CHARGE_DAMAGE_MULTIPLIER := 1.25
const MAXIMUM_PAYLOAD_RADIUS_MULTIPLIER := 1.50
const MAXIMUM_PAYLOAD_DAMAGE_MULTIPLIER := 1.50
const MAXIMUM_PAYLOAD_INTERVAL_MULTIPLIER := 1.75
const LUCKY_SHOT_CHANCE_PER_STACK := 0.15
const GLASS_CANNON_CRITICAL_MULTIPLIER_BONUS := 2.0
const GLASS_CANNON_NONCRITICAL_MULTIPLIER := 0.70
const DEADEYE_CRITICAL_MULTIPLIER_BONUS := 2.0
const BOSS_STUN_DURATION_MULTIPLIER := 0.50
const PREDATORY_INSTINCT_HEALTH_THRESHOLD := 0.25
const PREDATORY_INSTINCT_DAMAGE_PER_STACK := 0.50
const PACK_HUNTER_DAMAGE_PER_STACK := 0.15
const INTERFERENCE_BEAM_DAMAGE_MULTIPLIER := 1.35
const HOLLOW_POINT_DAMAGE_PER_STACK := 0.25
const LONG_BARREL_MAX_DAMAGE_PER_STACK := 0.30
const POINT_BLANK_MAX_DAMAGE_PER_STACK := 0.30
const GIANT_KILLER_SPECIAL_DAMAGE_MULTIPLIER := 1.50
const GIANT_KILLER_NORMAL_DAMAGE_MULTIPLIER := 0.65
const THERMITE_BOMBS_DAMAGE_MULTIPLIER := 1.25
const OPENING_SHOT_CHANCE_PER_STACK := 0.20
const BIG_GAME_CONTROL_ELITE_DURATION_PER_STACK := 1.25
const BIG_GAME_CONTROL_NORMAL_DURATION_PER_STACK := 0.75
const EMERGENCY_BRAKE_DURATION_PER_STACK := 1.35
const LONG_TERM_INVESTMENT_RATE_PER_ROUND := 0.05
const LONG_TERM_INVESTMENT_MAXIMUM_INVESTMENT_BONUS := 0.50
const NETWORK_UPGRADE_SPEED_PER_NEIGHBOR_PER_STACK := 0.08
const FRENZY_SPEED_PER_ENEMY_PER_STACK := 0.04
const FRENZY_MAXIMUM_ENEMY_COUNT := 10
const DUELIST_ONE_ENEMY_DAMAGE_PER_STACK := 0.30
const DUELIST_TWO_ENEMY_DAMAGE_PER_STACK := 0.15
const STRENGTH_IN_NUMBERS_DAMAGE_PER_NEIGHBOR := 0.15
const STRENGTH_IN_NUMBERS_MAXIMUM_NEIGHBORS := 4
const LONE_WOLF_DAMAGE_MULTIPLIER := 1.50
const LONE_WOLF_ATTACK_SPEED_MULTIPLIER := 1.35
const LONE_WOLF_RANGE_MULTIPLIER := 1.25
const CROWD_PLEASER_DAMAGE_PER_ENEMY := 0.08
const CROWD_PLEASER_MAXIMUM_DAMAGE_BONUS := 1.50
const LINGERING_THOUGHTS_DURATION_MULTIPLIER := 1.25
const QUICK_THINKING_DURATION_MULTIPLIER := 0.80
const QUICK_THINKING_COOLDOWN_MULTIPLIER := 0.80
const RELENTLESS_SPEED_PER_STACK := 0.10
const RELENTLESS_MAXIMUM_STACKS := 5
const MICROWAVE_MAX_HEALTH_DAMAGE_RATIO := 0.30
const MICROWAVE_BEAM_DAMAGE_CAP_MULTIPLIER := 5.0
const MICROWAVE_EXPLOSION_RADIUS := BUILD_CELL_SIZE * 1.5

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
		"bonus_tags": [&"reveal"],
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
}

const RELICS := {
	"long_term_investment": {"display_name": "Long-Term Investment", "description": "Towers gain 5% of their base sell value per completed round per stack, tracked retroactively and capped at a 50% bonus.", "rarity": &"common", "category": &"global", "stackable": true},
	"dividends": {"display_name": "Dividends", "description": "Gain 5% interest at the end of each round, up to $500.", "rarity": &"rare", "category": &"global", "stackable": false},
	"holiday_sale": {"display_name": "Holiday Sale", "description": "Each round, one tower's build price is reduced by 35%; all others increase by 15%.", "rarity": &"rare", "category": &"global", "stackable": false},
	"contraband_blueprint": {"display_name": "Contraband Blueprint", "description": "Adds one random tower outside your five-tower roster beneath the normal tower slots. It costs $0 to build and is removed after placement.", "rarity": &"legendary", "category": &"global", "stackable": false},
	"network_upgrade": {"display_name": "Network Upgrade", "description": "Technology towers gain 8% attack speed per stack for each Technology tower directly above, below, left, or right of them.", "rarity": &"common", "category": &"technology", "stackable": true},
	"singularity_core": {"display_name": "Singularity Core", "description": "Choose one already-built Technology tower. That tower can purchase both final paths.", "rarity": &"legendary", "category": &"technology", "stackable": false},
	"pack_hunter": {"display_name": "Pack Hunter", "description": "Biological attacks deal 15% more damage per stack when another Biological tower is targeting that enemy.", "rarity": &"common", "category": &"biological", "stackable": true},
	"predatory_instinct": {"display_name": "Predatory Instinct", "description": "Biological attacks deal 50% more damage per stack to enemies at or below 25% health.", "rarity": &"common", "category": &"biological", "stackable": true},
	"perfect_mutation": {"display_name": "Perfect Mutation", "description": "Choose one already-built Biological tower. That tower can purchase both final paths.", "rarity": &"legendary", "category": &"biological", "stackable": false},
	"focused_lens": {"display_name": "Focused Lens", "description": "Beam damage increases by 20%, but range is reduced by 10%.", "rarity": &"common", "category": &"beam", "stackable": true},
	"wide_lens": {"display_name": "Wide Lens", "description": "Beam range increases by 20%, but damage is reduced by 10%.", "rarity": &"common", "category": &"beam", "stackable": true},
	"interference_beam": {"display_name": "Interference Beam", "description": "Beams deal 35% more damage to slowed or stunned enemies.", "rarity": &"rare", "category": &"beam", "stackable": false},
	"microwave": {"display_name": "Microwave", "description": "An enemy killed by Beam damage explodes for 30% of its maximum health, capped at five times the killing damage.", "rarity": &"rare", "category": &"beam", "stackable": false},
	"death_ray": {"display_name": "Death Ray", "description": "Beams gain infinite Pierce, but turn speed is reduced to 90 degrees per second.", "rarity": &"legendary", "category": &"beam", "stackable": false},
	"hollow_point": {"display_name": "Hollow Point", "description": "Ballistic attacks deal 25% more damage per stack to full-health enemies.", "rarity": &"common", "category": &"ballistic", "stackable": true},
	"heavy_rounds": {"display_name": "Heavy Rounds", "description": "Ballistic damage increases by 25%, but attacks take 15% longer.", "rarity": &"common", "category": &"ballistic", "stackable": true},
	"lightweight_ammo": {"display_name": "Lightweight Ammo", "description": "Ballistic attacks are 20% faster, but deal 15% less damage.", "rarity": &"common", "category": &"ballistic", "stackable": true},
	"long_barrel": {"display_name": "Long Barrel", "description": "Ballistic damage gains up to 30% per stack based on distance from its source.", "rarity": &"common", "category": &"ballistic", "stackable": true},
	"point_blank": {"display_name": "Point Blank", "description": "Ballistic damage gains up to 30% per stack at close range.", "rarity": &"common", "category": &"ballistic", "stackable": true},
	"armor_piercing": {"display_name": "Armor Piercing", "description": "Ballistic attacks gain Pierce 1.", "rarity": &"rare", "category": &"ballistic", "stackable": false},
	"suppressive_fire": {"display_name": "Suppressive Fire", "description": "Ballistic attacks slow enemies for at least 0.75 seconds.", "rarity": &"rare", "category": &"ballistic", "stackable": false},
	"rubber_bullets": {"display_name": "Rubber Bullets", "description": "Ballistic attacks bounce once to another enemy within 3 tiles.", "rarity": &"legendary", "category": &"ballistic", "stackable": false},
	"experimental_munitions": {"display_name": "Experimental Munitions", "description": "All Ballistic weapons can critically hit.", "rarity": &"legendary", "category": &"ballistic", "stackable": false},
	"frenzy": {"display_name": "Frenzy", "description": "Melee attacks become 4% faster per enemy in range per stack, counting up to 10 enemies.", "rarity": &"common", "category": &"melee", "stackable": true},
	"duelist": {"display_name": "Duelist", "description": "Melee damage gains 30% per stack with one enemy in range or 15% per stack with two.", "rarity": &"common", "category": &"melee", "stackable": true},
	"relentless": {"display_name": "Relentless", "description": "Gain 10% Melee attack speed after each attack against the same primary target, up to five stacks. Changing targets resets it.", "rarity": &"rare", "category": &"melee", "stackable": false},
	"giant_killer": {"display_name": "Giant Killer", "description": "Melee attacks deal 50% more damage to elites and bosses, but 35% less to normal enemies.", "rarity": &"rare", "category": &"melee", "stackable": false},
	"strength_in_numbers": {"display_name": "Strength in Numbers", "description": "Gain 15% Melee damage per nearby Melee tower, counting up to four.", "rarity": &"rare", "category": &"melee", "stackable": false},
	"lone_wolf": {"display_name": "Lone Wolf", "description": "Gain 50% damage, 35% attack speed, and 25% range when no other tower is within 2.5 tiles.", "rarity": &"legendary", "category": &"melee", "stackable": false},
	"high_yield": {"display_name": "High Yield", "description": "Explosion radius increases by 25%, but damage is reduced by 15%.", "rarity": &"common", "category": &"explosive", "stackable": true},
	"concentrated_charge": {"display_name": "Concentrated Charge", "description": "Explosion radius is reduced by 20%, but damage increases by 25%.", "rarity": &"common", "category": &"explosive", "stackable": true},
	"crowd_pleaser": {"display_name": "Crowd Pleaser", "description": "Explosions gain 8% damage per enemy caught, up to 150% bonus damage.", "rarity": &"rare", "category": &"explosive", "stackable": false},
	"direct_hit": {"display_name": "Direct Hit", "description": "Explosions gain 60% damage against one target, 30% against two, or 15% against three.", "rarity": &"rare", "category": &"explosive", "stackable": false},
	"thermite_bombs": {"display_name": "Thermite Bombs", "description": "Explosions ignore armor and deal 25% more damage to armored enemies.", "rarity": &"rare", "category": &"explosive", "stackable": false},
	"maximum_payload": {"display_name": "Maximum Payload", "description": "Explosion damage and radius increase by 50%, but explosive cooldowns take 75% longer.", "rarity": &"rare", "category": &"explosive", "stackable": false, "enabled": false},
	"charred_clothes": {"display_name": "Charred Clothes", "description": "Explosions permanently remove Hidden from enemies they hit.", "rarity": &"rare", "category": &"explosive", "stackable": false},
	"conductive": {"display_name": "Conductive", "description": "Armor increases Electric damage instead of reducing it.", "rarity": &"common", "category": &"electric", "stackable": false},
	"lucky_shot": {"display_name": "Lucky Shot", "description": "Critical-hit chance increases by 15 percentage points.", "rarity": &"common", "category": &"critical", "stackable": true},
	"opening_shot": {"display_name": "Opening Shot", "description": "Gain 20 percentage points of critical-hit chance per stack against full-health enemies.", "rarity": &"common", "category": &"critical", "stackable": true},
	"glass_cannon": {"display_name": "Glass Cannon", "description": "Adds +2x critical damage, but non-critical attacks deal 30% less damage.", "rarity": &"rare", "category": &"critical", "stackable": false},
	"pressure_point": {"display_name": "Pressure Point", "description": "Critical hits ignore armor.", "rarity": &"rare", "category": &"critical", "stackable": false},
	"deadeye": {"display_name": "Deadeye", "description": "Adds +2x to the critical-hit multiplier.", "rarity": &"rare", "category": &"critical", "stackable": false},
	"lingering_thoughts": {"display_name": "Lingering Thoughts", "description": "Psionic abilities last 25% longer per stack.", "rarity": &"common", "category": &"psionic", "stackable": true},
	"quick_thinking": {"display_name": "Quick Thinking", "description": "Psionic duration and cooldown are both reduced by 20% per stack.", "rarity": &"common", "category": &"psionic", "stackable": true},
	"spotter": {"display_name": "Spotter", "description": "Hidden enemies inside any Reveal tower's range can be targeted by all towers until they leave every Reveal range.", "rarity": &"common", "category": &"reveal", "stackable": false},
	"perfect_intelligence": {"display_name": "Perfect Intelligence", "description": "A Hidden enemy permanently loses Hidden when it enters any Reveal tower's range.", "rarity": &"rare", "category": &"reveal", "stackable": false},
	"deep_penetration": {"display_name": "Deep Penetration", "description": "Adds +1 Pierce.", "rarity": &"common", "category": &"pierce", "stackable": true},
	"follow_through": {"display_name": "Follow Through", "description": "Piercing attacks lose no power after each hit.", "rarity": &"rare", "category": &"pierce", "stackable": false},
	"big_game_control": {"display_name": "Big Game Control", "description": "Stuns last 25% longer per stack against elites and 25% less per stack against normal enemies.", "rarity": &"common", "category": &"stun", "stackable": true},
	"emergency_brake": {"display_name": "Emergency Brake", "description": "Stuns last 35% longer per stack against enemies with at least 130 base movement speed.", "rarity": &"common", "category": &"stun", "stackable": true},
	"youre_not_special": {"display_name": "You're Not Special", "description": "Bosses can be stunned for 50% of the normal duration.", "rarity": &"legendary", "category": &"stun", "stackable": false},
	"trade_agreement": {"display_name": "Trade Agreement", "description": "Hive Mother, Drone Depot, and Mech Bay gain triple spawn limits, but take 50% longer to spawn units and cost twice as much to build. Saucer is unaffected.", "rarity": &"legendary", "category": &"spawner", "stackable": false},
}

const HOLIDAY_SALE_DISCOUNT_MULTIPLIER := 0.65
const HOLIDAY_SALE_OTHER_COST_MULTIPLIER := 1.15
const RUBBER_BULLETS_BOUNCE_RANGE := 3.0
const TRADE_AGREEMENT_SPAWN_LIMIT_MULTIPLIER := 3
const TRADE_AGREEMENT_SPAWN_INTERVAL_MULTIPLIER := 1.5
const TRADE_AGREEMENT_BUILD_COST_MULTIPLIER := 2.0

const TOWER_TEXTURES := {
	&"invader": preload("res://assets/towers/invader.png"),
	&"gauss_repeater": preload("res://assets/towers/gauss_repeater.png"),
	&"beholder": preload("res://assets/towers/beholder.png"),
	&"reaver": preload("res://assets/towers/reaver.png"),
	&"brainiac": preload("res://assets/towers/brainiac.png"),
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
	&"gauss_repeater": [800, 911, 1444, 2944],
	&"beholder": [2500, 2722, 3389, 4665],
	&"reaver": [175, 216, 450, 933],
	&"brainiac": [400, 475, 650, 1316],
	&"longshot": [1675, 1841, 2450, 4200],
	&"slinger": [225, 325, 515, 965],
	&"voidcaller": [675, 741, 941, 1608],
	&"orbitalcannon": [350, 408, 658, 1408],
	&"energycore": [225, 256, 366, 643],
	&"saucer": [1675, 2033, 2366, 2900],
	&"hivemother": [200, 300, 600, 1466],
	&"dronedepot": [500, 650, 1016, 2016],
	&"mechbay": [900, 1050, 1350, 2400],
}

const TOWER_PATH_SELL_VALUE_ADDITIONS := {
	&"invader": {&"a": 1533, &"b": 1516},
	&"gauss_repeater": {&"a": 5944, &"b": 5944,},
	&"beholder": {&"a": 7632, &"b": 7699},
	&"reaver": {&"a": 1599, &"b": 1633},
	&"brainiac": {&"a": 3333, &"b": 3366},
	&"longshot": {&"a": 7200, &"b": 7033},
	&"slinger": {&"a": 2215, &"b": 2215},
	&"voidcaller": {&"a": 3274, &"b": 3108},
	&"orbitalcannon": {&"a": 3074, &"b": 3241},
	&"energycore": {&"a": 1476, &"b": 1643},
	&"saucer": {&"a": 4066, &"b": 3966},
	&"hivemother": {&"a": 3132, &"b": 3132},
	&"dronedepot": {&"a": 3682, &"b": 3849},
	&"mechbay": {&"a": 3733, &"b": 3733},
}

const ENEMIES := {
	"normal": {
		"display_name": "Normal",
		"health": 40,
		"health_per_wave": 2.5,
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
		"traits": [&"basic"],
		"color": Color(1.0, 1.0, 1.0),
		"visual_scale": 1.0,
	},
	"runner": {
		"display_name": "Runner",
		"health": 30,
		"health_per_wave": 7.5,
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
		"traits": [&"fast"],
		"color": Color(1.0, 0.85, 0.2),
		"visual_scale": 0.85,
	},
	"swarmling": {
		"display_name": "Swarmling",
		"health": 10,
		"health_per_wave": 2.5,
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
		"traits": [&"small", &"swarm"],
		"color": Color(0.55, 1.0, 0.55),
		"visual_scale": 0.65,
	},
	"bruiser": {
		"display_name": "Bruiser",
		"health": 180,
		"health_per_wave": 20.0,
		"move_speed": 70.0,
		"cash_reward": 23,
		"base_damage": 10,
		"armor": 0,
		"earliest_debut_round": 4,
		"formation_strength": 6,
		"director_cost": 4,
		"spawn_weight": 45,
		"spawn_style": &"spaced",
		"role": &"tank",
		"traits": [&"slow", &"high_health"],
		"color": Color(0.75, 0.45, 0.25),
		"visual_scale": 1.25,
	},
	"splitter": {
		"display_name": "Splitter",
		"health": 140,
		"health_per_wave": 15.0,
		"move_speed": 95.0,
		"cash_reward": 19,
		"base_damage": 8,
		"armor": 0,
		"earliest_debut_round": 7,
		"formation_strength": 7,
		"director_cost": 4,
		"spawn_weight": 35,
		"spawn_style": &"steady",
		"role": &"pressure",
		"traits": [&"splits"],
		"split_enemy_id": &"swarmling",
		"split_count": 2,
		"color": Color(0.65, 0.25, 0.9),
		"visual_scale": 1.1,
	},
	"hidden": {
		"display_name": "Hidden",
		"health": 90,
		"health_per_wave": 10.0,
		"move_speed": 110.0,
		"cash_reward": 15,
		"base_damage": 6,
		"armor": 0,
		"earliest_debut_round": 7,
		"formation_strength": 5,
		"director_cost": 3,
		"spawn_weight": 24,
		"spawn_style": &"burst",
		"role": &"pressure",
		"traits": [&"hidden"],
		"color": Color(0.42, 0.32, 0.62),
		"visual_scale": 0.9,
	},
	"armored": {
		"display_name": "Armored",
		"health": 300,
		"health_per_wave": 30.0,
		"move_speed": 75.0,
		"cash_reward": 38,
		"base_damage": 12,
		"armor": 20,
		"earliest_debut_round": 4,
		"formation_strength": 10,
		"director_cost": 6,
		"spawn_weight": 30,
		"spawn_style": &"spaced",
		"role": &"tank",
		"traits": [&"armored"],
		"color": Color(0.55, 0.62, 0.7),
		"visual_scale": 1.2,
	},
	"buffer": {
		"display_name": "Buffer",
		"health": 150,
		"health_per_wave": 20.0,
		"move_speed": 85.0,
		"cash_reward": 30,
		"base_damage": 7,
		"armor": 0,
		"earliest_debut_round": 7,
		"formation_strength": 8,
		"director_cost": 5,
		"spawn_weight": 24,
		"spawn_style": &"steady",
		"role": &"support",
		"traits": [&"speed_aura"],
		"speed_aura_radius": 100.0,
		"speed_aura_multiplier": 1.2,
		"color": Color(0.2, 0.9, 1.0),
		"visual_scale": 1.0,
	},
	"regenerator": {
		"display_name": "Regenerator",
		"health": 350,
		"health_per_wave": 30.0,
		"move_speed": 80.0,
		"cash_reward": 45,
		"base_damage": 15,
		"armor": 0,
		"earliest_debut_round": 10,
		"formation_strength": 12,
		"director_cost": 7,
		"spawn_weight": 20,
		"spawn_style": &"spaced",
		"role": &"tank",
		"traits": [&"regenerates"],
		"regeneration_per_second": 20,
		"color": Color(0.25, 1.0, 0.35),
		"visual_scale": 1.15,
	},
	"rusher": {
		"display_name": "Rusher",
		"health": 200,
		"health_per_wave": 25.0,
		"move_speed": 90.0,
		"cash_reward": 38,
		"base_damage": 15,
		"armor": 0,
		"earliest_debut_round": 10,
		"formation_strength": 10,
		"director_cost": 6,
		"spawn_weight": 22,
		"spawn_style": &"burst",
		"role": &"pressure",
		"traits": [&"fast", &"rushes"],
		"rush_start_ratio": 0.7,
		"rush_speed_multiplier": 2.0,
		"color": Color(1.0, 0.25, 0.2),
		"visual_scale": 1.0,
	},
	"summoner": {
		"display_name": "Summoner",
		"health": 500,
		"health_per_wave": 40.0,
		"move_speed": 60.0,
		"cash_reward": 56,
		"base_damage": 20,
		"armor": 0,
		"earliest_debut_round": 10,
		"formation_strength": 18,
		"director_cost": 10,
		"spawn_weight": 15,
		"spawn_style": &"spaced",
		"role": &"support",
		"traits": [&"summons"],
		"summon_enemy_id": &"swarmling",
		"summon_interval": 4.0,
		"summon_limit": 3,
		"color": Color(0.8, 0.2, 1.0),
		"visual_scale": 1.3,
	},
	"brute": {
		"display_name": "Brute",
		"health": 5000,
		"health_per_wave": 200.0,
		"move_speed": 40.0,
		"cash_reward": 375,
		"base_damage": 100,
		"armor": 0,
		"earliest_debut_round": 20,
		"formation_strength": 0,
		"director_cost": 0,
		"spawn_weight": 0,
		"spawn_style": &"boss",
		"role": &"boss",
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

			"behavior_flags": {
				"dual_weapons": true,
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
	"gauss_repeater": {
		"display_name": "Gauss Repeater",
		"placement_cost": 800,
		"footprint_cells": Vector2i(2, 2),
		"type_tags": [&"technology"],
		"damage_tags": [&"electric"],
		"delivery_type": DELIVERY_PROJECTILE,
		"impact_mode": IMPACT_FIRST_CONTACT,
		"bonus_tags": [],
		"pierce_count": 0,
		"paths": {
			"a": {
				"display_name": "Heavy Accelerator",
				"description": "Periodically fires a zero-spread heavy round straight along Gauss's current aim. The heavy round has unlimited Pierce.",
				"cost": 9150,
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
				"cost": 9000,
				"unlock_level": 3,
				"stat_multipliers": {
					"firerate": 0.7,
				},

				"stat_additions": {
					"range": 1.0,
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
				"damage": 20,
				"projectile_speed": 900.0,
				"firerate": 0.080,
				"range": 14.0,
				"maximum_spread_degrees": 18.0,
				"minimum_spread_degrees": 4.5,
				"spread_tighten_duration": 5.0,
				"spread_recovery_delay": 1.0,
				"spread_recovery_per_second": 10.0,
			},
			{
				"upgrade_cost": 333,
				"damage": 20,
				"projectile_speed": 950.0,
				"firerate": 0.060,
				"range": 14.0,
				"maximum_spread_degrees": 18.0,
				"minimum_spread_degrees": 4.5,
				"spread_tighten_duration": 4.25,
				"spread_recovery_delay": 1.0,
				"spread_recovery_per_second": 10.0,
			},
			{
				"upgrade_cost": 1600,
				"damage": 40,
				"projectile_speed": 1050.0,
				"firerate": 0.05,
				"range": 15.0,
				"maximum_spread_degrees": 16.0,
				"minimum_spread_degrees": 4.0,
				"spread_tighten_duration": 3.25,
				"spread_recovery_delay": 1.0,
				"spread_recovery_per_second": 10.0,
			},
			{
				"upgrade_cost": 4500,
				"damage": 70,
				"projectile_speed": 1200.0,
				"firerate": 0.05,
				"range": 17.0,
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
		"display_name": "Beholder",
		"placement_cost": 2500,
		"footprint_cells": Vector2i(2, 2),
		"type_tags": [&"biological"],
		"damage_tags": [&"beam"],
		"primary_damage_type": &"beam",
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_PRIMARY,
		"bonus_tags": [],
		"paths": {
			"a": {
				"display_name": "Death Burst",
				"description": "An enemy releases a small Explosive burst when it dies while Beholder is actively targeting it, regardless of which attack lands the final hit.",
				"cost": 8900,
				"unlock_level": 3,
				"add_damage_tags": [&"explosive"],
				"behavior_flags": {
					"beholder_death_explosion": true,
				},
				"behavior_values": {
					"death_explosion_radius": 3.0,
					"death_explosion_damage_multiplier": 1.0,
				},
			},
			"b": {
				"display_name": "Escalating Beam",
				"description": "Starts at 50% of the previous level's damage and gains 25% every 0.5 seconds of uninterrupted fire, up to 250%.",
				"cost": 9100,
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
				"add_bonus_tags": [&"reveal"],
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
				"upgrade_cost": 3833,
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
				"range": 5.5,
				"combo_hit_count": 3,
				"combo_stagger": 0.16,
			},
			{
				"upgrade_cost": 125,
				"damage": 90,
				"firerate": .85,
				"range": 5.75,
				"combo_hit_count": 3,
				"combo_stagger": 0.16,
			},
			{
				"upgrade_cost": 700,
				"damage": 220,
				"firerate": 0.65,
				"range": 6.0,
				"combo_hit_count": 3,
				"combo_stagger": 0.12,
			},
			{
				"upgrade_cost": 1450,
				"damage": 400,
				"firerate": 0.50,
				"range": 7.0,
				"combo_hit_count": 3,
				"combo_stagger": 0.10,
			},
		],
	},
	"brainiac": {
		"display_name": "Brainiac",
		"placement_cost": 400,
		"footprint_cells": Vector2i(2, 2),
		"type_tags": [&"biological", &"technology"],
		"damage_tags": [&"ballistic"],
		"delivery_type": DELIVERY_PROJECTILE,
		"impact_mode": IMPACT_FIRST_CONTACT,
		"bonus_tags": [],
		"paths": {
			"a": {
				"display_name": "Piercing Volley",
				"description": "Each converging bolt pierces through one additional enemy. As standard Pierce attacks, the bolts bypass armor.",
				"cost": 6150,
				"unlock_level": 3,
				"add_bonus_tags": [&"pierce"],
				"pierce_count_add": 1,
				"stat_multipliers": {
					"damage": 1.60,
				},
			},
			"b": {
				"display_name": "Psionic Link",
				"description": "Every 6 seconds, links Brainiac's current target for 2 seconds. Thirty-five percent of the damage it receives from all towers is spread to enemies around it.",
				"cost": 6150,
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
				"display_name": "Extreme Range",
				"description": "Longshot's direct shots deal 75% damage nearby, normal damage at half range, and 225% damage at maximum range.",
				"cost": 9000,
				"unlock_level": 3,
				"behavior_flags": {"longshot_distance_damage": true},
				"behavior_values": {
					"distance_minimum_multiplier": 0.75,
					"distance_midpoint_multiplier": 1.0,
					"distance_maximum_multiplier": 2.25,
				},
			},
			"b": {
				"display_name": "Minefield",
				"description": "Periodically places up to three Explosive mines on nearby path cells. Mines clear after each round.",
				"cost": 8500,
				"unlock_level": 3,
				"add_damage_tags": [&"explosive"],
				"behavior_flags": {"longshot_mines": true},
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
		
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 500,
				"firerate": 2.20,
				"range": 23.0,
			},
			{
				"upgrade_cost": 500,
				"damage": 625,
				"firerate": 2.10,
				"range": 23.0,
			},
			{
				"upgrade_cost": 1825,
				"damage": 1050,
				"firerate": 1.95,
				"range": 23,
			},
			{
				"upgrade_cost": 5250,
				"damage": 2325,
				"firerate": 1.65,
				"range": 23.0,
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
				"description": "Increases impact damage by 30%. The initial hit and every bounced impact create an Explosive blast dealing 75% of the impact's damage.",
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
					"contact_explosion_damage_multiplier": 0.75,
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
				"range": 12.5,
				"bounce_count": 1,
				"bounce_range": 7.0,
			},
			{
				"upgrade_cost": 300,
				"damage": 48,
				"projectile_speed": 520.0,
				"firerate": 0.666667,
				"range": 13.0,
				"bounce_count": 1,
				"bounce_range": 7.0,
			},
			{
				"upgrade_cost": 570,
				"damage": 86,
				"projectile_speed": 570.0,
				"firerate": 0.666667,
				"range": 15.0,
				"bounce_count": 1,
				"bounce_range": 7.0,
			},
			{
				"upgrade_cost": 1350,
				"damage": 168,
				"projectile_speed": 570.0,
				"firerate": 0.666667,
				"range": 15.0,
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
				"damage": 20,
				"firerate": 0.40,
				"range": 7.5,
				"projectile_count": 1,
				"slow_duration": 0.0,
			},
			{
				"upgrade_cost": 95,
				"damage": 28,
				"firerate": 0.40,
				"range": 7.5,
				"projectile_count": 2,
				"slow_duration": 0.0,
			},
			{
				"upgrade_cost": 330,
				"damage": 38,
				"firerate": 0.40,
				"range": 8.25,
				"projectile_count": 2,
				"slow_duration": 0.50,
			},
			{
				"upgrade_cost": 830,
				"damage": 94,
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
		"bonus_tags": [],
		"paths": {
			"a": {
				"display_name": "Homing Rockets",
				"description": "Adds Explosive. Launches two powerful homing rockets every three seconds while continuing to fire the Electric gun.",
				"cost": 3500,
				"unlock_level": 3,
				"add_damage_tags": [&"explosive"],
				"behavior_flags": {"saucer_twin_rockets": true},
				"behavior_values": {
					"saucer_rocket_damage_multiplier": 2.0,
					"saucer_rocket_interval": 3.0,
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
				"damage": 275,
				"projectile_speed": 650.0,
				"firerate": 0.65,
				"range": 20.0,
				"splash_radius": 2.25,
				"flyer_move_speed": 165.0,
				"flyer_attack_radius": 5.0,
				"abduction_cooldown": 16.0,
				"abduction_radius": 1.5,
				"abduction_health_threshold": 0.0,
				"monster_stats": {"damage": 750, "attack_interval": 1.0, "aim_radius": 1.25, "acquisition_radius": 8.0, "move_speed": 90.0, "lifetime": 10.0},
			},
			{
				"upgrade_cost": 1075,
				"damage": 390,
				"projectile_speed": 760.0,
				"firerate": 0.60,
				"range": 21.0,
				"splash_radius": 2.75,
				"flyer_move_speed": 190.0,
				"flyer_attack_radius": 5.5,
				"abduction_cooldown": 16.0,
				"abduction_radius": 1.5,
				"abduction_health_threshold": 0.0,
				"monster_stats": {"damage": 400, "attack_interval": 1.0, "aim_radius": 1.25, "acquisition_radius": 8.0, "move_speed": 90.0, "lifetime": 10.0},
				"add_bonus_tags": [&"reveal"],
			},
			{
				"upgrade_cost": 1000,
				"damage": 600,
				"projectile_speed": 760.0,
				"firerate": 0.60,
				"range": 21.0,
				"splash_radius": 2.75,
				"flyer_move_speed": 190.0,
				"flyer_attack_radius": 5.5,
				"abduction_cooldown": 13.0,
				"abduction_radius": 2.0,
				"abduction_health_threshold": 0.40,
				"monster_stats": {"damage": 400, "attack_interval": 1.0, "aim_radius": 1.25, "acquisition_radius": 8.0, "move_speed": 90.0, "lifetime": 10.0},
			},
			{
				"upgrade_cost": 1600,
				"damage": 675,
				"projectile_speed": 920.0,
				"firerate": 0.45,
				"range": 22.0,
				"splash_radius": 3.0,
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
				"description": "Each Spore Turret fires three projectiles simultaneously, with each projectile dealing 65% damage.",
				"cost": 5000,
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
				"cost": 5000,
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
				"cost": 5000,
				"unlock_level": 3,
				"remove_damage_tags": [&"ballistic"],
				"add_damage_tags": [&"beam"],
				"primary_damage_type": &"beam",
				"unit_stat_multipliers": {
					"damage": 1.25,
					"damage_budget": 1.50,
				},
				"unit_stat_overrides": {
					"damage_tags": [&"beam"],
					"continuous_beam": true,
				},
			},
			"b": {
				"display_name": "Final Payload",
				"description": "Adds Explosive. When a drone exhausts its damage budget, it self-destructs and the depot must replace it.",
				"cost": 5500,
				"unlock_level": 3,
				"add_damage_tags": [&"explosive"],
				"unit_stat_overrides": {
					"additional_damage_tags": [&"explosive"],
					"explode_on_damage_budget": true,
					"budget_explosion_radius": 2.75,
					"budget_explosion_damage_multiplier": 6.0,
				},
			},
		},
		"levels": [
			{
				"upgrade_cost": 0,
				"spawn_interval": 10.0,
				"spawn_limit": 1,
				"deployment_radius": 11.0,
				"unit_stats": {"damage": 100, "attack_interval": 0.35, "aim_radius": 5.0, "move_speed": 120.0, "leash_radius": 14.0, "damage_budget": 600, "recharge_duration": 3.0},
			},
			{
				"upgrade_cost": 450,
				"spawn_interval": 9.0,
				"spawn_limit": 1,
				"deployment_radius": 12.0,
				"unit_stats": {"damage": 145, "attack_interval": 0.32, "aim_radius": 5.5, "move_speed": 135.0, "leash_radius": 15.0, "damage_budget": 900, "recharge_duration": 2.8},
			},
			{
				"upgrade_cost": 1100,
				"spawn_interval": 8.0,
				"spawn_limit": 2,
				"deployment_radius": 13.0,
				"unit_stats": {"damage": 155, "attack_interval": 0.29, "aim_radius": 6.0, "move_speed": 150.0, "leash_radius": 16.0, "damage_budget": 1200, "recharge_duration": 2.6},
			},
			{
				"upgrade_cost": 3000,
				"spawn_interval": 6.0,
				"spawn_limit": 3,
				"deployment_radius": 15.0,
				"unit_stats": {"damage": 340, "attack_interval": 0.22, "aim_radius": 7.0, "move_speed": 190.0, "leash_radius": 18.0, "damage_budget": 2000, "recharge_duration": 2.0},
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
				"description": "Deploys larger, slower mechs whose two-stage area slams damage and stun every enemy around them.",
				"cost": 4000,
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
				"cost": 4000,
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
				"unit_stats": {"damage": 210, "attack_interval": 0.85, "aim_radius": 3.0, "move_speed": 60.0},
			},
			{
				"upgrade_cost": 3150,
				"spawn_interval": 8.0,
				"spawn_limit": 3,
				"deployment_radius": 3.0,
				"unit_stats": {"damage": 300, "attack_interval": 0.7, "aim_radius": 4.0, "move_speed": 78.0},
			},
		],
	},
}

const MODES := {
	"easy": {
		"display_name": "Easy",
		"starting_cash": 750,
		"starting_lives": 100,
		"max_rounds": 20,
		"starting_spawn_threat": 1.0,
		"threat_continuous_ratio": 0.7,
		"threat_chunk_ratio": 0.3,
		"threat_chunk_interval": 4.0,
		"active_enemy_cap": 120,
	},
}


static func get_enemy(enemy_id: StringName) -> Dictionary:
	assert(ENEMIES.has(enemy_id), "Unknown enemy ID: %s" % enemy_id)
	return ENEMIES[enemy_id].duplicate(true)


static func build_enemy_debut_plan(rng: RandomNumberGenerator) -> Dictionary:
	var plan := FIXED_ENEMY_DEBUT_ROUNDS.duplicate(true)
	for group in ENEMY_DEBUT_GROUPS:
		var enemies: Array = group["enemies"].duplicate()
		var rounds: Array = group["rounds"].duplicate()
		shuffle_with_rng(enemies, rng)
		shuffle_with_rng(rounds, rng)
		for index in enemies.size():
			plan[StringName(enemies[index])] = int(rounds[index])
	return plan


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
	for round_number in range(1, 21):
		if round_number == 20:
			plan[round_number] = &"final_escort"
			continue
		var available := get_available_enemy_ids(round_number, debut_plan)
		var styles := get_eligible_wave_styles(round_number, available)
		var selected := choose_weighted_wave_style(
			styles,
			rng,
			previous_style
		)
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


static func get_tower(tower_id: StringName) -> Dictionary:
	assert(TOWERS.has(tower_id), "Unknown tower ID: %s" % tower_id)
	var tower: Dictionary = TOWERS[tower_id].duplicate(true)
	tower["texture"] = TOWER_TEXTURES.get(tower_id)
	return tower


static func get_spawned_unit(unit_id: StringName) -> Dictionary:
	assert(SPAWNED_UNITS.has(unit_id), "Unknown spawned unit ID: %s" % unit_id)
	return SPAWNED_UNITS[unit_id].duplicate(true)


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
	var description := "$%d build cost. %s %s attack with %s impact." % [
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
