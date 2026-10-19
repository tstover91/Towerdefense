extends Node

const MODE_SELECT_SCENE := "res://prototype/prototype_mode_select.tscn"
const ArenaLayoutScript = preload("res://siege_prototype/siege_arena_layout.gd")
const RunStateScript = preload("res://siege_prototype/siege_run_state.gd")
const TierCatalogScript = preload("res://siege_prototype/siege_town_hall_catalog.gd")
const StructureCatalogScript = preload("res://siege_prototype/siege_structure_catalog.gd")

var run_state: RefCounted
var build_cycle_index := 0
var pending_purchase_kind: StringName
var pending_purchase_cost := 0


func _ready() -> void:
	$HUD/TopBar/BackButton.pressed.connect(_return_to_mode_select)
	$HUD/BottomBar/AttackButton.pressed.connect(_start_attack)
	$HUD/BottomBar/RebuildButton.pressed.connect(_new_run)
	$HUD/BottomBar/BuildButton.pressed.connect(_cycle_build)
	$HUD/BottomBar/UpgradeButton.pressed.connect(_upgrade_selected)
	$HUD/BottomBar/SpeedButton.pressed.connect(_toggle_speed)
	$HUD/BottomBar/ViewButton.pressed.connect(_reset_view)
	$SiegeCombat.status_changed.connect(_on_status_changed)
	$SiegeCombat.wave_started.connect(_on_wave_started)
	$SiegeCombat.wave_finished.connect(_on_wave_finished)
	$SiegeBoard.edit_status_changed.connect(_on_status_changed)
	$SiegeBoard.selected_structure_changed.connect(_on_selection_changed)
	$SiegeBoard.structure_added.connect(_on_structure_added)
	_new_run()
	$HUD/TopBar/BackButton.grab_focus()


func _return_to_mode_select() -> void:
	get_tree().change_scene_to_file(MODE_SELECT_SCENE)


func _new_run() -> void:
	$SiegeCombat.reset_fortress()
	run_state = RunStateScript.new()
	run_state.blueprint = ArenaLayoutScript.new().get_run_initial_blueprint()
	$SiegeBoard.load_blueprint(run_state.blueprint)
	$SiegeBoard.set_edit_mode(true)
	pending_purchase_kind = &""
	pending_purchase_cost = 0
	build_cycle_index = 0
	$HUD/BottomBar/AttackButton.disabled = false
	_set_build_controls_enabled(true)
	_on_status_changed("TH1 begins · tap the Cannon, upgrade it for 3 bolts, then start battle A")
	_refresh_hud()


func _start_attack() -> void:
	if run_state.completed:
		return
	_cancel_pending_purchase()
	var blueprint: Array[Dictionary] = $SiegeBoard.capture_current_blueprint()
	run_state.blueprint = blueprint.duplicate(true)
	run_state.begin_combat(blueprint)
	$SiegeBoard.set_edit_mode(false)
	var wave: Array[Dictionary] = TierCatalogScript.build_wave(run_state.town_hall, run_state.battle_index)
	var budget := TierCatalogScript.get_wave_housing(wave)
	$SiegeCombat.start_wave(wave, "TH%d-%s · %d housing" % [run_state.town_hall, run_state.get_battle_letter(), budget])


func _cycle_build() -> void:
	if $SiegeCombat.active or run_state.completed:
		return
	var kinds: Array[StringName] = TierCatalogScript.get_unlocked_build_kinds(run_state.town_hall)
	if kinds.is_empty():
		_on_status_changed("No additional defenses unlock at TH1")
		return
	for offset in kinds.size():
		var index := (build_cycle_index + offset) % kinds.size()
		var kind: StringName = kinds[index]
		var cap := TierCatalogScript.get_count_cap(run_state.town_hall, kind)
		if $SiegeBoard.get_structure_count(kind) >= cap:
			continue
		var cost := StructureCatalogScript.get_build_cost(kind)
		if run_state.currency < cost:
			continue
		build_cycle_index = (index + 1) % kinds.size()
		pending_purchase_kind = kind
		pending_purchase_cost = cost
		$SiegeBoard.begin_build(kind)
		$HUD/BottomBar/BuildButton.text = "PLACE %s · %d" % [_short_name(kind), cost]
		return
	_on_status_changed("No affordable unlocked building slots · win a battle or upgrade instead")


func _on_structure_added(structure: Node) -> void:
	if pending_purchase_kind == &"" or structure.kind != pending_purchase_kind:
		return
	if not run_state.spend(pending_purchase_cost):
		return
	run_state.blueprint = $SiegeBoard.capture_current_blueprint()
	pending_purchase_kind = &""
	pending_purchase_cost = 0
	$HUD/BottomBar/BuildButton.text = "BUILD"
	_refresh_hud()


func _upgrade_selected() -> void:
	if $SiegeCombat.active or run_state.completed:
		return
	_cancel_pending_purchase()
	var structure: Node = $SiegeBoard.get_selected_structure()
	if structure == null:
		_on_status_changed("Select a defense or wall first")
		return
	if structure.kind == &"command_core":
		_on_status_changed("The Command Core advances after battle B")
		return
	var cap := TierCatalogScript.get_level_cap(run_state.town_hall, structure.kind)
	var next_level: int = structure.level + 1
	if cap <= 0 or next_level > cap:
		_on_status_changed("%s is already at its TH%d cap" % [String(structure.definition.get("display_name", structure.kind)), run_state.town_hall])
		return
	var cost := StructureCatalogScript.get_upgrade_cost(structure.kind, next_level)
	if cost < 0 or not run_state.spend(cost):
		_on_status_changed("Need %d bolts for level %d" % [cost, next_level])
		return
	$SiegeBoard.upgrade_structure(structure.structure_id, next_level)
	run_state.blueprint = $SiegeBoard.capture_current_blueprint()
	_on_status_changed("%s upgraded to level %d for %d bolts" % [String(structure.definition.get("display_name", structure.kind)), next_level, cost])
	_refresh_hud()


func _toggle_speed() -> void:
	var next_speed := 2.0 if is_equal_approx($SiegeCombat.combat_speed, 1.0) else 1.0
	$SiegeCombat.set_combat_speed(next_speed)
	$HUD/BottomBar/SpeedButton.text = "%d×" % int(next_speed)


func _reset_view() -> void:
	$SiegeBoard.reset_view()


func _on_status_changed(text: String) -> void:
	$HUD/BottomBar/Status.text = text


func _on_selection_changed(structure: Node) -> void:
	if structure == null:
		$HUD/BottomBar/UpgradeButton.text = "UPGRADE"
		return
	var next_level: int = structure.level + 1
	var cost := StructureCatalogScript.get_upgrade_cost(structure.kind, next_level)
	$HUD/BottomBar/UpgradeButton.text = "UP L%d · %d" % [next_level, cost] if cost >= 0 else "MAX / LOCKED"


func _on_wave_started() -> void:
	$HUD/BottomBar/AttackButton.disabled = true
	_set_build_controls_enabled(false)
	_refresh_hud()


func _on_wave_finished(result: StringName) -> void:
	$SiegeCombat.clear_attackers()
	$SiegeBoard.set_edit_mode(true)
	if result == &"defenders":
		var reward := TierCatalogScript.get_reward(run_state.town_hall, run_state.battle_index)
		var outcome: Dictionary = run_state.record_victory(reward, run_state.precombat_blueprint)
		if bool(outcome.get("tier_advanced", false)):
			_upgrade_command_core_in_blueprint(run_state.blueprint, run_state.town_hall)
		$SiegeBoard.load_blueprint(run_state.blueprint)
		if run_state.completed:
			_on_status_changed("RUN COMPLETE · TH1-TH3 survived · %d bolts banked" % run_state.currency)
		else:
			_on_status_changed("Defense held · +%d bolts · prepare TH%d-%s" % [reward, run_state.town_hall, run_state.get_battle_letter()])
	else:
		$SiegeBoard.load_blueprint(run_state.record_defeat())
		_on_status_changed("Base destroyed · no bolts lost · layout restored for a safe retry")
	$HUD/BottomBar/AttackButton.disabled = run_state.completed
	_set_build_controls_enabled(not run_state.completed)
	_refresh_hud()


func _upgrade_command_core_in_blueprint(blueprint: Array[Dictionary], town_hall: int) -> void:
	for entry in blueprint:
		if StringName(entry.get("kind", &"")) == &"command_core":
			entry["level"] = town_hall
			return


func _cancel_pending_purchase() -> void:
	pending_purchase_kind = &""
	pending_purchase_cost = 0
	$SiegeBoard.cancel_build()
	$HUD/BottomBar/BuildButton.text = "BUILD"


func _set_build_controls_enabled(enabled: bool) -> void:
	$HUD/BottomBar/BuildButton.disabled = not enabled
	$HUD/BottomBar/UpgradeButton.disabled = not enabled


func _refresh_hud() -> void:
	var budget := TierCatalogScript.get_army_budget(run_state.town_hall, run_state.battle_index)
	$HUD/TopBar/PhaseBadge.text = "TH%d · %s\nROUND %d / 6" % [run_state.town_hall, run_state.get_battle_letter(), run_state.get_round_number()]
	$HUD/TopBar/Currency.text = "%d BOLTS\n%d HOUSING" % [run_state.currency, budget]
	$HUD/BottomBar/AttackButton.text = "ATTACK %s" % run_state.get_battle_letter()


func _short_name(kind: StringName) -> String:
	match kind:
		&"archer_tower": return "ARCHER"
		&"mortar": return "MORTAR"
		&"wall": return "WALL"
		_: return "CANNON"
