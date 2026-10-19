extends Node

const MODE_SELECT_SCENE := "res://prototype/prototype_mode_select.tscn"
const ArenaLayoutScript = preload("res://siege_prototype/siege_arena_layout.gd")
const RunStateScript = preload("res://siege_prototype/siege_run_state.gd")
const TierCatalogScript = preload("res://siege_prototype/siege_town_hall_catalog.gd")
const StructureCatalogScript = preload("res://siege_prototype/siege_structure_catalog.gd")
const SHOP_KINDS: Array[StringName] = [&"cannon", &"archer_tower", &"mortar", &"wall"]

var run_state: RefCounted
var pending_purchase_kind: StringName
var pending_purchase_cost := 0


func _ready() -> void:
	$HUD/TopBar/BackButton.pressed.connect(_return_to_mode_select)
	$HUD/BottomBar/AttackButton.pressed.connect(_start_attack)
	$HUD/BottomBar/RebuildButton.pressed.connect(_new_run)
	$HUD/BottomBar/SpeedButton.pressed.connect(_toggle_speed)
	$HUD/BottomBar/ViewButton.pressed.connect(_reset_view)
	$HUD/ShopButton.pressed.connect(_toggle_shop)
	$HUD/BuildTray/Margin/Stack/Header/CloseButton.pressed.connect(_close_shop)
	$HUD/BuildTray/Margin/Stack/Cards/CannonCard.pressed.connect(func() -> void: _select_build_kind(&"cannon"))
	$HUD/BuildTray/Margin/Stack/Cards/ArcherCard.pressed.connect(func() -> void: _select_build_kind(&"archer_tower"))
	$HUD/BuildTray/Margin/Stack/Cards/MortarCard.pressed.connect(func() -> void: _select_build_kind(&"mortar"))
	$HUD/BuildTray/Margin/Stack/Cards/WallCard.pressed.connect(func() -> void: _select_build_kind(&"wall"))
	$HUD/PlacementPanel/Margin/Actions/CancelButton.pressed.connect(_cancel_pending_purchase)
	$HUD/PlacementPanel/Margin/Actions/ConfirmButton.pressed.connect(_confirm_build)
	$HUD/SelectionPanel/Margin/Actions/UpgradeButton.pressed.connect(_upgrade_selected)
	$SiegeCombat.status_changed.connect(_on_status_changed)
	$SiegeCombat.wave_started.connect(_on_wave_started)
	$SiegeCombat.wave_finished.connect(_on_wave_finished)
	$SiegeBoard.edit_status_changed.connect(_on_status_changed)
	$SiegeBoard.selected_structure_changed.connect(_on_selection_changed)
	$SiegeBoard.structure_added.connect(_on_structure_added)
	$SiegeBoard.build_preview_changed.connect(_on_build_preview_changed)
	$SiegeBoard.wall_extension_requested.connect(_confirm_build)
	$SiegeBoard.view_transform_changed.connect(_on_view_transform_changed)
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
	_hide_context_panels()
	$HUD/BottomBar/AttackButton.disabled = false
	_set_build_controls_enabled(true)
	_on_status_changed("Tap Shop to build · tap a structure for its Upgrade button")
	_refresh_hud()


func _start_attack() -> void:
	if run_state.completed:
		return
	_cancel_pending_purchase()
	_close_shop()
	$HUD/SelectionPanel.visible = false
	var blueprint: Array[Dictionary] = $SiegeBoard.capture_current_blueprint()
	run_state.blueprint = blueprint.duplicate(true)
	run_state.begin_combat(blueprint)
	$SiegeBoard.set_edit_mode(false)
	var wave: Array[Dictionary] = TierCatalogScript.build_wave(run_state.town_hall, run_state.battle_index)
	var budget := TierCatalogScript.get_wave_housing(wave)
	$SiegeCombat.start_wave(wave, "TH%d-%s · %d housing" % [run_state.town_hall, run_state.get_battle_letter(), budget])


func _toggle_shop() -> void:
	if $SiegeCombat.active or run_state.completed:
		return
	if $HUD/BuildTray.visible:
		_close_shop()
		return
	_cancel_pending_purchase()
	$HUD/SelectionPanel.visible = false
	_refresh_shop_cards()
	$HUD/BuildTray.visible = true
	_on_status_changed("Choose a building · each card shows cost and built limit")


func _close_shop() -> void:
	$HUD/BuildTray.visible = false


func _select_build_kind(kind: StringName) -> void:
	if $SiegeCombat.active or run_state.completed:
		return
	var cap: int = TierCatalogScript.get_count_cap(run_state.town_hall, kind)
	var built: int = $SiegeBoard.get_structure_count(kind)
	var cost: int = StructureCatalogScript.get_build_cost(kind)
	if cap <= 0:
		_on_status_changed("%s unlocks at a later Town Hall" % _display_name(kind))
		return
	if built >= cap:
		_on_status_changed("All %s slots are already built" % _display_name(kind))
		return
	if run_state.currency < cost:
		_on_status_changed("Need %d Gold to build %s" % [cost, _display_name(kind)])
		return
	pending_purchase_kind = kind
	pending_purchase_cost = cost
	$SiegeBoard.begin_build(kind)
	$HUD/BuildTray.visible = false
	$HUD/SelectionPanel.visible = false
	$HUD/PlacementPanel.visible = true
	var price := "FREE" if cost == 0 else "%d GOLD" % cost
	$HUD/PlacementPanel/Margin/Actions/PlacementLabel.text = "%s · %s\nDRAG TO MOVE" % [_display_name(kind).to_upper(), price]
	$HUD/PlacementPanel/Margin/Actions/ConfirmButton.disabled = true
	$HUD/PlacementPanel/Margin/Actions/ConfirmButton.visible = true
	$HUD/PlacementPanel/Margin/Actions/ConfirmButton.text = "✓"


func _confirm_build() -> void:
	if pending_purchase_kind == &"":
		return
	if not $SiegeBoard.confirm_pending_build():
		_on_status_changed("Tap a valid empty position before confirming")


func _on_build_preview_changed(_kind: StringName, cell: Vector2i, can_confirm: bool) -> void:
	$HUD/PlacementPanel/Margin/Actions/ConfirmButton.disabled = not can_confirm
	if cell.x >= 0:
		_position_placement_panel($SiegeBoard.get_build_preview_screen_rect())


func _on_structure_added(structure: Node) -> void:
	if pending_purchase_kind == &"" or structure.kind != pending_purchase_kind:
		return
	var placed_kind: StringName = pending_purchase_kind
	if not run_state.spend(pending_purchase_cost):
		return
	run_state.blueprint = $SiegeBoard.capture_current_blueprint()
	pending_purchase_kind = &""
	pending_purchase_cost = 0
	$HUD/PlacementPanel.visible = false
	_refresh_hud()
	if placed_kind == &"wall" and $SiegeBoard.get_structure_count(&"wall") < TierCatalogScript.get_count_cap(run_state.town_hall, &"wall"):
		$HUD/SelectionPanel.visible = false
		call_deferred("_continue_wall_placement", structure.grid_cell)
	else:
		_on_selection_changed(structure)


func _continue_wall_placement(cell: Vector2i) -> void:
	if not $SiegeCombat.active and not run_state.completed:
		pending_purchase_kind = &"wall"
		pending_purchase_cost = StructureCatalogScript.get_build_cost(&"wall")
		if $SiegeBoard.is_wall_chain_active():
			$SiegeBoard.advance_wall_chain(cell)
		else:
			$SiegeBoard.begin_wall_chain(cell)
		$HUD/PlacementPanel.visible = true
		$HUD/PlacementPanel/Margin/Actions/PlacementLabel.text = "WALL ROW\nTap a green arrow to extend"
		$HUD/PlacementPanel/Margin/Actions/ConfirmButton.visible = false
		_position_placement_panel($SiegeBoard.cell_rect(cell))


func _on_view_transform_changed() -> void:
	if not $HUD/PlacementPanel.visible:
		return
	if $SiegeBoard.is_wall_chain_active():
		var focus_cell: Vector2i = $SiegeBoard.get_wall_chain_focus_cell()
		if focus_cell.x >= 0:
			_position_placement_panel($SiegeBoard.cell_rect(focus_cell))
	else:
		_position_placement_panel($SiegeBoard.get_build_preview_screen_rect())


func _position_placement_panel(target_rect: Rect2) -> void:
	if target_rect.size == Vector2.ZERO:
		return
	var panel: Control = $HUD/PlacementPanel
	var panel_size := panel.size
	if panel_size.x <= 1.0:
		panel_size = Vector2(390.0, 68.0)
	var viewport_size := get_viewport().get_visible_rect().size
	var target := Vector2(target_rect.get_center().x - panel_size.x * 0.5, target_rect.position.y - panel_size.y - 12.0)
	if target.y < 58.0:
		target.y = target_rect.end.y + 12.0
	target.x = clampf(target.x, 8.0, maxf(viewport_size.x - panel_size.x - 8.0, 8.0))
	target.y = clampf(target.y, 58.0, maxf(viewport_size.y - panel_size.y - 8.0, 58.0))
	panel.position = target


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
		_on_status_changed("%s is already at its TH%d cap" % [_display_name(structure.kind), run_state.town_hall])
		return
	var cost := StructureCatalogScript.get_upgrade_cost(structure.kind, next_level)
	if cost < 0 or not run_state.spend(cost):
		_on_status_changed("Need %d Gold for level %d" % [cost, next_level])
		return
	$SiegeBoard.upgrade_structure(structure.structure_id, next_level)
	run_state.blueprint = $SiegeBoard.capture_current_blueprint()
	_on_status_changed("%s upgraded to level %d for %d Gold" % [_display_name(structure.kind), next_level, cost])
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
	if structure == null or $SiegeCombat.active or pending_purchase_kind != &"":
		$HUD/SelectionPanel.visible = false
		return
	$HUD/BuildTray.visible = false
	$HUD/SelectionPanel.visible = true
	$HUD/SelectionPanel/Margin/Actions/SelectedLabel.text = "%s · LEVEL %d" % [_display_name(structure.kind).to_upper(), structure.level]
	var button: Button = $HUD/SelectionPanel/Margin/Actions/UpgradeButton
	if structure.kind == &"command_core":
		button.text = "UPGRADES AFTER B"
		button.disabled = true
		return
	var next_level: int = structure.level + 1
	var cap := TierCatalogScript.get_level_cap(run_state.town_hall, structure.kind)
	var cost := StructureCatalogScript.get_upgrade_cost(structure.kind, next_level)
	if next_level > cap or cost < 0:
		button.text = "MAX FOR TH%d" % run_state.town_hall
		button.disabled = true
	else:
		button.text = "UPGRADE TO L%d · %d GOLD" % [next_level, cost]
		button.disabled = run_state.currency < cost


func _on_wave_started() -> void:
	_hide_context_panels()
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
			_on_status_changed("RUN COMPLETE · TH2-TH3 survived · %d Gold banked" % run_state.currency)
		else:
			_on_status_changed("Defense held · +%d Gold · prepare TH%d-%s" % [reward, run_state.town_hall, run_state.get_battle_letter()])
	else:
		$SiegeBoard.load_blueprint(run_state.record_defeat())
		_on_status_changed("Base destroyed · no Gold lost · layout restored for a safe retry")
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
	$HUD/PlacementPanel.visible = false


func _hide_context_panels() -> void:
	$HUD/BuildTray.visible = false
	$HUD/PlacementPanel.visible = false
	$HUD/SelectionPanel.visible = false


func _set_build_controls_enabled(enabled: bool) -> void:
	$HUD/ShopButton.disabled = not enabled
	$HUD/SelectionPanel/Margin/Actions/UpgradeButton.disabled = not enabled


func _refresh_hud() -> void:
	var budget := TierCatalogScript.get_army_budget(run_state.town_hall, run_state.battle_index)
	$HUD/TopBar/PhaseBadge.text = "TH%d · %s\nROUND %d / 4" % [run_state.town_hall, run_state.get_battle_letter(), run_state.get_round_number()]
	$HUD/TopBar/Currency.text = "%d GOLD\n%d HOUSING" % [run_state.currency, budget]
	$HUD/BottomBar/AttackButton.text = "ATTACK %s" % run_state.get_battle_letter()
	_refresh_shop_cards()
	var selected: Node = $SiegeBoard.get_selected_structure()
	if selected != null and $HUD/SelectionPanel.visible:
		_on_selection_changed(selected)


func _refresh_shop_cards() -> void:
	if run_state == null:
		return
	for kind in SHOP_KINDS:
		var card: Button = _card_for_kind(kind)
		var cap: int = TierCatalogScript.get_count_cap(run_state.town_hall, kind)
		var built: int = $SiegeBoard.get_structure_count(kind)
		var cost: int = StructureCatalogScript.get_build_cost(kind)
		if cap <= 0:
			card.text = "%s\nUNLOCKS TH3" % _display_name(kind).to_upper()
			card.disabled = true
		elif built >= cap:
			card.text = "%s\nBUILT %d / %d · MAX" % [_display_name(kind).to_upper(), built, cap]
			card.disabled = true
		else:
			var price: String = "FREE" if cost == 0 else "%d GOLD" % cost
			card.text = "%s\n%s · BUILT %d / %d" % [_display_name(kind).to_upper(), price, built, cap]
			card.disabled = run_state.currency < cost


func _card_for_kind(kind: StringName) -> Button:
	match kind:
		&"archer_tower": return $HUD/BuildTray/Margin/Stack/Cards/ArcherCard
		&"mortar": return $HUD/BuildTray/Margin/Stack/Cards/MortarCard
		&"wall": return $HUD/BuildTray/Margin/Stack/Cards/WallCard
		_: return $HUD/BuildTray/Margin/Stack/Cards/CannonCard


func _display_name(kind: StringName) -> String:
	return String(StructureCatalogScript.get_definition(kind, 1).get("display_name", kind))
