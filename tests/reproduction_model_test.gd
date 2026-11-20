extends SceneTree
## The core loop is tested across real save boundaries, not by creating a child
## directly. Tests advance only the temporary archive's recorded timestamps.
const Model = preload("res://scripts/garden_state.gd")
var checks: int = 0
var failures: int = 0
var paths: Array[String] = []

func check(value: bool,message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("REPRODUCTION MODEL: "+message)

func fresh(suffix: String) -> RefCounted:
	var path: String = "/tmp/conservatory_reproduction_%s_%d.json" % [suffix,Time.get_ticks_usec()]
	paths.append(path)
	var state = Model.new(path)
	state.new_game()
	return state

func reload(state: RefCounted) -> RefCounted:
	var result = Model.new(state.save_path)
	check(result.load_game(),"Reproduction save reloads")
	return result

func loop_child(state: RefCounted,mother: String,father: String,expected_generation: int) -> String:
	var count: int = state.plants.size()
	var counter: int = state.id_counter
	var before: int = int(state.resources.sunlight)
	var result: Dictionary = state.pollinate(mother,father)
	check(result.ok,"Any selected mature parents can pollinate")
	if not result.ok: return ""
	check(state.plants.size()==count and state.id_counter==counter,"Fertilization holds embryos without creating owned plants or consuming plant IDs")
	check(int(state.resources.sunlight)==before-Model.POLLINATION_COST,"Pollination spends the disclosed cost once")
	var batch: Dictionary = state.pollinations[mother]
	check(batch.seeds.size()==2 and int(batch.generation)==expected_generation,"A hybrid fruit holds two next-generation seeds")
	var original_genome: Dictionary = batch.seeds[0].genome.duplicate(true)
	check(original_genome.parents==[mother,father],"Fertilization records both exact parents")
	check(not state.pollinate(mother,father).ok,"A developing fruit cannot be overwritten by a repeated action")
	check(not state.harvest_fruit(mother).ok,"Unripe fruit cannot be harvested early")
	state = reload(state)
	check(state.pollinations[mother].seeds[0].genome==original_genome,"Unripe embryos persist exactly across reload")
	state.pollinations[mother].ready_at = 0
	var harvest: Dictionary = state.harvest_fruit(mother)
	check(harvest.ok and harvest.fruits.size()==1 and harvest.fruits[0].kind=="hybrid","Ripe cross produces one collectible hybrid fruit")
	check(not state.pollinations.has(mother) and int(harvest.sunlight)==30,"Harvest releases the maternal slot and funds continued breeding")
	check(not state.harvest_fruit(mother).ok,"The same fruit cannot be harvested twice")
	state = reload(state)
	var fruit: Dictionary = state.fruit_inventory.back()
	check(fruit.seeds[0].genome==original_genome,"Harvested fruit keeps the fertilized genome before extraction")
	var seeds_before: int = state.seed_bank.size()
	check(state.extract_seeds(str(fruit.id)).ok,"Stored fruit opens into seeds")
	check(state.seed_bank.size()==seeds_before+2 and state.fruit_inventory.is_empty(),"Extraction consumes one fruit and gives its two seeds")
	check(not state.extract_seeds(str(fruit.id)).ok,"Repeated extraction cannot duplicate seed genomes")
	state = reload(state)
	check(state.seed_bank[seeds_before].genome==original_genome,"Stored seed retains its full frozen genome")
	var random_before: int = state.random.state
	var birth: Dictionary = state.plant_seed(seeds_before)
	check(birth.ok,"The extracted hybrid seed can be sown")
	if not birth.ok: return ""
	var child: Dictionary = birth.plant
	check(state.random.state==random_before,"Sowing a fertilized seed does not reroll genetic randomness")
	check(state.id_counter==counter+1 and state.plants.size()==count+1,"Sowing creates exactly one unique owned plant")
	check(int(child.generation)==expected_generation and not child.mature,"The child grows before becoming a parent")
	for field: String in ["genes","gene_sources","stats","skills","skill_genes","parents","lineage_mix","inherited_graft_records"]:
		check(child.get(field)==original_genome.get(field),"Sowing preserves inherited "+field)
	check(not state.pollinate(str(child.id),father).ok,"Immature children cannot be used early")
	child.ready_at = 0
	state.tick_growth()
	check(child.mature and state.fruit_crops.has(child.id),"Maturation makes the same individual fertile and starts its natural fruit cycle")
	state.save_game()
	return str(child.id)

func _initialize() -> void:
	var state: RefCounted = fresh("loop")
	var leaf: String = str(state.plant_order[0])
	var bloom: String = str(state.plant_order[1])
	var vine: String = str(state.plant_order[2])
	var before: Dictionary = state.resources.duplicate()
	check(not state.pollinate(leaf,leaf).ok and state.resources==before,"Same-individual selection cannot spend breeding resources")
	check(not state.pollinate(leaf,"missing").ok and state.resources==before,"Unknown parent IDs cannot spend resources")
	var g2: String = loop_child(state,leaf,bloom,2)
	state = reload(state)
	check(not g2.is_empty() and state.plants.has(g2),"The first hybrid remains in the owned archive")
	if g2.is_empty(): quit(1); return
	check(state.plants[g2].lineage_mix=={"Leaf":0.5,"Bloom":0.5},"G2 carries equal contributions from both founding types")
	var g3: String = loop_child(state,g2,vine,3)
	state = reload(state)
	if g3.is_empty(): quit(1); return
	check(state.plants[g3].lineage_mix=={"Leaf":0.25,"Bloom":0.25,"Vine":0.5},"G3 retains both grandparents and the next parent")
	var root: Dictionary = state._create_base(3,2938531)
	state._add_plant(root)
	state.save_game()
	var g4: String = loop_child(state,g3,str(root.id),4)
	state = reload(state)
	if g4.is_empty(): quit(1); return
	check(state.plants[g4].lineage_mix=={"Leaf":0.125,"Bloom":0.125,"Vine":0.25,"Root":0.5},"G4 preserves four founding lineages instead of resetting to dominant species")
	check(state.lineage(g4,4).ancestors.size()==2,"Full parentage remains navigable after repeated fruit and seed cycles")
	# Each source entry must describe the gamete that really supplied its allele.
	var child: Dictionary = state.plants[g4]
	for slot: String in child.genes:
		var source: Dictionary = child.gene_sources[slot]
		check(source.allele_a.parent_id==g3 and source.allele_b.parent_id==root.id,"Locus "+slot+" identifies both actual parental gametes")
		check(source.allele_a.value==state.plants[g3].genes[slot][source.allele_a.allele] and source.allele_b.value==root.genes[slot][source.allele_b.allele],"Locus "+slot+" source values match selected parental alleles")
		check(source.expressed==child.genes[slot].dominant and source.carried==child.genes[slot].recessive,"Locus "+slot+" provenance matches visible/carried genes")
	# Natural fruit and seed regeneration keep the same mixed ancestry.
	state.fruit_crops[g4].natural_ready_at = 0
	var natural: Dictionary = state.harvest_fruit(g4)
	check(natural.ok and natural.fruits[0].kind=="natural" and int(natural.sunlight)==10,"Every mature hybrid can grow a natural collectible fruit")
	var seed_index: int = state.seed_bank.size()
	state.extract_seeds(str(natural.fruits[0].id))
	check(state.seed_bank[seed_index].genome.parents==[g4] and int(state.seed_bank[seed_index].generation)==5,"Natural hybrid fruit produces a next-generation lineage seed")
	var natural_child: Dictionary = state.plant_seed(seed_index).plant
	check(natural_child.lineage_mix==child.lineage_mix and int(natural_child.generation)==5,"Natural seeds preserve all hybrid ancestry when replanted")
	# Historical tendency seeds with archived parent IDs recover real ancestry.
	var old_seed: Dictionary = state._make_seed(0,"Common")
	old_seed.parents = [g4]
	state.seed_bank.append(old_seed)
	var restored_old: Dictionary = state.plant_seed(state.seed_bank.size()-1).plant
	check(restored_old.lineage_mix==child.lineage_mix and restored_old.parents==[g4],"Earlier collected hybrid seeds no longer revert to a base fern")
	# Crosses remain available across the complete type matrix, including traps.
	var all: RefCounted = fresh("all_types")
	all.resources.sunlight = 10000
	var ids: Array[String] = []
	for i in range(Model.TYPES.size()):
		var specimen: Dictionary = all._create_base(mini(i,6),38177+i)
		specimen.type = Model.TYPES[i]
		if i==7: specimen.species = "Hollow Pitcher"
		all._add_plant(specimen)
		ids.append(str(specimen.id))
	for a in range(ids.size()):
		for b in range(ids.size()):
			if a==b: continue
			all.pollinations.clear()
			var result: Dictionary = all.pollinate(ids[a],ids[b])
			check(result.ok and result.batch.seeds.size()==2,Model.TYPES[a]+" × "+Model.TYPES[b]+" is fertile without a species whitelist")
	# Successful grafts keep real donor anatomy through the seed pipeline.
	all.pollinations.clear()
	all.resources.grafts = 100
	var host: Dictionary = all.plants[ids[0]]
	var donor: Dictionary = all.plants[ids[5]]
	var graft_result: Dictionary = {}
	for i in range(100):
		donor.donor_ready_at = 0
		graft_result = all.graft(str(host.id),str(donor.id),"feature")
		if bool(graft_result.get("success",false)): break
	check(bool(graft_result.get("success",false)),"Different-type plants can graft real donor tissue")
	var record: Dictionary = host.graft_history[0]
	check(record.donor_type=="Toxin" and record.donor_genes==donor.genes and record.donor_seed==donor.seed,"Graft records preserve the actual donor's anatomy and genome")
	var inherited_seed: Dictionary = {}
	for i in range(100):
		all.pollinations.clear()
		var result: Dictionary = all.pollinate(str(host.id),ids[1])
		for seed_data: Dictionary in result.batch.seeds:
			if not seed_data.genome.inherited_graft_records.is_empty(): inherited_seed = seed_data
		if not inherited_seed.is_empty(): break
	check(not inherited_seed.is_empty(),"Recorded graft tissue can be inherited by hybrid seeds")
	if not inherited_seed.is_empty():
		all.seed_bank.append(inherited_seed.duplicate(true))
		var inherited: Dictionary = all.plant_seed(all.seed_bank.size()-1).plant
		check(inherited.inherited_graft_records[0].donor_type=="Toxin" and inherited.inherited_graft_records[0].donor_genes==inherited_seed.genome.inherited_graft_records[0].donor_genes,"Sowing preserves inherited donor anatomy rather than just a color")
	# V1 migration reconstructs ancestry from the existing archive's real parents.
	state.save_game()
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(state.save_path))
	for key: String in ["fruit_inventory","fruit_crops","pollinations","reproduction_counter"]: payload.erase(key)
	payload.seed_bank = [state._make_seed(0,"Common")]
	for specimen: Dictionary in payload.plants.values():
		specimen.erase("lineage_mix")
		specimen.erase("lineage_name")
	var old_file := FileAccess.open(state.save_path,FileAccess.WRITE)
	old_file.store_string(JSON.stringify(payload))
	old_file.close()
	var legacy: RefCounted = reload(state)
	check(legacy.plants[g4].lineage_mix==child.lineage_mix,"Older saved hybrids recover all ancestor types recursively")
	check(legacy.fruit_inventory.is_empty() and legacy.pollinations.is_empty() and not legacy.fruit_crops.is_empty(),"Old gardens gain a natural fruit cycle without losing their existing archive")
	# Reject new corrupt payloads before they can destroy otherwise valid saves.
	legacy.save_game()
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(legacy.save_path))
	check(legacy._valid_save(valid),"New reproduction archive validates")
	var malformed: Dictionary = valid.duplicate(true)
	malformed.fruit_inventory = ["broken fruit"]
	check(not legacy._valid_save(malformed),"Malformed stored fruits are rejected")
	malformed = valid.duplicate(true)
	malformed.fruit_crops[leaf].natural_ready_at = "tomorrow"
	check(not legacy._valid_save(malformed),"Malformed crop timers are rejected")
	malformed = valid.duplicate(true)
	malformed.seed_bank.append({"genome":{"genes":"broken"}})
	check(not legacy._valid_save(malformed),"Incomplete embryo genomes are rejected")
	malformed = valid.duplicate(true)
	malformed.plants[g4].lineage_mix = {"Unknown":1.0}
	check(not legacy._valid_save(malformed),"Unknown lineage types are rejected")
	# Harvest and extraction convenience actions obey the same single-use rules.
	for id: String in legacy.fruit_crops: legacy.fruit_crops[id].natural_ready_at = 0
	var overview: Dictionary = legacy.fruit_overview()
	check(int(overview.ready)==legacy.fruit_crops.size(),"Overview counts every ripe individual crop")
	check(legacy.harvest_all_fruit().ok,"Harvest-all collects mature fruits")
	var stored_count: int = legacy.fruit_inventory.size()
	var seeds_before: int = legacy.seed_bank.size()
	check(not legacy.harvest_all_fruit().ok,"Harvest-all cannot collect already harvested crops again")
	check(legacy.extract_all_seeds().ok and legacy.seed_bank.size()==seeds_before+stored_count,"Extract-all yields exactly the stored natural seeds")
	check(not legacy.extract_all_seeds().ok,"Extract-all cannot duplicate opened fruit")
	# Active-time life stages do not spend the age of an offline garden.
	var living: RefCounted = fresh("lifecycle")
	var aging_id: String = str(living.plant_order[0])
	var pollen_id: String = str(living.plant_order[1])
	var organism: Dictionary = living.plants[aging_id]
	organism.born_at = 1
	check(living.life_profile(aging_id).stage=="mature" and float(organism.life_age)==0.0,"An old wallclock birth date does not age a plant offline")
	organism.life_age = 1199.0
	check(living.advance_lifecycle(1.0) and living.life_profile(aging_id).stage=="aging","Active growth reaches the aging stage at twenty minutes")
	check(int(living.life_profile(aging_id).remaining)==300,"Aging plants have five active minutes left")
	living.save_game()
	var offline: RefCounted = reload(living)
	check(float(offline.plants[aging_id].life_age)==1200.0,"Life age persists without adding offline elapsed time")
	check(not living.advance_lifecycle(0.0) and not living.advance_lifecycle(-1.0),"Non-positive lifecycle ticks do not advance age")
	living.place_in_bed(aging_id,0)
	living.place_in_display(aging_id,0)
	check(living.pollinate(aging_id,pollen_id).ok,"An aging plant remains fertile while still alive")
	var dying_genes: Dictionary = organism.genes.duplicate(true)
	var dying_sources: Dictionary = organism.gene_sources.duplicate(true)
	organism.life_age = 1499.0
	check(living.advance_lifecycle(1.0) and living.life_profile(aging_id).stage=="withered","A plant naturally withers after twenty-five active minutes")
	check(bool(organism.withered) and bool(organism.retired) and living.plants.has(aging_id),"Withering retains the archived individual instead of deleting its DNA")
	check(not living.bed.has(aging_id) and not living.display_bed.has(aging_id),"Withered plants leave the living garden beds")
	check(organism.genes==dying_genes and organism.gene_sources==dying_sources,"Withering leaves all alleles and provenance unchanged")
	check(not living.pollinate(aging_id,pollen_id).ok and not living.crossbreed(aging_id,pollen_id).ok,"Withered parents cannot fertilize or breed")
	check(not living.graft(aging_id,pollen_id).ok and not living.graft(pollen_id,aging_id).ok,"Withered plants cannot supply or receive graft tissue")
	check(not living.mutate(aging_id).ok and not living.mature_plant(aging_id).ok,"Mutation and quick growth cannot revive a withered plant")
	check(not living.place_in_bed(aging_id,0) and not living.place_in_display(aging_id,0),"Withered archives cannot be placed as living plants")
	check(bool(living.fruit_status(aging_id).natural_ready),"A withered plant retains one final ripe natural fruit")
	check(living.pollinations.has(aging_id),"A pollinated fruit retains its frozen embryos after the mother withers")
	var last_fruit: Dictionary = living.harvest_fruit(aging_id)
	check(last_fruit.ok and last_fruit.fruits.size()==1 and last_fruit.fruits[0].kind=="natural","The final natural fruit can be collected exactly once")
	check(not living.fruit_crops.has(aging_id),"A final harvest does not schedule a new fruit crop on dead tissue")
	living.tick_reproduction()
	check(not living.harvest_fruit(aging_id).ok and not living.fruit_crops.has(aging_id),"Readiness ticks cannot restart final fruit production")
	living.pollinations[aging_id].ready_at = 0
	check(living.harvest_fruit(aging_id).ok and not living.pollinations.has(aging_id),"The existing pollinated fruit can still ripen and be harvested after maternal death")
	var seeds_index: int = living.seed_bank.size()
	living.extract_all_seeds()
	var successor: Dictionary = living.plant_seed(seeds_index).plant
	check(successor.parents==[aging_id] and float(successor.life_age)==0.0 and not bool(successor.withered),"The final fruit seed starts a fresh living generation with the old DNA ancestry")
	check(living.lineage(str(successor.id)).ancestors[0].id==aging_id,"Withered ancestors remain available in later family trees")
	living.save_game()
	var last_reload: RefCounted = reload(living)
	check(bool(last_reload.plants[aging_id].withered) and not last_reload.fruit_crops.has(aging_id),"A consumed final crop stays consumed across reload")
	check(last_reload.plants[str(successor.id)].parents==[aging_id],"A seed-grown successor retains its withered ancestor across reload")
	# New mutations record the actual changed germline locus, not an invented parent.
	living.resources.agents = 100
	var target: String = pollen_id
	var mutation: Dictionary = {}
	for i in range(100):
		mutation = living.mutate(target,"chemical","pattern")
		if mutation.get("outcome","")=="New trait": break
	var actual: Dictionary = living.plants[target]
	check(mutation.get("outcome","")=="New trait" and actual.gene_sources.pattern.expressed_origin=="mutation","A mutated locus records its true mutation origin")
	check(actual.gene_sources.pattern.expressed==actual.genes.pattern.dominant and actual.gene_sources.pattern.carried==actual.genes.pattern.recessive,"Mutation provenance matches the changed expressed and carried values")
	check(str(actual.gene_sources.pattern.allele_a.parent_id).is_empty(),"A mutation is not mislabeled as a new parental allele")
	for path: String in paths:
		for file_path: String in [path,path.get_basename()+".backup.json",path+".tmp"]:
			if FileAccess.file_exists(file_path): DirAccess.remove_absolute(file_path)
	print("REPRODUCTION MODEL TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
