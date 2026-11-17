extends SceneTree
const Model = preload("res://scripts/garden_state.gd")
var checks: int = 0
var failures: int = 0
var path: String

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAILED: " + message)

func _initialize() -> void:
	path = "/tmp/conservatory_wild_%d.json" % Time.get_ticks_usec()
	var state: RefCounted = Model.new(path)
	state.new_game()
	check(state.field_kits == 12, "new botanists receive a field satchel")
	var field: Dictionary = state.begin_expedition()
	check(field.position == [15,18] and field.map_seed > 0, "expedition starts outside the conservatory")
	check(field.discovered_biomes == ["Mosswood"], "first habitat is known")
	state.move_explorer(-1, 99)
	check(state.expedition.position == [0,31], "model clamps explorer inside forty by thirty-two map")
	var steps: int = state.expedition.steps
	state.move_explorer(0,31)
	check(state.expedition.steps == steps, "standing still does not count a step")
	state.move_explorer(15,16)
	var archive_size: int = state.plants.size()
	var identity_counter: int = state.id_counter
	var light: int = state.resources.sunlight
	var encounter: Dictionary = state.wild_encounter("Mosswood","moss_01")
	check(encounter.ok and encounter.plant.type == "Leaf", "first reachable patch is a familiar wild fern")
	check(encounter.plant.origin.kind == "wild" and encounter.plant.origin.biome == "Mosswood", "organism has a field origin")
	check(state.plants.size() == archive_size and state.id_counter == identity_counter, "finding a plant does not acquire it or spend a persistent ID")
	check(state.resources.sunlight == light and state.field_kits == 12, "encounter does not consume garden resources")
	check(is_equal_approx(state.capture_odds(), 0.9), "common plant shows ninety percent collection odds")
	state.move_explorer(16,16)
	check(state.expedition.position == [15,16], "encounter holds the player in place")
	check(not state.wild_encounter("Sporefen","fen_01").ok, "a second encounter cannot replace an active specimen")
	var study: Dictionary = state.resolve_wild_capture("observe")
	check(study.ok and not study.caught and study.observed, "observation studies without collecting")
	check(is_equal_approx(study.chance, 0.98) and state.field_kits == 12, "observation adds fifteen points up to ninety-eight without consuming a kit")
	check(not state.resolve_wild_capture("observe").ok and is_equal_approx(state.capture_odds(),0.98), "observation cannot stack indefinitely")
	check(state.field_status().can_entangle and is_equal_approx(state.capture_odds("entangle"),0.98), "owned mature vines can steady a capture")
	var restored: RefCounted = Model.new(path)
	check(restored.load_game(), "active expedition save reloads")
	check(restored.expedition.position == [15,16] and restored.expedition.active_encounter.observed, "position and observation persist")
	check(JSON.parse_string(JSON.stringify(restored.expedition.active_encounter.plant.genes)) == JSON.parse_string(JSON.stringify(state.expedition.active_encounter.plant.genes)), "encounter genes survive reload identically")
	var first: Dictionary = state.resolve_wild_capture("gather")
	var repeated: Dictionary = restored.resolve_wild_capture("gather")
	check(first.caught == repeated.caught and first.fled == repeated.fled, "save reload cannot reroll collection or withdrawal")
	check(state.field_kits == 11 and restored.field_kits == 11, "attempt spends exactly one kit")
	check(is_equal_approx(first.chance,0.98), "shown odds are used for resolution")
	# A collection is probabilistic. Follow multiple independent patches until one joins.
	var caught: Dictionary = first
	for i in range(40):
		if caught.caught: break
		state.leave_wild_encounter()
		state.field_kits = 12
		state.wild_encounter("Mosswood","test_cutting_%d" % i)
		state.resolve_wild_capture("observe")
		caught = state.resolve_wild_capture("gather")
	check(caught.caught, "observed plants can be collected in the field")
	if caught.caught:
		var specimen: Dictionary = caught.plant
		check(state.plants.has(specimen.id) and state.plant_order.has(specimen.id), "caught specimen enters the living archive and tray")
		check(specimen.mature and specimen.parents.is_empty() and specimen.generation == 1, "wild founding organism is mature and has no invented ancestors")
		check(not str(specimen.id).begins_with("wild_") and state.expedition.active_encounter.is_empty(), "collection assigns an owned identity and closes the encounter")
		check(state.discovered.has(specimen.species), "wild collection records a codex discovery")
		check(state.expedition.collected_sites.has(specimen.origin.site), "collected patch is marked on the map")
		check(not state.wild_encounter(specimen.origin.biome,specimen.origin.site).ok, "same patch cannot duplicate its collected individual")
		var wild_id: String = specimen.id
		var parent_id: String = state.plant_order[0]
		var child: Dictionary = state.crossbreed(wild_id,parent_id)
		check(child.ok and child.plant.parents.has(wild_id), "wild genes feed directly into the breeding loop")
		state.save_game()
		var collection_save: RefCounted = Model.new(path)
		check(collection_save.load_game() and JSON.parse_string(JSON.stringify(collection_save.plants[wild_id].origin)) == JSON.parse_string(JSON.stringify(specimen.origin)), "wild provenance persists in full pedigree save")
	state.leave_wild_encounter()
	var revisit: Dictionary = state.wild_encounter("Amber Hollow","amber_02")
	var seed: int = revisit.plant.seed
	var genes: Dictionary = revisit.plant.genes.duplicate(true)
	state.leave_wild_encounter()
	var again: Dictionary = state.wild_encounter("Amber Hollow","amber_02")
	check(again.plant.seed == seed and again.plant.genes == genes, "abandoning a patch does not reroll its organism")
	state.field_kits = 0
	var attempts: int = state.expedition.active_encounter.attempts
	check(not state.resolve_wild_capture("gather").ok and state.expedition.active_encounter.attempts == attempts, "empty satchel cannot reroll or consume an attempt")
	state.resources.sunlight = 19
	check(not state.restock_field_kits().ok and state.field_kits == 0, "kit refill checks gathered light")
	state.resources.sunlight = 20
	check(state.restock_field_kits().ok and state.field_kits == 5 and state.resources.sunlight == 0, "five kits cost exactly twenty light")
	state.leave_wild_encounter()
	state.expedition.collected_sites = ["moss_01"]
	state.expedition.site_records = {"fen_01":{"fled":true,"attempts":2,"observed":true}}
	state.expedition.respawn_day -= 1
	state.begin_expedition()
	check(state.expedition.collected_sites.is_empty() and state.expedition.site_records.is_empty(), "a new field day regrows spent and withdrawn patches")
	check(state.expedition.position == [15,16] and state.expedition.captures >= 1, "daily regrowth preserves position and lifetime collections")
	check(not state.wild_encounter("Unknown","invalid").ok, "unmapped biomes cannot generate plants")
	var seen_species: Dictionary = {}
	var early_traps: int = 0
	state.expedition.captures = 0
	for biome: String in Model.WILD_BIOMES:
		for i in range(20):
			state.leave_wild_encounter()
			var found: Dictionary = state.wild_encounter(biome,"atlas_%s_%d" % [biome,i])
			seen_species[found.plant.species] = true
			if found.plant.type == "Carnivorous": early_traps += 1
	check(seen_species.size() == 7, "all seven founding species are reachable in wild habitats")
	check(early_traps == 0, "carnivorous lineage does not appear in early exploration")
	state.leave_wild_encounter()
	state.save_game()
	var saved: FileAccess = FileAccess.open(path,FileAccess.READ)
	var legacy: Dictionary = JSON.parse_string(saved.get_as_text())
	saved.close()
	legacy.erase("field_kits")
	legacy.erase("expedition")
	saved = FileAccess.open(path,FileAccess.WRITE)
	saved.store_string(JSON.stringify(legacy))
	saved.close()
	var old_garden: RefCounted = Model.new(path)
	check(old_garden.load_game() and old_garden.field_kits == 12 and old_garden.expedition.position == [15,18], "existing garden saves gain wilderness without losing plants")
	check(old_garden.plants.size() == state.plants.size(), "legacy migration preserves the complete archive")
	check(not state._valid_expedition({"position":["bad",2]}), "malformed expedition positions are rejected")
	check(not state._valid_expedition({"active_encounter":{"plant":{}}}), "malformed active encounters are rejected")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path.get_basename()+".backup.json")
	print("WILD TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
