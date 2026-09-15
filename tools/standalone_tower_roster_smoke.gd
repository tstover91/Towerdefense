extends SceneTree

const GameStats = preload("res://stat_database.gd")
const DraftManagerScript = preload("res://draft_manager.gd")
const Registry = preload("res://tower_attacks/tower_attack_component_registry.gd")

func _initialize() -> void:
	var families := GameStats.get_playable_tower_family_ids()
	assert(not families.has(&"invader"))
	assert(not families.has(&"longshot"))
	assert(not families.has(&"slinger"))
	assert(not families.has(&"energycore"))
	assert(not families.has(&"voidcaller"))
	assert(not families.has(&"orbitalcannon"))
	assert(not families.has(&"brainiac"))
	assert(not families.has(&"saucer"))
	assert(not families.has(&"dronedepot"))
	assert(not families.has(&"mechbay"))
	assert(not families.has(&"irradiator"))
	assert(not families.has(&"reaver"))
	assert(GameStats.get_tower_paths(&"fisherman").is_empty())
	assert(GameStats.get_canonical_tower_family_id(&"invader") == &"gunslinger")
	assert(GameStats.get_canonical_tower_family_id(&"gauss_repeater") == &"gauss_gunner")
	assert(GameStats.get_canonical_tower_family_id(&"brainiac") == &"psionic")
	assert(GameStats.get_canonical_tower_family_id(&"beholder") == &"psionic")
	var standalone_ids: Array[StringName] = [
		&"gunslinger",
		&"laser_cannon",
		&"gauss_gunner",
		&"anti_materiel",
		&"kill_chain",
		&"explosive_ricochet",
		&"razor_disc",
		&"containment_core",
		&"tesla_core",
		&"orb_barrage",
		&"singularity",
		&"psionic",
		&"solar_lance",
		&"bombardment",
		&"atomic_strike",
		&"gunship",
		&"mothership",
		&"drone_depot",
		&"mech_bay",
		&"sentry_array",
		&"reactor",
		&"isotope_projector",
		&"assassin",
		&"champion",
	]
	for tower_id in standalone_ids:
		assert(families.has(tower_id))
		assert(GameStats.get_tower_paths(tower_id).is_empty())
		assert(not GameStats.get_tower_inherent_path(tower_id).is_empty() or tower_id == &"gauss_gunner")
		var priced_tower := GameStats.get_tower(tower_id)
		var price_curve: Array = GameStats.STANDALONE_TOWER_PRICE_CURVES[tower_id]
		assert(priced_tower["placement_cost"] == price_curve[0])
		for level_index in range(1, price_curve.size()):
			assert(priced_tower["levels"][level_index]["upgrade_cost"] == price_curve[level_index])
	var laser := GameStats.get_tower(&"laser_cannon")
	assert(laser["display_name"] == "Laser Cannon")
	assert(laser["inherent_path"]["primary_damage_type"] == &"beam")
	assert(laser["levels"][2]["add_bonus_tags"].is_empty())
	assert(Registry.create_component(&"laser_cannon", laser, &"spawner") != null)
	var gunslinger := GameStats.get_tower(&"gunslinger")
	assert(gunslinger["levels"][1]["add_bonus_tags"] == [&"reveal"])
	assert(gunslinger["levels"][2]["add_bonus_tags"].is_empty())
	var gauss := GameStats.get_tower(&"gauss_gunner")
	assert(GameStats.get_tower_paths(&"gauss_gunner").is_empty())
	assert(Registry.create_component(&"gauss_gunner", gauss, &"spawner") != null)
	var anti_materiel := GameStats.get_tower(&"anti_materiel")
	assert(anti_materiel["inherent_path"]["stat_additions"]["critical_multiplier"] == 1.0)
	assert(anti_materiel["inherent_path"]["pierce_count_add"] == 1)
	assert(anti_materiel["levels"][3]["range"] == 13.0)
	assert(Registry.create_component(&"anti_materiel", anti_materiel, &"spawner") != null)
	var kill_chain := GameStats.get_tower(&"kill_chain")
	assert(kill_chain["inherent_path"]["behavior_flags"]["longshot_kill_chain"])
	assert(kill_chain["levels"][3]["range"] == 12.5)
	var explosive_ricochet := GameStats.get_tower(&"explosive_ricochet")
	assert(not explosive_ricochet["inherent_path"].has("behavior_flags"))
	assert(explosive_ricochet["levels"][2]["bounce_count"] == 2)
	assert(explosive_ricochet["final_level_path"]["behavior_flags"]["slinger_contact_explosions"])
	var razor_disc := GameStats.get_tower(&"razor_disc")
	assert(razor_disc["inherent_path"]["pierce_count_add"] == 4)
	assert(razor_disc["levels"][2]["pierce_count_add"] == 4)
	assert(not razor_disc["inherent_path"].get("behavior_flags", {}).get("infinite_pierce", false))
	var containment_core := GameStats.get_tower(&"containment_core")
	assert(containment_core["inherent_path"]["behavior_flags"]["energy_shockwave"])
	var tesla_core := GameStats.get_tower(&"tesla_core")
	assert(tesla_core["levels"][0]["slow_duration"] == 0.50)
	assert(tesla_core["levels"][2]["behavior_values"]["branch_additional_targets"] == 2)
	assert(tesla_core["levels"][3]["projectile_count"] == 2)
	var orb_barrage := GameStats.get_tower(&"orb_barrage")
	assert(orb_barrage["levels"][0]["projectile_count"] == 1)
	assert(orb_barrage["levels"][2]["projectile_count"] == 2)
	assert(orb_barrage["levels"][2]["volley_stagger"] > 0.0)
	assert(orb_barrage["final_level_path"]["stat_overrides"]["projectile_count"] == 5)
	var singularity := GameStats.get_tower(&"singularity")
	assert(singularity["levels"][0]["behavior_flags"]["dedicated_singularity_attack"])
	assert(singularity["levels"][3]["behavior_flags"]["singularity_event_horizon"])
	assert(Registry.create_component(&"orb_barrage", orb_barrage, &"spawner") != null)
	assert(Registry.create_component(&"singularity", singularity, &"spawner") != null)
	var psionic := GameStats.get_tower(&"psionic")
	assert(psionic["inherent_path"]["behavior_flags"]["brainiac_ramping_beam"])
	assert(psionic["final_level_path"]["behavior_flags"]["brainiac_psionic_link"])
	assert(Registry.create_component(&"psionic", psionic, &"spawner") != null)
	var solar_lance := GameStats.get_tower(&"solar_lance")
	assert(solar_lance["levels"][0]["behavior_flags"]["orbital_solar_lance"])
	var bombardment := GameStats.get_tower(&"bombardment")
	assert(bombardment["levels"][0]["behavior_flags"]["orbital_bombardment"])
	var atomic_strike := GameStats.get_tower(&"atomic_strike")
	assert(atomic_strike["levels"][0]["behavior_flags"]["orbital_atomic_strike"])
	for orbital_id in [&"solar_lance", &"bombardment", &"atomic_strike"]:
		assert(Registry.create_component(orbital_id, GameStats.get_tower(orbital_id), &"spawner") != null)
	var gunship := GameStats.get_tower(&"gunship")
	assert(gunship["levels"][0]["behavior_flags"]["saucer_twin_rockets"])
	assert(gunship["levels"][3]["behavior_values"]["saucer_rocket_count"] == 4)
	var mothership := GameStats.get_tower(&"mothership")
	assert(mothership["levels"][0]["behavior_flags"]["saucer_vulnerability_field"])
	assert(mothership["levels"][3]["behavior_values"]["saucer_field_vulnerability"] == 0.25)
	for saucer_id in [&"gunship", &"mothership"]:
		assert(Registry.create_component(saucer_id, GameStats.get_tower(saucer_id), &"spawner") != null)
	var drone_depot := GameStats.get_tower(&"drone_depot")
	assert(drone_depot["inherent_path"]["stat_overrides"]["spawned_unit_id"] == &"drone")
	var mech_bay := GameStats.get_tower(&"mech_bay")
	assert(mech_bay["inherent_path"]["stat_overrides"]["spawned_unit_id"] == &"mech")
	assert(mech_bay["texture"] == GameStats.TOWER_TEXTURES[&"mechbay"])
	var sentry_array := GameStats.get_tower(&"sentry_array")
	assert(sentry_array["inherent_path"]["stat_overrides"]["spawned_unit_id"] == &"sentry_turret")
	assert(sentry_array["levels"][0]["spawn_limit"] == 1)
	assert(sentry_array["levels"][3]["spawn_limit"] == 5)
	for factory_id in [&"drone_depot", &"mech_bay", &"sentry_array"]:
		assert(Registry.create_component(factory_id, GameStats.get_tower(factory_id), &"spawner") != null)
	var reactor := GameStats.get_tower(&"reactor")
	assert(reactor["levels"][0]["behavior_flags"]["irradiator_reactor"])
	assert(reactor["levels"][3]["range"] == 9.5)
	var isotope_projector := GameStats.get_tower(&"isotope_projector")
	assert(isotope_projector["levels"][0]["behavior_flags"]["irradiator_isotope_beam"])
	assert(isotope_projector["levels"][3]["range"] == 11.0)
	assert(not isotope_projector["bonus_tags"].has(&"pierce"))
	assert(Registry.create_component(&"reactor", reactor, &"spawner") != null)
	assert(Registry.create_component(&"isotope_projector", isotope_projector, &"spawner") != null)
	var assassin := GameStats.get_tower(&"assassin")
	assert(assassin["inherent_path"]["behavior_flags"]["reaver_assassinate"])
	assert(assassin["levels"][0]["behavior_flags"]["reaver_roaming"])
	assert(assassin["final_level_path"]["behavior_flags"]["reaver_time_bubble"])
	var champion := GameStats.get_tower(&"champion")
	assert(champion["display_name"] == "Champion")
	assert(champion["levels"][0]["melee_arc_degrees"] == 120.0)
	assert(champion["levels"][3]["melee_arc_degrees"] == 360.0)
	assert(not champion["levels"][3]["behavior_flags"].has("reaver_enforcer"))
	assert(Registry.create_component(&"assassin", assassin, &"spawner") != null)
	assert(Registry.create_component(&"champion", champion, &"spawner") != null)
	var fisherman_final := GameStats.get_tower_final_level_path(&"fisherman")
	assert(fisherman_final["primary_damage_type"] == &"electric")
	assert(fisherman_final["behavior_values"]["hook_target_count"] == 2)
	assert(fisherman_final["behavior_flags"]["fisherman_electric_pulse"])
	var draft := DraftManagerScript.new(RandomNumberGenerator.new())
	var offers := draft.roll_tower_offers([], standalone_ids)
	assert(offers.size() == 3)
	print("Standalone tower roster smoke checks passed")
	quit()
