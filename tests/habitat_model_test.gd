extends SceneTree
## Landscapes give honest collection guidance and never rewrite old organisms.
const Model = preload("res://scripts/garden_state.gd")
const Habitat = preload("res://scripts/habitat_catalog.gd")
const World = preload("res://scripts/wilderness.gd")
var checks: int = 0
var failures: int = 0

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)

func organism(p: Dictionary) -> String:
	var copy: Dictionary=p.duplicate(true)
	copy.erase("origin")
	return JSON.stringify(copy)

func _initialize() -> void:
	var path: String="/tmp/conservatory_habitats_%d.json" % Time.get_ticks_usec()
	var state=Model.new(path)
	state.new_game()
	state.begin_expedition()
	state.expedition.captures=0
	check(Habitat.region("Unknown").is_empty() and Habitat.patch("Unknown","invalid").is_empty(),"An unknown landscape has no invented species or field hint")
	check(Habitat.preferred_habitats("Unknown").is_empty(),"Unknown custom species have no fabricated ecology")
	var counts: Dictionary={}
	var terrain_names: Dictionary={}
	var all_families: Dictionary={}
	for site: Dictionary in World.SITES:
		var biome: String=str(site.biome)
		var info: Dictionary=Habitat.site_info(biome,str(site.id))
		if not counts.has(biome): counts[biome]={}
		counts[biome][info.id]=true
		terrain_names[info.terrain]=true
		var p: Dictionary=state.preview_wild_plant(biome,str(site.id))
		all_families[p.species]=true
		check(info.species.has(p.species),"The actual plant lives in the microhabitat shown by its map clue: "+str(site.id))
		check(p.origin.habitat_key==info.id and p.origin.habitat==info.name and p.origin.landscape==info.landscape,"Collected provenance identifies the actual landscape and microhabitat: "+str(site.id))
	for biome: String in Model.WILD_BIOMES:
		var guide: Dictionary=Habitat.region(biome)
		check(not guide.landscape.is_empty() and not guide.clue.is_empty() and not guide.signature_species.is_empty(),"The region has landscape, species and useful botanical directions: "+biome)
		check(counts[biome].size()==3,"The actual reachable map has all three distinct microhabitats in "+biome)
		var residents: int=0
		for i in range(120):
			var site: String="ecology_%s_%d" % [biome,i]
			var info: Dictionary=Habitat.patch(biome,site)
			var p: Dictionary=state.preview_wild_plant(biome,site)
			if p.species==info.primary_species: residents+=1
		check(residents>=68 and residents<=108,"The advertised resident family is a real encounter preference in "+biome+": "+str(residents)+"/120")
	check(all_families.size()==7,"All seven founding families remain reachable on the real map")
	check(terrain_names.size()>=12,"Microhabitats distinguish more than twelve physical landscape motifs")
	for i in range(Habitat.SPECIES.size()):
		var guides: Array[Dictionary]=Habitat.preferred_habitats(Habitat.SPECIES[i])
		check(not guides.is_empty() and guides[0].primary,"Each founding species has a real favored habitat: "+Habitat.SPECIES[i])
		check(Habitat.preferred_habitats(Habitat.TYPES[i])==guides,"Species and inherited plant type point to the same botanical homes")
		var reached_companion: bool=false
		var ordered: bool=true
		for entry: Dictionary in guides:
			if not entry.primary: reached_companion=true
			elif reached_companion: ordered=false
		check(ordered,"Useful resident habitats appear before occasional companion locations")
	var before: String=JSON.stringify([state.expedition,state.plants,state.plant_order,state.resources,state.random.state,state.id_counter])
	var disk_before: PackedByteArray=FileAccess.get_file_as_bytes(path)
	var isolated: Dictionary=Habitat.patch("Mosswood","moss_01")
	isolated.species_pool.clear()
	isolated.species.clear()
	var guide_copy: Dictionary=Habitat.region("Mosswood")
	guide_copy.signature_species.clear()
	check(Habitat.patch("Mosswood","moss_01").primary_species=="Veilfern" and Habitat.species_pool("Mosswood","moss_01").size()==4 and not Habitat.region("Mosswood").signature_species.is_empty(),"Art and UI callers cannot mutate the shared ecological guide")
	check(JSON.stringify([state.expedition,state.plants,state.plant_order,state.resources,state.random.state,state.id_counter])==before and FileAccess.get_file_as_bytes(path)==disk_before,"Reading landscape guidance changes neither a garden nor its saved file")
	var stable: Dictionary=Habitat.patch("Moonfen","field_099_097")
	state.expedition.respawn_day-=1
	state.begin_expedition()
	check(Habitat.patch("Moonfen","field_099_097")==stable,"Daily regrowth changes individuals without shuffling the landscape's microhabitat")
	# An old departed encounter must use the previous regional lottery when
	# resumed, rather than silently becoming a newly favored family after update.
	for biome: String in Model.WILD_BIOMES:
		var site: String="legacy_"+biome
		state.expedition.site_records[site]={"attempts":1,"observed":true,"fled":false}
		var old: Dictionary=state.preview_wild_plant(biome,site)
		var rng:=RandomNumberGenerator.new()
		rng.seed=int(old.seed)
		var pool: Array=Model.WILD_BIOMES[biome]
		var expected: int=int(pool[rng.randi_range(0,pool.size()-1)])
		check(old.species==Model.SPECIES[expected].name and not old.origin.has("habitat_key"),"An already started legacy patch preserves its original family lottery: "+biome)
		var actual: Dictionary=state.wild_encounter(biome,site)
		check(organism(actual.plant)==organism(old),"Entering an old observed patch preserves its full genome: "+biome)
		state.leave_wild_encounter()
		check(organism(state.preview_wild_plant(biome,site))==organism(old),"Leaving and returning cannot reroll the old individual: "+biome)
	var fresh: Dictionary=state.wild_encounter("Glassfall Coast","fresh_tidal_patch")
	var active_snapshot: String=JSON.stringify(fresh.plant)
	check(state.expedition.site_records["fresh_tidal_patch"].ecology_version==1,"New encounters mark which ecological rule generated them")
	var restored=Model.new(path)
	check(restored.load_game(),"The habitat-bearing encounter save reloads")
	check(JSON.parse_string(JSON.stringify(restored.preview_wild_plant("Glassfall Coast","fresh_tidal_patch")))==JSON.parse_string(active_snapshot),"Reloading and drawing an active encounter preserves every plant field exactly")
	check(Habitat.preferred_habitats("Hollow Pitcher").size()==3 and Habitat.preferred_habitats("Carnivorous")[0].rare,"Rare pitcher guidance identifies the same three deep habitats as the collection rules")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path.get_basename()+".backup.json")
	print("HABITAT MODEL TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
