extends Node2D

const GameStats = preload("res://stat_database.gd")
const MapData = preload("res://map_database.gd")
const MOB_SCENE = preload("res://mob.tscn")
const HITSCAN_EFFECT_SCENE = preload("res://hitscan_effect.tscn")
const EXPLOSION_ZONE_SCENE = preload("res://explosion_zone.tscn")
const WaveDirectorScript = preload("res://wave_director.gd")
const DraftManagerScript = preload("res://draft_manager.gd")
const BuildControllerScript = preload("res://build_controller.gd")
const RoundControllerScript = preload("res://round_controller.gd")
const ReinforcementControllerScript = preload("res://reinforcement_controller.gd")
const RunStateScript = preload("res://run_state.gd")
const ItemShopManagerScript = preload("res://tower_items/item_shop_manager.gd")
const TowerItemInventoryServiceScript = preload(
	"res://tower_items/tower_item_inventory_service.gd"
)
const ROLE_FODDER := WaveDirectorScript.ROLE_FODDER
const ROLE_PRESSURE := WaveDirectorScript.ROLE_PRESSURE
const ROLE_TANK := WaveDirectorScript.ROLE_TANK
const ROLE_SUPPORT := WaveDirectorScript.ROLE_SUPPORT
const ROUND_STANDARD: StringName = RoundControllerScript.ROUND_STANDARD
const ROUND_HORDE: StringName = RoundControllerScript.ROUND_HORDE
const ROUND_ELITE: StringName = RoundControllerScript.ROUND_ELITE
const ROUND_GAUNTLET: StringName = RoundControllerScript.ROUND_GAUNTLET
const ROUND_PAYDAY: StringName = RoundControllerScript.ROUND_PAYDAY
const VARIANT_NORMAL: StringName = &"normal"
const VARIANT_HORDE: StringName = &"horde"
const VARIANT_ELITE: StringName = &"elite"
const VARIANT_PAYDAY: StringName = &"payday"
const ENEMY_AURA_REFRESH_INTERVAL := 0.15
const MAX_POOLED_HITSCAN_EFFECTS := 128
const MAX_POOLED_EXPLOSION_EFFECTS := 64
const RANDOM_SPAWN_BREAK_CHANCE := WaveDirectorScript.RANDOM_SPAWN_BREAK_CHANCE
const RANDOM_SPAWN_BREAK_MIN_DURATION := WaveDirectorScript.RANDOM_SPAWN_BREAK_MIN_DURATION
const RANDOM_SPAWN_BREAK_MAX_DURATION := WaveDirectorScript.RANDOM_SPAWN_BREAK_MAX_DURATION
const ELITE_EVENT_MIN_INTERVAL := 15.0
const ELITE_EVENT_MAX_INTERVAL := 25.0
const GAUNTLET_ELITE_MIN_INTERVAL := 10.0
const GAUNTLET_ELITE_MAX_INTERVAL := 18.0
const FINAL_ELITE_PACK_START_RATIO := 0.8
const ELITE_EVENT_RESERVED_SLOTS := 12
const GAUNTLET_EVENT_RESERVED_SLOTS := 20
const DRAFT_HEALTH_RECOVERY := 20
const DRAFT_HEALTH_COST_RATIO := 0.30
const DRAFT_HEALTH_PRICE_INCREMENT := 25
const TOWER_DRAFT_ROUNDS: Array[int] = [3, 8, 12]
const RELIC_DRAFT_ROUNDS: Array[int] = []
const REINFORCEMENT_DRAFT_ROUNDS: Array[int] = []
const TOWER_SCENE = preload("res://base_tower.tscn")
const DEFAULT_TOWER_ICON = preload("res://icon.svg")
const TOWER_SLOT_COUNT := 5
const CONTRABAND_SLOT_INDEX := TOWER_SLOT_COUNT
const TRADE_AGREEMENT_TOWER_IDS: Array[StringName] = [
	&"hivemother",
	&"dronedepot",
	&"mechbay",
]
const DRAFT_TOWER: StringName = &"tower"
const DRAFT_RELIC: StringName = &"relic"
const DRAFT_ITEM: StringName = &"item"
const BUILD_CELL_SIZE := GameStats.BUILD_CELL_SIZE
const DOCK_BUILD_TOP_OFFSET := -230.0
const DOCK_COMPACT_INSPECTOR_TOP_OFFSET := -108.0
const DOCK_INFO_INSPECTOR_TOP_OFFSET := -218.0
const DOCK_PATH_INSPECTOR_TOP_OFFSET := -286.0
const DOCK_TARGET_INSPECTOR_TOP_OFFSET := -188.0
const BUILD_BLOCKER_COLLISION_MASK := 4
const AFFORDABLE_TOWER_COLOR := Color(0.35, 1.0, 0.35)
const UNAFFORDABLE_TOWER_COLOR := Color(1.0, 0.3, 0.3)
const UI_INK := Color("20213a")
const UI_CREAM := Color("fff0c2")
const UI_LIME := Color("9be33b")
const UI_CYAN := Color("35d6e8")
const UI_ORANGE := Color("ff8a2b")
const UI_RED := Color("e84c3d")
const UI_PURPLE := Color("b46cff")
const UI_MAGENTA := Color("e94bd6")
const UI_GOLD := Color("ffd447")
const TOWER_FAN_BUTTON_SIZE := 76.0
const TOWER_FAN_BUTTON_GAP := 12.0
const TOWER_FAN_MAX_COLUMNS := 5
const PLACEMENT_DRAG_THRESHOLD := 12.0
const PLACEMENT_DRAG_PREVIEW_OFFSET := Vector2(0.0, -75.0)
const HUD_STRIP_LEFT := 12.0
const HUD_STRIP_RIGHT_MARGIN := 12.0
const HUD_STRIP_ICON_WIDTH := 30.0
const HUD_STRIP_ICON_SEPARATION := 3.0
const RELIC_HUD_SLOT_COUNT := 5
const DRAG_KIND_TOWER: StringName = &"tower"
const DRAG_KIND_REINFORCEMENT: StringName = &"reinforcement"

signal money_changed(new_amount: int)
signal round_started(round_number: int)
signal round_ended(round_number: int)

@onready var spawntimer: Timer = $SpawnTimer
@onready var map_container: Node2D = $MapContainer
@onready var tower_list: ItemList = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/BuildState/TowerSelectionArea/ItemList
@onready var between_round_shop: Control = $MainUI/BetweenRoundShop
@onready var pause_menu: Control = $MainUI/PauseMenu
@onready var sandbox_panel: Control = $MainUI/SandboxPanel
@onready var speed_button: Button = $MainUI/HUDRoot/EdgeControls/ControlMargin/Buttons/SpeedButton
@onready var pause_button: Button = $MainUI/HUDRoot/EdgeControls/ControlMargin/Buttons/PauseButton
@onready var thumb_controls: Control = $MainUI/HUDRoot/ThumbControls
@onready var build_sidebar_state: VBoxContainer = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/BuildState
@onready var tower_selection_area: VBoxContainer = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/BuildState/TowerSelectionArea
@onready var tower_fan: Control = $MainUI/HUDRoot/TowerFan
@onready var build_toggle_button: Button = $MainUI/HUDRoot/BuildToggleButton
@onready var reinforcement_button: Button = $MainUI/HUDRoot/ThumbControls/ReinforcementButton
@onready var reinforcement_cooldown_label: Label = $MainUI/HUDRoot/ThumbControls/ReinforcementButton/CooldownLabel
@onready var tower_inspector: VBoxContainer = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector
@onready var sidebar: Control = $MainUI/HUDRoot/Sidebar
@onready var money_display: Label = $MainUI/HUDRoot/TopLeftPanel/StatusMargin/StatusGrid/moneydisplay
@onready var lives_display: Label = $MainUI/HUDRoot/TopLeftPanel/StatusMargin/StatusGrid/livesdisplay
@onready var round_count_display: Label = $MainUI/HUDRoot/TopLeftPanel/StatusMargin/StatusGrid/roundcount
@onready var round_timer_display: Label = $MainUI/HUDRoot/TopLeftPanel/StatusMargin/StatusGrid/roundtimer
@onready var enemy_strip: PanelContainer = $MainUI/HUDRoot/EnemyStrip
@onready var enemy_toggle_button: Button = $MainUI/HUDRoot/TopLeftPanel/StatusMargin/StatusGrid/EnemyIntelButton
@onready var enemy_icon_list: HFlowContainer = $MainUI/HUDRoot/EnemyStrip/EnemyStripContent/EnemyIconList
@onready var enemy_info_panel: PanelContainer = $MainUI/HUDRoot/EnemyStrip/EnemyStripContent/EnemyInfoPanel
@onready var enemy_info_name: Label = $MainUI/HUDRoot/EnemyStrip/EnemyStripContent/EnemyInfoPanel/EnemyInfoMargin/EnemyInfoLayout/NameLabel
@onready var enemy_info_description: Label = $MainUI/HUDRoot/EnemyStrip/EnemyStripContent/EnemyInfoPanel/EnemyInfoMargin/EnemyInfoLayout/DescriptionLabel
@onready var relic_strip: PanelContainer = $MainUI/HUDRoot/RelicStrip
@onready var relic_icon_list: HBoxContainer = $MainUI/HUDRoot/RelicStrip/RelicIconList
@onready var relic_info_panel: PanelContainer = $MainUI/HUDRoot/RelicInfoPanel
@onready var relic_info_name: Label = $MainUI/HUDRoot/RelicInfoPanel/RelicInfoMargin/RelicInfoLayout/Header/NameLabel
@onready var relic_info_affected: Label = $MainUI/HUDRoot/RelicInfoPanel/RelicInfoMargin/RelicInfoLayout/Header/AffectedLabel
@onready var relic_info_description: Label = $MainUI/HUDRoot/RelicInfoPanel/RelicInfoMargin/RelicInfoLayout/DescriptionLabel
@onready var tower_name_label: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorHeader/InspectorTitle/TowerNameLabel
@onready var tower_level_label: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorHeader/InspectorTitle/TowerLevelLabel
@onready var tower_xp_label: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorHeader/InspectorTitle/TowerXpLabel
@onready var tower_portrait_button: Button = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorHeader/PortraitButton
@onready var tower_aim_button: Button = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorHeader/AimButton
@onready var tower_inspector_details: VBoxContainer = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll
@onready var tower_information_content: HBoxContainer = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/InformationContent
@onready var tower_path_label: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/InformationContent/TowerPathLabel
@onready var tower_tags_label: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/InformationContent/TowerTagsLabel
@onready var tower_relics_label: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/InformationContent/TowerRelicsLabel
@onready var tower_items_section: VBoxContainer = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/InformationContent/ItemsSection
@onready var tower_items_label: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/InformationContent/ItemsSection/ItemsLabel
@onready var tower_item_inventory_panel: Control = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/TowerItemInventoryPanel
@onready var tower_upgrade_section: VBoxContainer = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/InformationContent/UpgradeSection
@onready var tower_upgrade_header: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/InformationContent/UpgradeSection/UpgradeHeaderLabel
@onready var tower_upgrade_description: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/InformationContent/UpgradeSection/UpgradeDescription
@onready var tower_upgrade_button: Button = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorHeader/UpgradeButton
@onready var tower_path_section: VBoxContainer = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/InformationContent/PathSection
@onready var tower_path_a_button: Button = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/InformationContent/PathSection/PathButtons/PathAButton
@onready var tower_path_b_button: Button = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/InformationContent/PathSection/PathButtons/PathBButton
@onready var tower_path_c_button: Button = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/InformationContent/PathSection/PathButtons/PathCButton
@onready var tower_path_description: Label = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/InformationContent/PathSection/PathDescription
@onready var tower_path_confirm_button: Button = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/InformationContent/PathSection/PathConfirmButton
@onready var tower_target_section: VBoxContainer = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/TargetSection
@onready var tower_target_buttons: GridContainer = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/TargetSection/TargetButtons
@onready var tower_target_first: Button = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/TargetSection/TargetButtons/TargetFirst
@onready var tower_target_last: Button = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/TargetSection/TargetButtons/TargetLast
@onready var tower_target_low: Button = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/TargetSection/TargetButtons/TargetLow
@onready var tower_target_high: Button = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/TargetSection/TargetButtons/TargetHigh
@onready var tower_direction_buttons: GridContainer = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/TargetSection/DirectionButtons
@onready var tower_manual_target_button: Button = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorScroll/InspectorContent/TargetSection/ManualTargetButton
@onready var tower_sell_button: Button = $MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/TowerInspector/InspectorHeader/SellButton
var mobs_left_to_spawn := 0
var mobs_alive := 0
var spawn_schedule: Array[Dictionary] = []
var enemy_rng := RandomNumberGenerator.new()
var wave_director = null
var shop_rng := RandomNumberGenerator.new()
var draft_manager = null
var item_shop_manager = null
var tower_item_inventory_service = null
var build_controller = null
var round_controller = null
var reinforcement_controller = null
var run_state = null
var place_mode: bool:
	get:
		ensure_build_controller()
		return build_controller.place_mode
	set(value):
		ensure_build_controller()
		build_controller.place_mode = value
var build_mode: bool:
	get:
		ensure_build_controller()
		return build_controller.build_mode
	set(value):
		ensure_build_controller()
		build_controller.build_mode = value
var tower_to_place: Node2D:
	get:
		ensure_build_controller()
		return build_controller.tower_to_place
	set(value):
		ensure_build_controller()
		build_controller.tower_to_place = value
var manual_targeting_tower: Node2D:
	get:
		ensure_build_controller()
		return build_controller.manual_targeting_tower
	set(value):
		ensure_build_controller()
		build_controller.manual_targeting_tower = value
var pending_tower_type: StringName:
	get:
		ensure_build_controller()
		return build_controller.pending_tower_type
	set(value):
		ensure_build_controller()
		build_controller.pending_tower_type = value
var pending_tower_cost: int:
	get:
		ensure_build_controller()
		return build_controller.pending_tower_cost
	set(value):
		ensure_build_controller()
		build_controller.pending_tower_cost = value
var pending_tower_is_contraband: bool:
	get:
		ensure_build_controller()
		return build_controller.pending_tower_is_contraband
	set(value):
		ensure_build_controller()
		build_controller.pending_tower_is_contraband = value
var round_number: int:
	get:
		ensure_round_controller()
		return round_controller.round_number
	set(value):
		ensure_round_controller()
		round_controller.round_number = value
var current_round_type: StringName:
	get:
		ensure_round_controller()
		return round_controller.current_round_type
	set(value):
		ensure_round_controller()
		round_controller.current_round_type = value
var round_eight_type: StringName:
	get:
		ensure_round_controller()
		return round_controller.round_eight_type
	set(value):
		ensure_round_controller()
		round_controller.round_eight_type = value
var round_sixteen_type: StringName:
	get:
		ensure_round_controller()
		return round_controller.round_sixteen_type
	set(value):
		ensure_round_controller()
		round_controller.round_sixteen_type = value
var round_time_remaining: float:
	get:
		ensure_round_controller()
		return round_controller.round_time_remaining
	set(value):
		ensure_round_controller()
		round_controller.round_time_remaining = value
var round_duration: float:
	get:
		ensure_round_controller()
		return round_controller.round_duration
	set(value):
		ensure_round_controller()
		round_controller.round_duration = value
var round_elapsed: float:
	get:
		ensure_round_controller()
		return round_controller.round_elapsed
	set(value):
		ensure_round_controller()
		round_controller.round_elapsed = value
var round_active: bool:
	get:
		ensure_round_controller()
		return round_controller.round_active
	set(value):
		ensure_round_controller()
		round_controller.round_active = value
var game_ended: bool:
	get:
		ensure_round_controller()
		return round_controller.game_ended
	set(value):
		ensure_round_controller()
		round_controller.game_ended = value
var max_rounds: int:
	get:
		ensure_round_controller()
		return round_controller.max_rounds
	set(value):
		ensure_round_controller()
		round_controller.max_rounds = value
var selected_reinforcement_id: StringName:
	get:
		ensure_reinforcement_controller()
		return reinforcement_controller.selected_reinforcement_id
	set(value):
		ensure_reinforcement_controller()
		reinforcement_controller.selected_reinforcement_id = value
var reinforcement_cooldown_remaining: float:
	get:
		ensure_reinforcement_controller()
		return reinforcement_controller.cooldown_remaining
	set(value):
		ensure_reinforcement_controller()
		reinforcement_controller.cooldown_remaining = value
var reinforcement_targeting: bool:
	get:
		ensure_reinforcement_controller()
		return reinforcement_controller.targeting
	set(value):
		ensure_reinforcement_controller()
		reinforcement_controller.targeting = value
var reinforcement_preview: Node2D:
	get:
		ensure_reinforcement_controller()
		return reinforcement_controller.preview
	set(value):
		ensure_reinforcement_controller()
		reinforcement_controller.preview = value
var money: int:
	get:
		ensure_run_state()
		return run_state.money
	set(value):
		ensure_run_state()
		run_state.money = value
var lives: int:
	get:
		ensure_run_state()
		return run_state.lives
	set(value):
		ensure_run_state()
		run_state.lives = value
var max_lives: int:
	get:
		ensure_run_state()
		return run_state.max_lives
	set(value):
		ensure_run_state()
		run_state.max_lives = value
var sandbox_mode: bool:
	get:
		ensure_run_state()
		return run_state.sandbox_mode
	set(value):
		ensure_run_state()
		run_state.sandbox_mode = value
var tower_roster: Array[StringName]:
	get:
		ensure_run_state()
		return run_state.tower_roster
	set(value):
		ensure_run_state()
		run_state.set_tower_roster(value)
var contraband_tower_id: StringName:
	get:
		ensure_run_state()
		return run_state.contraband_tower_id
	set(value):
		ensure_run_state()
		run_state.contraband_tower_id = value
var holiday_sale_tower_id: StringName:
	get:
		ensure_run_state()
		return run_state.holiday_sale_tower_id
	set(value):
		ensure_run_state()
		run_state.holiday_sale_tower_id = value
var owned_shop_items: Dictionary:
	get:
		ensure_run_state()
		return run_state.owned_shop_items
	set(value):
		ensure_run_state()
		run_state.owned_shop_items = value
var run_bonuses: Dictionary:
	get:
		ensure_run_state()
		return run_state.run_bonuses
	set(value):
		ensure_run_state()
		run_state.run_bonuses = value
var enemy_debut_plan: Dictionary = {}
var round_style_plan: Dictionary = {}
var current_wave_spawn_style: StringName = &"standard"
var next_elite_event_time := INF
var final_elite_pack_spawned := false
var last_gauntlet_spawn_style: StringName = &""
var gauntlet_style_repeat_count := 0
var spawn_threat := 0.0
var threat_per_second := 0.0
var threat_chunk_elapsed := 0.0
var threat_continuous_ratio := 1.0
var threat_chunk_ratio := 0.0
var threat_chunk_interval := 4.0
var active_enemy_cap := 160
var absolute_enemy_cap := 240
var enemy_aura_refresh_remaining := 0.0
var pooled_hitscan_effects: Array[Node2D] = []
var pooled_explosion_effects: Array[Node2D] = []
var spawning_active := false
var director_cooldown := 0.0
var spore_network_last_refresh_msec := -1000000
var spore_network_primary_owner_id := 0
var spore_network_primary_target: Node2D
var spore_network_secondary_owner_id := 0
var spore_network_secondary_target: Node2D
var mode_id: StringName = &"easy"
var shop_open := false
var active_draft_type: StringName = &""
var active_draft_offers: Array[StringName] = []
var active_draft_choice_quantities: Dictionary = {}
var draft_health_purchased := false
var pending_path_relic_tower_selection: StringName = &""
var recent_relic_offers: Array[StringName] = []
var pending_enemy_spawns: Array[Dictionary] = []
var displayed_tower: Node = null
var sidebar_confirmation_tower_id := 0
var sidebar_confirmation_action := -1
var context_dock_tween: Tween
var relic_hud_buttons: Dictionary = {}
var enemy_hud_buttons: Dictionary = {}
var enemy_strip_expanded := false
var tower_fan_buttons: Array[Button] = []
var tower_fan_tween: Tween
var tower_fan_open := false
var tower_info_expanded := false
var tower_target_panel_open := false
var tower_has_targeting_controls := false
var placement_drag_candidate_kind: StringName = &""
var placement_drag_candidate_slot := -1
var placement_drag_pointer_index := -1
var placement_drag_start_screen_position := Vector2.ZERO
var placement_drag_world_position := Vector2.ZERO
var active_placement_drag_kind: StringName = &""
var selected_relic_hud_id: StringName = &""
var selected_enemy_hud_id: StringName = &""
var enemy_hud_round := -1
var playable_map_width := 0.0
var active_map: TowerDefenseMap
var next_spawn_path_index := 0
var game_speed := 1.0

func _ready() -> void:
	Engine.time_scale = 1.0
	game_speed = 1.0
	sandbox_mode = SessionState.sandbox_mode
	load_selected_map()
	update_speed_button()
	enemy_rng.randomize()
	shop_rng.randomize()
	wave_director = WaveDirectorScript.new(enemy_rng, get_active_enemy_count)
	draft_manager = DraftManagerScript.new(shop_rng)
	item_shop_manager = ItemShopManagerScript.new(shop_rng)
	ensure_build_controller()
	round_controller = RoundControllerScript.new(enemy_rng)
	ensure_reinforcement_controller()
	generate_run_director_plan()
	roll_challenge_round_order()
	_align_sidebar_to_build_grid()
	get_viewport().size_changed.connect(_align_sidebar_to_build_grid)
	var mode: Dictionary = GameStats.get_mode(mode_id)
	run_state.initialize(mode, sandbox_mode)
	tower_item_inventory_service = TowerItemInventoryServiceScript.new()
	tower_item_inventory_service.setup(run_state)
	max_rounds = mode["max_rounds"]
	if sandbox_mode:
		max_rounds = 100
		run_state.set_tower_roster(GameStats.get_playable_tower_family_ids())
	else:
		roll_random_starting_towers(2)
	populate_tower_list()
	clear_tower_details()
	update_money()
	update_lives()
	update_round_count()
	refresh_relic_hud()
	refresh_enemy_hud(true)
	enemy_toggle_button.pressed.connect(_on_enemy_strip_toggled)
	spawntimer.timeout.connect(_spawn_mob)
	reinforcement_button.pressed.connect(_on_reinforcement_button_pressed)
	reinforcement_button.gui_input.connect(_on_reinforcement_button_gui_input)
	connect_tower_inspector_signals()
	between_round_shop.draft_confirmed.connect(_on_draft_confirmed)
	between_round_shop.draft_health_requested.connect(_on_draft_health_requested)
	between_round_shop.item_purchase_requested.connect(_on_item_purchase_requested)
	between_round_shop.item_lock_toggled.connect(_on_item_lock_toggled)
	between_round_shop.item_reroll_requested.connect(_on_item_reroll_requested)
	between_round_shop.item_shop_closed.connect(_on_item_shop_closed)
	between_round_shop.setup(self)
	tower_item_inventory_panel.setup(self)
	update_play_pause_button()
	if sandbox_mode:
		pause_button.hide()
		sandbox_panel.configure(self)
	else:
		sandbox_panel.hide()


func load_selected_map() -> void:
	for child in map_container.get_children():
		child.queue_free()
	var selected_map_id: StringName = SessionState.selected_map_id
	active_map = MapData.instantiate_map(selected_map_id)
	assert(active_map != null, "Unable to instantiate map: %s" % selected_map_id)
	map_container.add_child(active_map)


func get_active_map() -> TowerDefenseMap:
	return active_map


func get_primary_enemy_path() -> Path2D:
	return active_map.get_enemy_path() if active_map != null else null


func get_enemy_paths() -> Array[Path2D]:
	return active_map.get_enemy_paths() if active_map != null else []


func get_next_spawn_path() -> Path2D:
	var paths := get_enemy_paths()
	if paths.is_empty():
		return null
	var path := paths[next_spawn_path_index % paths.size()]
	next_spawn_path_index = (next_spawn_path_index + 1) % paths.size()
	return path


func get_path_id_for_requester(requester: Node) -> StringName:
	if active_map == null or not is_instance_valid(requester):
		return &""
	var requester_path_follow = requester.get("path_follow")
	if requester_path_follow is PathFollow2D:
		return active_map.get_path_id(requester_path_follow.get_parent() as Path2D)
	return &""


func clear_all_path_followers() -> void:
	for path in get_enemy_paths():
		for path_follow in path.get_children():
			path_follow.queue_free()


func populate_tower_list() -> void:
	tower_list.clear()
	var visible_slot_count := tower_roster.size() if sandbox_mode else TOWER_SLOT_COUNT
	for slot_index in visible_slot_count:
		if slot_index < tower_roster.size():
			var tower_id: StringName = tower_roster[slot_index]
			var tower_data := GameStats.get_tower(tower_id)
			tower_list.add_item(
				(
					"%s\n$%d" % [
						tower_data["display_name"],
						get_tower_build_cost(tower_id),
					]
					if sandbox_mode
					else "$%d" % get_tower_build_cost(tower_id)
				),
				tower_data.get("texture", DEFAULT_TOWER_ICON)
			)
			tower_list.set_item_tooltip(
				slot_index,
				tower_data["display_name"]
			)
			continue

		tower_list.add_item("Empty Slot", DEFAULT_TOWER_ICON)
		tower_list.set_item_icon_modulate(slot_index, Color.TRANSPARENT)
		tower_list.set_item_disabled(slot_index, true)
		tower_list.set_item_selectable(slot_index, false)
	if not sandbox_mode and not contraband_tower_id.is_empty():
		tower_list.add_item(
			"$0",
			GameStats.get_tower(contraband_tower_id).get(
				"texture",
				DEFAULT_TOWER_ICON
			)
		)
		tower_list.set_item_tooltip(
			CONTRABAND_SLOT_INDEX,
			"Contraband: %s" % GameStats.get_tower(contraband_tower_id)["display_name"]
		)
	populate_tower_fan()


func populate_tower_fan() -> void:
	for child in tower_fan.get_children():
		tower_fan.remove_child(child)
		child.queue_free()
	tower_fan_buttons.clear()

	var slot_indices: Array[int] = []
	var roster_slot_count := tower_roster.size() if sandbox_mode else mini(
		tower_roster.size(), TOWER_SLOT_COUNT
	)
	for slot_index in roster_slot_count:
		slot_indices.append(slot_index)
	if not sandbox_mode and not contraband_tower_id.is_empty():
		slot_indices.append(CONTRABAND_SLOT_INDEX)

	for slot_index in slot_indices:
		var tower_id := get_sidebar_tower_id(slot_index)
		if tower_id.is_empty():
			continue
		var is_contraband := (
			not sandbox_mode and slot_index == CONTRABAND_SLOT_INDEX
		)
		var tower_data := GameStats.get_tower(tower_id)
		var button := create_tower_fan_button(
			slot_index,
			tower_data,
			is_contraband
		)
		tower_fan.add_child(button)
		tower_fan_buttons.append(button)
	layout_tower_fan_buttons()
	update_tower_affordability()


func create_tower_fan_button(
	slot_index: int,
	tower_data: Dictionary,
	is_contraband: bool
) -> Button:
	var tower_id := get_sidebar_tower_id(slot_index)
	var cost := get_tower_build_cost(tower_id, is_contraband)
	var button := Button.new()
	button.name = "Tower_%s" % String(tower_id)
	button.custom_minimum_size = Vector2.ONE * TOWER_FAN_BUTTON_SIZE
	button.size = Vector2.ONE * TOWER_FAN_BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "Drag %s onto the map · $%d" % [
		tower_data["display_name"], cost
	]
	button.set_meta("slot_index", slot_index)
	button.add_theme_stylebox_override(
		"normal", make_tower_fan_button_style(
			Color(0.0706, 0.0784, 0.102, 0.74),
			Color(0.0353, 0.0392, 0.0549, 0.88)
		)
	)
	button.add_theme_stylebox_override(
		"hover", make_tower_fan_button_style(
			Color(0.1373, 0.1333, 0.1216, 0.84),
			Color(0.5059, 0.4314, 0.2941, 0.72)
		)
	)
	button.add_theme_stylebox_override(
		"pressed", make_tower_fan_button_style(
			Color(0.1843, 0.1569, 0.1176, 0.9),
			Color(0.5059, 0.4314, 0.2941, 0.78),
			false
		)
	)
	button.add_theme_stylebox_override(
		"disabled", make_tower_fan_button_style(
			Color(0.0902, 0.0941, 0.1098, 0.56),
			Color(0.0353, 0.0392, 0.0549, 0.62),
			false
		)
	)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var icon := TextureRect.new()
	icon.name = "TowerIcon"
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 13.0
	icon.offset_top = 8.0
	icon.offset_right = -13.0
	icon.offset_bottom = -21.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = tower_data.get("texture", DEFAULT_TOWER_ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	button.add_child(icon)

	var price_label := Label.new()
	price_label.name = "PriceLabel"
	price_label.anchor_left = 0.5
	price_label.anchor_top = 1.0
	price_label.anchor_right = 0.5
	price_label.anchor_bottom = 1.0
	price_label.offset_left = -27.0
	price_label.offset_top = -25.0
	price_label.offset_right = 27.0
	price_label.offset_bottom = -5.0
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_label.text = "$%d" % cost
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.add_theme_color_override(
		"font_color", Color(0.82, 0.78, 0.67, 0.96)
	)
	price_label.add_theme_font_size_override("font_size", 12)
	var price_style := StyleBoxFlat.new()
	price_style.bg_color = Color(0.025, 0.03, 0.045, 0.78)
	price_style.set_corner_radius_all(7)
	price_label.add_theme_stylebox_override("normal", price_style)
	button.add_child(price_label)
	button.pressed.connect(_on_tower_fan_button_pressed.bind(slot_index))
	button.gui_input.connect(_on_tower_fan_button_gui_input.bind(slot_index))
	return button


func make_tower_fan_button_style(
	background: Color,
	border: Color,
	with_shadow := true
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	if with_shadow:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
		style.shadow_size = 3
		style.shadow_offset = Vector2(0.0, 3.0)
	return style


func layout_tower_fan_buttons() -> void:
	if not is_instance_valid(tower_fan) or tower_fan_buttons.is_empty():
		return
	var button_half := Vector2.ONE * TOWER_FAN_BUTTON_SIZE * 0.5
	var build_rect := build_toggle_button.get_global_rect()
	var grid_left := build_rect.position.x - tower_fan.global_position.x
	var grid_bottom := (
		build_rect.position.y
		- tower_fan.global_position.y
		- TOWER_FAN_BUTTON_GAP
	)
	var available_width := maxf(
		get_viewport_rect().size.x - build_rect.position.x - 16.0,
		TOWER_FAN_BUTTON_SIZE
	)
	var maximum_columns_by_width := maxi(
		int(floor(
			(available_width + TOWER_FAN_BUTTON_GAP)
			/ (TOWER_FAN_BUTTON_SIZE + TOWER_FAN_BUTTON_GAP)
		)),
		1
	)
	var column_count := mini(
		mini(TOWER_FAN_MAX_COLUMNS, maximum_columns_by_width),
		tower_fan_buttons.size()
	)
	var cell_step := TOWER_FAN_BUTTON_SIZE + TOWER_FAN_BUTTON_GAP
	for button_index in tower_fan_buttons.size():
		var row_index := button_index / column_count
		var column_index := button_index % column_count
		var target_position := Vector2(
			grid_left + float(column_index) * cell_step,
			grid_bottom - TOWER_FAN_BUTTON_SIZE - float(row_index) * cell_step
		)
		var button := tower_fan_buttons[button_index]
		button.position = target_position
		button.pivot_offset = button_half
		button.set_meta("fan_target_position", target_position)


func _on_tower_fan_button_pressed(slot_index: int) -> void:
	select_tower_build_slot(slot_index)


func _on_tower_fan_button_gui_input(
	event: InputEvent,
	slot_index: int
) -> void:
	if is_pointer_press_event(event):
		begin_placement_drag_candidate(
			DRAG_KIND_TOWER,
			slot_index,
			get_pointer_screen_position(event),
			get_pointer_index(event)
		)


func show_tower_details(tower: Node) -> void:
	if (
		not is_instance_valid(tower)
		or not tower.has_method("get_sidebar_stats")
		or not bool(tower.get("is_placed"))
	):
		clear_tower_details()
		return

	var selection_changed := displayed_tower != tower
	displayed_tower = tower
	if selection_changed:
		tower_info_expanded = false
		tower_target_panel_open = false
	var stats: Dictionary = tower.get_sidebar_stats()
	build_sidebar_state.hide()
	tower_inspector.show()
	tower_selection_area.hide()
	tower_name_label.text = stats["display_name"]
	var xp_level := int(stats.get("xp_level", 1))
	tower_level_label.text = "Level %d of %d" % [
		xp_level,
		GameStats.TOWER_XP_MAX_LEVEL,
	]
	var xp_into_level := float(stats.get("xp_into_level", 0.0))
	var xp_to_next_level := float(stats.get("xp_to_next_level", 0.0))
	if xp_to_next_level <= 0.0:
		tower_xp_label.text = "MAX LEVEL"
	else:
		tower_xp_label.text = "%.1f / %.1f XP" % [
			xp_into_level,
			xp_to_next_level,
		]
	var tower_data := GameStats.get_tower(StringName(tower.get("tower_id")))
	tower_portrait_button.icon = tower_data.get("texture", DEFAULT_TOWER_ICON)
	tower_portrait_button.tooltip_text = "Show %s information" % stats["display_name"]
	var path_status: String = stats.get("path_status", "")
	tower_path_label.visible = not path_status.is_empty()
	tower_path_label.text = path_status
	tower_tags_label.text = "Type: %s\nAttack: %s\nBonus: %s" % [
		format_tower_tags(stats.get("type_tags", [])),
		format_tower_tags(stats.get("attack_tags", [])),
		format_tower_tags(stats.get("bonus_tags", [])),
	]
	var active_relics: Array = stats.get("active_relic_effects", [])
	tower_relics_label.text = "Relics: %s" % format_relic_names(active_relics)
	tower_relics_label.tooltip_text = format_relic_effect_tooltip(active_relics)
	update_tower_item_controls(tower)
	if not round_active:
		tower_item_inventory_panel.refresh(tower)
	update_tower_upgrade_controls(tower, stats)
	update_tower_path_controls(tower)
	if tower_path_section.visible:
		tower_path_label.hide()
	update_tower_target_controls(tower)
	update_tower_sell_control(tower)
	update_tower_inspector_panel_visibility()


func connect_tower_inspector_signals() -> void:
	tower_portrait_button.pressed.connect(_on_tower_portrait_pressed)
	tower_aim_button.pressed.connect(_on_tower_aim_pressed)
	tower_upgrade_button.pressed.connect(_on_sidebar_upgrade_pressed)
	tower_path_a_button.pressed.connect(_on_sidebar_path_slot_pressed.bind(0))
	tower_path_b_button.pressed.connect(_on_sidebar_path_slot_pressed.bind(1))
	tower_path_c_button.pressed.connect(_on_sidebar_path_slot_pressed.bind(2))
	tower_path_confirm_button.pressed.connect(_on_sidebar_path_confirmed)
	tower_target_first.pressed.connect(_on_sidebar_target_pressed.bind(0))
	tower_target_last.pressed.connect(_on_sidebar_target_pressed.bind(1))
	tower_target_low.pressed.connect(_on_sidebar_target_pressed.bind(2))
	tower_target_high.pressed.connect(_on_sidebar_target_pressed.bind(3))
	for direction_index in tower_direction_buttons.get_child_count():
		var direction_button := tower_direction_buttons.get_child(direction_index) as Button
		direction_button.pressed.connect(
			_on_sidebar_direction_pressed.bind(direction_index)
		)
	tower_manual_target_button.pressed.connect(_on_sidebar_manual_target_pressed)
	tower_sell_button.pressed.connect(_on_sidebar_sell_pressed)


func _on_tower_portrait_pressed() -> void:
	tower_info_expanded = not tower_info_expanded
	tower_target_panel_open = false
	update_tower_inspector_panel_visibility()


func _on_tower_aim_pressed() -> void:
	if not tower_has_targeting_controls:
		return
	tower_target_panel_open = not tower_target_panel_open
	tower_info_expanded = false
	update_tower_inspector_panel_visibility()


func update_tower_inspector_panel_visibility() -> void:
	if not is_instance_valid(tower_inspector):
		return
	tower_information_content.visible = tower_info_expanded
	tower_item_inventory_panel.visible = tower_info_expanded and not round_active
	tower_target_section.visible = (
		tower_target_panel_open and tower_has_targeting_controls
	)
	tower_inspector_details.visible = (
		tower_information_content.visible or tower_target_section.visible
	)
	tower_portrait_button.button_pressed = tower_info_expanded
	tower_aim_button.button_pressed = tower_target_section.visible
	update_context_dock_layout()


func update_tower_upgrade_controls(tower: Node, stats: Dictionary) -> void:
	if tower.get("instance_progression") != null:
		tower_upgrade_section.hide()
		tower_upgrade_button.hide()
		return
	var levels: Array = GameStats.get_tower(tower.tower_id)["levels"]
	var next_level := int(stats["level"]) + 1
	var has_level_upgrade := next_level < levels.size()
	tower_upgrade_section.visible = has_level_upgrade
	tower_upgrade_button.visible = has_level_upgrade
	if not has_level_upgrade:
		return
	var upgrade_cost := int(levels[next_level]["upgrade_cost"])
	var awaiting_confirmation := (
		int(tower.get("pending_action")) == BaseTower.MenuAction.UPGRADE
	)
	tower_upgrade_header.text = "CONFIRM UPGRADE" if awaiting_confirmation else "NEXT UPGRADE"
	tower_upgrade_description.text = "Advance to Level %d of %d." % [
		next_level + 1,
		levels.size(),
	]
	tower_upgrade_button.text = (
		"Tap Again · $%d" if awaiting_confirmation else "Upgrade · $%d"
	) % upgrade_cost
	tower_upgrade_button.tooltip_text = (
		"Tap twice to upgrade. Tapping anywhere else cancels confirmation."
	)
	tower_upgrade_button.disabled = money < upgrade_cost


func update_tower_item_controls(tower: Node) -> void:
	tower_items_section.visible = tower.get("instance_progression") != null
	if not tower_items_section.visible or tower.get("item_controller") == null:
		return
	var item_lines: PackedStringArray = []
	var tooltip_lines: PackedStringArray = []
	var item_ids: Array[StringName] = tower.get_equipped_item_ids()
	for slot_index in GameStats.TOWER_ITEM_SLOT_COUNT:
		var item_id := item_ids[slot_index]
		if item_id.is_empty():
			item_lines.append("%d. Empty" % (slot_index + 1))
			continue
		var item := GameStats.get_tower_item(item_id)
		var item_name := String(item.get("display_name", item_id))
		var is_active: bool = tower.item_controller.is_item_active_in_slot(
			slot_index
		)
		item_lines.append(
			"%d. %s%s" % [
				slot_index + 1,
				item_name,
				"" if is_active else " · INACTIVE",
			]
		)
		var tooltip := "%s: %s" % [item_name, item.get("description", "")]
		if not is_active:
			tooltip += "\nInactive: %s" % tower.item_controller.get_incompatibility_reason(
				item_id
			)
		tooltip_lines.append(tooltip)
	tower_items_label.text = "\n".join(item_lines)
	tower_items_label.tooltip_text = "\n\n".join(tooltip_lines)


func update_tower_path_controls(tower: Node) -> void:
	if tower.has_evolution_options():
		update_tower_evolution_controls(tower)
		return
	if tower.get("instance_progression") != null:
		tower_path_section.hide()
		tower_path_label.hide()
		return
	var paths := GameStats.get_tower_paths(tower.tower_id)
	var show_paths: bool = (
		not paths.is_empty()
		and tower.tower_level >= tower.get_path_unlock_level(&"a")
		and (
			tower.has_available_path_purchase()
			or not tower.purchased_paths.is_empty()
		)
	)
	tower_path_section.visible = show_paths
	if not show_paths:
		return
	var path_buttons: Array[Button] = [
		tower_path_a_button,
		tower_path_b_button,
		tower_path_c_button,
	]
	tower_path_c_button.hide()
	var path_ids: Array[StringName] = [&"a", &"b"]
	for index in path_ids.size():
		var path_id := path_ids[index]
		var button := path_buttons[index]
		if not paths.has(path_id):
			button.hide()
			continue
		button.show()
		var path: Dictionary = paths[path_id]
		var path_name: String = String(path.get("display_name", "Path %s" % path_id.to_upper()))
		var path_cost: int = int(path.get("cost", 0))
		button.tooltip_text = String(path.get("description", ""))
		if tower.purchased_paths.has(path_id):
			button.text = "%s · OWNED" % path_name
			button.disabled = true
		elif not tower.purchased_paths.is_empty() and not tower.can_purchase_multiple_paths():
			button.text = "%s · LOCKED" % path_name
			button.disabled = true
		else:
			button.text = "%s · $%d" % [path_name, path_cost]
			button.disabled = not tower.can_purchase_path(path_id)
		button.button_pressed = tower.pending_path_choice == path_id
	tower_path_confirm_button.disabled = tower.pending_path_choice.is_empty()
	if tower.pending_path_choice.is_empty():
		tower_path_confirm_button.text = "Select a Path"
		tower_path_description.text = "Select a path to view its effect."
	else:
		tower_path_confirm_button.text = "Confirm Path"
		tower_path_description.text = String(
			paths[tower.pending_path_choice].get("description", "")
		)


func update_tower_evolution_controls(tower: Node) -> void:
	var evolutions := GameStats.get_tower_evolutions(tower.tower_id)
	var evolution_ids: Array = evolutions.keys()
	var evolution_buttons: Array[Button] = [
		tower_path_a_button,
		tower_path_b_button,
		tower_path_c_button,
	]
	tower_path_section.visible = not evolutions.is_empty()
	if evolutions.is_empty():
		return
	var owned_evolution_id: StringName = tower.instance_progression.evolution_id
	for index in evolution_buttons.size():
		var button := evolution_buttons[index]
		if index >= evolution_ids.size():
			button.hide()
			continue
		button.show()
		var evolution_id := StringName(evolution_ids[index])
		var evolution: Dictionary = evolutions[evolution_id]
		var evolution_name := String(
			evolution.get("display_name", "Evolution %d" % (index + 1))
		)
		var evolution_cost := int(evolution.get("cost", 0))
		var required_level := int(evolution.get(
			"required_level",
			GameStats.TOWER_EVOLUTION_DEFAULT_LEVEL
		))
		button.tooltip_text = String(evolution.get("description", ""))
		if owned_evolution_id == evolution_id:
			button.text = "%s · OWNED" % evolution_name
			button.disabled = true
		elif not owned_evolution_id.is_empty():
			button.text = "%s · LOCKED" % evolution_name
			button.disabled = true
		elif tower.instance_progression.level < required_level:
			button.text = "%s · LV %d" % [evolution_name, required_level]
			button.disabled = true
		else:
			button.text = "%s · $%d" % [evolution_name, evolution_cost]
			button.disabled = not tower.can_purchase_evolution(evolution_id)
		button.button_pressed = tower.pending_evolution_choice == evolution_id
	var has_pending_choice: bool = not StringName(
		tower.pending_evolution_choice
	).is_empty()
	tower_path_confirm_button.disabled = not has_pending_choice
	if not owned_evolution_id.is_empty():
		tower_path_confirm_button.text = "Evolution Complete"
		tower_path_description.text = "This tower's evolution is permanent."
	elif not has_pending_choice:
		tower_path_confirm_button.text = "Select an Evolution"
		var first_evolution: Dictionary = evolutions[evolution_ids[0]]
		var required_level := int(first_evolution.get(
			"required_level",
			GameStats.TOWER_EVOLUTION_DEFAULT_LEVEL
		))
		tower_path_description.text = (
			"Reach Level %d to evolve this tower." % required_level
			if tower.instance_progression.level < required_level
			else "Choose a permanent evolution for this tower."
		)
	else:
		tower_path_confirm_button.text = "Confirm Evolution"
		tower_path_description.text = String(
			evolutions[tower.pending_evolution_choice].get("description", "")
		)


func update_tower_target_controls(tower: Node) -> void:
	var attack_component: Variant = tower.get("attack_component")
	var shows_targeting: bool = (
		attack_component != null
		and attack_component.shows_target_mode_control()
		and (
			not tower.uses_standard_spawner_system()
			or tower.uses_drone_targeting()
		)
	)
	tower_has_targeting_controls = shows_targeting
	tower_aim_button.visible = shows_targeting
	if not shows_targeting:
		tower_target_panel_open = false
		tower_target_section.hide()
		return
	var manual_targeting: bool = tower.uses_manual_ground_targeting()
	var directional_targeting: bool = tower.uses_directional_aim()
	tower_manual_target_button.visible = manual_targeting
	tower_direction_buttons.visible = directional_targeting and not manual_targeting
	tower_target_buttons.visible = not manual_targeting and not directional_targeting
	if directional_targeting:
		for direction_index in tower_direction_buttons.get_child_count():
			var direction_button := tower_direction_buttons.get_child(
				direction_index
			) as Button
			direction_button.toggle_mode = true
			direction_button.button_pressed = tower.aim_direction.is_equal_approx(
				TowerMenuController.AIM_DIRECTIONS[direction_index]
			)
	if manual_targeting or directional_targeting:
		return
	var drone_targeting: bool = tower.uses_drone_targeting()
	tower_target_first.text = "Distributed" if drone_targeting else "First"
	tower_target_last.text = "Focus Max HP" if drone_targeting else "Last"
	tower_target_low.visible = not drone_targeting
	tower_target_high.visible = not drone_targeting
	var current_mode: int = (
		int(tower.get_drone_target_mode())
		if drone_targeting
		else int(tower.get("target_mode"))
	)
	for index in 4:
		var button := [
			tower_target_first,
			tower_target_last,
			tower_target_low,
			tower_target_high,
		][index] as Button
		button.button_pressed = current_mode == index


func update_tower_sell_control(tower: Node) -> void:
	var sell_price := int(tower.get_sell_price())
	var awaiting_confirmation := (
		int(tower.get("pending_action")) == BaseTower.MenuAction.SELL
	)
	tower_sell_button.text = (
		"Tap Again · $%d" if awaiting_confirmation else "Sell · $%d"
	) % sell_price
	tower_sell_button.tooltip_text = (
		"Tap twice to sell. Tapping anywhere else cancels confirmation."
	)


func _on_sidebar_upgrade_pressed() -> void:
	if (
		is_instance_valid(displayed_tower)
		and prepare_sidebar_double_tap(BaseTower.MenuAction.UPGRADE)
	):
		displayed_tower.request_upgrade()


func _on_sidebar_path_slot_pressed(slot_index: int) -> void:
	if not is_instance_valid(displayed_tower):
		return
	if displayed_tower.has_evolution_options():
		var evolution_ids: Array = GameStats.get_tower_evolutions(
			displayed_tower.tower_id
		).keys()
		if slot_index < evolution_ids.size():
			displayed_tower.select_evolution_choice(
				StringName(evolution_ids[slot_index])
			)
		return
	var path_ids: Array[StringName] = [&"a", &"b"]
	if slot_index < path_ids.size():
		displayed_tower.select_path_choice(path_ids[slot_index])


func _on_sidebar_path_confirmed() -> void:
	if is_instance_valid(displayed_tower):
		if displayed_tower.has_evolution_options():
			displayed_tower.purchase_selected_evolution()
		else:
			displayed_tower.purchase_selected_path()


func _on_sidebar_target_pressed(mode: int) -> void:
	if not is_instance_valid(displayed_tower):
		return
	displayed_tower.select_sidebar_target_mode(mode)
	tower_target_panel_open = false
	update_tower_inspector_panel_visibility()


func _on_sidebar_direction_pressed(direction_index: int) -> void:
	if is_instance_valid(displayed_tower):
		displayed_tower.select_aim_direction(direction_index)
		tower_target_panel_open = false
		update_tower_inspector_panel_visibility()


func _on_sidebar_manual_target_pressed() -> void:
	if is_instance_valid(displayed_tower):
		tower_target_panel_open = false
		displayed_tower.begin_manual_targeting()
		update_tower_inspector_panel_visibility()


func _on_sidebar_sell_pressed() -> void:
	if (
		is_instance_valid(displayed_tower)
		and prepare_sidebar_double_tap(BaseTower.MenuAction.SELL)
	):
		displayed_tower.request_sell()


func _on_sidebar_back_pressed() -> void:
	reset_sidebar_confirmation()
	if is_instance_valid(displayed_tower):
		displayed_tower.set_selected(false)
	else:
		clear_tower_details()
	set_build_drawer_open(true)


func prepare_sidebar_double_tap(action: BaseTower.MenuAction) -> bool:
	if not is_instance_valid(displayed_tower):
		return false
	var tower_instance_id := displayed_tower.get_instance_id()
	if (
		sidebar_confirmation_action == int(action)
		and sidebar_confirmation_tower_id == tower_instance_id
		and int(displayed_tower.get("pending_action")) == int(action)
	):
		reset_sidebar_confirmation()
		return true

	if int(displayed_tower.get("pending_action")) != BaseTower.MenuAction.NONE:
		displayed_tower.pending_action = BaseTower.MenuAction.NONE
		displayed_tower.show_current_range_preview()
	if action == BaseTower.MenuAction.UPGRADE:
		displayed_tower.request_upgrade()
	else:
		displayed_tower.request_sell()
	sidebar_confirmation_action = int(action)
	sidebar_confirmation_tower_id = tower_instance_id
	return false


func reset_sidebar_confirmation() -> void:
	sidebar_confirmation_action = -1
	sidebar_confirmation_tower_id = 0


func cancel_sidebar_confirmation() -> void:
	var tower := displayed_tower
	var action := sidebar_confirmation_action
	var tower_id := sidebar_confirmation_tower_id
	reset_sidebar_confirmation()
	if (
		is_instance_valid(tower)
		and tower.get_instance_id() == tower_id
		and int(tower.get("pending_action")) == action
	):
		tower.show_main_menu()


func format_tower_tags(tags: Array) -> String:
	if tags.is_empty():
		return "None"
	var display_tags: Array[String] = []
	for tag in tags:
		var words := String(tag).replace("_", " ").split(" ")
		for index in words.size():
			words[index] = words[index].capitalize()
		display_tags.append(" ".join(words))
	return ", ".join(display_tags)


func format_relic_names(relic_ids: Array) -> String:
	if relic_ids.is_empty():
		return "None"
	var names: Array[String] = []
	for relic_id in relic_ids:
		names.append(String(GameStats.get_relic(StringName(relic_id))["display_name"]))
	return ", ".join(names)


func format_relic_effect_tooltip(relic_ids: Array) -> String:
	if relic_ids.is_empty():
		return "No owned relic currently modifies this tower."
	var lines: Array[String] = []
	for relic_id in relic_ids:
		var relic := GameStats.get_relic(StringName(relic_id))
		lines.append("%s: %s" % [relic["display_name"], relic["description"]])
	return "\n\n".join(lines)


func refresh_enemy_hud(force := false) -> void:
	if not is_instance_valid(enemy_icon_list) or wave_director == null:
		return
	var displayed_round := maxi(round_number, 1)
	if round_controller != null:
		displayed_round = clampi(
			round_controller.get_displayed_round(),
			1,
			maxi(max_rounds, 1)
		)
	if not force and enemy_hud_round == displayed_round:
		return
	enemy_hud_round = displayed_round
	for child in enemy_icon_list.get_children():
		enemy_icon_list.remove_child(child)
		child.queue_free()
	enemy_hud_buttons.clear()

	var enemy_ids: Array[StringName] = (
		wave_director.get_available_enemies(displayed_round)
	)
	enemy_ids.sort_custom(
		func(first: StringName, second: StringName) -> bool:
			return String(GameStats.get_enemy(first)["display_name"]) < String(
				GameStats.get_enemy(second)["display_name"]
			)
	)
	for enemy_id in enemy_ids:
		var enemy := GameStats.get_enemy(enemy_id)
		var button := Button.new()
		button.name = "Enemy_%s" % String(enemy_id)
		button.custom_minimum_size = Vector2(30.0, 28.0)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.text = get_enemy_icon_label(enemy_id)
		button.tooltip_text = String(enemy["display_name"])
		button.set_meta("enemy_id", enemy_id)
		apply_enemy_icon_style(button, Color(enemy.get("color", UI_LIME)))
		button.pressed.connect(_on_enemy_hud_pressed.bind(enemy_id))
		enemy_icon_list.add_child(button)
		enemy_hud_buttons[enemy_id] = button
	if (
		not selected_enemy_hud_id.is_empty()
		and enemy_hud_buttons.has(selected_enemy_hud_id)
	):
		show_enemy_hud_selection(selected_enemy_hud_id)
	else:
		clear_enemy_hud_selection()
	update_compact_hud_strip_layout()


func get_enemy_icon_label(enemy_id: StringName) -> String:
	var display_name := String(GameStats.get_enemy(enemy_id)["display_name"])
	var words := display_name.split(" ", false)
	if words.size() == 1:
		return String(words[0]).left(2).to_upper()
	var abbreviation := ""
	for word in words:
		abbreviation += String(word).left(1).to_upper()
		if abbreviation.length() >= 2:
			break
	return abbreviation


func make_enemy_icon_style(background: Color, pressed := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var muted_background := background.darkened(0.68)
	muted_background.a = 0.9 if pressed else 0.76
	style.bg_color = muted_background
	var muted_border := background.darkened(0.42)
	muted_border.a = 0.72 if pressed else 0.48
	style.border_color = muted_border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	if not pressed:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
		style.shadow_size = 2
		style.shadow_offset = Vector2(0.0, 2.0)
	return style


func apply_enemy_icon_style(button: Button, enemy_color: Color) -> void:
	var foreground := Color(0.8471, 0.8078, 0.702, 1.0)
	button.add_theme_color_override("font_color", foreground)
	button.add_theme_color_override("font_hover_color", foreground)
	button.add_theme_color_override("font_pressed_color", foreground)
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_stylebox_override(
		"normal", make_enemy_icon_style(enemy_color)
	)
	button.add_theme_stylebox_override(
		"hover", make_enemy_icon_style(enemy_color.lightened(0.08))
	)
	button.add_theme_stylebox_override(
		"pressed", make_enemy_icon_style(enemy_color, true)
	)
	button.add_theme_stylebox_override(
		"hover_pressed", make_enemy_icon_style(enemy_color, true)
	)


func get_short_enemy_description(enemy_id: StringName) -> String:
	var enemy := GameStats.get_enemy(enemy_id)
	var trait_descriptions := {
		&"basic": "No special ability.",
		&"fast": "Moves quickly.",
		&"small": "Small and easy to overwhelm individually.",
		&"swarm": "Arrives in large groups.",
		&"slow": "Moves slowly.",
		&"high_health": "Takes a lot of damage to bring down.",
		&"splits": "Splits into smaller enemies when defeated.",
		&"hidden": "Must be revealed before most towers can target it.",
		&"armored": "Armor reduces incoming damage.",
		&"speed_aura": "Speeds up nearby enemies.",
		&"regenerates": "Regains health while moving.",
		&"rushes": "Occasionally surges forward.",
		&"summons": "Summons additional enemies.",
		&"shielded": "Carries a shield that absorbs hits.",
		&"shield_aura": "Shields nearby enemies.",
		&"boss": "A major boss threat.",
	}
	var descriptions: Array[String] = []
	for trait_value in enemy.get("traits", []):
		var trait_id := StringName(trait_value)
		if trait_descriptions.has(trait_id):
			descriptions.append(String(trait_descriptions[trait_id]))
	if descriptions.is_empty():
		return "%s enemy." % String(enemy.get("role", &"standard")).capitalize()
	return " ".join(descriptions)


func _on_enemy_hud_pressed(enemy_id: StringName) -> void:
	if selected_enemy_hud_id == enemy_id:
		clear_enemy_hud_selection()
	else:
		clear_relic_hud_selection()
		show_enemy_hud_selection(enemy_id)


func _on_enemy_strip_toggled() -> void:
	set_enemy_intel_expanded(enemy_toggle_button.button_pressed)


func set_enemy_intel_expanded(is_expanded: bool) -> void:
	enemy_strip_expanded = is_expanded and not enemy_hud_buttons.is_empty()
	enemy_strip.visible = enemy_strip_expanded
	enemy_toggle_button.button_pressed = enemy_strip_expanded
	enemy_toggle_button.tooltip_text = (
		"Close enemy intel" if enemy_strip_expanded else "Open enemy intel"
	)
	if not enemy_strip_expanded:
		clear_enemy_hud_selection()


func show_enemy_hud_selection(enemy_id: StringName) -> void:
	if not enemy_hud_buttons.has(enemy_id):
		clear_enemy_hud_selection()
		return
	selected_enemy_hud_id = enemy_id
	for button_id in enemy_hud_buttons:
		var button := enemy_hud_buttons[button_id] as Button
		button.button_pressed = StringName(button_id) == enemy_id
	var enemy := GameStats.get_enemy(enemy_id)
	enemy_info_name.text = String(enemy["display_name"])
	enemy_info_description.text = get_short_enemy_description(enemy_id)
	enemy_info_panel.show()


func clear_enemy_hud_selection() -> void:
	selected_enemy_hud_id = &""
	for button_value in enemy_hud_buttons.values():
		(button_value as Button).button_pressed = false
	if is_instance_valid(enemy_info_panel):
		enemy_info_panel.hide()


func update_compact_hud_strip_layout() -> void:
	if not is_instance_valid(enemy_strip) or not is_instance_valid(relic_strip):
		return
	var maximum_width := maxf(
		get_viewport_rect().size.x - HUD_STRIP_LEFT - HUD_STRIP_RIGHT_MARGIN,
		44.0
	)
	enemy_toggle_button.button_pressed = enemy_strip_expanded
	var relic_width := clampf(
		10.0 + float(maxi(RELIC_HUD_SLOT_COUNT, relic_hud_buttons.size())) * (
			HUD_STRIP_ICON_WIDTH + HUD_STRIP_ICON_SEPARATION
		),
		44.0,
		maximum_width
	)
	relic_strip.offset_right = HUD_STRIP_LEFT + relic_width
	var info_left := HUD_STRIP_LEFT
	var info_right := minf(
		get_viewport_rect().size.x - 12.0,
		HUD_STRIP_LEFT + 480.0
	)
	if info_right - info_left < 300.0:
		info_left = 12.0
	relic_info_panel.offset_left = info_left
	relic_info_panel.offset_right = info_right
	enemy_strip.visible = enemy_strip_expanded and not enemy_hud_buttons.is_empty()
	enemy_toggle_button.visible = not enemy_hud_buttons.is_empty()
	relic_strip.show()


func refresh_relic_hud() -> void:
	if not is_instance_valid(relic_icon_list):
		return
	for child in relic_icon_list.get_children():
		relic_icon_list.remove_child(child)
		child.queue_free()
	relic_hud_buttons.clear()
	var owned_relic_ids: Array[StringName] = []
	for relic_key in GameStats.RELICS:
		var relic_id := StringName(relic_key)
		if get_relic_count(relic_id) > 0:
			owned_relic_ids.append(relic_id)
	var filled_slot_count := 0
	for relic_id in owned_relic_ids:
		if filled_slot_count >= RELIC_HUD_SLOT_COUNT:
			break
		var relic := GameStats.get_relic(relic_id)
		var count := get_relic_count(relic_id)
		for stack_index in count:
			if filled_slot_count >= RELIC_HUD_SLOT_COUNT:
				break
			var button := Button.new()
			button.name = "Relic_%s_%d" % [String(relic_id), stack_index]
			button.custom_minimum_size = Vector2(30.0, 28.0)
			button.toggle_mode = stack_index == 0
			button.focus_mode = Control.FOCUS_NONE
			button.clip_text = true
			button.text = get_relic_icon_label(relic_id)
			button.tooltip_text = String(relic["display_name"])
			if count > 1:
				button.tooltip_text += " · Copy %d/%d" % [stack_index + 1, count]
			button.set_meta("relic_id", relic_id)
			apply_relic_icon_style(button, StringName(relic["rarity"]))
			button.pressed.connect(_on_relic_hud_pressed.bind(relic_id))
			relic_icon_list.add_child(button)
			if stack_index == 0:
				relic_hud_buttons[relic_id] = button
			filled_slot_count += 1
	for _slot_index in range(filled_slot_count, RELIC_HUD_SLOT_COUNT):
		relic_icon_list.add_child(create_empty_relic_hud_slot())
	if not selected_relic_hud_id.is_empty():
		if get_relic_count(selected_relic_hud_id) > 0:
			show_relic_hud_selection(selected_relic_hud_id)
		else:
			clear_relic_hud_selection()
	update_compact_hud_strip_layout()


func create_empty_relic_hud_slot() -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(30.0, 28.0)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0706, 0.0784, 0.102, 0.38)
	style.border_color = Color(0.2784, 0.2706, 0.251, 0.38)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	slot.add_theme_stylebox_override("panel", style)
	var marker := Label.new()
	marker.text = "·"
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_theme_color_override(
		"font_color", Color(0.6588, 0.6549, 0.6196, 0.5)
	)
	slot.add_child(marker)
	return slot


func get_relic_icon_label(relic_id: StringName) -> String:
	match relic_id:
		&"charred_clothes":
			return "CH"
		&"perfect_intelligence":
			return "INT"
	var words := String(relic_id).split("_", false)
	if words.size() == 1:
		return String(words[0]).left(2).to_upper()
	var abbreviation := ""
	for word in words:
		if not word.is_empty():
			abbreviation += word.left(1).to_upper()
		if abbreviation.length() >= 3:
			break
	return abbreviation


func get_relic_rarity_color(rarity: StringName) -> Color:
	match rarity:
		&"common":
			return UI_CYAN
		&"rare":
			return UI_MAGENTA
		&"legendary":
			return UI_GOLD
		_:
			return UI_CREAM


func make_relic_icon_style(
	background: Color,
	border: Color,
	pressed := false
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var muted_background := background.darkened(0.72)
	muted_background.a = 0.9 if pressed else 0.76
	style.bg_color = muted_background
	var muted_border := border.darkened(0.35)
	muted_border.a = 0.72 if pressed else 0.5
	style.border_color = muted_border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	if not pressed:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
		style.shadow_size = 2
		style.shadow_offset = Vector2(0.0, 2.0)
	return style


func apply_relic_icon_style(button: Button, rarity: StringName) -> void:
	var accent := get_relic_rarity_color(rarity)
	var foreground := Color(0.8471, 0.8078, 0.702, 1.0)
	button.add_theme_color_override("font_color", foreground)
	button.add_theme_color_override("font_hover_color", foreground)
	button.add_theme_color_override("font_pressed_color", foreground)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_stylebox_override(
		"normal", make_relic_icon_style(accent, accent)
	)
	button.add_theme_stylebox_override(
		"hover", make_relic_icon_style(accent.lightened(0.08), accent)
	)
	button.add_theme_stylebox_override(
		"pressed", make_relic_icon_style(accent, accent, true)
	)
	button.add_theme_stylebox_override(
		"hover_pressed", make_relic_icon_style(accent, accent, true)
	)


func get_short_relic_description(relic: Dictionary) -> String:
	var description := String(relic.get("description", ""))
	var exclusive_index := description.find(" Exclusive with ")
	if exclusive_index >= 0:
		description = description.left(exclusive_index)
	const MAX_DESCRIPTION_LENGTH := 175
	if description.length() <= MAX_DESCRIPTION_LENGTH:
		return description
	var cutoff := description.rfind(" ", MAX_DESCRIPTION_LENGTH)
	if cutoff < 0:
		cutoff = MAX_DESCRIPTION_LENGTH
	return description.left(cutoff).trim_suffix(".") + "…"


func _on_relic_hud_pressed(relic_id: StringName) -> void:
	if selected_relic_hud_id == relic_id:
		clear_relic_hud_selection()
	else:
		clear_enemy_hud_selection()
		show_relic_hud_selection(relic_id)


func show_relic_hud_selection(relic_id: StringName) -> void:
	if get_relic_count(relic_id) <= 0:
		clear_relic_hud_selection()
		return
	selected_relic_hud_id = relic_id
	for button_id in relic_hud_buttons:
		var button := relic_hud_buttons[button_id] as Button
		button.button_pressed = StringName(button_id) == relic_id
	var relic := GameStats.get_relic(relic_id)
	var count := get_relic_count(relic_id)
	relic_info_name.text = String(relic["display_name"])
	if count > 1:
		relic_info_name.text += " ×%d" % count
	relic_info_description.text = get_short_relic_description(relic)
	var affected_count := apply_relic_hud_highlights()
	if StringName(relic["category"]) == &"global":
		relic_info_affected.text = "Run-wide effect"
	elif affected_count == 0:
		relic_info_affected.text = "No towers affected"
	else:
		relic_info_affected.text = "Affects %d tower%s" % [
			affected_count,
			"" if affected_count == 1 else "s",
		]
	relic_info_panel.show()


func apply_relic_hud_highlights() -> int:
	var affected_count := 0
	for tower in get_tree().get_nodes_in_group("towers"):
		if (
			not is_instance_valid(tower)
			or tower.is_queued_for_deletion()
			or not bool(tower.get("is_placed"))
			or not tower.has_method("set_relic_highlight")
		):
			continue
		var affected: bool = (
			not selected_relic_hud_id.is_empty()
			and tower.has_method("receives_relic_effect")
			and tower.receives_relic_effect(selected_relic_hud_id)
		)
		tower.set_relic_highlight(
			not selected_relic_hud_id.is_empty(),
			affected
		)
		if affected:
			affected_count += 1
	return affected_count


func clear_relic_hud_selection() -> void:
	selected_relic_hud_id = &""
	for button_value in relic_hud_buttons.values():
		(button_value as Button).button_pressed = false
	relic_info_panel.hide()
	apply_relic_hud_highlights()


func refresh_relic_hud_highlights() -> void:
	if selected_relic_hud_id.is_empty():
		return
	show_relic_hud_selection(selected_relic_hud_id)


func clear_tower_details(tower: Node = null) -> void:
	if tower != null and displayed_tower != tower:
		return
	displayed_tower = null
	tower_info_expanded = false
	tower_target_panel_open = false
	tower_has_targeting_controls = false
	reset_sidebar_confirmation()
	tower_inspector.hide()
	tower_inspector_details.hide()
	build_sidebar_state.show()
	update_context_dock_layout()


func _on_build_toggle_pressed() -> void:
	if tower_inspector.visible:
		clear_tower_details()
	set_build_drawer_open(not tower_fan_open)


func set_build_drawer_open(is_open: bool) -> void:
	if is_open and not build_sidebar_state.visible:
		return
	if is_open and reinforcement_targeting:
		cancel_reinforcement_targeting()
	tower_fan_open = is_open
	tower_selection_area.hide()
	build_toggle_button.button_pressed = is_open
	build_toggle_button.tooltip_text = (
		"Close tower choices" if is_open else "Build towers"
	)
	if not is_open:
		tower_list.deselect_all()
	animate_tower_fan(is_open)
	update_context_dock_layout()


func animate_tower_fan(is_open: bool) -> void:
	if tower_fan_tween != null:
		tower_fan_tween.kill()
	var origin := build_toggle_button.get_global_rect().get_center() - tower_fan.global_position
	var closed_position := origin - Vector2.ONE * TOWER_FAN_BUTTON_SIZE * 0.5
	if is_open:
		layout_tower_fan_buttons()
		tower_fan.show()
		tower_fan_tween = create_tween().set_parallel(true)
		tower_fan_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for button_index in tower_fan_buttons.size():
			var button := tower_fan_buttons[button_index]
			var target_position: Vector2 = button.get_meta("fan_target_position")
			button.position = closed_position
			button.scale = Vector2.ONE * 0.62
			button.modulate.a = 0.0
			var delay := float(button_index) * 0.025
			tower_fan_tween.tween_property(
				button, "position", target_position, 0.20
			).set_delay(delay)
			tower_fan_tween.tween_property(
				button, "scale", Vector2.ONE, 0.18
			).set_delay(delay)
			tower_fan_tween.tween_property(
				button, "modulate:a", 1.0, 0.12
			).set_delay(delay)
		return

	if not tower_fan.visible:
		return
	tower_fan_tween = create_tween().set_parallel(true)
	tower_fan_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for button in tower_fan_buttons:
		tower_fan_tween.tween_property(button, "position", closed_position, 0.11)
		tower_fan_tween.tween_property(button, "scale", Vector2.ONE * 0.72, 0.11)
		tower_fan_tween.tween_property(button, "modulate:a", 0.0, 0.08)
	tower_fan_tween.chain().tween_callback(Callable(tower_fan, "hide"))


func update_context_dock_layout() -> void:
	thumb_controls.show()
	if tower_inspector.visible:
		build_toggle_button.show()
		var target_top := DOCK_COMPACT_INSPECTOR_TOP_OFFSET
		if tower_target_section.visible:
			target_top = DOCK_TARGET_INSPECTOR_TOP_OFFSET
		elif tower_information_content.visible:
			target_top = (
				DOCK_PATH_INSPECTOR_TOP_OFFSET
				if tower_path_section.visible
				else DOCK_INFO_INSPECTOR_TOP_OFFSET
			)
		show_context_dock(
			target_top,
			-12.0
		)
	else:
		if context_dock_tween != null:
			context_dock_tween.kill()
		sidebar.modulate.a = 1.0
		sidebar.hide()
		build_toggle_button.show()


func show_context_dock(target_top: float, target_bottom: float) -> void:
	if context_dock_tween != null:
		context_dock_tween.kill()
	var opening := not sidebar.visible
	if opening:
		sidebar.offset_top = target_top + 18.0
		sidebar.offset_bottom = target_bottom + 18.0
		sidebar.modulate.a = 0.0
		sidebar.show()
	context_dock_tween = create_tween().set_parallel(true)
	context_dock_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	context_dock_tween.tween_property(sidebar, "offset_top", target_top, 0.16)
	context_dock_tween.tween_property(
		sidebar, "offset_bottom", target_bottom, 0.16
	)
	context_dock_tween.tween_property(sidebar, "modulate:a", 1.0, 0.12)


func refresh_tower_details() -> void:
	if is_instance_valid(displayed_tower):
		show_tower_details(displayed_tower)
	else:
		clear_tower_details()

func _process(delta: float) -> void:
	if place_mode and tower_to_place:
		var pointer_world_position := (
			placement_drag_world_position
			if active_placement_drag_kind == DRAG_KIND_TOWER
			else get_global_mouse_position()
		)
		var snap := get_tower_build_position(
			pointer_world_position,
			pending_tower_type
		)
		var sprite = tower_to_place.get_node("Sprite2D")
		tower_to_place.position = snap
		var placement_is_valid := can_place_tower(snap)
		tower_to_place.set_range_preview(true, placement_is_valid)
		if placement_is_valid:
			sprite.modulate = Color(1, 1, 1, 0.5)
		else:
			sprite.modulate = Color(1, 0, 0, 0.5)

	_process_round_director(delta)
	_process_enemy_speed_auras(delta)
	_process_reinforcements(delta)


func _process_reinforcements(delta: float) -> void:
	ensure_reinforcement_controller()
	reinforcement_controller.process_cooldown(
		delta,
		round_active
		and not shop_open
		and not game_ended
	)
	var preview_world_position := (
		placement_drag_world_position
		if active_placement_drag_kind == DRAG_KIND_REINFORCEMENT
		else get_global_mouse_position()
	)
	reinforcement_controller.update_preview(preview_world_position)
	update_reinforcement_button()


func get_selected_reinforcement_option() -> Dictionary:
	ensure_reinforcement_controller()
	return reinforcement_controller.get_selected_option()


func can_begin_reinforcement_targeting() -> bool:
	ensure_reinforcement_controller()
	return reinforcement_controller.can_begin_targeting(
		game_ended,
		round_active,
		shop_open,
		build_mode,
		is_selecting_path_relic_tower()
	)


func _on_reinforcement_button_pressed() -> void:
	set_build_drawer_open(false)
	if reinforcement_targeting:
		cancel_reinforcement_targeting()
		return
	begin_reinforcement_targeting()


func _on_reinforcement_button_gui_input(event: InputEvent) -> void:
	if is_pointer_press_event(event):
		begin_placement_drag_candidate(
			DRAG_KIND_REINFORCEMENT,
			-1,
			get_pointer_screen_position(event),
			get_pointer_index(event)
		)


func begin_reinforcement_targeting() -> void:
	if not can_begin_reinforcement_targeting():
		return
	close_all_tower_menus()
	reinforcement_controller.begin_targeting()
	update_reinforcement_button()


func cancel_reinforcement_targeting() -> void:
	ensure_reinforcement_controller()
	reinforcement_controller.cancel_targeting()
	if (
		active_placement_drag_kind == DRAG_KIND_REINFORCEMENT
		or placement_drag_candidate_kind == DRAG_KIND_REINFORCEMENT
	):
		clear_placement_drag_state()
	update_reinforcement_button()


func is_valid_reinforcement_drop_position(world_position: Vector2) -> bool:
	ensure_reinforcement_controller()
	return reinforcement_controller.is_valid_drop_position(world_position)


func deploy_reinforcements(world_position: Vector2) -> bool:
	ensure_reinforcement_controller()
	var deployed: bool = reinforcement_controller.deploy(
		world_position,
		round_number
	)
	if deployed:
		update_reinforcement_button()
	return deployed


func clear_reinforcement_drops() -> void:
	ensure_reinforcement_controller()
	reinforcement_controller.clear_drops()


func update_reinforcement_button() -> void:
	if not is_instance_valid(reinforcement_button):
		return
	var option := get_selected_reinforcement_option()
	var display_name := String(option.get("display_name", "Reinforcements"))
	reinforcement_button.text = ""
	reinforcement_button.button_pressed = reinforcement_targeting
	reinforcement_cooldown_label.hide()
	if reinforcement_targeting:
		reinforcement_button.tooltip_text = (
			"Release to deploy %s; tap again to cancel" % display_name
		)
		reinforcement_button.disabled = false
	elif reinforcement_cooldown_remaining > 0.0:
		reinforcement_cooldown_label.show()
		reinforcement_cooldown_label.text = "%d" % ceili(
			reinforcement_cooldown_remaining
		)
		reinforcement_button.tooltip_text = "%s are recovering" % display_name
		reinforcement_button.disabled = true
	else:
		reinforcement_button.tooltip_text = "Drag onto the map · %s" % String(
			option.get("description", "")
		)
		reinforcement_button.disabled = not can_begin_reinforcement_targeting()

func update_lives() -> void:
	lives_display.text = "Health: %d/%d" % [lives, max_lives]

func update_money() -> void:
	money_display.text = "Money: Unlimited" if sandbox_mode else "Money: $%d" % money
	update_tower_affordability()
	money_changed.emit(money)
	refresh_tower_details()


func update_tower_affordability() -> void:
	for slot_index in tower_list.item_count:
		var tower_id := get_sidebar_tower_id(slot_index)
		if tower_id.is_empty():
			continue
		var placement_cost := get_tower_build_cost(
			tower_id,
			slot_index == CONTRABAND_SLOT_INDEX
		)
		var price_color := (
			AFFORDABLE_TOWER_COLOR
			if money >= placement_cost
			else UNAFFORDABLE_TOWER_COLOR
		)
		tower_list.set_item_custom_fg_color(slot_index, price_color)
	for button in tower_fan_buttons:
		var slot_index := int(button.get_meta("slot_index"))
		var tower_id := get_sidebar_tower_id(slot_index)
		if tower_id.is_empty():
			continue
		var placement_cost := get_tower_build_cost(
			tower_id,
			not sandbox_mode and slot_index == CONTRABAND_SLOT_INDEX
		)
		button.disabled = not sandbox_mode and money < placement_cost
		button.modulate = (
			Color.WHITE
			if not button.disabled
			else Color(0.72, 0.70, 0.68, 0.72)
		)

func add_money(amount: int) -> void:
	ensure_run_state()
	run_state.add_money(amount)
	update_money()

func spend_money(amount: int) -> bool:
	ensure_run_state()
	if run_state.spend_money(amount):
		update_money()
		return true
	return false

func close_all_tower_menus() -> void:
	cancel_manual_tower_targeting()
	for tower in get_tree().get_nodes_in_group("towers"):
		tower.set_selected(false)


func begin_manual_tower_targeting(tower: Node2D) -> void:
	ensure_build_controller()
	var previous_tower: Node2D = build_controller.begin_manual_targeting(tower)
	if is_instance_valid(previous_tower) and previous_tower != tower:
		previous_tower.cancel_manual_targeting()


func finish_manual_tower_targeting(tower: Node2D) -> void:
	ensure_build_controller()
	build_controller.finish_manual_targeting(tower)


func cancel_manual_tower_targeting() -> void:
	ensure_build_controller()
	var tower: Node2D = build_controller.take_manual_targeting_tower()
	if not is_instance_valid(tower):
		return
	tower.cancel_manual_targeting()


func roll_challenge_round_order() -> void:
	ensure_round_controller()
	round_controller.roll_challenge_round_order()


func generate_run_director_plan() -> void:
	ensure_wave_director()
	wave_director.generate_run_plan()
	enemy_debut_plan = wave_director.enemy_debut_plan
	round_style_plan = wave_director.round_style_plan


func ensure_wave_director() -> void:
	if wave_director == null:
		wave_director = WaveDirectorScript.new(enemy_rng, get_active_enemy_count)


func ensure_build_controller() -> void:
	if build_controller != null:
		return
	build_controller = BuildControllerScript.new()


func ensure_round_controller() -> void:
	if round_controller != null:
		return
	round_controller = RoundControllerScript.new(enemy_rng)


func ensure_reinforcement_controller() -> void:
	if reinforcement_controller != null:
		return
	reinforcement_controller = ReinforcementControllerScript.new(
		self,
		is_world_position_in_playable_area
	)


func ensure_run_state() -> void:
	if run_state != null:
		return
	run_state = RunStateScript.new()


func sync_wave_director_context() -> void:
	ensure_wave_director()
	wave_director.enemy_debut_plan = enemy_debut_plan
	wave_director.round_style_plan = round_style_plan
	wave_director.set_round_context(
		round_number,
		current_round_type,
		current_wave_spawn_style
	)
	wave_director.last_gauntlet_spawn_style = last_gauntlet_spawn_style
	wave_director.gauntlet_style_repeat_count = gauntlet_style_repeat_count


func sync_wave_director_style_memory() -> void:
	last_gauntlet_spawn_style = wave_director.last_gauntlet_spawn_style
	gauntlet_style_repeat_count = wave_director.gauntlet_style_repeat_count


func get_round_type(wave: int) -> StringName:
	ensure_round_controller()
	return round_controller.get_round_type(wave)


func start_round() -> void:
	ensure_round_controller()
	var blocked_by_gameplay := (
		shop_open or build_mode or is_selecting_path_relic_tower()
	)
	if not round_controller.can_start_round(blocked_by_gameplay):
		return
	close_all_tower_menus()
	next_spawn_path_index = 0
	pending_enemy_spawns.clear()
	spawn_schedule.clear()
	var next_round := round_number + 1
	if not round_controller.begin_round(get_wave_duration(next_round)):
		return
	threat_per_second = get_wave_threat_rate(round_number)
	if current_round_type in [ROUND_HORDE, ROUND_GAUNTLET, ROUND_PAYDAY]:
		threat_per_second *= get_horde_threat_multiplier(round_number)
	var mode: Dictionary = GameStats.get_mode(mode_id)
	spawn_threat = mode.get("starting_spawn_threat", 1.0)
	threat_chunk_elapsed = 0.0
	threat_continuous_ratio = mode.get("threat_continuous_ratio", 1.0)
	threat_chunk_ratio = mode.get("threat_chunk_ratio", 0.0)
	threat_chunk_interval = mode.get("threat_chunk_interval", 4.0)
	active_enemy_cap = mode.get("active_enemy_cap", 160)
	absolute_enemy_cap = maxi(
		int(mode.get("absolute_enemy_cap", 240)),
		active_enemy_cap
	)
	if current_round_type in [ROUND_HORDE, ROUND_PAYDAY]:
		active_enemy_cap = mini(
			int(mode.get("horde_active_enemy_cap", 200)),
			absolute_enemy_cap
		)
	elif current_round_type == ROUND_GAUNTLET:
		active_enemy_cap = mini(
			int(mode.get("gauntlet_active_enemy_cap", 220)),
			absolute_enemy_cap
		)
	director_cooldown = 0.0
	final_elite_pack_spawned = false
	last_gauntlet_spawn_style = &""
	gauntlet_style_repeat_count = 0
	ensure_wave_director()
	wave_director.reset_round_style_memory()
	if current_round_type == ROUND_ELITE:
		next_elite_event_time = enemy_rng.randf_range(
			ELITE_EVENT_MIN_INTERVAL,
			ELITE_EVENT_MAX_INTERVAL
		)
	elif current_round_type == ROUND_GAUNTLET:
		next_elite_event_time = enemy_rng.randf_range(
			GAUNTLET_ELITE_MIN_INTERVAL,
			GAUNTLET_ELITE_MAX_INTERVAL
		)
	else:
		next_elite_event_time = INF
	spawning_active = true
	current_wave_spawn_style = choose_wave_spawn_style(round_number)
	if round_number == max_rounds:
		current_wave_spawn_style = &"boss_escort"
		spawn_schedule = build_timed_boss_opening()
	else:
		spawn_schedule = build_debut_opening(round_number)
	mobs_left_to_spawn = spawn_schedule.size()
	round_started.emit(round_number)
	spawntimer.one_shot = true
	update_round_count()
	update_play_pause_button()
	
func update_round_count() -> void:
	if sandbox_mode and not round_active:
		round_count_display.text = "Sandbox wave: %d" % maxi(round_number, 1)
		round_timer_display.text = (
			"Spawning test enemies"
			if spawning_active or mobs_left_to_spawn > 0
			else "Sandbox ready"
		)
		refresh_enemy_hud()
		return
	ensure_round_controller()
	var displayed_round: int = round_controller.get_displayed_round()
	refresh_enemy_hud()
	round_count_display.text = "Round: %d/%d" % [displayed_round, max_rounds]
	var round_type_name := get_round_type_display_name(current_round_type)
	if round_active and spawning_active:
		if current_round_type == ROUND_STANDARD:
			round_timer_display.text = "Spawning: %ds" % ceili(round_time_remaining)
		else:
			round_timer_display.text = "%s: %ds" % [
				round_type_name,
				ceili(round_time_remaining),
			]
	elif round_active:
		if current_round_type == ROUND_STANDARD:
			round_timer_display.text = "Clear remaining enemies"
		else:
			round_timer_display.text = "%s: Clear remaining enemies" % round_type_name
	elif shop_open:
		round_timer_display.text = (
			"Item Shop" if active_draft_type == DRAFT_ITEM else "Draft"
		)
	elif is_selecting_path_relic_tower():
		var relic := GameStats.get_relic(pending_path_relic_tower_selection)
		round_timer_display.text = "%s: Select a tower" % relic["display_name"]
	else:
		round_timer_display.text = "Build Phase"


func get_round_type_display_name(round_type: StringName) -> String:
	ensure_round_controller()
	return round_controller.get_round_type_display_name(round_type)
	
func end_round() -> void:
	ensure_round_controller()
	if not round_controller.end_round():
		return
	spawning_active = false
	cancel_reinforcement_targeting()
	clear_reinforcement_drops()
	clear_active_projectiles()
	spawn_schedule.clear()
	pending_enemy_spawns.clear()
	mobs_left_to_spawn = 0
	spawntimer.stop()
	round_ended.emit(round_number)
	add_money(calculate_end_round_reward())
	roll_holiday_sale_tower()
	update_round_count()

	match round_controller.get_post_round_action(
		TOWER_DRAFT_ROUNDS,
		RELIC_DRAFT_ROUNDS,
		REINFORCEMENT_DRAFT_ROUNDS
	):
		RoundControllerScript.POST_ROUND_VICTORY:
			victory()
		RoundControllerScript.POST_ROUND_TOWER_DRAFT:
			open_tower_draft()
		RoundControllerScript.POST_ROUND_ITEM_SHOP:
			open_item_shop()
		RoundControllerScript.POST_ROUND_RELIC_DRAFT:
			open_relic_draft()
		RoundControllerScript.POST_ROUND_REINFORCEMENT_DRAFT:
			open_reinforcement_draft_placeholder()
		_:
			enter_build_phase()


func open_reinforcement_draft_placeholder() -> void:
	# Reinforcement choices will plug into this scheduled beat once their draft
	# content exists. Until then, continue into the normal build phase.
	enter_build_phase()


func enter_build_phase() -> void:
	ensure_round_controller()
	round_controller.enter_build_phase()
	update_round_count()
	update_play_pause_button()


func calculate_end_round_reward() -> int:
	ensure_round_controller()
	return round_controller.calculate_end_round_reward(
		money,
		get_relic_count(&"dividends") > 0
	)


func clear_active_projectiles() -> void:
	for projectile in get_tree().get_nodes_in_group("tower_projectiles"):
		if is_instance_valid(projectile):
			projectile.queue_free()
	for resolver in get_tree().get_nodes_in_group("tower_attack_resolvers"):
		if is_instance_valid(resolver):
			resolver.queue_free()
	for effect in get_tree().get_nodes_in_group("tower_attack_visuals"):
		if is_instance_valid(effect):
			if effect.has_method("recycle_now"):
				effect.recycle_now()
			else:
				effect.queue_free()


func get_shared_spore_target(requesting_tower: Node) -> Node2D:
	refresh_spore_network_cache()
	if not is_instance_valid(requesting_tower):
		return null
	var requesting_owner_id := requesting_tower.get_instance_id()
	if (
		spore_network_primary_owner_id != requesting_owner_id
		and is_valid_spore_network_target(spore_network_primary_target)
	):
		return spore_network_primary_target
	if (
		spore_network_secondary_owner_id != requesting_owner_id
		and is_valid_spore_network_target(spore_network_secondary_target)
	):
		return spore_network_secondary_target
	return null


func refresh_spore_network_cache() -> void:
	var current_time_msec := Time.get_ticks_msec()
	if current_time_msec - spore_network_last_refresh_msec < 200:
		return
	spore_network_last_refresh_msec = current_time_msec
	spore_network_primary_owner_id = 0
	spore_network_primary_target = null
	spore_network_secondary_owner_id = 0
	spore_network_secondary_target = null
	var owner_targets: Dictionary = {}
	for candidate in get_tree().get_nodes_in_group("spawned_units"):
		if (
			candidate.unit_id != &"spore_turret"
			or not is_instance_valid(candidate.parent_tower)
			or not candidate.locally_acquired_target
			or not is_valid_spore_network_target(candidate.local_target)
		):
			continue
		var owner_id: int = candidate.parent_tower.get_instance_id()
		var progress := float(candidate.local_target.path_follow.progress)
		if (
			not owner_targets.has(owner_id)
			or progress > float(owner_targets[owner_id]["progress"])
		):
			owner_targets[owner_id] = {
				"target": candidate.local_target,
				"progress": progress,
			}
	for owner_id in owner_targets:
		var entry: Dictionary = owner_targets[owner_id]
		var entry_progress := float(entry["progress"])
		var primary_progress := get_spore_network_target_progress(
			spore_network_primary_target
		)
		if entry_progress > primary_progress:
			spore_network_secondary_owner_id = spore_network_primary_owner_id
			spore_network_secondary_target = spore_network_primary_target
			spore_network_primary_owner_id = int(owner_id)
			spore_network_primary_target = entry["target"]
		elif entry_progress > get_spore_network_target_progress(
			spore_network_secondary_target
		):
			spore_network_secondary_owner_id = int(owner_id)
			spore_network_secondary_target = entry["target"]


func is_valid_spore_network_target(candidate: Variant) -> bool:
	return (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and not candidate.finished
		and is_instance_valid(candidate.path_follow)
	)


func get_spore_network_target_progress(candidate: Variant) -> float:
	if not is_valid_spore_network_target(candidate):
		return -INF
	return float(candidate.path_follow.progress)


func open_tower_draft() -> void:
	open_between_round_draft(
		DRAFT_TOWER,
		roll_tower_offers(),
		get_tower_roster_dictionary()
	)


func open_item_shop() -> void:
	if shop_open or game_ended:
		return
	cancel_pending_tower_placement()
	close_all_tower_menus()
	shop_open = true
	ensure_round_controller()
	round_controller.enter_draft_phase()
	active_draft_type = DRAFT_ITEM
	draft_health_purchased = false
	ensure_run_state()
	item_shop_manager.open_shop(
		round_number,
		run_state.locked_tower_item_offers,
		get_preferred_shop_item_ids()
	)
	active_draft_offers = item_shop_manager.offers.duplicate()
	update_round_count()
	update_play_pause_button()
	var health_recovery := get_draft_health_recovery()
	var health_cost := get_draft_health_cost(health_recovery)
	between_round_shop.open_item_shop(
		round_number,
		max_rounds,
		item_shop_manager.offers,
		item_shop_manager.locked_slots,
		run_state.tower_item_inventory,
		money,
		item_shop_manager.get_reroll_cost(),
		health_recovery,
		health_cost,
		health_recovery > 0 and (sandbox_mode or money >= health_cost)
	)


func refresh_item_shop_view() -> void:
	if not shop_open or active_draft_type != DRAFT_ITEM:
		return
	ensure_run_state()
	active_draft_offers = item_shop_manager.offers.duplicate()
	between_round_shop.refresh_item_shop(
		item_shop_manager.offers,
		item_shop_manager.locked_slots,
		run_state.tower_item_inventory,
		money,
		item_shop_manager.get_reroll_cost()
	)


func get_preferred_shop_item_ids() -> Array[StringName]:
	var preferred: Array[StringName] = []
	var placed_towers := get_placed_towers_for_item_management()
	for item_id in GameStats.get_tower_item_ids():
		for tower in placed_towers:
			if tower.item_controller.is_item_compatible(item_id):
				preferred.append(item_id)
				break
	return preferred


func _on_item_purchase_requested(slot_index: int, item_id: StringName) -> void:
	if (
		not shop_open
		or active_draft_type != DRAFT_ITEM
		or not item_shop_manager.is_valid_offer_slot(slot_index)
		or item_shop_manager.offers[slot_index] != item_id
	):
		return
	var item := GameStats.get_tower_item(item_id)
	if not spend_money(int(item.get("price", 0))):
		refresh_item_shop_view()
		return
	ensure_run_state()
	if not run_state.add_tower_item(item_id):
		add_money(int(item.get("price", 0)))
		return
	item_shop_manager.mark_purchased(slot_index)
	run_state.set_locked_tower_item_offers(
		item_shop_manager.get_locked_offer_ids()
	)
	refresh_item_inventory_interfaces()
	refresh_item_shop_view()


func _on_item_lock_toggled(slot_index: int) -> void:
	if not shop_open or active_draft_type != DRAFT_ITEM:
		return
	item_shop_manager.toggle_lock(slot_index)
	ensure_run_state()
	run_state.set_locked_tower_item_offers(
		item_shop_manager.get_locked_offer_ids()
	)
	refresh_item_shop_view()


func _on_item_reroll_requested() -> void:
	if (
		not shop_open
		or active_draft_type != DRAFT_ITEM
		or not item_shop_manager.has_rerollable_slots()
	):
		return
	var reroll_cost: int = item_shop_manager.get_reroll_cost()
	if not spend_money(reroll_cost):
		refresh_item_shop_view()
		return
	item_shop_manager.reroll(round_number, get_preferred_shop_item_ids())
	ensure_run_state()
	run_state.set_locked_tower_item_offers(
		item_shop_manager.get_locked_offer_ids()
	)
	refresh_item_shop_view()


func _on_item_shop_closed() -> void:
	if not shop_open or active_draft_type != DRAFT_ITEM:
		return
	ensure_run_state()
	run_state.set_locked_tower_item_offers(
		item_shop_manager.get_locked_offer_ids()
	)
	shop_open = false
	active_draft_type = &""
	active_draft_offers.clear()
	draft_health_purchased = false
	between_round_shop.hide()
	enter_build_phase()


func open_relic_draft() -> void:
	var offers := roll_relic_offers()
	var choice_quantities := get_relic_choice_quantities(offers)
	open_between_round_draft(
		DRAFT_RELIC,
		offers,
		owned_shop_items,
		choice_quantities
	)


func open_between_round_draft(
	draft_type: StringName,
	offers: Array[StringName],
	owned_items: Dictionary,
	choice_quantities: Dictionary = {}
) -> void:
	if shop_open or game_ended:
		return
	cancel_pending_tower_placement()
	close_all_tower_menus()
	shop_open = true
	ensure_round_controller()
	round_controller.enter_draft_phase()
	active_draft_type = draft_type
	active_draft_offers = offers.duplicate()
	active_draft_choice_quantities = choice_quantities.duplicate()
	draft_health_purchased = false
	update_round_count()
	update_play_pause_button()
	var health_recovery := get_draft_health_recovery()
	var health_cost := get_draft_health_cost(health_recovery)
	between_round_shop.open_draft(
		round_number,
		max_rounds,
		draft_type,
		offers,
		owned_items,
		choice_quantities,
		health_recovery,
		health_cost,
		health_recovery > 0 and (sandbox_mode or money >= health_cost)
	)


func get_draft_health_recovery() -> int:
	ensure_run_state()
	return run_state.get_draft_health_recovery(DRAFT_HEALTH_RECOVERY)


func get_draft_health_cost(health_recovery: int) -> int:
	if health_recovery <= 0:
		return 0
	var full_recovery_cost := (
		float(GameStats.get_round_cash_reward(round_number))
		* DRAFT_HEALTH_COST_RATIO
	)
	var proportional_cost := (
		full_recovery_cost
		* float(health_recovery)
		/ float(DRAFT_HEALTH_RECOVERY)
	)
	return maxi(
		roundi(proportional_cost / float(DRAFT_HEALTH_PRICE_INCREMENT))
			* DRAFT_HEALTH_PRICE_INCREMENT,
		DRAFT_HEALTH_PRICE_INCREMENT
	)


func _on_draft_health_requested() -> void:
	if not shop_open or draft_health_purchased:
		return
	var health_recovery := get_draft_health_recovery()
	if health_recovery <= 0:
		between_round_shop.update_health_button(0, 0, false)
		return
	var health_cost := get_draft_health_cost(health_recovery)
	if not spend_money(health_cost):
		between_round_shop.update_health_button(
			health_recovery,
			health_cost,
			false
		)
		return
	draft_health_purchased = true
	run_state.restore_health(health_recovery)
	update_lives()
	between_round_shop.mark_health_purchased(health_recovery)
	refresh_item_shop_view()


func ensure_draft_manager() -> void:
	if draft_manager == null:
		draft_manager = DraftManagerScript.new(shop_rng)


func sync_draft_manager_history() -> void:
	ensure_draft_manager()
	draft_manager.recent_relic_offers = recent_relic_offers.duplicate()


func get_relic_choice_quantities(offers: Array[StringName]) -> Dictionary:
	ensure_draft_manager()
	return draft_manager.get_relic_choice_quantities(round_number, offers)


func roll_relic_offers() -> Array[StringName]:
	sync_draft_manager_history()
	var path_relic_eligibility := {
		&"singularity_core": has_eligible_built_tower_for_path_relic(
			&"singularity_core"
		),
		&"perfect_mutation": has_eligible_built_tower_for_path_relic(
			&"perfect_mutation"
		),
	}
	var offers: Array[StringName] = draft_manager.roll_relic_offers(
		round_number,
		owned_shop_items,
		get_tower_roster_tags(),
		path_relic_eligibility,
		has_dedicated_spawner_available()
	)
	recent_relic_offers = draft_manager.recent_relic_offers.duplicate()
	return offers


func is_relic_applicable_to_current_loadout(
	item_id: StringName,
	current_tags: Array[StringName] = []
) -> bool:
	ensure_draft_manager()
	var tags := current_tags
	if tags.is_empty():
		tags = get_tower_roster_tags()
	return draft_manager.is_relic_applicable(
		item_id,
		tags,
		has_dedicated_spawner_available()
	)


func has_dedicated_spawner_available() -> bool:
	for tower_id in TRADE_AGREEMENT_TOWER_IDS:
		if tower_roster.has(tower_id) or tower_id == contraband_tower_id:
			return true
	for tower in get_tree().get_nodes_in_group("towers"):
		if (
			is_instance_valid(tower)
			and tower.is_placed
			and TRADE_AGREEMENT_TOWER_IDS.has(StringName(tower.tower_id))
		):
			return true
	return false


func get_tower_roster_tags() -> Array[StringName]:
	ensure_run_state()
	var roster_tags: Array[StringName] = run_state.get_roster_base_tags()
	for tower in get_tree().get_nodes_in_group("towers"):
		if not is_instance_valid(tower) or not tower.is_placed:
			continue
		for tag_group in [tower.type_tags, tower.damage_tags, tower.bonus_tags]:
			for tag in tag_group:
				var typed_tag := StringName(tag)
				if not roster_tags.has(typed_tag):
					roster_tags.append(typed_tag)
	return roster_tags


func roll_tower_offers() -> Array[StringName]:
	ensure_draft_manager()
	return draft_manager.roll_tower_offers(tower_roster)


func _on_draft_confirmed(item_id: StringName, quantity: int) -> void:
	if not shop_open:
		return
	if active_draft_type == DRAFT_TOWER:
		collect_tower(item_id)
	else:
		collect_relic(item_id, quantity)
	shop_open = false
	active_draft_type = &""
	active_draft_offers.clear()
	active_draft_choice_quantities.clear()
	draft_health_purchased = false
	between_round_shop.hide()
	if item_id in [&"singularity_core", &"perfect_mutation"]:
		begin_path_relic_tower_selection(item_id)
		return
	enter_build_phase()


func collect_relic(item_id: StringName, quantity := 1) -> void:
	ensure_run_state()
	if not run_state.collect_relic(item_id, quantity):
		return
	if item_id == &"contraband_blueprint":
		activate_contraband_blueprint()
	elif item_id == &"holiday_sale":
		roll_holiday_sale_tower()
	refresh_placed_tower_stats()
	populate_tower_list()
	update_tower_affordability()
	refresh_relic_hud()


func activate_contraband_blueprint() -> void:
	ensure_run_state()
	run_state.activate_contraband_blueprint(shop_rng)


func roll_holiday_sale_tower() -> void:
	ensure_run_state()
	run_state.roll_holiday_sale_tower(shop_rng)
	populate_tower_list()
	update_tower_affordability()


func get_sidebar_tower_id(slot_index: int) -> StringName:
	ensure_run_state()
	return run_state.get_sidebar_tower_id(slot_index, CONTRABAND_SLOT_INDEX)


func get_tower_build_cost(tower_id: StringName, is_contraband := false) -> int:
	ensure_run_state()
	return run_state.get_tower_build_cost(
		tower_id,
		is_contraband,
		TRADE_AGREEMENT_TOWER_IDS
	)

func roll_random_starting_towers(count: int = 2) -> void:
	ensure_draft_manager()
	ensure_run_state()
	run_state.set_tower_roster(draft_manager.roll_random_starting_towers(count))


func collect_tower(tower_id: StringName) -> void:
	ensure_run_state()
	if not run_state.collect_tower(tower_id, TOWER_SLOT_COUNT):
		return
	populate_tower_list()
	update_tower_affordability()


func get_tower_roster_dictionary() -> Dictionary:
	ensure_run_state()
	return run_state.get_tower_roster_dictionary()


func get_tower_item_inventory() -> Dictionary:
	ensure_run_state()
	return run_state.tower_item_inventory.duplicate()


func get_placed_towers_for_item_management() -> Array[Node]:
	var towers: Array[Node] = []
	for candidate in get_tree().get_nodes_in_group("towers"):
		if (
			is_instance_valid(candidate)
			and not candidate.is_queued_for_deletion()
			and bool(candidate.get("is_placed"))
			and candidate.get("instance_progression") != null
		):
			towers.append(candidate)
	towers.sort_custom(func(a: Node, b: Node) -> bool:
		return String(a.instance_progression.instance_uid) < String(
			b.instance_progression.instance_uid
		)
	)
	return towers


func can_manage_tower_items() -> bool:
	return not game_ended and not round_active


func equip_inventory_item_to_tower(
	item_id: StringName,
	tower: Node,
	slot_index: int
) -> bool:
	if (
		not can_manage_tower_items()
		or not is_instance_valid(tower)
		or not tower.is_placed
		or not GameStats.has_tower_item(item_id)
		or slot_index < 0
		or slot_index >= GameStats.TOWER_ITEM_SLOT_COUNT
		or not tower.item_controller.is_item_compatible(item_id)
	):
		return false
	ensure_run_state()
	if tower_item_inventory_service.equip_item(tower, item_id, slot_index):
		refresh_item_inventory_interfaces(tower)
		refresh_item_shop_view()
		return true
	refresh_item_inventory_interfaces(tower)
	return false


func unequip_tower_item_to_inventory(tower: Node, slot_index: int) -> bool:
	if (
		not can_manage_tower_items()
		or not is_instance_valid(tower)
		or slot_index < 0
		or slot_index >= GameStats.TOWER_ITEM_SLOT_COUNT
	):
		return false
	ensure_run_state()
	if not tower_item_inventory_service.unequip_item(tower, slot_index):
		return false
	refresh_item_inventory_interfaces(tower)
	refresh_item_shop_view()
	return true


func return_tower_items_to_inventory(tower: Node) -> void:
	if not is_instance_valid(tower):
		return
	ensure_run_state()
	tower_item_inventory_service.return_all_items(tower)
	refresh_item_inventory_interfaces()


func refresh_item_inventory_interfaces(preferred_tower: Node = null) -> void:
	if is_instance_valid(tower_item_inventory_panel):
		tower_item_inventory_panel.refresh(preferred_tower)
	if is_instance_valid(between_round_shop):
		between_round_shop.refresh_inventory_panel(preferred_tower)


func refresh_placed_tower_stats() -> void:
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(tower) and tower.is_placed:
			tower.load_base_tags()
			tower.load_level_stats()
			tower.update_menu_buttons()
	refresh_tower_details()
	refresh_relic_hud_highlights()


func get_run_bonus(effect: StringName) -> float:
	ensure_run_state()
	return run_state.get_run_bonus(effect)


func get_relic_count(relic_id: StringName) -> int:
	ensure_run_state()
	return run_state.get_relic_count(relic_id)


func is_selecting_path_relic_tower() -> bool:
	return not pending_path_relic_tower_selection.is_empty()


func get_path_relic_required_type(relic_id: StringName) -> StringName:
	return &"technology" if relic_id == &"singularity_core" else &"biological"


func is_tower_eligible_for_path_relic(tower: Node, relic_id: StringName) -> bool:
	return (
		is_instance_valid(tower)
		and not tower.is_queued_for_deletion()
		and bool(tower.get("is_placed"))
		and tower.has_method("has_type_tag")
		and tower.has_type_tag(get_path_relic_required_type(relic_id))
		and tower.has_method("has_path_options")
		and tower.has_path_options()
		and StringName(tower.get("dual_path_relic_source")).is_empty()
	)


func has_eligible_built_tower_for_path_relic(relic_id: StringName) -> bool:
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_tower_eligible_for_path_relic(tower, relic_id):
			return true
	return false


func begin_path_relic_tower_selection(relic_id: StringName) -> void:
	pending_path_relic_tower_selection = relic_id
	close_all_tower_menus()
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(tower) and bool(tower.get("is_placed")):
			tower.set_range_preview(
				true,
				is_tower_eligible_for_path_relic(tower, relic_id)
			)
	update_round_count()
	update_play_pause_button()


func try_assign_path_relic_to_tower(tower: Node) -> void:
	if not is_selecting_path_relic_tower():
		return
	var relic_id := pending_path_relic_tower_selection
	if not is_tower_eligible_for_path_relic(tower, relic_id):
		return
	tower.grant_dual_path_relic(relic_id)
	pending_path_relic_tower_selection = &""
	for candidate in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(candidate) and bool(candidate.get("is_placed")):
			candidate.set_range_preview(false)
	round_controller.enter_build_phase()
	update_round_count()
	update_play_pause_button()
	refresh_relic_hud_highlights()
	show_tower_details(tower)


func can_tower_purchase_both_paths(tower: Node) -> bool:
	return (
		is_instance_valid(tower)
		and not StringName(tower.get("dual_path_relic_source")).is_empty()
	)


func cancel_pending_tower_placement() -> void:
	ensure_build_controller()
	var pending_tower: Node2D = build_controller.clear_pending_placement()
	if is_instance_valid(pending_tower):
		clear_tower_details(pending_tower)
		pending_tower.queue_free()
	if (
		active_placement_drag_kind == DRAG_KIND_TOWER
		or placement_drag_candidate_kind == DRAG_KIND_TOWER
	):
		clear_placement_drag_state()
	tower_list.deselect_all()
	update_play_pause_button()
	
func _spawn_mob():
	if not spawning_active or spawn_schedule.is_empty():
		mobs_left_to_spawn = 0
		spawntimer.stop()
		return
	var spawn_event: Dictionary = spawn_schedule.front()
	var event_cap := active_enemy_cap
	if not spawn_event.get("special_event", false):
		if current_round_type == ROUND_ELITE:
			event_cap = maxi(active_enemy_cap - ELITE_EVENT_RESERVED_SLOTS, 1)
		elif current_round_type == ROUND_GAUNTLET:
			event_cap = maxi(active_enemy_cap - GAUNTLET_EVENT_RESERVED_SLOTS, 1)
	if mobs_alive >= event_cap:
		spawntimer.start(0.2)
		return

	var enemy_id: StringName = spawn_event["enemy_id"]
	var spawn_cost := get_spawn_event_director_cost(spawn_event)
	var free_spawn: bool = spawn_event.get("free_spawn", false)
	if not free_spawn and spawn_threat < spawn_cost:
		spawntimer.start(0.1)
		return

	spawn_schedule.pop_front()
	if not free_spawn:
		spawn_threat -= spawn_cost
	_create_mob(
		enemy_id,
		0.0,
		spawn_event.get("variant", VARIANT_NORMAL),
		StringName(spawn_event.get("path_id", &""))
	)
	mobs_left_to_spawn = spawn_schedule.size()

	if spawn_schedule.is_empty():
		spawntimer.stop()
		director_cooldown = spawn_event["delay_after"]
		if sandbox_mode and not round_active:
			spawning_active = false
			update_round_count()
			sandbox_panel.set_status(
				"Wave deployed. %d enemies active." % mobs_alive
			)
	else:
		var delay_after: float = spawn_event["delay_after"]
		spawntimer.start(delay_after)


func _create_mob(
	enemy_id: StringName,
	start_progress: float,
	spawn_variant: StringName = VARIANT_NORMAL,
	path_id: StringName = &""
) -> void:
	if game_ended:
		return
	var enemy_path: Path2D
	if active_map != null:
		enemy_path = (
			get_next_spawn_path()
			if path_id.is_empty()
			else active_map.get_enemy_path(path_id)
		)
	if enemy_path == null:
		push_error("Cannot spawn %s: map path '%s' does not exist" % [enemy_id, path_id])
		return

	var mob = MOB_SCENE.instantiate()
	mob.enemy_id = enemy_id
	mob.wave_number = round_number
	mob.health_multiplier = get_enemy_health_multiplier(round_number, enemy_id)
	mob.spawn_variant = spawn_variant
	mob.mob_killed.connect(_on_mob_killed)
	mob.reached_end.connect(_on_mob_reached_end)
	mob.spawn_requested.connect(_on_mob_spawn_requested)
	var pf := PathFollow2D.new()
	enemy_path.add_child(pf)
	pf.loop = false
	pf.add_child(mob)
	mob.set_path_follow(pf, start_progress)
	mobs_alive += 1


func sandbox_spawn_wave(wave_type: StringName, test_wave: int) -> void:
	if not sandbox_mode:
		return
	var wave := clampi(test_wave, 1, max_rounds)
	var available := get_available_enemies(wave)
	if available.is_empty():
		sandbox_panel.set_status("No enemies are available for that wave.")
		return

	var enemy_batch: Array[Dictionary] = []
	var standard_count := clampi(14 + ceili(float(wave) * 0.6), 15, 36)
	match wave_type:
		&"horde":
			for _index in clampi(24 + wave, 25, 48):
				enemy_batch.append({
					"enemy_id": choose_weighted_enemy(available),
					"variant": VARIANT_HORDE,
				})
		&"elite":
			for _index in maxi(standard_count - 5, 8):
				enemy_batch.append({
					"enemy_id": choose_weighted_enemy(available),
					"variant": VARIANT_NORMAL,
				})
			for _index in clampi(2 + floori(float(wave) / 8.0), 2, 6):
				enemy_batch.append({
					"enemy_id": choose_weighted_enemy(available),
					"variant": VARIANT_ELITE,
				})
		&"gauntlet":
			for _index in clampi(20 + wave, 24, 44):
				enemy_batch.append({
					"enemy_id": choose_weighted_enemy(available),
					"variant": VARIANT_HORDE,
				})
			for _index in clampi(3 + floori(float(wave) / 6.0), 3, 8):
				enemy_batch.append({
					"enemy_id": choose_weighted_enemy(available),
					"variant": VARIANT_ELITE,
				})
		&"boss":
			for _index in clampi(6 + floori(float(wave) / 3.0), 8, 18):
				enemy_batch.append({
					"enemy_id": choose_weighted_enemy(available),
					"variant": VARIANT_NORMAL,
				})
			enemy_batch.insert(floori(float(enemy_batch.size()) / 2.0), {
				"enemy_id": &"brute",
				"variant": VARIANT_NORMAL,
			})
		_:
			for _index in standard_count:
				enemy_batch.append({
					"enemy_id": choose_weighted_enemy(available),
					"variant": VARIANT_NORMAL,
				})

	sandbox_queue_enemy_batch(enemy_batch, wave, String(wave_type).capitalize())


func sandbox_spawn_enemy(
	enemy_id: StringName,
	count: int,
	spawn_variant: StringName,
	test_wave: int
) -> void:
	if not sandbox_mode or not GameStats.ENEMIES.has(enemy_id):
		return
	var enemy_batch: Array[Dictionary] = []
	for _index in clampi(count, 1, 50):
		enemy_batch.append({
			"enemy_id": enemy_id,
			"variant": spawn_variant,
		})
	sandbox_queue_enemy_batch(
		enemy_batch,
		clampi(test_wave, 1, max_rounds),
		GameStats.get_enemy(enemy_id)["display_name"]
	)


func sandbox_queue_enemy_batch(
	enemy_batch: Array[Dictionary],
	test_wave: int,
	label: String
) -> void:
	if enemy_batch.is_empty():
		return
	round_number = test_wave
	for entry in enemy_batch:
		spawn_schedule.append({
			"enemy_id": entry["enemy_id"],
			"variant": entry.get("variant", VARIANT_NORMAL),
			"free_spawn": true,
			"delay_after": 0.08,
			"style": &"sandbox",
		})
	mobs_left_to_spawn = spawn_schedule.size()
	spawning_active = true
	update_round_count()
	sandbox_panel.set_status(
		"Queued %d %s enemies at wave %d scaling." % [
			enemy_batch.size(), label, test_wave,
		]
	)
	if spawntimer.is_stopped():
		spawntimer.start(0.01)


func sandbox_clear_enemies() -> void:
	if not sandbox_mode:
		return
	spawning_active = false
	spawn_schedule.clear()
	pending_enemy_spawns.clear()
	mobs_left_to_spawn = 0
	spawntimer.stop()
	clear_active_projectiles()
	clear_all_path_followers()
	mobs_alive = 0
	update_round_count()
	sandbox_panel.set_status("All test enemies cleared.")


func sandbox_restore_health() -> void:
	if not sandbox_mode:
		return
	run_state.restore_full_health()
	update_lives()
	sandbox_panel.set_status("Health restored.")


func _on_mob_spawn_requested(
	enemy_id: StringName,
	path_progress: float,
	spawn_variant: StringName,
	requester: Node,
	request_kind: StringName
) -> void:
	var path_id := get_path_id_for_requester(requester)
	if mobs_alive >= absolute_enemy_cap:
		if request_kind == &"split":
			pending_enemy_spawns.append({
				"enemy_id": enemy_id,
				"path_progress": path_progress,
				"spawn_variant": spawn_variant,
				"path_id": path_id,
			})
		elif is_instance_valid(requester) and requester.has_method("resolve_spawn_request"):
			requester.resolve_spawn_request(request_kind, false)
		return
	_create_mob(enemy_id, path_progress, spawn_variant, path_id)
	if is_instance_valid(requester) and requester.has_method("resolve_spawn_request"):
		requester.resolve_spawn_request(request_kind, true)


func flush_pending_enemy_spawns() -> void:
	while (
		not pending_enemy_spawns.is_empty()
		and mobs_alive < absolute_enemy_cap
		and not game_ended
	):
		var request: Dictionary = pending_enemy_spawns.pop_front()
		_create_mob(
			request["enemy_id"],
			request["path_progress"],
			request["spawn_variant"],
			StringName(request.get("path_id", &""))
		)


func _process_enemy_speed_auras(delta: float) -> void:
	enemy_aura_refresh_remaining -= delta
	if enemy_aura_refresh_remaining > 0.0:
		return
	enemy_aura_refresh_remaining = ENEMY_AURA_REFRESH_INTERVAL
	var mobs := get_tree().get_nodes_in_group("mobs")
	for mob in mobs:
		if is_instance_valid(mob) and mob.has_method("reset_cached_speed_aura"):
			mob.reset_cached_speed_aura()
	for buffer in get_tree().get_nodes_in_group("speed_buffers"):
		if not is_instance_valid(buffer) or buffer.is_queued_for_deletion():
			continue
		for mob in mobs:
			if (
				mob == buffer
				or not is_instance_valid(mob)
				or mob.is_queued_for_deletion()
				or not mob.has_method("apply_cached_speed_aura_from")
			):
				continue
			mob.apply_cached_speed_aura_from(buffer)


func spawn_hitscan_visual(
	start_position: Vector2,
	end_position: Vector2,
	attack_type: StringName
) -> void:
	var effect: Node2D
	while not pooled_hitscan_effects.is_empty() and effect == null:
		var candidate: Node2D = pooled_hitscan_effects.pop_back() as Node2D
		if is_instance_valid(candidate):
			effect = candidate
	if effect == null:
		effect = HITSCAN_EFFECT_SCENE.instantiate() as Node2D
		add_child(effect)
		effect.recycle_requested.connect(_recycle_hitscan_effect)
	effect.setup(start_position, end_position, attack_type)


func spawn_explosion_visual(center: Vector2, radius: float) -> void:
	var effect: Node2D
	while not pooled_explosion_effects.is_empty() and effect == null:
		var candidate: Node2D = pooled_explosion_effects.pop_back() as Node2D
		if is_instance_valid(candidate):
			effect = candidate
	if effect == null:
		effect = EXPLOSION_ZONE_SCENE.instantiate() as Node2D
		add_child(effect)
		effect.recycle_requested.connect(_recycle_explosion_effect)
	effect.global_position = center
	effect.setup(radius)


func _recycle_hitscan_effect(effect: Node2D) -> void:
	if not is_instance_valid(effect) or pooled_hitscan_effects.has(effect):
		return
	effect.deactivate_for_pool()
	if pooled_hitscan_effects.size() >= MAX_POOLED_HITSCAN_EFFECTS:
		effect.queue_free()
	else:
		pooled_hitscan_effects.append(effect)


func _recycle_explosion_effect(effect: Node2D) -> void:
	if not is_instance_valid(effect) or pooled_explosion_effects.has(effect):
		return
	effect.deactivate_for_pool()
	if pooled_explosion_effects.size() >= MAX_POOLED_EXPLOSION_EFFECTS:
		effect.queue_free()
	else:
		pooled_explosion_effects.append(effect)


func choose_wave_spawn_style(wave: int) -> StringName:
	sync_wave_director_context()
	return wave_director.choose_wave_spawn_style(wave)


func get_wave_duration(wave: int) -> float:
	ensure_wave_director()
	return wave_director.get_wave_duration(wave)


func get_wave_threat_rate(wave: int) -> float:
	ensure_wave_director()
	return wave_director.get_wave_threat_rate(wave)


func get_horde_threat_multiplier(wave: int) -> float:
	ensure_wave_director()
	return wave_director.get_horde_threat_multiplier(wave)


func get_horde_group_size_multiplier(wave: int) -> float:
	ensure_wave_director()
	return wave_director.get_horde_group_size_multiplier(wave)


func get_horde_spawn_delay_multiplier(wave: int) -> float:
	ensure_wave_director()
	return wave_director.get_horde_spawn_delay_multiplier(wave)


func get_enemy_health_multiplier(wave: int, enemy_id: StringName) -> float:
	return GameStats.get_enemy_health_multiplier(wave, enemy_id)


func simulate_director_spawn_counts(
	wave: int,
	round_type: StringName,
	seed: int,
	regenerate_plan := true
) -> Dictionary:
	ensure_wave_director()
	wave_director.enemy_debut_plan = enemy_debut_plan
	wave_director.round_style_plan = round_style_plan
	var simulated_max_rounds := int(GameStats.get_mode(mode_id)["max_rounds"])
	var counts: Dictionary = wave_director.simulate_spawn_counts(
		wave,
		round_type,
		seed,
		mode_id,
		simulated_max_rounds,
		regenerate_plan
	)
	enemy_debut_plan = wave_director.enemy_debut_plan
	round_style_plan = wave_director.round_style_plan
	return counts


func _process_round_director(delta: float) -> void:
	if not round_active or not spawning_active:
		return

	ensure_round_controller()
	var duration_finished: bool = round_controller.advance_time(delta)
	spawn_threat += threat_per_second * threat_continuous_ratio * delta
	threat_chunk_elapsed += delta
	while threat_chunk_interval > 0.0 and threat_chunk_elapsed >= threat_chunk_interval:
		threat_chunk_elapsed -= threat_chunk_interval
		spawn_threat += (
			threat_per_second
			* threat_chunk_interval
			* threat_chunk_ratio
		)
	director_cooldown = maxf(director_cooldown - delta, 0.0)
	process_special_round_events()
	update_round_count()

	if duration_finished:
		stop_timed_spawning()
		return

	if not spawntimer.is_stopped():
		return

	if spawn_schedule.is_empty() and director_cooldown <= 0.0:
		spawn_schedule = build_director_group()
		mobs_left_to_spawn = spawn_schedule.size()

	if not spawn_schedule.is_empty():
		spawntimer.start(0.01)


func stop_timed_spawning() -> void:
	spawning_active = false
	spawn_schedule.clear()
	mobs_left_to_spawn = 0
	spawntimer.stop()
	update_round_count()

	if mobs_alive == 0:
		end_round()


func get_available_enemies(wave: int) -> Array[StringName]:
	sync_wave_director_context()
	var available: Array[StringName] = wave_director.get_available_enemies(wave)
	enemy_debut_plan = wave_director.enemy_debut_plan
	round_style_plan = wave_director.round_style_plan
	return available


func process_special_round_events() -> void:
	if current_round_type not in [ROUND_ELITE, ROUND_GAUNTLET]:
		return

	var final_pack_time := round_duration * FINAL_ELITE_PACK_START_RATIO
	if not final_elite_pack_spawned and round_elapsed >= final_pack_time:
		final_elite_pack_spawned = true
		var final_elite_count := (
			3 if round_number >= 11 else (1 if round_number == 6 else 2)
		)
		var final_escort_count := (
			enemy_rng.randi_range(6, 10)
			if current_round_type == ROUND_GAUNTLET
			else enemy_rng.randi_range(3, 5)
				if round_number == 6
				else enemy_rng.randi_range(4, 7)
		)
		inject_special_spawn_schedule(build_elite_event_schedule(
			final_elite_count,
			final_escort_count,
			VARIANT_HORDE if current_round_type == ROUND_GAUNTLET else VARIANT_NORMAL
		))

	if round_elapsed < next_elite_event_time or round_elapsed >= final_pack_time:
		return

	var elite_count := 1
	var escort_count := enemy_rng.randi_range(3, 6)
	var next_interval_min := ELITE_EVENT_MIN_INTERVAL
	var next_interval_max := ELITE_EVENT_MAX_INTERVAL
	var escort_variant := VARIANT_NORMAL
	if current_round_type == ROUND_GAUNTLET:
		elite_count = enemy_rng.randi_range(1, 3)
		escort_count = enemy_rng.randi_range(4, 8)
		next_interval_min = GAUNTLET_ELITE_MIN_INTERVAL
		next_interval_max = GAUNTLET_ELITE_MAX_INTERVAL
		escort_variant = VARIANT_HORDE
	elif round_number == 6:
		elite_count = 1
		escort_count = enemy_rng.randi_range(2, 4)
	else:
		elite_count = enemy_rng.randi_range(1, 2)

	inject_special_spawn_schedule(build_elite_event_schedule(
		elite_count,
		escort_count,
		escort_variant
	))
	next_elite_event_time += enemy_rng.randf_range(
		next_interval_min,
		next_interval_max
	)


func build_elite_event_schedule(
	elite_count: int,
	escort_count: int,
	escort_variant: StringName
) -> Array[Dictionary]:
	sync_wave_director_context()
	return wave_director.build_elite_event_schedule(
		elite_count,
		escort_count,
		escort_variant
	)


func inject_special_spawn_schedule(schedule: Array[Dictionary]) -> void:
	if schedule.is_empty():
		return
	for index in range(schedule.size() - 1, -1, -1):
		spawn_schedule.push_front(schedule[index])
	mobs_left_to_spawn = spawn_schedule.size()
	spawntimer.stop()
	spawntimer.start(0.01)


func build_director_group() -> Array[Dictionary]:
	sync_wave_director_context()
	var schedule: Array[Dictionary] = wave_director.build_director_group()
	sync_wave_director_style_memory()
	return schedule


func build_debut_opening(wave: int) -> Array[Dictionary]:
	sync_wave_director_context()
	return wave_director.build_debut_opening(wave)


func build_timed_boss_opening() -> Array[Dictionary]:
	sync_wave_director_context()
	return wave_director.build_timed_boss_opening()


func get_spawn_event_director_cost(spawn_event: Dictionary) -> float:
	ensure_wave_director()
	return wave_director.get_spawn_event_director_cost(spawn_event)


func choose_weighted_enemy(available: Array[StringName]) -> StringName:
	sync_wave_director_context()
	return wave_director.choose_weighted_enemy(available)


func get_active_enemy_count(enemy_id: StringName) -> int:
	if not is_inside_tree():
		return 0
	var count := 0
	for mob in get_tree().get_nodes_in_group("mobs"):
		if (
			is_instance_valid(mob)
			and not mob.finished
			and mob.enemy_id == enemy_id
		):
			count += 1
	return count


func _on_mob_reached_end(damage: int) -> void:
	ensure_run_state()
	run_state.take_damage(damage)
	update_lives()
	
	if lives == 0:
		if sandbox_mode:
			mob_finished()
			return
		defeat()
		return

	mob_finished()

func defeat() -> void:
	finish_game("Defeat!\nYou reached round %d." % round_number)

func victory() -> void:
	finish_game("Victory!\nYou completed all %d rounds." % max_rounds)

func finish_game(message: String) -> void:
	ensure_round_controller()
	if not round_controller.finish_game():
		return
	cancel_reinforcement_targeting()
	clear_reinforcement_drops()
	spawning_active = false
	spawn_schedule.clear()
	pending_enemy_spawns.clear()
	mobs_left_to_spawn = 0
	spawntimer.stop()
	clear_active_projectiles()
	shop_open = false
	between_round_shop.hide()
	close_all_tower_menus()
	clear_tower_details()

	ensure_build_controller()
	var pending_tower: Node2D = build_controller.clear_pending_placement()
	if is_instance_valid(pending_tower):
		pending_tower.queue_free()
	
	pause_button.disabled = true
	speed_button.disabled = true
	tower_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_timer_display.text = "Run complete"
	$MainUI/endscreen/VBoxContainer/resultlabel.text = message
	$MainUI/endscreen.visible = true
	
	clear_all_path_followers()
	mobs_alive = 0

func _on_mob_killed(reward: int) -> void:
	var reward_multiplier := 1.0 + get_run_bonus(&"kill_reward")
	add_money(roundi(float(reward) * reward_multiplier))
	mob_finished()


func mob_finished() -> void:
	mobs_alive = maxi(mobs_alive - 1, 0)
	flush_pending_enemy_spawns()

	ensure_round_controller()
	if round_controller.should_finish_round(
		spawning_active,
		mobs_left_to_spawn,
		mobs_alive,
		pending_enemy_spawns.size()
	):
		end_round()


func is_pointer_press_event(event: InputEvent) -> bool:
	return (
		(
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		)
		or (event is InputEventScreenTouch and event.pressed)
	)


func is_pointer_release_event(event: InputEvent) -> bool:
	return (
		(
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and not event.pressed
		)
		or (event is InputEventScreenTouch and not event.pressed)
	)


func is_pointer_drag_event(event: InputEvent) -> bool:
	return (
		event is InputEventScreenDrag
		or (
			event is InputEventMouseMotion
			and event.button_mask & MOUSE_BUTTON_MASK_LEFT != 0
		)
	)


func get_pointer_screen_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		return event.position
	if event is InputEventMouseMotion:
		return event.position
	if event is InputEventScreenTouch:
		return event.position
	if event is InputEventScreenDrag:
		return event.position
	return Vector2.ZERO


func get_pointer_index(event: InputEvent) -> int:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return event.index
	return -1


func begin_placement_drag_candidate(
	kind: StringName,
	slot_index: int,
	screen_position: Vector2,
	pointer_index: int
) -> void:
	if (
		not active_placement_drag_kind.is_empty()
		or not placement_drag_candidate_kind.is_empty()
	):
		return
	placement_drag_candidate_kind = kind
	placement_drag_candidate_slot = slot_index
	placement_drag_pointer_index = pointer_index
	placement_drag_start_screen_position = screen_position


func clear_placement_drag_state() -> void:
	placement_drag_candidate_kind = &""
	placement_drag_candidate_slot = -1
	placement_drag_pointer_index = -1
	active_placement_drag_kind = &""


func pointer_event_matches_drag(event: InputEvent) -> bool:
	return get_pointer_index(event) == placement_drag_pointer_index


func screen_to_placement_world_position(screen_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * (
		screen_position + PLACEMENT_DRAG_PREVIEW_OFFSET
	)


func begin_active_placement_drag(screen_position: Vector2) -> bool:
	var candidate_kind := placement_drag_candidate_kind
	if candidate_kind == DRAG_KIND_TOWER:
		select_tower_build_slot(placement_drag_candidate_slot)
		if not place_mode or not is_instance_valid(tower_to_place):
			clear_placement_drag_state()
			return false
		clear_tower_details(tower_to_place)
	elif candidate_kind == DRAG_KIND_REINFORCEMENT:
		set_build_drawer_open(false)
		begin_reinforcement_targeting()
		if not reinforcement_targeting:
			clear_placement_drag_state()
			return false
	else:
		return false

	active_placement_drag_kind = candidate_kind
	placement_drag_candidate_kind = &""
	placement_drag_world_position = screen_to_placement_world_position(
		screen_position
	)
	update_active_placement_drag_preview()
	return true


func update_active_placement_drag_preview() -> void:
	if (
		active_placement_drag_kind == DRAG_KIND_TOWER
		and place_mode
		and is_instance_valid(tower_to_place)
	):
		var snap := get_tower_build_position(
			placement_drag_world_position,
			pending_tower_type
		)
		tower_to_place.position = snap
		var placement_is_valid := can_place_tower(snap)
		tower_to_place.set_range_preview(true, placement_is_valid)
		var sprite := tower_to_place.get_node("Sprite2D") as CanvasItem
		sprite.modulate = (
			Color(1.0, 1.0, 1.0, 0.5)
			if placement_is_valid
			else Color(1.0, 0.0, 0.0, 0.5)
		)
	elif active_placement_drag_kind == DRAG_KIND_REINFORCEMENT:
		ensure_reinforcement_controller()
		reinforcement_controller.update_preview(placement_drag_world_position)


func finish_active_placement_drag(screen_position: Vector2) -> void:
	placement_drag_world_position = screen_to_placement_world_position(
		screen_position
	)
	update_active_placement_drag_preview()
	var completed_kind := active_placement_drag_kind
	active_placement_drag_kind = &""

	if completed_kind == DRAG_KIND_TOWER:
		if (
			is_instance_valid(tower_to_place)
			and can_place_tower(tower_to_place.position)
		):
			var placed_tower := tower_to_place
			finalize_tower_placement()
			placed_tower._on_confirm_pressed()
		else:
			cancel_pending_tower_placement()
	elif completed_kind == DRAG_KIND_REINFORCEMENT:
		if not deploy_reinforcements(placement_drag_world_position):
			cancel_reinforcement_targeting()
	clear_placement_drag_state()


func handle_placement_drag_input(event: InputEvent) -> bool:
	if (
		not active_placement_drag_kind.is_empty()
		and pointer_event_matches_drag(event)
	):
		if is_pointer_drag_event(event):
			placement_drag_world_position = screen_to_placement_world_position(
				get_pointer_screen_position(event)
			)
			update_active_placement_drag_preview()
			return true
		if is_pointer_release_event(event):
			finish_active_placement_drag(get_pointer_screen_position(event))
			return true

	if (
		placement_drag_candidate_kind.is_empty()
		or not pointer_event_matches_drag(event)
	):
		return false
	if is_pointer_drag_event(event):
		var screen_position := get_pointer_screen_position(event)
		if screen_position.distance_to(
			placement_drag_start_screen_position
		) >= PLACEMENT_DRAG_THRESHOLD:
			return begin_active_placement_drag(screen_position)
	if is_pointer_release_event(event):
		placement_drag_candidate_kind = &""
		placement_drag_candidate_slot = -1
		placement_drag_pointer_index = -1
	return false


func _input(event: InputEvent) -> void:
	cancel_sidebar_confirmation_on_other_press(event)
	if handle_placement_drag_input(event):
		get_viewport().set_input_as_handled()
		return
	ensure_build_controller()
	if not is_instance_valid(build_controller.manual_targeting_tower):
		build_controller.clear_invalid_manual_target()
		return
	if (
		event.is_action_pressed("ui_cancel")
		or (
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_RIGHT
			and event.pressed
		)
	):
		get_viewport().set_input_as_handled()
		cancel_manual_tower_targeting()
		return
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		get_viewport().set_input_as_handled()
		var targeting_tower: Node2D = build_controller.manual_targeting_tower
		if targeting_tower.confirm_manual_target_position(get_global_mouse_position()):
			finish_manual_tower_targeting(targeting_tower)


func cancel_sidebar_confirmation_on_other_press(event: InputEvent) -> void:
	if sidebar_confirmation_action < 0:
		return
	var press_position := Vector2.ZERO
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		press_position = event.position
	elif event is InputEventScreenTouch and event.pressed:
		press_position = event.position
	else:
		return

	var confirmation_button: Button = (
		tower_upgrade_button
		if sidebar_confirmation_action == BaseTower.MenuAction.UPGRADE
		else tower_sell_button
	)
	if (
		is_instance_valid(confirmation_button)
		and confirmation_button.get_global_rect().has_point(press_position)
	):
		return
	cancel_sidebar_confirmation()

func _unhandled_input(event: InputEvent) -> void:
	if enemy_strip_expanded:
		if event.is_action_pressed("ui_cancel"):
			set_enemy_intel_expanded(false)
			get_viewport().set_input_as_handled()
			return
		var pointer_position := Vector2.ZERO
		var is_pointer_press := false
		if event is InputEventMouseButton:
			is_pointer_press = event.pressed
			pointer_position = event.position
		elif event is InputEventScreenTouch:
			is_pointer_press = event.pressed
			pointer_position = event.position
		if (
			is_pointer_press
			and not enemy_strip.get_global_rect().has_point(pointer_position)
			and not enemy_toggle_button.get_global_rect().has_point(pointer_position)
		):
			set_enemy_intel_expanded(false)
			get_viewport().set_input_as_handled()
			return
	if reinforcement_targeting:
		if (
			event.is_action_pressed("ui_cancel")
			or (
				event is InputEventMouseButton
				and event.button_index == MOUSE_BUTTON_RIGHT
				and event.pressed
			)
		):
			get_viewport().set_input_as_handled()
			cancel_reinforcement_targeting()
			return
		if (
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		):
			get_viewport().set_input_as_handled()
			deploy_reinforcements(get_global_mouse_position())
			return

	if is_selecting_path_relic_tower():
		return
	if event.is_action_pressed("ui_cancel") and not game_ended:
		get_viewport().set_input_as_handled()
		open_pause_menu()
		return

	if shop_open:
		return

	if (
		(
			not selected_relic_hud_id.is_empty()
			or not selected_enemy_hud_id.is_empty()
		)
		and (
			(
				event is InputEventMouseButton
				and event.button_index == MOUSE_BUTTON_LEFT
				and event.pressed
			)
			or (event is InputEventScreenTouch and event.pressed)
		)
	):
		clear_relic_hud_selection()
		clear_enemy_hud_selection()

	if (
		place_mode
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		finalize_tower_placement()
		return

	if event is InputEventMouseButton and event.pressed and not build_mode:
		close_all_tower_menus()
		set_build_drawer_open(false)

func can_place_tower(pos: Vector2) -> bool:
	if not is_instance_valid(tower_to_place):
		return false

	var tower_id: StringName = tower_to_place.tower_id
	if not build_controller.can_place_tower_on_grid(
		pos,
		tower_id,
		get_build_bounds(),
		is_build_cell_blocked_by_path
	):
		return false

	var space_state = get_world_2d().direct_space_state
	var shape_node := tower_to_place.get_node("clickarea/CollisionShape2D")
	var shape: Shape2D = shape_node.shape
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.collision_mask = BUILD_BLOCKER_COLLISION_MASK
	var clickarea := tower_to_place.get_node("clickarea")
	params.transform = Transform2D(0, pos + clickarea.position)
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var result = space_state.intersect_shape(params)
	return result.is_empty()

func finalize_tower_placement() -> void:
	if not is_instance_valid(tower_to_place):
		return
	var pos := tower_to_place.position
	if not can_place_tower(pos):
		return
	build_controller.await_confirmation()
	tower_to_place.position = pos
	tower_to_place.get_node("towerconfirm").visible = true
	tower_list.deselect_all()


func world_to_build_cell(world_position: Vector2) -> Vector2i:
	ensure_build_controller()
	return build_controller.world_to_build_cell(world_position)


func get_tower_footprint(tower_id: StringName) -> Vector2i:
	ensure_build_controller()
	return build_controller.get_tower_footprint(tower_id)


func get_tower_build_position(world_position: Vector2, tower_id: StringName) -> Vector2:
	ensure_build_controller()
	return build_controller.get_tower_build_position(world_position, tower_id)


func get_tower_build_cells(tower_position: Vector2, tower_id: StringName) -> Array[Vector2i]:
	ensure_build_controller()
	var cells: Array[Vector2i] = build_controller.get_tower_build_cells(
		tower_position,
		tower_id
	)
	return cells


func get_build_cell_center(cell: Vector2i) -> Vector2:
	ensure_build_controller()
	return build_controller.get_build_cell_center(cell)


func is_build_cell_in_playable_area(cell: Vector2i) -> bool:
	ensure_build_controller()
	return build_controller.is_build_cell_in_bounds(cell, get_build_bounds())


func get_build_bounds() -> Rect2:
	if active_map != null:
		return active_map.get_build_bounds()
	return Rect2(Vector2.ZERO, get_viewport_rect().size)


func get_playable_right_edge() -> float:
	if active_map != null:
		return active_map.get_build_bounds().end.x
	return playable_map_width


func is_world_position_in_playable_area(world_position: Vector2) -> bool:
	if active_map != null:
		return active_map.contains_world_position(world_position)
	return Rect2(Vector2.ZERO, get_viewport_rect().size).has_point(world_position)


func _align_sidebar_to_build_grid() -> void:
	var viewport_width := get_viewport_rect().size.x
	playable_map_width = floorf(viewport_width / BUILD_CELL_SIZE) * BUILD_CELL_SIZE
	if active_map != null:
		active_map.configure_runtime_build_bounds(Rect2(
			Vector2.ZERO,
			Vector2(playable_map_width, get_viewport_rect().size.y)
		))
	layout_tower_fan_buttons()
	update_context_dock_layout()
	update_compact_hud_strip_layout()

func is_build_cell_blocked_by_path(cell: Vector2i) -> bool:
	if active_map == null:
		return false
	var cell_center := get_build_cell_center(cell)
	return active_map.is_point_blocked_by_path(cell_center)


func get_path_cell_positions_near(
	origin: Vector2,
	maximum_radius: float
) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if maximum_radius <= 0.0:
		return positions
	if active_map == null or get_enemy_paths().is_empty():
		return positions
	ensure_build_controller()
	return build_controller.get_path_cell_positions_near(
		origin,
		maximum_radius,
		get_build_bounds(),
		active_map
	)


func is_build_cell_occupied(cell: Vector2i) -> bool:
	ensure_build_controller()
	return build_controller.is_build_cell_occupied(cell)


func reserve_tower_build_cells(tower: Node2D) -> void:
	ensure_build_controller()
	build_controller.reserve_tower_build_cells(tower)


func release_tower_build_cells(tower: Node2D) -> void:
	ensure_build_controller()
	build_controller.release_tower_build_cells(tower)

func _on_tower_confirmed(tower: Node2D) -> void:
	reserve_tower_build_cells(tower)
	ensure_build_controller()
	var placement_cost: int = build_controller.pending_tower_cost
	var was_contraband: bool = build_controller.pending_tower_is_contraband
	build_controller.clear_pending_placement()
	run_state.spend_money(placement_cost)
	if was_contraband and run_state.consume_contraband(tower.tower_id):
		populate_tower_list()
	update_money()
	update_play_pause_button()
	show_tower_details(tower)
	call_deferred("refresh_placed_tower_stats")

func _on_tower_cancelled(tower: Node2D) -> void:
	clear_tower_details(tower)
	ensure_build_controller()
	build_controller.clear_pending_placement()
	update_play_pause_button()


func _on_tower_sold(tower: Node2D) -> void:
	release_tower_build_cells(tower)
	call_deferred("refresh_placed_tower_stats")

func start_build_tower() -> void:
	if game_ended or shop_open or build_mode or pending_tower_type.is_empty():
		return
	close_all_tower_menus()

	var pending_tower: Node2D = TOWER_SCENE.instantiate()
	pending_tower.main = self
	pending_tower.tower_id = pending_tower_type
	pending_tower.purchase_price = pending_tower_cost
	pending_tower.tower_confirmed.connect(_on_tower_confirmed)
	pending_tower.tower_cancelled.connect(_on_tower_cancelled)
	pending_tower.tower_sold.connect(_on_tower_sold)
	build_controller.begin_placement(pending_tower)
	update_play_pause_button()
	add_child(pending_tower)
	show_tower_details(pending_tower)


func can_select_tower() -> bool:
	return not game_ended and not shop_open and not build_mode


func can_purchase_tower_evolution() -> bool:
	return (
		not game_ended
		and not shop_open
		and not is_selecting_path_relic_tower()
	)

@warning_ignore("unused_parameter")
func _on_item_list_item_selected(index: int) -> void:
	select_tower_build_slot(index)


func select_tower_build_slot(index: int) -> void:
	if game_ended or shop_open or is_selecting_path_relic_tower():
		tower_list.deselect_all()
		return
	
	var selected_tower_id := get_sidebar_tower_id(index)
	if selected_tower_id.is_empty():
		tower_list.deselect_all()
		return

	var selected_is_contraband := (
		not sandbox_mode and index == CONTRABAND_SLOT_INDEX
	)
	if build_mode:
		if selected_tower_id == pending_tower_type:
			cancel_pending_tower_placement()
			return
		cancel_pending_tower_placement()

	var cost := get_tower_build_cost(selected_tower_id, selected_is_contraband)
	
	if money >= cost:
		ensure_build_controller()
		build_controller.begin_pending_tower(
			selected_tower_id,
			cost,
			selected_is_contraband
		)
		start_build_tower()
		set_build_drawer_open(false)
		tower_list.select(index)
	else:
		tower_list.deselect_all()

func _on_restartbutton_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
	
func _on_quitbutton_pressed() -> void:
	SessionState.return_to_main_menu()


func _on_speed_button_pressed() -> void:
	game_speed = 2.0 if is_equal_approx(game_speed, 1.0) else 1.0
	Engine.time_scale = game_speed
	update_speed_button()


func update_speed_button() -> void:
	var speed_text := "%dx" % int(game_speed)
	speed_button.text = speed_text
	speed_button.tooltip_text = "Game Speed: %s" % speed_text


func _on_pause_button_pressed() -> void:
	if game_ended or shop_open or is_selecting_path_relic_tower():
		return
	if round_active:
		open_pause_menu()
	else:
		start_round()


func open_pause_menu() -> void:
	ensure_round_controller()
	ensure_wave_director()
	var enemy_round := clampi(
		round_controller.get_displayed_round(),
		1,
		max_rounds
	)
	var placed_towers: Array[Node] = []
	for tower in get_tree().get_nodes_in_group("towers"):
		if (
			is_instance_valid(tower)
			and not tower.is_queued_for_deletion()
			and bool(tower.get("is_placed"))
		):
			placed_towers.append(tower)
	pause_menu.open_menu(
		owned_shop_items,
		placed_towers,
		wave_director.get_available_enemies(enemy_round),
		enemy_round
	)


func update_play_pause_button() -> void:
	if game_ended:
		pause_button.disabled = true
		return
	if round_active:
		pause_button.text = "II"
		pause_button.tooltip_text = "Pause"
		pause_button.disabled = false
	else:
		pause_button.text = "▶"
		pause_button.tooltip_text = "Start Round %d" % mini(
			round_number + 1,
			max_rounds
		)
		pause_button.disabled = (
			shop_open or build_mode or is_selecting_path_relic_tower()
		)
