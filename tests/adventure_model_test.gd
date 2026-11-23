extends SceneTree
const State = preload("res://scripts/garden_state.gd")
const Rules = preload("res://scripts/plant_adventure.gd")
const DNA = preload("res://scripts/plant_dna.gd")
var checks: int=0
var failures: int=0
var paths: Array[String]=[]

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("ADVENTURE MODEL: "+message)

func fresh(tag: String) -> RefCounted:
	var path: String="/tmp/conservatory_adventure_%s_%d.json" % [tag,Time.get_ticks_usec()]
	paths.append(path)
	var state=State.new(path)
	state.new_game()
	return state

func fingerprint(state: RefCounted) -> String:
	return DNA.canonical([state.plants,state.plant_order,state.bed,state.display_bed,state.resources,state.market,state.fair,state.adventure,state.seed_bank,state.fruit_inventory,state.fruit_crops,state.pollinations,state.random.state,state.id_counter,state.reproduction_counter,state.expedition])

func genotype(p: Dictionary) -> String:
	return DNA.canonical([p.genes,p.stats,p.skill_genes,p.parents,p.seed,p.lineage_mix])

func collect_four(state: RefCounted) -> Dictionary:
	var ids: Dictionary={}
	for key: String in ["river_fan","floatcap","gripvine","stone_root"]:
		var result: Dictionary=state.adventure_collect(key)
		check(bool(result.ok),"A real riverside cutting is available: "+key)
		ids[key]=str(result.plant_id)
	return ids

func ripe_cross(state: RefCounted,a: String,b: String,seed_value: int=5102026) -> Dictionary:
	state.random.seed=seed_value
	var result: Dictionary=state.adventure_begin_cross(a,b)
	check(bool(result.get("ok",false)),"The adventure uses normal two-parent pollination")
	if not result.get("ok",false): return {}
	check(int(state.pollinations[a].ready_at)-int(state.pollinations[a].started_at)==18,"Cross fruit keeps the normal18-second timer")
	var denied_before: String=fingerprint(state)
	check(not state.adventure_siblings(a).ok and fingerprint(state)==denied_before,"Unripe siblings cannot be planted and failed preview is atomic")
	var care: Dictionary=state.apply_care(a,"ripening")
	check(bool(care.ok),"Real ripening care can prepare a cross for testing")
	return result

func grow(state: RefCounted,ids: Array) -> void:
	for id: String in ids:
		var result: Dictionary=state.apply_care(id,"sunlamp")
		check(bool(result.ok) and bool(state.get_plant(id).mature),"Real sunshine care matures the actual seedling")

func run() -> void:
	var state: RefCounted=fresh("raft")
	var before: String=fingerprint(state)
	check(state.adventure_info().stage=="shore" and state.adventure_plants().size()==5,"New and migrated gardens begin with the stream mystery")
	for i in range(3):
		state.adventure_info(); state.adventure_plants(); state.adventure_preview(str(state.plant_order[0])); state.adventure_capabilities(state.plants[state.plant_order[0]])
	check(fingerprint(state)==before,"Reading clue, template and ability panels never spends RNG, resources, IDs or inventory")
	check(not state.adventure_collect("moonbell").ok and fingerprint(state)==before,"The far-bank flower cannot be collected through a closed stream")
	check(not state.adventure_collect("not_a_plant").ok and fingerprint(state)==before,"Unknown cutting requests are pure failures")
	var old_resources: Dictionary=state.resources.duplicate(true)
	var ids: Dictionary=collect_four(state)
	check(state.resources==old_resources,"Discovering the four introductory cuttings is free")
	for row: Dictionary in state.adventure_plants():
		if str(row.key)=="moonbell":
			check(not row.available and not row.claimed,"Island discovery remains visibly locked until a crossing exists")
			continue
		check(row.claimed and row.available,"Claimed shore cuttings show their actual owned plant")
		var quote: Dictionary=state.market_quote("plant",str(row.id))
		check(not quote.eligible and quote.reason=="Field cuttings stay with you. Their offspring can be traded.","Free cuttings cannot be converted to unlimited market money")
		var unchanged: String=fingerprint(state)
		check(not state.market_sell("plant",str(row.id)).ok and fingerprint(state)==unchanged,"Direct sale cannot bypass the field cutting guard")
		check(not state.adventure_collect(str(row.key)).ok and fingerprint(state)==unchanged,"Repeated collection cannot duplicate a living original")
	check(state.life_profile(str(ids.river_fan)).life_limit==3600,"Healthy field cuttings have a valid60-minute active lifespan reserve")
	check(state.adventure_preview(str(ids.river_fan)).eligible,"Expressed sheltering traits work in founders as well as descendants")
	# The exact two fertilized embryos are used, even with a very large seed box
	# and a full bed. No earlier packet or existing garden placement is touched.
	var packet: Dictionary=state.seed_bank[0].duplicate(true)
	for i in range(340): state.seed_bank.append(packet.duplicate(true))
	var bank_before: String=DNA.canonical(state.seed_bank)
	for i in range(state.bed.size()): state.bed[i]=str(state.plant_order[i%state.plant_order.size()])
	var bed_before: Array=state.bed.duplicate()
	var cross: Dictionary=ripe_cross(state,str(ids.river_fan),str(ids.floatcap))
	var embryos: Array=state.pollinations[str(ids.river_fan)].seeds.duplicate(true)
	var natural_before: Dictionary=state.fruit_crops.duplicate(true)
	var light_before: int=int(state.resources.sunlight)
	var planted: Dictionary=state.adventure_siblings(str(ids.river_fan))
	check(planted.ok and planted.plants.size()==2 and planted.plant_ids.size()==2,"A ripe cross plants both real siblings with their IDs")
	check(int(state.resources.sunlight)==light_before+10 and int(planted.sunlight)==10,"The shortcut grants normal30light harvest and charges20 for two normal plantings")
	check(state.bed==bed_before and not state.bed.has(planted.plant_ids[0]) and not state.bed.has(planted.plant_ids[1]),"A full garden benches both seedlings without moving existing plants")
	check(DNA.canonical(state.seed_bank)==bank_before and state.fruit_inventory.is_empty(),"Sowing siblings leaves the335-plus existing seed inventory exact")
	check(state.fruit_crops==natural_before,"Only the hybrid fruit is harvested; natural crops remain untouched")
	for i in range(2):
		var child: Dictionary=planted.plants[i]
		check(genotype(child)==genotype(embryos[i].genome),"Planted sibling preserves every fertilized gene, skill, stat, parent and ancestry share")
		check(child.parents==[ids.river_fan,ids.floatcap] and int(child.generation)==2,"Sibling records are real two-parentG2 births")
		check(not child.mature and int(child.ready_at)-int(child.born_at)==12,"The normal12-second seedling lifetime is preserved")
		check(not state.adventure_preview(str(child.id)).eligible,"An immature ability cannot open the world before it unfolds")
		check(state.adventure_capabilities(child).raft,"Both homozygous parent combinations produce the actual promised raft traits")
	var twice_before: String=fingerprint(state)
	check(not state.adventure_siblings(str(ids.river_fan)).ok and fingerprint(state)==twice_before,"Queued repeated sow clicks cannot generate or reward extra siblings")
	grow(state,planted.plant_ids)
	var child_id: String=str(planted.plant_ids[0])
	var child_snapshot: String=genotype(state.plants[child_id])
	var wallet: int=state.market_wallet()
	var supplies: Dictionary=state.resources.duplicate(true)
	check(state.adventure_preview(child_id).eligible,"The grown raft offspring is eligible through its real traits")
	check(not state.adventure_use(child_id,"stream","vine").ok,"An arbitrary route cannot be selected without its genes")
	var opened: Dictionary=state.adventure_use(child_id,"stream","raft")
	check(opened.ok and state.adventure_info().stage=="island" and state.adventure.route=="raft","The raft permanently changes the stream")
	check(genotype(state.plants[child_id])==child_snapshot and state.resources==supplies and state.market_wallet()==wallet and state.owns_plant(child_id),"Using an ability keeps the original plant, all DNA, and every resource")
	var opened_before: String=fingerprint(state)
	check(not state.adventure_use(child_id).ok and fingerprint(state)==opened_before,"A permanent crossing cannot be awarded twice")
	var moon: Dictionary=state.adventure_collect("moonbell")
	check(moon.ok and state.adventure_info().stage=="lantern","The island flower becomes a real new breeding parent")
	check(moon.plant.genes.glow=={"dominant":"Soft Glow","recessive":"Soft Glow"},"Moonbell has real canonical SoftGlow DNA in both copies")
	check(state.adventure_preview(str(moon.plant_id),"lantern").eligible,"Actual glow works in any generation without an arbitrary generation key")
	var glowing_id: String=""
	var g3: Dictionary={}
	for attempt in range(12):
		var mother: String=str(moon.plant_id) if attempt%2==0 else child_id
		var father: String=child_id if attempt%2==0 else str(moon.plant_id)
		var started: Dictionary=state.adventure_begin_cross(mother,father)
		check(started.ok,"A second real cross can use the previous hybrid as a parent")
		# Simulate elapsed ripening time; embryos were already generated by the
		# unchanged pollination rule. No genome or RNG result is edited.
		state.pollinations[mother].ready_at=0
		g3=state.adventure_siblings(mother)
		check(g3.ok,"The full breeding loop repeats for later generations")
		grow(state,g3.plant_ids)
		for id: String in g3.plant_ids:
			var plant: Dictionary=state.get_plant(id)
			check(int(plant.generation)==3 and plant.parents.has(child_id),"G3 keeps the actualG2parent and lineage")
			if str(plant.genes.glow.dominant)=="Soft Glow": glowing_id=id
		if not glowing_id.is_empty(): break
	check(not glowing_id.is_empty(),"Actual independent inheritance produces an eligible glowing grandchild")
	if not glowing_id.is_empty():
		var no_cost: String=DNA.canonical([state.plants,state.resources,state.seed_bank,state.market])
		var restored: Dictionary=state.adventure_use(glowing_id,"lantern")
		check(restored.ok and state.adventure_info().stage=="restored","A real glowingG3descendant restores the hidden courtyard")
		check(DNA.canonical([state.plants,state.resources,state.seed_bank,state.market])==no_cost,"Restoring the courtyard retains the descendant and spends no supplies")
		var repeat: String=fingerprint(state)
		check(not state.adventure_use(glowing_id,"lantern").ok and fingerprint(state)==repeat,"The courtyard is a permanent discovery, not a repeatable payout")
	check(Rules.valid_adventure(state.adventure,state.plants),"Completed adventure evidence passes strict save validation")
	state.save_game()
	var restored_state=State.new(state.save_path)
	check(restored_state.load_game() and DNA.canonical(restored_state.adventure)==DNA.canonical(state.adventure),"Cuttings, crossings, latest siblings and courtyard survive reload")
	# Mutation or the end of a useful plant's life does not erase a place it grew.
	state.plants[child_id].genes.texture.dominant="Matte"
	state.plants[child_id].withered=true
	check(Rules.valid_adventure(state.adventure,state.plants) and state.adventure_info().stage=="restored","Recorded ability evidence remains valid after its plant later mutates or withers")
	var evidence_bad: Dictionary=state.adventure.duplicate(true)
	evidence_bad.route_record.evidence.genes.texture.dominant="Matte"
	check(not Rules.valid_adventure(evidence_bad,state.plants),"Forged crossing evidence without the required genes is rejected")
	var stage_bad: Dictionary=Rules.default_adventure()
	stage_bad.route="raft"; stage_bad.route_plant_id=child_id
	check(not Rules.valid_adventure(stage_bad,state.plants),"A forged progress flag cannot skip the actual inherited ability")
	var invalid_id: Dictionary=state.adventure.duplicate(true)
	invalid_id.cuttings.river_fan="missing_plant"
	check(not Rules.valid_adventure(invalid_id,state.plants),"Dangling cutting references are rejected")
	var original_id: String=str(ids.river_fan)
	state.plants[original_id].withered=true
	state.plants[original_id].retired=true
	var replacement: Dictionary=state.adventure_collect("river_fan")
	check(replacement.ok and str(replacement.plant_id)!=original_id and state.plants.has(original_id),"A withered cutting can be replaced without deleting its archived DNA")
	check(not state.adventure_collect("river_fan").ok,"A living replacement cannot be duplicated")
	var variant: Dictionary=state.get_plant(str(ids.floatcap))
	variant.genes.pattern.dominant="Starburst"
	check(not state.adventure_collect("floatcap").ok,"A cosmetic mutation does not duplicate a still-useful cutting")
	variant.genes.texture.dominant="Matte"
	check(state.adventure_collect("floatcap").ok,"A capability-changing mutation can recover its original field cutting")
	# The alternative route uses ordinary ancestry and genes too.
	var bridge_state: RefCounted=fresh("vine")
	var bridge_ids: Dictionary=collect_four(bridge_state)
	ripe_cross(bridge_state,str(bridge_ids.gripvine),str(bridge_ids.stone_root))
	var vines: Dictionary=bridge_state.adventure_siblings(str(bridge_ids.gripvine))
	grow(bridge_state,vines.plant_ids)
	for id: String in vines.plant_ids:
		check(bridge_state.adventure_capabilities(bridge_state.plants[id]).vine,"Both vine/root offspring honestly inherit the alternative bridge solution")
	check(bridge_state.adventure_use(str(vines.plant_ids[0]),"stream","vine").ok and bridge_state.adventure.route=="vine","A second independent genetic solution opens the same stream")
	check(bridge_state.market_quote("plant",str(vines.plant_ids[1])).eligible,"Real offspring remain tradeable after their free parents were protected")
	# Old saves omit adventure entirely and keep every organism and currency.
	var old: RefCounted=fresh("legacy")
	var file=FileAccess.open(old.save_path,FileAccess.READ)
	var payload: Dictionary=JSON.parse_string(file.get_as_text()); file.close()
	payload.erase("adventure")
	file=FileAccess.open(old.save_path,FileAccess.WRITE); file.store_string(JSON.stringify(payload)); file.close()
	var migrated=State.new(old.save_path)
	check(migrated.load_game() and migrated.adventure==Rules.default_adventure(),"The optional adventure field migrates existing saves")
	var legacy_genes_kept: bool=migrated.plants.size()==old.plants.size()
	for id: String in old.plants:
		legacy_genes_kept=legacy_genes_kept and genotype(migrated.plants[id])==genotype(old.plants[id])
	check(legacy_genes_kept and DNA.canonical(migrated.resources)==DNA.canonical(old.resources),"Migration preserves original DNA and money")
	# The fast path can resume after ordinary nursery actions or a saved game.
	# Stored fruit already paid its harvest reward; sowing cannot pay it twice.
	for stored_as_seeds: bool in [false,true]:
		var resumed: RefCounted=fresh("resume_seeds" if stored_as_seeds else "resume_fruit")
		var parents: Dictionary=collect_four(resumed)
		resumed.adventure_begin_cross(str(parents.river_fan),str(parents.floatcap))
		resumed.pollinations[str(parents.river_fan)].ready_at=0
		var fruit_result: Dictionary=resumed.harvest_fruit(str(parents.river_fan))
		check(fruit_result.ok and fruit_result.fruits.size()==1,"Ordinary nursery harvest can precede the adventure shortcut")
		if stored_as_seeds:
			check(resumed.extract_seeds(str(fruit_result.fruits[0].id)).ok,"Ordinary extraction keeps the exact adventure embryos")
		resumed.save_game()
		var continued=State.new(resumed.save_path)
		check(continued.load_game(),"A pending nursery handoff survives closing the game")
		check(continued.adventure_info().cross_ready and continued.adventure_info().cross_status==("stored_seeds" if stored_as_seeds else "stored_fruit"),"The field bench honestly resumes existing stored fruit or extracted seeds")
		continued.resources.sunlight=19
		var too_poor: String=fingerprint(continued)
		check(not continued.adventure_siblings(str(parents.river_fan)).ok and fingerprint(continued)==too_poor,"Insufficient light cannot partly consume a stored fruit or seed")
		continued.resources.sunlight=20
		var remaining_packets: int=continued.seed_bank.size()-(2 if stored_as_seeds else 0)
		var finished: Dictionary=continued.adventure_siblings(str(parents.river_fan))
		check(finished.ok and int(finished.sunlight)==-20 and int(continued.resources.sunlight)==0,"Resuming a harvested batch charges only the normal sowing cost")
		check(continued.seed_bank.size()==remaining_packets and continued.fruit_inventory.is_empty(),"Resuming consumes exactly its two embryos and no other packets")
	# Ability rules work for arbitrary names and archive IDs. They never inspect
	# the special introductory parent names or require a scripted recipe.
	var ordinary: Dictionary=state.plants[child_id].duplicate(true)
	ordinary.name="A player's odd river invention"
	ordinary.id="ordinary_custom_hybrid"
	ordinary.genes.texture.dominant="Waxy"
	check(Rules.capabilities(ordinary).raft,"A player-named ordinary hybrid with the same genes has the same physical ability")
	ordinary.lineage_mix={"Leaf":0.2,"Spore":0.2,"Bloom":0.6}
	check(Rules.capabilities(ordinary).raft,"Later mixed lineages retain a functional20-percent ancestry contribution")
	ordinary.lineage_mix.Spore=0.19
	ordinary.lineage_mix.Bloom=0.61
	check(Rules.capabilities(ordinary).raft,"Expressed broad waxy leaves remain useful regardless of family percentages")
	ordinary.genes.shape.dominant="Pointed"
	check(not Rules.capabilities(ordinary).raft,"A narrow leaf cannot claim a canopy through its ancestry alone")
	for malformed: Variant in [null,[],{},true,{"version":1,"cuttings":[]}, {"version":1,"cuttings":{},"route":"raft"}]:
		check(not Rules.valid_adventure(malformed,state.plants),"Malformed adventure ledgers fail without changing the garden")
	var cared=fresh("care_reserve")
	var field_parent: Dictionary=cared.adventure_collect("river_fan").plant
	var before_care: String=fingerprint(cared)
	check(not cared.apply_care(str(field_parent.id),"water").ok and not cared.apply_care(str(field_parent.id),"longevity").ok,"Already cared-for field parents cannot overfill their lifespan reserve")
	check(fingerprint(cared)==before_care,"Rejected extra lifetime care spends nothing and preserves the archive")
	cared.save_game()
	var cared_reload=State.new(cared.save_path)
	check(cared_reload.load_game() and cared_reload.life_profile(str(field_parent.id)).life_limit==3600.0,"The one-hour field-parent lifetime survives reload after rejected care")
	for path: String in paths:
		for suffix: String in ["", ".tmp"]: DirAccess.remove_absolute(path+suffix)
		DirAccess.remove_absolute(path.get_basename()+".backup.json")
	print("ADVENTURE MODEL TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
