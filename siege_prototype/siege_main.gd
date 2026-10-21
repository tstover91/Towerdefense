extends Node

const MODE_SELECT_SCENE := "res://prototype/prototype_mode_select.tscn"
const ArenaLayoutScript = preload("res://siege_prototype/siege_arena_layout.gd")
const RunStateScript = preload("res://siege_prototype/siege_run_state.gd")
const TierCatalogScript = preload("res://siege_prototype/siege_town_hall_catalog.gd")
const StructureCatalogScript = preload("res://siege_prototype/siege_structure_catalog.gd")
const AttackerCatalogScript = preload("res://siege_prototype/siege_attacker_catalog.gd")
const WallPlanCatalogScript = preload("res://siege_prototype/siege_wall_plan_catalog.gd")
const SHOP_KINDS: Array[StringName] = [&"cannon", &"archer_tower", &"mortar", &"air_defense", &"wizard_tower", &"wall"]

var run_state: RefCounted
var pending_purchase_kind: StringName
var pending_purchase_cost := 0
var pending_wall_plan_id: StringName


func _ready() -> void:
	$HUD/TopBar/BackButton.pressed.connect(_return_to_mode_select)
	$HUD/BottomBar/AttackButton.pressed.connect(_start_attack)
	$HUD/BottomBar/RebuildButton.pressed.connect(_new_run)
	$HUD/BottomBar/SpeedButton.pressed.connect(_toggle_speed)
	$HUD/BottomBar/ViewButton.pressed.connect(_reset_view)
	$HUD/BottomBar/ScoutButton.pressed.connect(_toggle_scout)
	$HUD/BottomBar/FortifyButton.pressed.connect(_open_wall_draft)
	$HUD/ScoutPanel/Margin/Stack/Header/CloseButton.pressed.connect(_close_scout)
	$HUD/ResultPanel/Margin/Stack/ContinueButton.pressed.connect(_close_result_panel)
	$HUD/WallDraftPanel/Margin/Stack/Cards/Plan1/Margin/Stack/ChooseButton.pressed.connect(func() -> void: _select_wall_plan(0))
	$HUD/WallDraftPanel/Margin/Stack/Cards/Plan2/Margin/Stack/ChooseButton.pressed.connect(func() -> void: _select_wall_plan(1))
	$HUD/WallDraftPanel/Margin/Stack/Cards/Plan3/Margin/Stack/ChooseButton.pressed.connect(func() -> void: _select_wall_plan(2))
	$HUD/WallDraftPanel/Margin/Stack/NotNowButton.pressed.connect(_close_wall_draft)
	$HUD/WallPlanPlacementPanel/Margin/Actions/CancelButton.pressed.connect(_cancel_wall_plan_placement)
	$HUD/WallPlanPlacementPanel/Margin/Actions/RotateButton.pressed.connect(_rotate_wall_plan)
	$HUD/WallPlanPlacementPanel/Margin/Actions/MirrorButton.pressed.connect(_mirror_wall_plan)
	$HUD/WallPlanPlacementPanel/Margin/Actions/ConfirmButton.pressed.connect(_confirm_wall_plan)
	$HUD/ShopButton.pressed.connect(_toggle_shop)
	$HUD/BuildTray/Margin/Stack/Header/CloseButton.pressed.connect(_close_shop)
	$HUD/BuildTray/Margin/Stack/Cards/CannonCard.pressed.connect(func() -> void: _select_build_kind(&"cannon"))
	$HUD/BuildTray/Margin/Stack/Cards/ArcherCard.pressed.connect(func() -> void: _select_build_kind(&"archer_tower"))
	$HUD/BuildTray/Margin/Stack/Cards/MortarCard.pressed.connect(func() -> void: _select_build_kind(&"mortar"))
	$HUD/BuildTray/Margin/Stack/Cards/AirDefenseCard.pressed.connect(func() -> void: _select_build_kind(&"air_defense"))
	$HUD/BuildTray/Margin/Stack/Cards/WizardTowerCard.pressed.connect(func() -> void: _select_build_kind(&"wizard_tower"))
	$HUD/BuildTray/Margin/Stack/Cards/WallCard.pressed.connect(func() -> void: _select_build_kind(&"wall"))
	$HUD/PlacementPanel/Margin/Actions/CancelButton.pressed.connect(_cancel_pending_purchase)
	$HUD/PlacementPanel/Margin/Actions/ConfirmButton.pressed.connect(_confirm_build)
	$HUD/SelectionPanel/Margin/Stack/Actions/SelectRowButton.pressed.connect(_select_wall_row)
	$HUD/SelectionPanel/Margin/Stack/Actions/RotateRowButton.pressed.connect(_rotate_wall_row)
	$HUD/SelectionPanel/Margin/Stack/Actions/UpgradeButton.pressed.connect(_upgrade_selected)
	$SiegeCombat.status_changed.connect(_on_status_changed)
	$SiegeCombat.wave_started.connect(_on_wave_started)
	$SiegeCombat.wave_finished.connect(_on_wave_finished)
	$SiegeBoard.edit_status_changed.connect(_on_status_changed)
	$SiegeBoard.selected_structure_changed.connect(_on_selection_changed)
	$SiegeBoard.structure_added.connect(_on_structure_added)
	$SiegeBoard.build_preview_changed.connect(_on_build_preview_changed)
	$SiegeBoard.wall_extension_requested.connect(_on_wall_extension_preview_requested)
	$SiegeBoard.wall_extension_start_requested.connect(_on_wall_extension_start_requested)
	$SiegeBoard.placement_cancel_requested.connect(_cancel_pending_purchase)
	$SiegeBoard.view_transform_changed.connect(_on_view_transform_changed)
	$SiegeBoard.wall_plan_preview_changed.connect(_on_wall_plan_preview_changed)
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
	$SiegeBoard.set_wall_extensions_enabled(false)
	pending_purchase_kind = &""
	pending_purchase_cost = 0
	pending_wall_plan_id = &""
	_hide_context_panels()
	$HUD/ResultPanel.visible = false
	$HUD/BottomBar/AttackButton.disabled = false
	_set_build_controls_enabled(true)
	_on_status_changed("")
	_refresh_hud()
	_refresh_wall_draft_cards()
	_open_wall_draft()


func _start_attack() -> void:
	if run_state.completed:
		return
	_cancel_pending_purchase()
	_cancel_wall_plan_placement(false)
	$HUD/WallDraftPanel.visible = false
	_close_shop()
	$HUD/SelectionPanel.visible = false
	$HUD/ScoutPanel.visible = false
	$HUD/ResultPanel.visible = false
	var blueprint: Array[Dictionary] = $SiegeBoard.capture_current_blueprint()
	run_state.blueprint = blueprint.duplicate(true)
	run_state.begin_combat(blueprint)
	$SiegeBoard.set_edit_mode(false)
	var wave: Array[Dictionary] = TierCatalogScript.build_wave(run_state.town_hall, run_state.battle_index)
	var budget := TierCatalogScript.get_wave_housing(wave)
	$SiegeCombat.start_wave(wave, "RANK %d-%s · %d housing" % [run_state.get_fortress_rank(), run_state.get_battle_letter(), budget])


func _toggle_shop() -> void:
	if $SiegeCombat.active or run_state.completed:
		return
	if $HUD/BuildTray.visible:
		_close_shop()
		return
	_cancel_pending_purchase()
	_cancel_wall_plan_placement(false)
	$HUD/WallDraftPanel.visible = false
	$HUD/SelectionPanel.visible = false
	_refresh_shop_cards()
	$HUD/BuildTray.visible = true
	_on_status_changed("Choose a defense · towers share the Fortress capacity")


func _close_shop() -> void:
	$HUD/BuildTray.visible = false


func _select_build_kind(kind: StringName) -> void:
	if $SiegeCombat.active or run_state.completed:
		return
	if kind == &"wall":
		_on_status_changed("New Walls come from Wall Plans")
		_open_wall_draft()
		return
	var cost: int = StructureCatalogScript.get_build_cost(kind)
	if not TierCatalogScript.is_build_kind_unlocked(run_state.town_hall, kind):
		_on_status_changed("%s unlocks at a later Fortress Rank" % _display_name(kind))
		return
	if kind == &"wall":
		var wall_cap := TierCatalogScript.get_wall_allowance(run_state.town_hall)
		if $SiegeBoard.get_structure_count(&"wall") >= wall_cap:
			_on_status_changed("All %d Walls are already built" % wall_cap)
			return
	else:
		var defense_cap := TierCatalogScript.get_defense_capacity(run_state.town_hall)
		if $SiegeBoard.get_defense_count() >= defense_cap:
			_on_status_changed("Defense capacity full · %d / %d" % [$SiegeBoard.get_defense_count(), defense_cap])
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
	$HUD/PlacementPanel/Margin/Actions/ConfirmButton.disabled = true
	$HUD/PlacementPanel/Margin/Actions/ConfirmButton.visible = true
	$HUD/PlacementPanel/Margin/Actions/ConfirmButton.text = "✓"


func _confirm_build() -> void:
	if pending_purchase_kind == &"":
		return
	var pending_wall_count: int = $SiegeBoard.get_pending_wall_count()
	if not $SiegeBoard.confirm_pending_build():
		_on_status_changed("Tap a valid empty position before confirming")
		return
	if pending_wall_count > 0:
		_finish_wall_batch(pending_wall_count)


func _on_build_preview_changed(_kind: StringName, cell: Vector2i, can_confirm: bool) -> void:
	$HUD/PlacementPanel/Margin/Actions/ConfirmButton.disabled = not can_confirm
	_update_wall_placement_label()
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
	elif placed_kind == &"wall":
		$SiegeBoard.cancel_build()
		$SiegeBoard.clear_selection()
		$HUD/SelectionPanel.visible = false
		_on_status_changed("All %d Walls built" % TierCatalogScript.get_count_cap(run_state.town_hall, &"wall"))
	else:
		_on_selection_changed(structure)


func _continue_wall_placement(cell: Vector2i) -> void:
	if not $SiegeCombat.active and not run_state.completed:
		var cap: int = TierCatalogScript.get_count_cap(run_state.town_hall, &"wall")
		var remaining: int = maxi(cap - $SiegeBoard.get_structure_count(&"wall"), 0)
		if remaining <= 0:
			return
		pending_purchase_kind = &"wall"
		pending_purchase_cost = StructureCatalogScript.get_build_cost(&"wall")
		$SiegeBoard.begin_wall_chain(cell, false, remaining)
		$HUD/PlacementPanel.visible = false
		_update_wall_placement_label()


func _on_wall_extension_start_requested(cell: Vector2i) -> void:
	if $SiegeCombat.active or run_state.completed or pending_purchase_kind != &"":
		return
	var selected: Node = $SiegeBoard.get_selected_structure()
	if selected == null or selected.kind != &"wall":
		return
	var cap: int = TierCatalogScript.get_count_cap(run_state.town_hall, &"wall")
	if $SiegeBoard.get_structure_count(&"wall") >= cap:
		_on_status_changed("All %d Walls built" % cap)
		return
	var cost := StructureCatalogScript.get_build_cost(&"wall")
	if run_state.currency < cost:
		_on_status_changed("Need %d Gold to build Wall" % cost)
		return
	pending_purchase_kind = &"wall"
	pending_purchase_cost = cost
	$SiegeBoard.begin_wall_chain_from_existing(selected.grid_cell, cap - $SiegeBoard.get_structure_count(&"wall"))
	_on_wall_extension_preview_requested()


func _on_wall_extension_preview_requested() -> void:
	if pending_purchase_kind != &"wall":
		return
	$HUD/PlacementPanel.visible = true
	$HUD/PlacementPanel/Margin/Actions/ConfirmButton.visible = true
	$HUD/PlacementPanel/Margin/Actions/ConfirmButton.disabled = false
	_update_wall_placement_label()
	_position_placement_panel($SiegeBoard.get_build_preview_screen_rect())


func _finish_wall_batch(wall_count: int) -> void:
	var total_cost := pending_purchase_cost * wall_count
	if total_cost > 0 and not run_state.spend(total_cost):
		return
	run_state.blueprint = $SiegeBoard.capture_current_blueprint()
	pending_purchase_kind = &""
	pending_purchase_cost = 0
	$HUD/PlacementPanel.visible = false
	_refresh_hud()
	var cap: int = TierCatalogScript.get_count_cap(run_state.town_hall, &"wall")
	var built: int = $SiegeBoard.get_structure_count(&"wall")
	if built >= cap:
		$SiegeBoard.clear_selection()
		$HUD/SelectionPanel.visible = false
		_on_status_changed("All %d Walls built" % cap)
		return
	var last_wall: Node = $SiegeBoard.get_selected_structure()
	if last_wall != null:
		call_deferred("_continue_wall_placement", last_wall.grid_cell)


func _update_wall_placement_label() -> void:
	var label: Label = $HUD/PlacementPanel/Margin/Actions/WallCountLabel
	var wall_mode := pending_purchase_kind == &"wall"
	label.visible = wall_mode
	if not wall_mode or run_state == null:
		return
	var cap: int = TierCatalogScript.get_count_cap(run_state.town_hall, &"wall")
	var built: int = $SiegeBoard.get_structure_count(&"wall")
	var previewed: int = $SiegeBoard.get_pending_wall_count()
	label.text = "%d DRAWN\n%d LEFT" % [previewed, maxi(cap - built - previewed, 0)]


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
	var panel_size := panel.get_combined_minimum_size()
	if panel_size.x <= 1.0:
		panel_size = Vector2(158.0, 68.0)
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
	_cancel_pending_purchase(false)
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
		_on_status_changed("%s is already at its Rank %d cap" % [_display_name(structure.kind), run_state.get_fortress_rank()])
		return
	var cost := StructureCatalogScript.get_upgrade_cost(structure.kind, next_level)
	if cost < 0 or not run_state.spend(cost):
		_on_status_changed("Need %d Gold for level %d" % [cost, next_level])
		return
	$SiegeBoard.upgrade_structure(structure.structure_id, next_level)
	run_state.blueprint = $SiegeBoard.capture_current_blueprint()
	_on_status_changed("%s upgraded to level %d for %d Gold" % [_display_name(structure.kind), next_level, cost])
	_refresh_hud()


func _select_wall_row() -> void:
	if $SiegeCombat.active or run_state.completed:
		return
	$SiegeBoard.select_wall_row()


func _rotate_wall_row() -> void:
	if $SiegeCombat.active or run_state.completed:
		return
	if $SiegeBoard.rotate_selected_wall_row():
		run_state.blueprint = $SiegeBoard.capture_current_blueprint()


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
	var row_count: int = $SiegeBoard.get_selected_wall_row_count()
	var row_selected: bool = structure.kind == &"wall" and row_count > 1
	$HUD/SelectionPanel/Margin/Stack/SelectedLabel.text = "%d WALLS · DRAG TO MOVE" % row_count if row_selected else "%s (LEVEL %d)" % [_display_name(structure.kind).to_upper(), structure.level]
	var select_row_button: Button = $HUD/SelectionPanel/Margin/Stack/Actions/SelectRowButton
	var rotate_row_button: Button = $HUD/SelectionPanel/Margin/Stack/Actions/RotateRowButton
	var button: Button = $HUD/SelectionPanel/Margin/Stack/Actions/UpgradeButton
	select_row_button.visible = structure.kind == &"wall" and not row_selected
	select_row_button.disabled = $SiegeBoard.get_selectable_wall_row_count() <= 1
	rotate_row_button.visible = row_selected
	rotate_row_button.disabled = false
	button.visible = not row_selected
	if structure.kind == &"command_core":
		button.text = "COMMAND CORE\nADVANCES AFTER B"
		button.disabled = true
		return
	var next_level: int = structure.level + 1
	var cap := TierCatalogScript.get_level_cap(run_state.town_hall, structure.kind)
	var cost := StructureCatalogScript.get_upgrade_cost(structure.kind, next_level)
	if next_level > cap or cost < 0:
		button.text = "MAX LEVEL\nFOR RANK %d" % run_state.get_fortress_rank()
		button.disabled = true
	else:
		button.text = "UPGRADE\nLEVEL %d · %d GOLD" % [next_level, cost]
		button.disabled = run_state.currency < cost


func _on_wave_started() -> void:
	_hide_context_panels()
	_cancel_wall_plan_placement(false)
	$HUD/BottomBar/AttackButton.disabled = true
	_set_build_controls_enabled(false)
	_refresh_hud()


func _on_wave_finished(result: StringName) -> void:
	$SiegeCombat.clear_attackers()
	$SiegeBoard.set_edit_mode(true)
	if result == &"defenders":
		var previous_town_hall: int = run_state.town_hall
		var reward := TierCatalogScript.get_reward(run_state.town_hall, run_state.battle_index)
		var outcome: Dictionary = run_state.record_victory(reward, run_state.precombat_blueprint)
		if bool(outcome.get("tier_advanced", false)):
			_upgrade_command_core_in_blueprint(run_state.blueprint, run_state.town_hall)
		$SiegeBoard.load_blueprint(run_state.blueprint)
		if run_state.completed:
			_on_status_changed("RUN COMPLETE · all 6 Fortress Ranks survived · %d Gold banked" % run_state.currency)
		else:
			_on_status_changed("Defense held · +%d Gold · prepare Rank %d-%s" % [reward, run_state.get_fortress_rank(), run_state.get_battle_letter()])
		_show_victory_result(reward, outcome, previous_town_hall)
	else:
		$SiegeBoard.load_blueprint(run_state.record_defeat())
		_on_status_changed("Base destroyed · no Gold lost · layout restored for a safe retry")
		$HUD/ScoutPanel.visible = true
	$HUD/BottomBar/AttackButton.disabled = run_state.completed
	_set_build_controls_enabled(not run_state.completed)
	_refresh_hud()


func _upgrade_command_core_in_blueprint(blueprint: Array[Dictionary], town_hall: int) -> void:
	for entry in blueprint:
		if StringName(entry.get("kind", &"")) == &"command_core":
			entry["level"] = town_hall
			return


func _cancel_pending_purchase(clear_selected := true) -> void:
	pending_purchase_kind = &""
	pending_purchase_cost = 0
	$SiegeBoard.cancel_build()
	if clear_selected:
		$SiegeBoard.clear_selection()
	$HUD/PlacementPanel.visible = false


func _hide_context_panels() -> void:
	$HUD/BuildTray.visible = false
	$HUD/PlacementPanel.visible = false
	$HUD/SelectionPanel.visible = false
	$HUD/WallDraftPanel.visible = false
	$HUD/WallPlanPlacementPanel.visible = false


func _set_build_controls_enabled(enabled: bool) -> void:
	$HUD/ShopButton.disabled = not enabled
	$HUD/BottomBar/ScoutButton.disabled = not enabled
	$HUD/BottomBar/FortifyButton.disabled = not enabled or (run_state != null and run_state.opening_wall_plan_claimed)
	$HUD/SelectionPanel/Margin/Stack/Actions/UpgradeButton.disabled = not enabled


func _refresh_hud() -> void:
	$HUD/TopBar/PhaseBadge.text = "RANK %d · %s\nROUND %d / %d" % [run_state.get_fortress_rank(), run_state.get_battle_letter(), run_state.get_round_number(), run_state.get_total_rounds()]
	$HUD/TopBar/Currency.text = "%d GOLD\nDEFENSES %d / %d" % [run_state.currency, $SiegeBoard.get_defense_count(), TierCatalogScript.get_defense_capacity(run_state.town_hall)]
	$HUD/BottomBar/AttackButton.text = "ATTACK %s" % run_state.get_battle_letter()
	_refresh_shop_cards()
	_refresh_scout_panel()
	_refresh_fortify_button()
	var selected: Node = $SiegeBoard.get_selected_structure()
	if selected != null and $HUD/SelectionPanel.visible:
		_on_selection_changed(selected)


func _refresh_shop_cards() -> void:
	if run_state == null:
		return
	for kind in SHOP_KINDS:
		var card: Button = _card_for_kind(kind)
		if kind == &"wall":
			card.visible = false
			card.disabled = true
			continue
		var cost: int = StructureCatalogScript.get_build_cost(kind)
		var unlocked := TierCatalogScript.is_build_kind_unlocked(run_state.town_hall, kind)
		card.visible = unlocked
		if not unlocked:
			card.disabled = true
		elif kind == &"wall":
			var wall_cap := TierCatalogScript.get_wall_allowance(run_state.town_hall)
			var walls_built: int = $SiegeBoard.get_structure_count(&"wall")
			var wall_price: String = "FREE" if cost == 0 else "%d GOLD" % cost
			card.text = "%s\n%s · BUILT %d / %d" % [_display_name(kind).to_upper(), wall_price, walls_built, wall_cap]
			card.disabled = walls_built >= wall_cap or run_state.currency < cost
		else:
			var price: String = "FREE" if cost == 0 else "%d GOLD" % cost
			var defenses_built: int = $SiegeBoard.get_defense_count()
			var defense_cap := TierCatalogScript.get_defense_capacity(run_state.town_hall)
			card.text = "%s\n%s · DEFENSES %d / %d" % [_display_name(kind).to_upper(), price, defenses_built, defense_cap]
			card.disabled = defenses_built >= defense_cap or run_state.currency < cost


func _card_for_kind(kind: StringName) -> Button:
	match kind:
		&"archer_tower": return $HUD/BuildTray/Margin/Stack/Cards/ArcherCard
		&"mortar": return $HUD/BuildTray/Margin/Stack/Cards/MortarCard
		&"air_defense": return $HUD/BuildTray/Margin/Stack/Cards/AirDefenseCard
		&"wizard_tower": return $HUD/BuildTray/Margin/Stack/Cards/WizardTowerCard
		&"wall": return $HUD/BuildTray/Margin/Stack/Cards/WallCard
		_: return $HUD/BuildTray/Margin/Stack/Cards/CannonCard


func _open_wall_draft() -> void:
	if run_state == null or run_state.completed or run_state.opening_wall_plan_claimed or $SiegeCombat.active:
		return
	_cancel_pending_purchase()
	_close_shop()
	$HUD/SelectionPanel.visible = false
	$HUD/ScoutPanel.visible = false
	$HUD/ResultPanel.visible = false
	$HUD/WallPlanPlacementPanel.visible = false
	pending_wall_plan_id = &""
	_refresh_wall_draft_cards()
	$HUD/WallDraftPanel.visible = true


func _close_wall_draft() -> void:
	$HUD/WallDraftPanel.visible = false
	if not $SiegeCombat.active:
		$HUD/ScoutPanel.visible = true
	_on_status_changed("Opening Wall Plan saved for later")


func _refresh_wall_draft_cards() -> void:
	if run_state == null:
		return
	var plans: Array[Dictionary] = WallPlanCatalogScript.get_opening_plans()
	var available := maxi(TierCatalogScript.get_wall_allowance(run_state.town_hall) - $SiegeBoard.get_structure_count(&"wall"), 0)
	for index in plans.size():
		var plan: Dictionary = plans[index]
		var card: Control = _wall_plan_card(index)
		var cells: Array = plan.get("cells", [])
		card.get_node("Margin/Stack/Name").text = "%s · %d WALLS" % [String(plan.get("name", "WALL PLAN")), cells.size()]
		card.get_node("Margin/Stack/Description").text = String(plan.get("description", ""))
		card.get_node("Margin/Stack/Preview").set_cells(cells)
		card.get_node("Margin/Stack/ChooseButton").disabled = cells.size() > available
	$HUD/WallDraftPanel/Margin/Stack/Subtitle.text = "Plans use different amounts from your %d-Wall Rank %d supply. Unused Walls stay available." % [available, run_state.get_fortress_rank()]


func _wall_plan_card(index: int) -> Control:
	match index:
		1: return $HUD/WallDraftPanel/Margin/Stack/Cards/Plan2
		2: return $HUD/WallDraftPanel/Margin/Stack/Cards/Plan3
		_: return $HUD/WallDraftPanel/Margin/Stack/Cards/Plan1


func _select_wall_plan(index: int) -> void:
	var plans: Array[Dictionary] = WallPlanCatalogScript.get_opening_plans()
	if index < 0 or index >= plans.size():
		return
	var plan: Dictionary = plans[index]
	var cells: Array = plan.get("cells", [])
	var available := maxi(TierCatalogScript.get_wall_allowance(run_state.town_hall) - $SiegeBoard.get_structure_count(&"wall"), 0)
	if cells.size() > available:
		_on_status_changed("This plan needs %d Walls · %d available" % [cells.size(), available])
		return
	pending_wall_plan_id = StringName(plan.get("id", &""))
	$HUD/WallDraftPanel.visible = false
	$HUD/WallPlanPlacementPanel.visible = true
	$HUD/WallPlanPlacementPanel/Margin/Actions/PlanLabel.text = "%s\n%d OF %d WALLS" % [String(plan.get("name", "WALL PLAN")), cells.size(), available]
	$SiegeBoard.begin_wall_plan(cells, Vector2i(plan.get("preferred_origin", Vector2i(-1, -1))))
	_on_status_changed("Drag the complete Wall Plan · rotate or mirror before confirming")


func _cancel_wall_plan_placement(reopen_draft := true) -> void:
	var was_active: bool = pending_wall_plan_id != &"" or $SiegeBoard.is_wall_plan_active()
	pending_wall_plan_id = &""
	$SiegeBoard.cancel_build()
	$HUD/WallPlanPlacementPanel.visible = false
	if was_active and reopen_draft and not $SiegeCombat.active and not run_state.opening_wall_plan_claimed:
		_refresh_wall_draft_cards()
		$HUD/WallDraftPanel.visible = true


func _rotate_wall_plan() -> void:
	$SiegeBoard.rotate_pending_wall_plan()


func _mirror_wall_plan() -> void:
	$SiegeBoard.mirror_pending_wall_plan()


func _on_wall_plan_preview_changed(can_confirm: bool) -> void:
	$HUD/WallPlanPlacementPanel/Margin/Actions/ConfirmButton.disabled = not can_confirm


func _confirm_wall_plan() -> void:
	if pending_wall_plan_id == &"":
		return
	var added: Array[Node2D] = $SiegeBoard.confirm_pending_wall_plan()
	if added.is_empty():
		_on_status_changed("Move the Wall Plan to a clear buildable area")
		return
	run_state.opening_wall_plan_claimed = true
	run_state.blueprint = $SiegeBoard.capture_current_blueprint()
	pending_wall_plan_id = &""
	$HUD/WallPlanPlacementPanel.visible = false
	$HUD/WallDraftPanel.visible = false
	$HUD/ScoutPanel.visible = true
	_on_status_changed("Wall Plan built · %d Walls placed · unused Walls remain available" % added.size())
	_refresh_hud()


func _refresh_fortify_button() -> void:
	if run_state == null:
		return
	var available := maxi(TierCatalogScript.get_wall_allowance(run_state.town_hall) - $SiegeBoard.get_structure_count(&"wall"), 0)
	if run_state.opening_wall_plan_claimed:
		$HUD/BottomBar/FortifyButton.text = "WALL PLAN\nPLACED"
		$HUD/BottomBar/FortifyButton.disabled = true
	else:
		$HUD/BottomBar/FortifyButton.text = "WALL PLAN\n%d AVAILABLE" % available
		$HUD/BottomBar/FortifyButton.disabled = $SiegeCombat.active or run_state.completed


func _toggle_scout() -> void:
	if $SiegeCombat.active:
		return
	$HUD/ScoutPanel.visible = not $HUD/ScoutPanel.visible
	if $HUD/ScoutPanel.visible:
		_refresh_scout_panel()


func _close_scout() -> void:
	$HUD/ScoutPanel.visible = false


func _close_result_panel() -> void:
	$HUD/ResultPanel.visible = false
	if not run_state.completed:
		$HUD/ScoutPanel.visible = true


func _refresh_scout_panel() -> void:
	if run_state == null or run_state.completed:
		return
	var wave: Array[Dictionary] = TierCatalogScript.build_wave(run_state.town_hall, run_state.battle_index)
	var counts: Dictionary = {}
	var order: Array[StringName] = []
	for entry in wave:
		var kind := StringName(entry.get("kind", &""))
		if not counts.has(kind):
			counts[kind] = 0
			order.append(kind)
		counts[kind] = int(counts[kind]) + 1
	var lines: PackedStringArray = []
	for kind in order:
		var level := 1
		for entry in wave:
			if StringName(entry.get("kind", &"")) == kind:
				level = int(entry.get("level", 1))
				break
		var definition := AttackerCatalogScript.get_definition(kind, level)
		var traits: PackedStringArray = []
		traits.append("AIR" if StringName(definition.get("movement_type", &"ground")) == &"air" else "GROUND")
		if bool(definition.get("is_support", false)):
			traits.append("HEALER")
		elif bool(definition.get("ignores_walls", false)):
			traits.append("JUMPS WALLS")
		elif float(definition.get("wall_damage", 0.0)) > float(definition.get("damage", 0.0)) * 2.0:
			traits.append("WALL BREAKER")
		if StringName(definition.get("preferred_target", &"any")) == &"defenses":
			traits.append("TARGETS DEFENSES")
		lines.append("%d× %s · L%d · %s" % [int(counts[kind]), String(definition.get("display_name", kind)), level, " · ".join(traits)])
	var budget := TierCatalogScript.get_wave_housing(wave)
	$HUD/ScoutPanel/Margin/Stack/Header/Title.text = "NEXT ATTACK · RANK %d-%s" % [run_state.get_fortress_rank(), run_state.get_battle_letter()]
	$HUD/ScoutPanel/Margin/Stack/Summary.text = "%d TROOPS · %d HOUSING" % [wave.size(), budget]
	$HUD/ScoutPanel/Margin/Stack/Roster.text = "\n".join(lines)


func _show_victory_result(reward: int, outcome: Dictionary, previous_town_hall: int) -> void:
	$HUD/ScoutPanel.visible = false
	$HUD/ResultPanel.visible = true
	var lines: PackedStringArray = ["+%d GOLD" % reward, "Fortress repaired automatically"]
	if run_state.completed:
		$HUD/ResultPanel/Margin/Stack/Title.text = "RUN COMPLETE"
		lines.append("All 6 Fortress Ranks survived")
		lines.append("%d Gold banked" % run_state.currency)
	elif bool(outcome.get("tier_advanced", false)):
		$HUD/ResultPanel/Margin/Stack/Title.text = "FORTRESS RANK %d REACHED" % run_state.get_fortress_rank()
		var old_capacity := TierCatalogScript.get_defense_capacity(previous_town_hall)
		var new_capacity := TierCatalogScript.get_defense_capacity(run_state.town_hall)
		var old_walls := TierCatalogScript.get_wall_allowance(previous_town_hall)
		var new_walls := TierCatalogScript.get_wall_allowance(run_state.town_hall)
		lines.append("Defense capacity: %d → %d" % [old_capacity, new_capacity])
		lines.append("Walls: %d → %d" % [old_walls, new_walls])
		var unlock_names: PackedStringArray = []
		for kind in TierCatalogScript.get_newly_unlocked_build_kinds(previous_town_hall, run_state.town_hall):
			unlock_names.append(_display_name(kind))
		if not unlock_names.is_empty():
			lines.append("New defense: %s" % ", ".join(unlock_names))
		var level_gains: PackedStringArray = []
		for kind in [&"cannon", &"archer_tower", &"mortar", &"air_defense", &"wizard_tower", &"wall"]:
			var old_level := TierCatalogScript.get_level_cap(previous_town_hall, kind)
			var new_level := TierCatalogScript.get_level_cap(run_state.town_hall, kind)
			if old_level > 0 and new_level > old_level:
				level_gains.append("%s L%d" % [_display_name(kind), new_level])
		if not level_gains.is_empty():
			lines.append("New upgrade caps: %s" % ", ".join(level_gains))
	else:
		$HUD/ResultPanel/Margin/Stack/Title.text = "DEFENSE HELD"
		lines.append("Rank %d · Attack %s ready" % [run_state.get_fortress_rank(), run_state.get_battle_letter()])
	$HUD/ResultPanel/Margin/Stack/Details.text = "\n".join(lines)


func _display_name(kind: StringName) -> String:
	return String(StructureCatalogScript.get_definition(kind, 1).get("display_name", kind))
