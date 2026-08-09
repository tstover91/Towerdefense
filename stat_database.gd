class_name StatDatabase
extends RefCounted

## Central gameplay reference. IDs are lowercase strings so scenes and save data
## can refer to entries without depending on node names.

const DEFAULT_ENEMY_ID := "normal"
const DEFAULT_TOWER_ID := "invader"
const BUILD_CELL_SIZE := 32.0

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
const THERMITE_BOMBS_DAMAGE_MULTIPLIER := 1.35
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
	"thermite_bombs": {"display_name": "Thermite Bombs", "description": "Explosions deal 35% more damage to armored enemies.", "rarity": &"rare", "category": &"explosive", "stackable": false},
	"maximum_payload": {"display_name": "Maximum Payload", "description": "Explosion damage and radius increase by 50%, but explosive cooldowns take 75% longer.", "rarity": &"rare", "category": &"explosive", "stackable": false, "enabled": false},
	"charred_clothes": {"display_name": "Charred Clothes", "description": "Explosions can hit Hidden enemies and permanently remove Hidden from enemies they hit.", "rarity": &"rare", "category": &"explosive", "stackable": false},
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

# Fixed upgraded sell values preserve the previous normal-price economy without
# allowing temporary build-price effects to alter refunds. Level 0 is handled
# separately using the price actually paid for that tower instance.
const TOWER_UPGRADED_SELL_VALUES := {
	&"invader": [125, 150, 210, 343, 626],
	&"gauss_repeater": [450, 550, 800, 1333, 2400],
	&"beholder": [500, 616, 900, 1500, 2700],
	&"reaver": [150, 183, 263, 436, 786],
	&"brainiac": [325, 398, 571, 955, 1721],
	&"longshot": [350, 433, 633, 1066, 1933],
	&"slinger": [175, 211, 298, 490, 873],
	&"voidcaller": [350, 433, 641, 1108, 2041],
	&"orbitalcannon": [700, 866, 1266, 2133, 3866],
	&"energycore": [300, 370, 536, 903, 1636],
	&"saucer": [525, 650, 950, 1600, 2900],
	&"hivemother": [250, 308, 450, 766, 1400],
	&"dronedepot": [550, 683, 1000, 1700, 3100],
	&"mechbay": [500, 616, 900, 1516, 2750],
}

const TOWER_PATH_SELL_VALUE_ADDITIONS := {
	&"invader": 500,
	&"gauss_repeater": 1500,
	&"beholder": 1666,
	&"reaver": 600,
	&"brainiac": 700,
	&"longshot": 800,
	&"slinger": 666,
	&"voidcaller": 833,
	&"orbitalcannon": 1400,
	&"energycore": 733,
	&"saucer": 1400,
	&"hivemother": 733,
	&"dronedepot": 1600,
	&"mechbay": 1433,
}

const ENEMIES := {
	"normal": {
		"display_name": "Normal",
		"health": 4,
		"health_per_wave": 0.25,
		"move_speed": 100.0,
		"cash_reward": 4,
		"base_damage": 4,
		"defense": 0.0,
		"first_wave": 1,
		"threat_cost": 1,
		"spawn_cost": 1,
		"spawn_weight": 100,
		"spawn_style": &"steady",
		"role": &"fodder",
		"traits": [&"basic"],
		"color": Color(1.0, 1.0, 1.0),
		"visual_scale": 1.0,
	},
	"runner": {
		"display_name": "Runner",
		"health": 3,
		"health_per_wave": 0.75,
		"move_speed": 160.0,
		"cash_reward": 8,
		"base_damage": 3,
		"defense": 0.0,
		"first_wave": 2,
		"threat_cost": 2,
		"spawn_cost": 1,
		"spawn_weight": 65,
		"spawn_style": &"burst",
		"role": &"pressure",
		"traits": [&"fast"],
		"color": Color(1.0, 0.85, 0.2),
		"visual_scale": 0.85,
	},
	"swarmling": {
		"display_name": "Swarmling",
		"health": 1,
		"health_per_wave": 0.25,
		"move_speed": 115.0,
		"cash_reward": 4,
		"base_damage": 1,
		"defense": 0.0,
		"first_wave": 3,
		"threat_cost": 1,
		"spawn_cost": 1,
		"spawn_weight": 55,
		"spawn_style": &"stream",
		"role": &"fodder",
		"traits": [&"small", &"swarm"],
		"color": Color(0.55, 1.0, 0.55),
		"visual_scale": 0.65,
	},
	"bruiser": {
		"display_name": "Bruiser",
		"health": 18,
		"health_per_wave": 2.0,
		"move_speed": 70.0,
		"cash_reward": 23,
		"base_damage": 10,
		"defense": 0.0,
		"first_wave": 4,
		"threat_cost": 6,
		"spawn_cost": 4,
		"spawn_weight": 45,
		"spawn_style": &"spaced",
		"role": &"tank",
		"traits": [&"slow", &"high_health"],
		"color": Color(0.75, 0.45, 0.25),
		"visual_scale": 1.25,
	},
	"splitter": {
		"display_name": "Splitter",
		"health": 14,
		"health_per_wave": 1.5,
		"move_speed": 95.0,
		"cash_reward": 19,
		"base_damage": 8,
		"defense": 0.0,
		"first_wave": 7,
		"threat_cost": 7,
		"spawn_cost": 4,
		"spawn_weight": 35,
		"spawn_style": &"steady",
		"role": &"pressure",
		"traits": [&"splits"],
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
		"cash_reward": 38,
		"base_damage": 12,
		"defense": 0.25,
		"first_wave": 9,
		"threat_cost": 10,
		"spawn_cost": 6,
		"spawn_weight": 30,
		"spawn_style": &"spaced",
		"role": &"tank",
		"traits": [&"armored"],
		"color": Color(0.55, 0.62, 0.7),
		"visual_scale": 1.2,
	},
	"buffer": {
		"display_name": "Buffer",
		"health": 15,
		"health_per_wave": 2.0,
		"move_speed": 85.0,
		"cash_reward": 30,
		"base_damage": 7,
		"defense": 0.0,
		"first_wave": 11,
		"threat_cost": 8,
		"spawn_cost": 5,
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
		"health": 35,
		"health_per_wave": 3.0,
		"move_speed": 80.0,
		"cash_reward": 45,
		"base_damage": 15,
		"defense": 0.0,
		"first_wave": 13,
		"threat_cost": 12,
		"spawn_cost": 7,
		"spawn_weight": 20,
		"spawn_style": &"spaced",
		"role": &"tank",
		"traits": [&"regenerates"],
		"regeneration_per_second": 2,
		"color": Color(0.25, 1.0, 0.35),
		"visual_scale": 1.15,
	},
	"rusher": {
		"display_name": "Rusher",
		"health": 20,
		"health_per_wave": 2.5,
		"move_speed": 90.0,
		"cash_reward": 38,
		"base_damage": 15,
		"defense": 0.0,
		"first_wave": 15,
		"threat_cost": 10,
		"spawn_cost": 6,
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
		"health": 50,
		"health_per_wave": 4.0,
		"move_speed": 60.0,
		"cash_reward": 56,
		"base_damage": 20,
		"defense": 0.0,
		"first_wave": 17,
		"threat_cost": 18,
		"spawn_cost": 10,
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
		"health": 500,
		"health_per_wave": 20.0,
		"move_speed": 40.0,
		"cash_reward": 375,
		"base_damage": 100,
		"defense": 0.0,
		"first_wave": 20,
		"threat_cost": 0,
		"spawn_cost": 0,
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
		"placement_cost": 125,
		"footprint_cells": Vector2i(1, 1),
		"type_tags": [&"biological"],
		"damage_tags": [&"ballistic"],
		"primary_damage_type": &"ballistic",
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_PRIMARY,
		"bonus_tags": [&"critical"],
		"paths": {
			"a": {
				"display_name": "Dual Pistols",
				"description": "Adds a second gun, doubling Invader's attack rate and granting Reveal.",
				"cost": 1500,
				"unlock_level": 4,
				"add_bonus_tags": [&"reveal"],
				"conditional_stat_multipliers": [
					{
						"unless_path": &"b",
						"values": {"firerate": 0.5},
					},
				],
				"behavior_flags": {
					"dual_weapons": true,
				},
			},
			"b": {
				"display_name": "Continuous Beam",
				"description": "Replaces Ballistic fire with a continuous Beam that tracks its primary target and deals tick damage only while physically aligned with it.",
				"cost": 1500,
				"unlock_level": 4,
				"remove_damage_tags": [&"ballistic"],
				"add_damage_tags": [&"beam"],
				"remove_bonus_tags": [&"critical"],
				"primary_damage_type": &"beam",
				"delivery_type": DELIVERY_HITSCAN,
				"impact_mode": IMPACT_PRIMARY,
				"behavior_flags": {
					"continuous_beam": true,
				},
			},
		},
		
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 1,
				"firerate": 0.16,
				"range": 11.0,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 75,
				"damage": 1,
				"firerate": 0.15,
				"range": 11.0,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 180,
				"damage": 2,
				"firerate": 0.14,
				"range": 12.0,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 400,
				"damage": 3,
				"firerate": 0.12,
				"range": 13.0,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 850,
				"damage": 5,
				"firerate": 0.10,
				"range": 14.0,
				"hidden_detection": false,
			},
		],
	},
	"gauss_repeater": {
		"display_name": "Gauss Repeater",
		"placement_cost": 450,
		"footprint_cells": Vector2i(1, 1),
		"type_tags": [&"technology"],
		"damage_tags": [&"electric"],
		"delivery_type": DELIVERY_PROJECTILE,
		"impact_mode": IMPACT_FIRST_CONTACT,
		"bonus_tags": [&"pierce"],
		"pierce_count": 1,
		"paths": {
			"a": {
				"display_name": "Heavy Accelerator",
				"description": "Periodically fires a zero-spread heavy round straight along Gauss's current aim. The heavy round has unlimited Pierce.",
				"cost": 4500,
				"unlock_level": 4,
				"behavior_flags": {
					"gauss_heavy_shot": true,
				},
				"behavior_values": {
					"heavy_shot_interval": 3.0,
					"heavy_shot_damage_multiplier": 15.0,
					"heavy_shot_speed_multiplier": 0.60,
				},
			},
			"b": {
				"display_name": "Threat Tracker",
				"description": "Tracks and fires at the strongest enemy inside the selected 45-degree cone. Changing cone direction resets spread.",
				"cost": 4500,
				"unlock_level": 4,
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
				"damage": 1,
				"projectile_speed": 900.0,
				"firerate": 0.075,
				"range": 14.0,
				"maximum_spread_degrees": 20.0,
				"minimum_spread_degrees": 5.0,
				"spread_tighten_duration": 5.0,
				"spread_recovery_delay": 1.0,
				"spread_recovery_per_second": 10.0,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 300,
				"damage": 1,
				"projectile_speed": 950.0,
				"firerate": 0.065,
				"range": 14.0,
				"maximum_spread_degrees": 20.0,
				"minimum_spread_degrees": 5.0,
				"spread_tighten_duration": 4.25,
				"spread_recovery_delay": 1.0,
				"spread_recovery_per_second": 10.0,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 750,
				"damage": 2,
				"projectile_speed": 1000.0,
				"firerate": 0.055,
				"range": 15.0,
				"maximum_spread_degrees": 20.0,
				"minimum_spread_degrees": 5.0,
				"spread_tighten_duration": 3.5,
				"spread_recovery_delay": 1.0,
				"spread_recovery_per_second": 10.0,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 1600,
				"damage": 2,
				"projectile_speed": 1100.0,
				"firerate": 0.0475,
				"range": 16.0,
				"maximum_spread_degrees": 20.0,
				"minimum_spread_degrees": 5.0,
				"spread_tighten_duration": 2.75,
				"spread_recovery_delay": 1.0,
				"spread_recovery_per_second": 10.0,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 3200,
				"damage": 3,
				"projectile_speed": 1200.0,
				"firerate": 0.040,
				"range": 17.0,
				"maximum_spread_degrees": 20.0,
				"minimum_spread_degrees": 5.0,
				"spread_tighten_duration": 2.0,
				"spread_recovery_delay": 1.0,
				"spread_recovery_per_second": 10.0,
				"hidden_detection": false,
			},
		],
	},
	"beholder": {
		"display_name": "Beholder",
		"placement_cost": 500,
		"footprint_cells": Vector2i(1, 1),
		"type_tags": [&"biological"],
		"damage_tags": [&"beam"],
		"primary_damage_type": &"beam",
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_PRIMARY,
		"bonus_tags": [&"reveal"],
		"paths": {
			"a": {
				"display_name": "Death Burst",
				"description": "An enemy explodes when it dies while Beholder is actively targeting it, regardless of which attack lands the final hit.",
				"cost": 5000,
				"unlock_level": 4,
				"add_damage_tags": [&"explosive"],
				"behavior_flags": {
					"beholder_death_explosion": true,
				},
				"behavior_values": {
					"death_explosion_radius": 3.0,
					"death_explosion_damage_multiplier": 4.0,
				},
			},
			"b": {
				"display_name": "Escalating Beam",
				"description": "Starts at 50% of the previous level's damage and gains 25% every 0.5 seconds of uninterrupted fire, up to 250%.",
				"cost": 5000,
				"unlock_level": 4,
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
				"damage": 2,
				"firerate": 0.18,
				"range": 7.5,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 350,
				"damage": 3,
				"firerate": 0.17,
				"range": 7.75,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 850,
				"damage": 5,
				"firerate": 0.15,
				"range": 8.0,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 1800,
				"damage": 7,
				"firerate": 0.13,
				"range": 8.5,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 3600,
				"damage": 10,
				"firerate": 0.11,
				"range": 9.0,
				"hidden_detection": false,
			},
		],
	},
	"reaver": {
		"display_name": "Reaver",
		"placement_cost": 150,
		"footprint_cells": Vector2i(1, 1),
		"type_tags": [&"biological"],
		"damage_tags": [&"melee"],
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_PRIMARY,
		"bonus_tags": [],
		"paths": {
			"a": {
				"display_name": "Time Bubble",
				"description": "Activates a Psionic slow aura around Reaver for three seconds, followed by a seven-second cooldown.",
				"cost": 1800,
				"unlock_level": 4,
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
				"cost": 1800,
				"unlock_level": 4,
				"add_bonus_tags": [&"critical"],
				"behavior_flags": {
					"reaver_assassinate": true,
				},
			},
		},
		
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 8,
				"firerate": 1.10,
				"range": 5.5,
				"combo_hit_count": 3,
				"combo_stagger": 0.16,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 100,
				"damage": 11,
				"firerate": 1.0,
				"range": 5.75,
				"combo_hit_count": 3,
				"combo_stagger": 0.16,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 240,
				"damage": 16,
				"firerate": 0.90,
				"range": 6.0,
				"combo_hit_count": 3,
				"combo_stagger": 0.16,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 520,
				"damage": 24,
				"firerate": 0.80,
				"range": 6.5,
				"combo_hit_count": 3,
				"combo_stagger": 0.16,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 1050,
				"damage": 36,
				"firerate": 0.68,
				"range": 7.0,
				"combo_hit_count": 3,
				"combo_stagger": 0.16,
				"hidden_detection": false,
			},
		],
	},
	"brainiac": {
		"display_name": "Brainiac",
		"placement_cost": 325,
		"footprint_cells": Vector2i(1, 1),
		"type_tags": [&"biological", &"technology"],
		"damage_tags": [&"ballistic"],
		"delivery_type": DELIVERY_PROJECTILE,
		"impact_mode": IMPACT_FIRST_CONTACT,
		"bonus_tags": [],
		"paths": {
			"a": {
				"display_name": "Convergence Burst",
				"description": "Bolts that reach the convergence point combine into one explosion. Each arriving bolt increases its damage and radius.",
				"cost": 2100,
				"unlock_level": 4,
				"add_damage_tags": [&"explosive"],
				"behavior_flags": {"brainiac_convergence_explosion": true},
				"behavior_values": {
					"convergence_base_radius": 1.5,
					"convergence_radius_per_arrival": 0.65,
					"convergence_damage_per_arrival": 1.0,
				},
			},
			"b": {
				"display_name": "Psionic Link",
				"description": "Every 6 seconds, links Brainiac's current target for 2 seconds. Half of the damage it receives from all towers is spread to enemies around it.",
				"cost": 2100,
				"unlock_level": 4,
				"add_bonus_tags": [&"psionic"],
				"behavior_flags": {"brainiac_psionic_link": true},
				"behavior_values": {
					"brainiac_link_duration": 2.0,
					"brainiac_link_cooldown": 6.0,
					"brainiac_link_radius": 3.5,
					"brainiac_link_damage_share": 0.5,
				},
			},
		},
		
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 2,
				"projectile_speed": 550.0,
				"firerate": 1.40,
				"range": 9.0,
				"projectile_count": 5,
				"volley_width": 5.5,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 220,
				"damage": 3,
				"projectile_speed": 600.0,
				"firerate": 1.30,
				"range": 9.5,
				"projectile_count": 5,
				"volley_width": 5.5,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 520,
				"damage": 4,
				"projectile_speed": 660.0,
				"firerate": 1.20,
				"range": 10.0,
				"projectile_count": 5,
				"volley_width": 5.5,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 1150,
				"damage": 6,
				"projectile_speed": 730.0,
				"firerate": 1.10,
				"range": 10.75,
				"projectile_count": 5,
				"volley_width": 5.5,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 2300,
				"damage": 9,
				"projectile_speed": 820.0,
				"firerate": 0.95,
				"range": 11.5,
				"projectile_count": 5,
				"volley_width": 5.5,
				"hidden_detection": false,
			},
		],
	},
	"longshot": {
		"display_name": "Longshot",
		"placement_cost": 350,
		"footprint_cells": Vector2i(1, 1),
		"type_tags": [&"biological"],
		"damage_tags": [&"ballistic"],
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_PRIMARY,
		"bonus_tags": [&"critical"],
		"paths": {
			"a": {
				"display_name": "Extreme Range",
				"description": "Longshot's direct shots gain damage with distance, reaching double damage at maximum range.",
				"cost": 2400,
				"unlock_level": 4,
				"behavior_flags": {"longshot_distance_damage": true},
				"behavior_values": {
					"distance_minimum_multiplier": 1.0,
					"distance_maximum_multiplier": 2.0,
				},
			},
			"b": {
				"display_name": "Minefield",
				"description": "Periodically places up to three Explosive mines on nearby path cells. Mines clear after each round.",
				"cost": 2400,
				"unlock_level": 4,
				"add_damage_tags": [&"explosive"],
				"behavior_flags": {"longshot_mines": true},
				"behavior_values": {
					"mine_interval": 5.0,
					"mine_maximum_count": 3,
					"mine_placement_radius": 6.0,
					"mine_trigger_radius": 1.0,
					"mine_explosion_radius": 3.0,
					"mine_damage_multiplier": 1.5,
				},
			},
		},
		
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 18,
				"firerate": 2.20,
				"range": 21.0,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 250,
				"damage": 27,
				"firerate": 2.10,
				"range": 22.0,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 600,
				"damage": 40,
				"firerate": 1.95,
				"range": 23.5,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 1300,
				"damage": 60,
				"firerate": 1.80,
				"range": 25.0,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 2600,
				"damage": 90,
				"firerate": 1.65,
				"range": 27.0,
				"hidden_detection": false,
			},
		],
	},
	"slinger": {
		"display_name": "Slinger",
		"placement_cost": 175,
		"footprint_cells": Vector2i(1, 1),
		"type_tags": [&"biological"],
		"damage_tags": [&"melee"],
		"primary_damage_type": &"melee",
		"delivery_type": DELIVERY_PROJECTILE,
		"impact_mode": IMPACT_PRIMARY,
		"bonus_tags": [],
		"paths": {
			"a": {
				"display_name": "Explosive Ricochet",
				"description": "The initial hit and every bounced impact create an Explosive blast.",
				"cost": 2000,
				"unlock_level": 4,
				"add_damage_tags": [&"explosive"],
				"behavior_flags": {
					"slinger_contact_explosions": true,
				},
				"behavior_values": {
					"contact_explosion_radius": 2.5,
				},
			},
			"b": {
				"display_name": "Razor Disc",
				"description": "The disc hits the first enemy in its line, then pierces every enemy behind it until maximum range.",
				"cost": 2000,
				"unlock_level": 4,
				"add_bonus_tags": [&"pierce"],
				"pierce_count_add": 1,
				"impact_mode": IMPACT_FIRST_CONTACT,
				"stat_overrides": {"bounce_count": 0},
				"behavior_flags": {
					"infinite_pierce": true,
				},
			},
		},
		
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 7,
				"projectile_speed": 480.0,
				"firerate": 1.0,
				"range": 12.5,
				"bounce_count": 2,
				"bounce_range": 7.0,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 110,
				"damage": 10,
				"projectile_speed": 520.0,
				"firerate": 0.92,
				"range": 13.0,
				"bounce_count": 2,
				"bounce_range": 7.0,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 260,
				"damage": 14,
				"projectile_speed": 570.0,
				"firerate": 0.84,
				"range": 13.5,
				"bounce_count": 2,
				"bounce_range": 7.0,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 575,
				"damage": 20,
				"projectile_speed": 630.0,
				"firerate": 0.74,
				"range": 14.25,
				"bounce_count": 2,
				"bounce_range": 7.0,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 1150,
				"damage": 29,
				"projectile_speed": 700.0,
				"firerate": 0.62,
				"range": 15.0,
				"bounce_count": 2,
				"bounce_range": 7.0,
				"hidden_detection": false,
			},
		],
	},
	"voidcaller": {
		"display_name": "Void Caller",
		"placement_cost": 350,
		"footprint_cells": Vector2i(1, 1),
		"type_tags": [&"biological"],
		"damage_tags": [&"explosive"],
		"delivery_type": DELIVERY_PROJECTILE,
		"impact_mode": IMPACT_FIRST_CONTACT,
		"bonus_tags": [],
		"paths": {
			"a": {
				"display_name": "Orb Barrage",
				"description": "Replaces the two-orb attack with a staggered five-orb fan.",
				"cost": 2500,
				"unlock_level": 4,
				"stat_overrides": {
					"projectile_count": 5,
					"volley_width": 6.0,
				},
			},
			"b": {
				"display_name": "Singularity",
				"description": "Keeps the normal two-orb attack. When ready, Singularity independently selects an enemy using Void Caller's targeting mode, then pulls for one second before exploding.",
				"cost": 2500,
				"unlock_level": 4,
				"add_bonus_tags": [&"psionic"],
				"behavior_flags": {"void_singularity": true},
				"behavior_values": {
					"singularity_cooldown": 12.0,
					"singularity_pull_duration": 1.0,
					"singularity_pull_radius": 5.0,
					"singularity_pull_speed": 160.0,
					"singularity_explosion_radius": 4.5,
					"singularity_damage_multiplier": 3.0,
				},
			},
		},
		
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 8,
				"projectile_speed": 440.0,
				"firerate": 2.0,
				"range": 8.0,
				"splash_radius": 2.5,
				"projectile_count": 2,
				"volley_width": 2.0,
				"volley_stagger": 0.14,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 250,
				"damage": 11,
				"projectile_speed": 470.0,
				"firerate": 1.90,
				"range": 8.25,
				"splash_radius": 2.75,
				"projectile_count": 2,
				"volley_width": 2.0,
				"volley_stagger": 0.14,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 625,
				"damage": 17,
				"projectile_speed": 510.0,
				"firerate": 1.80,
				"range": 8.75,
				"splash_radius": 3.0,
				"projectile_count": 2,
				"volley_width": 2.0,
				"volley_stagger": 0.14,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 1400,
				"damage": 25,
				"projectile_speed": 560.0,
				"firerate": 1.65,
				"range": 9.25,
				"splash_radius": 3.5,
				"projectile_count": 2,
				"volley_width": 2.0,
				"volley_stagger": 0.14,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 2800,
				"damage": 38,
				"projectile_speed": 620.0,
				"firerate": 1.50,
				"range": 10.0,
				"splash_radius": 4.0,
				"projectile_count": 2,
				"volley_width": 2.0,
				"volley_stagger": 0.14,
				"hidden_detection": false,
			},
		],
	},
	"orbitalcannon": {
		"display_name": "Orbital Cannon",
		"placement_cost": 700,
		"footprint_cells": Vector2i(1, 1),
		"type_tags": [&"technology"],
		"damage_tags": [&"explosive"],
		"delivery_type": DELIVERY_PROJECTILE,
		"impact_mode": IMPACT_PRIMARY,
		"bonus_tags": [&"stun"],
		"minimum_range": 5.0,
		"paths": {
			"a": {
				"display_name": "Solar Lance",
				"description": "Replaces the stunning strike with a two-second, tile-wide persistent beam that has infinite Pierce.",
				"cost": 4200,
				"unlock_level": 4,
				"remove_bonus_tags": [&"stun"],
				"add_bonus_tags": [&"pierce"],
				"stat_overrides": {"stun_duration": 0.0},
				"behavior_flags": {
					"orbital_solar_lance": true,
					"infinite_pierce": true,
				},
				"behavior_values": {
					"solar_lance_duration": 2.0,
					"solar_lance_tick_interval": 0.2,
					"solar_lance_tick_damage_multiplier": 0.25,
					"solar_lance_dual_tick_damage_multiplier": 0.10,
				},
			},
			"b": {
				"display_name": "Bombardment",
				"description": "Replaces each strike with five smaller staggered strikes around the selected location.",
				"cost": 4200,
				"unlock_level": 4,
				"behavior_flags": {"orbital_bombardment": true},
				"behavior_values": {
					"bombardment_strike_count": 5,
					"bombardment_stagger": 0.15,
					"bombardment_spread_radius": 3.0,
					"bombardment_damage_multiplier": 0.45,
					"bombardment_radius_multiplier": 0.70,
				},
			},
		},
		
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 35,
				"projectile_speed": 900.0,
				"firerate": 4.0,
				"range": 24.0,
				"splash_radius": 3.5,
				"stun_duration": 1.25,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 500,
				"damage": 50,
				"projectile_speed": 950.0,
				"firerate": 3.8,
				"range": 25.0,
				"splash_radius": 4.0,
				"stun_duration": 1.40,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 1200,
				"damage": 75,
				"projectile_speed": 1000.0,
				"firerate": 3.5,
				"range": 26.0,
				"splash_radius": 4.5,
				"stun_duration": 1.55,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 2600,
				"damage": 115,
				"projectile_speed": 1100.0,
				"firerate": 3.1,
				"range": 28.0,
				"splash_radius": 5.25,
				"stun_duration": 1.75,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 5200,
				"damage": 175,
				"projectile_speed": 1200.0,
				"firerate": 2.7,
				"range": 30.0,
				"splash_radius": 6.0,
				"stun_duration": 2.0,
				"hidden_detection": false,
			},
		],
	},
	"energycore": {
		"display_name": "Energy Core",
		"placement_cost": 300,
		"footprint_cells": Vector2i(1, 1),
		"type_tags": [&"technology"],
		"damage_tags": [&"electric"],
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_PRIMARY,
		"bonus_tags": [],
		"paths": {
			"a": {
				"display_name": "Shockwave",
				"description": "Every six seconds, releases an electric pulse that damages and stuns all enemies in range.",
				"cost": 2200,
				"unlock_level": 4,
				"add_bonus_tags": [&"stun"],
				"behavior_flags": {"energy_shockwave": true},
				"behavior_values": {
					"shockwave_cooldown": 6.0,
					"shockwave_damage_multiplier": 2.0,
					"shockwave_stun_duration": 0.75,
				},
			},
			"b": {
				"display_name": "Branching Current",
				"description": "Normal attacks chain to two nearby enemies, losing 25% base damage with each jump.",
				"cost": 2200,
				"unlock_level": 4,
				"behavior_flags": {"energy_branching_current": true},
				"behavior_values": {
					"branch_additional_targets": 2,
					"branch_range": 4.0,
					"branch_damage_loss": 0.25,
				},
			},
		},
		
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 3,
				"firerate": 0.38,
				"range": 7.5,
				"slow_duration": 0.50,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 210,
				"damage": 4,
				"firerate": 0.36,
				"range": 7.75,
				"slow_duration": 0.50,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 500,
				"damage": 5,
				"firerate": 0.33,
				"range": 8.25,
				"slow_duration": 0.50,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 1100,
				"damage": 7,
				"firerate": 0.30,
				"range": 8.75,
				"slow_duration": 0.50,
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 2200,
				"damage": 10,
				"firerate": 0.26,
				"range": 9.5,
				"slow_duration": 0.50,
				"hidden_detection": false,
			},
		],
	},
	"saucer": {
		"display_name": "Saucer",
		"placement_cost": 525,
		"footprint_cells": Vector2i(1, 1),
		"type_tags": [&"technology"],
		"damage_tags": [&"electric"],
		"primary_damage_type": &"electric",
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_PRIMARY,
		"bonus_tags": [&"reveal"],
		"paths": {
			"a": {
				"display_name": "Homing Rockets",
				"description": "Adds Explosive. Launches two powerful homing rockets every three seconds while continuing to fire the Electric gun.",
				"cost": 4200,
				"unlock_level": 4,
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
				"cost": 4200,
				"unlock_level": 4,
				"add_bonus_tags": [&"spawner"],
				"behavior_flags": {"saucer_monster_drop": true},
			},
		},
		"levels": [
			{
				"upgrade_cost": 0,
				"damage": 6,
				"projectile_speed": 650.0,
				"firerate": 0.65,
				"range": 20.0,
				"splash_radius": 2.25,
				"flyer_move_speed": 165.0,
				"flyer_attack_radius": 5.0,
				"abduction_cooldown": 16.0,
				"abduction_radius": 1.5,
				"abduction_health_threshold": 0.35,
				"monster_stats": {"damage": 16, "attack_interval": 1.0, "aim_radius": 1.25, "acquisition_radius": 8.0, "move_speed": 90.0, "lifetime": 10.0},
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 375,
				"damage": 9,
				"projectile_speed": 700.0,
				"firerate": 0.60,
				"range": 21.0,
				"splash_radius": 2.5,
				"flyer_move_speed": 175.0,
				"flyer_attack_radius": 5.25,
				"abduction_cooldown": 15.0,
				"abduction_radius": 1.5,
				"abduction_health_threshold": 0.35,
				"monster_stats": {"damage": 23, "attack_interval": 0.95, "aim_radius": 1.25, "acquisition_radius": 8.0, "move_speed": 90.0, "lifetime": 10.0},
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 900,
				"damage": 14,
				"projectile_speed": 760.0,
				"firerate": 0.55,
				"range": 22.0,
				"splash_radius": 2.75,
				"flyer_move_speed": 185.0,
				"flyer_attack_radius": 5.5,
				"abduction_cooldown": 14.0,
				"abduction_radius": 1.5,
				"abduction_health_threshold": 0.35,
				"monster_stats": {"damage": 34, "attack_interval": 0.9, "aim_radius": 1.25, "acquisition_radius": 8.0, "move_speed": 90.0, "lifetime": 10.0},
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 1950,
				"damage": 21,
				"projectile_speed": 830.0,
				"firerate": 0.50,
				"range": 23.0,
				"splash_radius": 3.1,
				"flyer_move_speed": 195.0,
				"flyer_attack_radius": 5.75,
				"abduction_cooldown": 13.0,
				"abduction_radius": 1.5,
				"abduction_health_threshold": 0.35,
				"monster_stats": {"damage": 50, "attack_interval": 0.85, "aim_radius": 1.25, "acquisition_radius": 8.0, "move_speed": 90.0, "lifetime": 10.0},
				"hidden_detection": false,
			},
			{
				"upgrade_cost": 3900,
				"damage": 31,
				"projectile_speed": 920.0,
				"firerate": 0.45,
				"range": 24.0,
				"splash_radius": 3.5,
				"flyer_move_speed": 210.0,
				"flyer_attack_radius": 6.0,
				"abduction_cooldown": 12.0,
				"abduction_radius": 1.5,
				"abduction_health_threshold": 0.35,
				"monster_stats": {"damage": 74, "attack_interval": 0.8, "aim_radius": 1.25, "acquisition_radius": 8.0, "move_speed": 90.0, "lifetime": 10.0},
				"hidden_detection": false,
			},
		],
	},
	"hivemother": {
		"display_name": "Hive Mother",
		"placement_cost": 250,
		"footprint_cells": Vector2i(1, 1),
		"type_tags": [&"biological"],
		"damage_tags": [&"ballistic"],
		"delivery_type": DELIVERY_PROJECTILE,
		"impact_mode": IMPACT_FIRST_CONTACT,
		"bonus_tags": [&"pierce", &"spawner"],
		"pierce_count": 1,
		"spawned_unit_id": &"spore_turret",
		"paths": {
			"a": {
				"display_name": "Triple Bloom",
				"description": "Each Spore Turret fires three projectiles simultaneously.",
				"cost": 2200,
				"unlock_level": 4,
				"unit_stat_overrides": {
					"projectile_count": 3,
					"volley_width": 1.5,
				},
			},
			"b": {
				"display_name": "Mycelial Network",
				"description": "Spore Turrets can attack enemies locally targeted by a turret belonging to another Hive Mother, even beyond their own range.",
				"cost": 2200,
				"unlock_level": 4,
				"unit_stat_overrides": {
					"shared_spore_targeting": true,
				},
			},
		},
		"levels": [
			{
				"upgrade_cost": 0,
				"spawn_interval": 7.0,
				"spawn_limit": 2,
				"deployment_radius": 6.0,
				"unit_stats": {"damage": 4, "attack_interval": 0.90, "aim_radius": 8.0, "move_speed": 0.0, "projectile_speed": 480.0, "lifetime": 25.0},
			},
			{
				"upgrade_cost": 175,
				"spawn_interval": 6.5,
				"spawn_limit": 2,
				"deployment_radius": 6.5,
				"unit_stats": {"damage": 6, "attack_interval": 0.82, "aim_radius": 8.5, "move_speed": 0.0, "projectile_speed": 520.0, "lifetime": 25.0},
			},
			{
				"upgrade_cost": 425,
				"spawn_interval": 6.0,
				"spawn_limit": 3,
				"deployment_radius": 7.0,
				"unit_stats": {"damage": 8, "attack_interval": 0.74, "aim_radius": 9.0, "move_speed": 0.0, "projectile_speed": 560.0, "lifetime": 25.0},
			},
			{
				"upgrade_cost": 950,
				"spawn_interval": 5.25,
				"spawn_limit": 4,
				"deployment_radius": 7.5,
				"unit_stats": {"damage": 11, "attack_interval": 0.65, "aim_radius": 10.0, "move_speed": 0.0, "projectile_speed": 610.0, "lifetime": 25.0},
			},
			{
				"upgrade_cost": 1900,
				"spawn_interval": 4.5,
				"spawn_limit": 5,
				"deployment_radius": 8.0,
				"unit_stats": {"damage": 15, "attack_interval": 0.55, "aim_radius": 11.0, "move_speed": 0.0, "projectile_speed": 680.0, "lifetime": 25.0},
			},
		],
	},
	"dronedepot": {
		"display_name": "Drone Depot",
		"placement_cost": 550,
		"footprint_cells": Vector2i(1, 1),
		"type_tags": [&"technology"],
		"damage_tags": [&"ballistic"],
		"delivery_type": DELIVERY_HITSCAN,
		"impact_mode": IMPACT_PRIMARY,
		"bonus_tags": [&"reveal", &"spawner"],
		"spawned_unit_id": &"drone",
		"paths": {
			"a": {
				"display_name": "Laser Drones",
				"description": "Replaces each drone's Ballistic weapon with a continuous Beam that must remain physically aligned with its primary target to deal tick damage.",
				"cost": 4800,
				"unlock_level": 4,
				"remove_damage_tags": [&"ballistic"],
				"add_damage_tags": [&"beam"],
				"primary_damage_type": &"beam",
				"unit_stat_overrides": {
					"damage_tags": [&"beam"],
					"continuous_beam": true,
				},
			},
			"b": {
				"display_name": "Final Payload",
				"description": "Adds Explosive. When a drone exhausts its damage budget, it self-destructs and the depot must replace it.",
				"cost": 4800,
				"unlock_level": 4,
				"add_damage_tags": [&"explosive"],
				"unit_stat_overrides": {
					"additional_damage_tags": [&"explosive"],
					"explode_on_damage_budget": true,
					"budget_explosion_radius": 2.75,
					"budget_explosion_damage_multiplier": 5.0,
				},
			},
		},
		"levels": [
			{
				"upgrade_cost": 0,
				"spawn_interval": 10.0,
				"spawn_limit": 1,
				"deployment_radius": 11.0,
				"unit_stats": {"damage": 3, "attack_interval": 0.35, "aim_radius": 5.0, "move_speed": 120.0, "leash_radius": 14.0, "damage_budget": 45, "recharge_duration": 3.0},
			},
			{
				"upgrade_cost": 400,
				"spawn_interval": 9.0,
				"spawn_limit": 1,
				"deployment_radius": 12.0,
				"unit_stats": {"damage": 4, "attack_interval": 0.32, "aim_radius": 5.5, "move_speed": 135.0, "leash_radius": 15.0, "damage_budget": 65, "recharge_duration": 2.8},
			},
			{
				"upgrade_cost": 950,
				"spawn_interval": 8.0,
				"spawn_limit": 2,
				"deployment_radius": 13.0,
				"unit_stats": {"damage": 6, "attack_interval": 0.29, "aim_radius": 6.0, "move_speed": 150.0, "leash_radius": 16.0, "damage_budget": 90, "recharge_duration": 2.6},
			},
			{
				"upgrade_cost": 2100,
				"spawn_interval": 7.0,
				"spawn_limit": 2,
				"deployment_radius": 14.0,
				"unit_stats": {"damage": 8, "attack_interval": 0.25, "aim_radius": 6.5, "move_speed": 170.0, "leash_radius": 17.0, "damage_budget": 130, "recharge_duration": 2.3},
			},
			{
				"upgrade_cost": 4200,
				"spawn_interval": 6.0,
				"spawn_limit": 3,
				"deployment_radius": 15.0,
				"unit_stats": {"damage": 11, "attack_interval": 0.22, "aim_radius": 7.0, "move_speed": 190.0, "leash_radius": 18.0, "damage_budget": 180, "recharge_duration": 2.0},
			},
		],
	},
	"mechbay": {
		"display_name": "Mech Bay",
		"placement_cost": 500,
		"footprint_cells": Vector2i(1, 1),
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
				"cost": 4300,
				"unlock_level": 4,
				"add_bonus_tags": [&"stun"],
				"unit_stat_multipliers": {
					"damage": 1.75,
					"attack_interval": 1.40,
					"move_speed": 0.60,
				},
				"unit_stat_overrides": {
					"additional_bonus_tags": [&"stun"],
					"mech_area_slam": true,
					"mech_slam_radius": 3.0,
					"stun_duration": 0.60,
					"visual_scale": 1.35,
				},
			},
			"b": {
				"display_name": "Hunter",
				"description": "Deploys faster mechs that pursue targets in either direction, prioritizing bosses and elites with increased critical chance.",
				"cost": 4300,
				"unlock_level": 4,
				"add_bonus_tags": [&"critical"],
				"unit_stat_multipliers": {
					"attack_interval": 0.75,
					"move_speed": 1.60,
				},
				"unit_stat_overrides": {
					"additional_bonus_tags": [&"critical"],
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
				"unit_stats": {"damage": 10, "attack_interval": 1.10, "aim_radius": 2.5, "move_speed": 45.0},
			},
			{
				"upgrade_cost": 350,
				"spawn_interval": 12.5,
				"spawn_limit": 1,
				"deployment_radius": 3.0,
				"unit_stats": {"damage": 14, "attack_interval": 1.0, "aim_radius": 2.75, "move_speed": 52.0},
			},
			{
				"upgrade_cost": 850,
				"spawn_interval": 11.0,
				"spawn_limit": 2,
				"deployment_radius": 3.0,
				"unit_stats": {"damage": 20, "attack_interval": 0.90, "aim_radius": 3.0, "move_speed": 60.0},
			},
			{
				"upgrade_cost": 1850,
				"spawn_interval": 9.5,
				"spawn_limit": 2,
				"deployment_radius": 3.0,
				"unit_stats": {"damage": 28, "attack_interval": 0.78, "aim_radius": 3.5, "move_speed": 68.0},
			},
			{
				"upgrade_cost": 3700,
				"spawn_interval": 8.0,
				"spawn_limit": 3,
				"deployment_radius": 3.0,
				"unit_stats": {"damage": 40, "attack_interval": 0.65, "aim_radius": 4.0, "move_speed": 78.0},
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
		"wave_duration_start": 20.0,
		"wave_duration_growth": 5.0,
		"wave_duration_max": 60.0,
		"final_wave_duration": 90.0,
		"starting_spawn_threat": 1.0,
		"threat_rate_base": 1.0,
		"threat_rate_growth": 0.12,
		"threat_rate_curve": 0.009,
		"threat_continuous_ratio": 0.7,
		"threat_chunk_ratio": 0.3,
		"threat_chunk_interval": 4.0,
		"active_enemy_cap": 120,
		"enemy_health_multiplier_base": 1.15,
		"enemy_health_multiplier_growth": 0.02,
	},
}


static func get_enemy(enemy_id: StringName) -> Dictionary:
	assert(ENEMIES.has(enemy_id), "Unknown enemy ID: %s" % enemy_id)
	return ENEMIES[enemy_id].duplicate(true)


static func get_tower(tower_id: StringName) -> Dictionary:
	assert(TOWERS.has(tower_id), "Unknown tower ID: %s" % tower_id)
	return TOWERS[tower_id].duplicate(true)


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
