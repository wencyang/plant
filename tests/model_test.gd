extends SceneTree

const Model = preload("res://scripts/garden_state.gd")
var checks: int = 0
var failures: int = 0
var state: RefCounted

func _initialize() -> void:
	state = Model.new("/tmp/conservatory_model_test.json")
	state.new_game()
	_check(state.plants.size() == 5, "five mature starter organisms")
	_check(state.bed.size() == 9 and state.display_bed.size() == 6, "garden dimensions")
	_check(state.discovered.size() == 3, "three starter lineages")
	_check(state.seed_bank.size() == 3, "three seeds available")
	var old_counter: int = state.id_counter
	var old_random_state: int = state.random.state
	var visits: Array = state.fair_requests()
	_check(visits.size()==3 and visits==state.fair_requests(), "daily garden visitors are deterministic")
	_check(state.id_counter==old_counter and state.random.state==old_random_state and state.plants.size()==5, "visiting the fair does not change the garden or RNG")
	_check(not state.has_method("generate_opponent") and not state.has_method("battle_reward"), "removed combat has no progression APIs")
	var a: String = state.plant_order[0]
	var b: String = state.plant_order[1]
	_check(not state.crossbreed(a, a).ok, "self-cross rejected")
	var before: int = state.resources.sunlight
	var birth: Dictionary = state.crossbreed(a, b)
	_check(birth.ok and state.resources.sunlight == before - 30, "cross charges light")
	var child: Dictionary = birth.plant
	_check(child.generation == 2 and child.parents == [a, b], "full parent records")
	_check(not child.mature and not state.place_in_bed(child.id, 0), "immature plants cannot be arranged")
	for stat: String in Model.STAT_NAMES:
		var midpoint: float = (float(state.plants[a].stats[stat]) + float(state.plants[b].stats[stat])) * 0.5
		_check(absf(float(child.stats[stat]) - midpoint) <= midpoint * 0.1 + 0.5, "inherited stat variance: " + stat)
	state.mature_plant(child.id)
	_check(child.mature and state.place_in_bed(child.id, 0), "quick growth and arrangement")
	state.place_in_bed(a, 0)
	_check(state.bed.count(a) == 1 and state.bed.count(child.id) == 1, "garden placement swaps without duplication")
	state.place_in_display(child.id, 4)
	state.place_in_display(a, 4)
	_check(state.display_bed.count(a) == 1 and state.display_bed.count(child.id) == 1, "display placement swaps")
	var score: Dictionary = state.display_score()
	_check(score.total == score.diversity + score.harmony + score.rarity, "beauty categories sum")
	state.claim_display()
	var after_claim: Dictionary = state.resources.duplicate()
	state.claim_display()
	_check(state.resources == after_claim, "display milestones cannot be claimed twice")
	state.toggle_favorite(b)
	_check(not state.graft(a, b).ok, "favorite donor protected")
	state.toggle_favorite(b)
	state.resources.grafts = 10
	var graft_result: Dictionary = state.graft(a, b, "feature")
	_check(graft_result.ok and state.plants[b].donor_ready_at > Time.get_unix_time_from_system(), "graft takes donor tissue on cooldown")
	_check(not state.graft(a, b).ok, "recovering donor protected")
	state.resources.agents = 1000
	state.random.seed = 91731
	var outcomes: Dictionary = {"New trait": 0, "No change": 0, "Deformity": 0}
	for i in range(600):
		var result: Dictionary = state.mutate(child.id, "chemical", "pattern")
		outcomes[result.outcome] += 1
	_check(outcomes["New trait"] > 350 and outcomes["New trait"] < 490, "70 percent mutation distribution")
	_check(outcomes["No change"] > 70 and outcomes["No change"] < 170, "20 percent unchanged distribution")
	_check(outcomes["Deformity"] > 25 and outcomes["Deformity"] < 100, "10 percent deformity distribution")
	_check(child.mutation_history.size() == 600, "permanent mutation history")
	var lineage: Dictionary = state.lineage(a)
	_check(lineage.descendants.size() == 1, "descendant lookup")
	var old_coins: int = state.market_wallet()
	var old_light: int = int(state.resources.sunlight)
	var reward: Dictionary = state.fair_claim(str(state.fair_requests()[0].key),a)
	_check(reward.ok and state.market_wallet()==old_coins+8 and int(state.resources.sunlight)==old_light+20, "showing a plant closes the peaceful resource loop")
	var seed_birth: Dictionary = state.plant_seed(0)
	_check(seed_birth.ok and state.bed.has(seed_birth.plant.id), "planted seed appears directly in garden")
	seed_birth.plant.ready_at = 0
	_check(state.tick_growth() and seed_birth.plant.mature, "elapsed growth matures offspring")
	state.rename_plant(child.id, "A remembered organism")
	state.save_game()
	var loaded: RefCounted = Model.new("/tmp/conservatory_model_test.json")
	_check(loaded.load_game(), "save reload succeeds")
	_check(loaded.plants[child.id].name == "A remembered organism", "rename persists")
	_check(loaded.plants[child.id].parents == child.parents, "pedigree persists")
	_check(loaded.plants[child.id].mutation_history.size() == 600, "history persists")
	_check(loaded.bed == state.bed and loaded.display_bed == state.display_bed, "exact garden placement persists")
	_check(loaded.plants[child.id].seed == child.seed, "anatomy seed persists")
	# Corrupt the primary save: the previous complete save remains recoverable.
	var file: FileAccess = FileAccess.open("/tmp/conservatory_model_test.json", FileAccess.WRITE)
	file.store_string("interrupted")
	file.close()
	var recovery: RefCounted = Model.new("/tmp/conservatory_model_test.json")
	_check(recovery.load_game(), "backup recovers corrupt primary")
	_check(not state._valid_save({"version": 1}), "malformed save rejected")
	var atlas: RefCounted = Model.new("/tmp/conservatory_collection_test.json")
	atlas.new_game()
	atlas.collection_seen.clear()
	for id: String in atlas.plant_order:
		atlas.plants[id].genes.pattern.dominant = "Solid"
	var initial_progress: Dictionary = atlas.collection_progress()
	_check(initial_progress.pattern_count == 1 and initial_progress.species_count == 3, "codex reports actual discoveries")
	_check(initial_progress.unclaimed == 0, "incomplete codex pages have no reward")
	for pattern: String in ["Striped", "Spotted"]:
		var variant: Dictionary = atlas._create_base(0, 7381 + atlas.plants.size())
		variant.genes.pattern.dominant = pattern
		atlas._add_plant(variant)
	var completed_page: Dictionary = atlas.collection_progress()
	_check(completed_page.species_pages[0].complete and completed_page.species_pages[0].total == 3, "three patterns complete a species page")
	var page_reward: Dictionary = atlas.claim_collection()
	_check(page_reward.ok and page_reward.seeds == 1 and page_reward.agents == 1, "species page awards one lineage seed and one agent")
	_check(atlas.seed_bank[-1].species == "Veilfern", "species reward seed matches completed page")
	_check(not atlas.claim_collection().ok, "codex page cannot be claimed twice")
	for pattern: String in ["Gradient", "Starburst", "Bicolor Ring"]:
		var variant: Dictionary = atlas._create_base(0, 7381 + atlas.plants.size())
		variant.genes.pattern.dominant = pattern
		atlas._add_plant(variant)
	var family_progress: Dictionary = atlas.collection_progress()
	_check(family_progress.pattern_count == 6 and family_progress.pattern_complete, "six patterns complete the family")
	var family_reward: Dictionary = atlas.claim_collection()
	_check(family_reward.seeds == 1 and family_reward.agents == 2 and atlas.seed_bank[-1].rarity == "Rare", "pattern family gives a rare seed and two agents")
	for species_index in range(3, 7):
		atlas._add_plant(atlas._create_base(species_index, 8129 + species_index))
	var atlas_progress: Dictionary = atlas.collection_progress()
	_check(atlas_progress.species_count == 7 and atlas_progress.atlas_complete, "all seven base species complete atlas")
	var atlas_reward: Dictionary = atlas.claim_collection()
	_check(atlas_reward.seeds == 1 and atlas_reward.agents == 2 and atlas.seed_bank[-1].rarity == "Rare", "atlas gives a rare seed and two agents")
	for id: String in atlas.plant_order:
		atlas.plants[id].genes.pattern.dominant = "Solid"
	_check(atlas.collection_progress().pattern_count == 6, "codex remembers markings after they change")
	atlas.save_game()
	var atlas_loaded: RefCounted = Model.new("/tmp/conservatory_collection_test.json")
	_check(atlas_loaded.load_game() and atlas_loaded.collection_claimed.size() == 3, "collection reward claims persist")
	_check(atlas_loaded.collection_progress().pattern_count == 6, "collection discoveries persist")
	_check(not atlas_loaded.claim_collection().ok, "reload cannot duplicate collection rewards")
	# Saves from before collection milestones still load, and recover live discoveries.
	var legacy_file: FileAccess = FileAccess.open("/tmp/conservatory_collection_test.json", FileAccess.READ)
	var legacy_payload: Dictionary = JSON.parse_string(legacy_file.get_as_text())
	legacy_file.close()
	legacy_payload.erase("collection_claimed")
	legacy_payload.erase("collection_seen")
	legacy_file = FileAccess.open("/tmp/conservatory_collection_test.json", FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy_payload))
	legacy_file.close()
	var legacy_model: RefCounted = Model.new("/tmp/conservatory_collection_test.json")
	_check(legacy_model.load_game() and legacy_model.collection_claimed.is_empty(), "legacy saves load with unclaimed collection milestones")
	_check(legacy_model.collection_progress().pattern_count >= 1, "legacy saves reconstruct discovery archive")
	print("MODEL TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)
