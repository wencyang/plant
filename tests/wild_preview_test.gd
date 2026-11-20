extends SceneTree
const Model = preload("res://scripts/garden_state.gd")
var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAILED: "+message)

func snapshot(state: RefCounted) -> String:
	return JSON.stringify([state.plants,state.bed,state.display_bed,state.resources,
		state.seed_bank,state.plant_order,state.field_kits,state.expedition,
		state.id_counter,state.discovered,state.claimed,state.collection_seen,
		state.random.state])

func genotype(plant: Dictionary) -> Array:
	return [plant.id,plant.seed,plant.name,plant.species,plant.type,plant.secondary_type,
		plant.genes,plant.stats,plant.skills,plant.skill_genes,plant.rarity,
		plant.parents,plant.generation,plant.mature,plant.deformed]

func _initialize() -> void:
	var path: String = "/tmp/conservatory_wild_preview_%d.json" % Time.get_ticks_usec()
	var unstarted: RefCounted = Model.new(path)
	var empty_before: String = snapshot(unstarted)
	check(not unstarted.preview_wild_plant("Mosswood","moss_01").is_empty(),"unstarted model can preview with default expedition values")
	check(snapshot(unstarted) == empty_before and not FileAccess.file_exists(path),"unstarted preview creates neither expedition nor save")
	check(unstarted.preview_wild_plant("Unknown","invalid").is_empty(),"unmapped preview has no invented plant")
	var state: RefCounted = Model.new(path)
	state.new_game()
	var first_before: String = snapshot(state)
	var saved_before: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var first: Dictionary = state.preview_wild_plant("Mosswood","moss_01")
	check(first.type == "Leaf" and first.origin.site == "moss_01","first map sprite is the familiar fern at its exact patch")
	check(snapshot(state) == first_before and FileAccess.get_file_as_bytes(path) == saved_before,"map preview never saves, spends resources or IDs, discovers plants, opens encounters, or advances gameplay RNG")
	for biome: String in Model.WILD_BIOMES:
		var site: String = "preview_"+biome
		var before: String = snapshot(state)
		var preview: Dictionary = state.preview_wild_plant(biome,site)
		var repeated: Dictionary = state.preview_wild_plant(biome,site)
		check(genotype(preview) == genotype(repeated),"repeated map rendering is stable in "+biome)
		check(snapshot(state) == before,"preview is pure in "+biome)
		var actual: Dictionary = state.wild_encounter(biome,site)
		check(actual.ok and genotype(actual.plant) == genotype(preview),"map artwork and encountered genome agree in "+biome)
		check(state.preview_wild_plant(biome,site) == actual.plant,"active specimen preview preserves the exact saved organism in "+biome)
		var isolated: Dictionary = state.preview_wild_plant(biome,site)
		isolated.genes.color.dominant = "000000"
		check(state.expedition.active_encounter.plant.genes.color.dominant != "000000","rendering cannot edit active organism through shared data")
		state.leave_wild_encounter()
	state.expedition.captures = 10
	var rare_site: String = ""
	for i in range(1000):
		var site: String = "preview_deep_%d" % i
		if state.preview_wild_plant("Ancient Grove",site).type == "Carnivorous":
			rare_site = site
			break
	check(not rare_site.is_empty(),"late wild previews include rare carnivorous lineage")
	if not rare_site.is_empty():
		var preview: Dictionary = state.preview_wild_plant("Ancient Grove",rare_site)
		var actual: Dictionary = state.wild_encounter("Ancient Grove",rare_site)
		check(actual.ok and genotype(actual.plant) == genotype(preview),"rare flytrap map art and actual encounter agree")
	state.leave_wild_encounter()
	state.move_explorer(90,72)
	check(genotype(state.preview_wild_plant("Moonfen")) == genotype(state.preview_wild_plant("Moonfen","Moonfen_90_72")),"implicit site preview follows the saved explorer position")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path.get_basename()+".backup.json")
	print("WILD PREVIEW TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
