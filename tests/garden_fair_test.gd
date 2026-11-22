extends SceneTree
const State = preload("res://scripts/garden_state.gd")
const Fair = preload("res://scripts/garden_fair.gd")
const Rules = preload("res://scripts/market_rules.gd")
const Care = preload("res://scripts/plant_care.gd")
const DNA = preload("res://scripts/plant_dna.gd")
var checks: int = 0
var failures: int = 0

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("GARDEN FAIR: "+message)

func snapshot(state: RefCounted) -> String:
	return Rules.fingerprint([state.plants,state.plant_order,state.bed,state.display_bed,state.resources,state.market,state.fair,state.seed_bank,state.fruit_inventory,state.fruit_crops,state.pollinations,state.random.state,state.id_counter,state.reproduction_counter,state.wins,state.battles])

func ribbon(state: RefCounted,key: String) -> Dictionary:
	for entry: Dictionary in state.fair_ribbons():
		if entry.key==key: return entry
	return {}

func grow(state: RefCounted,seed_index: int) -> Dictionary:
	var result: Dictionary = state.plant_seed(seed_index)
	if not result.ok: return {}
	result.plant.ready_at=0
	state.tick_growth()
	return result.plant

func _initialize() -> void:
	var path: String = "/tmp/conservatory_fair_%d.json" % Time.get_ticks_usec()
	var state = State.new(path)
	state.new_game()
	var a: String = str(state.plant_order[0])
	var b: String = str(state.plant_order[1])
	state.wins=17
	state.battles=31
	check(not state.has_method("battle_reward") and not state.has_method("generate_opponent"),"Combat reward and opponent APIs have actually been removed")
	check(Fair.valid_fair(state.fair,state.plants) and state.fair.claims.is_empty() and state.fair.ribbons.is_empty(),"Fresh games begin with a valid independent fair ledger")
	var requests: Array = state.fair_requests()
	check(requests.size()==3 and requests[0].eligible_ids.size()==5,"Every day offers three peaceful visits and a starter-accessible welcome request")
	check(requests[0].npc.begins_with("Mira") and requests[1].npc.begins_with("Jun") and requests[2].npc.begins_with("Pip"),"Requests consistently name their distinct garden visitors")
	check(int(requests[0].reward.coins)==8 and int(requests[0].reward.sunlight)==20,"The easy visit clearly discloses its meaningful starter reward")
	var criteria: Dictionary = {}
	for day in range(20000,20006):
		var definitions: Array = Fair.requests(day)
		check(definitions.size()==3 and definitions[0].day==day and definitions[0].key.begins_with("daily:%d:" % day),"Daily identities embed their UTC date rather than shared mutable slot indices")
		check(Rules.fingerprint(definitions)==Rules.fingerprint(Fair.requests(day)),"The same date always produces the same requests without gameplay RNG")
		criteria[definitions[1].slug]=true
		criteria[definitions[2].slug]=true
		check(int(definitions[2].reward.grafts)+int(definitions[2].reward.agents)==1,"Journey visits award one useful grafting or mutation supply")
	check(criteria.size()==12,"Both rotating request pools expose six distinct real gardening goals")
	var before: String = snapshot(state)
	var saved_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	for count in range(5):
		state.fair_requests()
		state.fair_ribbons()
		state.fair_preview(str(requests[0].key),a)
	check(snapshot(state)==before and FileAccess.get_file_as_bytes(path)==saved_bytes,"Reading requests, eligibility, ribbons and rewards never mutates state, IDs, RNG or save bytes")
	var preview: Dictionary = state.fair_preview(str(requests[0].key),a)
	check(preview.ok and preview.eligible and not preview.claimed and preview.reason.contains("keep"),"Preview verifies a real matching owned plant and clearly promises it stays")
	var held: String = Rules.fingerprint([state.plants,state.plant_order,state.bed,state.display_bed,state.seed_bank,state.fruit_inventory,state.random.state,state.id_counter])
	var old_coins: int = state.market_wallet()
	var old_resources: Dictionary = state.resources.duplicate(true)
	var result: Dictionary = state.fair_claim(str(requests[0].key),a)
	check(result.ok and state.market_wallet()==old_coins+8 and int(state.resources.sunlight)==int(old_resources.sunlight)+20,"Showing a plant awards exact listed coins and gathered light")
	check(Rules.fingerprint([state.plants,state.plant_order,state.bed,state.display_bed,state.seed_bank,state.fruit_inventory,state.random.state,state.id_counter])==held,"A visit never consumes, damages, moves or rerolls the shown plant or any seed")
	check(state.wins==17 and state.battles==31,"Peaceful progression leaves archived legacy combat counters unchanged")
	check(state.fair.claims.has(requests[0].key) and state.fair_preview(str(requests[0].key),a).claimed,"A successful daily claim is permanently identified by request date and plant")
	before=snapshot(state)
	check(not state.fair_claim(str(requests[0].key),b).ok and snapshot(state)==before,"The same daily request cannot be repeated with a different plant")
	var expired: String = str(Fair.requests(Fair.day()-1)[0].key)
	check(not state.fair_claim(expired,a).ok and snapshot(state)==before,"An expired request key cannot pay yesterday's gift again")
	check(not state.fair_claim("unknown",a).ok and snapshot(state)==before,"Unknown requests are rejected transactionally")
	var current_key: String = str(requests[1].key)
	check(not state.fair_preview(current_key,"missing").eligible,"A missing organism cannot qualify by ID alone")
	var p: Dictionary = state.get_plant(b)
	p.withered=true
	check(not state.fair_preview(current_key,b).eligible and state.fair_preview(current_key,b).reason.contains("living"),"Withered plants cannot be used as live fair exhibits")
	p.withered=false
	p.life_age=float(Care.life_limits(p).life_limit)
	check(not state.fair_preview(current_key,b).eligible,"A plant beyond its actual lifetime is rejected even before the lifecycle tick marks its withered flag")
	p.life_age=0.0
	p.mature=false
	check(not state.fair_preview(current_key,b).eligible and state.fair_preview(current_key,b).reason.contains("finish growing"),"Seedlings must mature before they can be shown")
	p.mature=true
	var selling: String = str(state.plant_order[4])
	check(state.market_sell("plant",selling).ok and not state.fair_preview(current_key,selling).eligible,"Sold archived organisms cannot qualify as owned exhibits")
	# Ordinary goals use actual alleles and physical measurements, including
	# carried traits and capped somatic care, rather than name or rarity tags.
	var specimen: Dictionary = state.get_plant(a).duplicate(true)
	var graft_goal: Dictionary = {"criterion":"graft"}
	specimen.graft_history=[{"success":false}]
	check(not Fair.meets(graft_goal,specimen),"A rejected graft record is not mistaken for a living successful graft")
	specimen["inherited_graft_records"]=[{"success":true}]
	check(Fair.meets(graft_goal,specimen),"A genuinely inherited living graft can be shown as a plant's collaboration story")
	for day in range(20000,20006):
		var definition: Dictionary = Fair.requests(day)[1]
		var sample: Dictionary = specimen.duplicate(true)
		match str(definition.criterion):
			"pattern","size","texture":
				var locus: String = str(definition.criterion)
				sample.genes[locus].dominant="Other"
				sample.genes[locus].recessive=definition.value
				check(Fair.meets(definition,sample),"A truly carried requested allele qualifies even when it is not currently visible")
				sample.genes[locus].recessive="Other"
				check(not Fair.meets(definition,sample) and not Fair.mismatch(definition,sample).is_empty(),"A missing requested allele gives an actionable mismatch reason")
			"height":
				sample.lineage_mix={"Leaf":1.0}
				sample.genes.size.dominant="Standard"
				sample.genes.form.dominant="Upright"
				sample.measurements.height_variation=1.0
				check(not Fair.meets(definition,sample),"A shorter plant cannot satisfy a height request by name or genotype alone")
				sample.care.height_bonus=0.60
				check(Fair.meets(definition,sample),"Actual growth fertilizer height counts toward a physical fair goal")
			"weight":
				sample.lineage_mix={"Leaf":1.0}
				sample.genes.size.dominant="Standard"
				sample.genes.texture.dominant="Matte"
				sample.genes.form.dominant="Upright"
				sample.measurements.weight_variation=1.0
				check(not Fair.meets(definition,sample),"A light plant cannot satisfy a mass request by displayed rarity")
				sample.care.weight_bonus=0.20
				check(Fair.meets(definition,sample),"Actual compost-grown mass counts toward a physical fair goal")
	var grown: Dictionary = grow(state,0)
	check(not grown.is_empty() and grown.origin.kind=="seed" and ribbon(state,"first_sprout").eligible,"Sowing and maturing an existing founding seed unlocks the first-sprout ribbon")
	check(state.pollinate(a,b).ok,"A real two-parent cross can be started for fair progression")
	state.pollinations[a].ready_at=0
	check(state.harvest_fruit(a).ok and state.extract_all_seeds().ok,"The breeding loop requires actual harvested fruit and collected full-genome seeds")
	var child: Dictionary = grow(state,state.seed_bank.size()-1)
	check(not child.is_empty() and child.parents.size()==2 and int(child.generation)==2,"A fertilized hybrid seed matures with its true parentage")
	check(ribbon(state,"first_cross").eligible and ribbon(state,"mixed_roots").eligible,"Real two-parent mixed ancestry unlocks both relevant permanent milestones")
	check(state.pollinate(str(child.id),a).ok,"A grown offspring can become a parent for the next generation")
	state.pollinations[child.id].ready_at=0
	state.harvest_fruit(str(child.id))
	state.extract_all_seeds()
	var grandchild: Dictionary = grow(state,state.seed_bank.size()-1)
	check(int(grandchild.generation)==3 and ribbon(state,"third_generation").eligible,"Later-generation breeding has a real separate ribbon goal")
	var wild: Dictionary = state.preview_wild_plant("Mosswood","fair_wild_fixture")
	wild.id=state._new_id()
	wild.origin.collected_at=int(Time.get_unix_time_from_system())
	state._add_plant(wild)
	check(ribbon(state,"wild_friend").eligible,"A genuinely wild-origin owned individual qualifies for the exploration ribbon")
	state.collection_seen["Veilfern"]=["Solid","Striped","Spotted","Gradient"]
	check(ribbon(state,"pattern_collector").eligible,"Permanent recorded visible discoveries drive the pattern ribbon")
	for founding: Dictionary in State.SPECIES:
		if not state.discovered.has(founding.name): state.discovered.append(founding.name)
	check(ribbon(state,"founding_atlas").eligible,"Discovering the actual seven founding species unlocks the atlas ribbon")
	# Make a real successful graft available for the rotating journey goal.
	state.resources.grafts=10
	state.random.seed=1
	var grafted: Dictionary = state.graft(str(grown.id),b)
	check(grafted.ok and grafted.success,"A real accepted graft supplies the graft-showcase journey fixture")
	var ordinary_definition: Dictionary = Fair.requests()[1]
	if str(ordinary_definition.criterion) in ["pattern","size","texture"]:
		grown.genes[str(ordinary_definition.criterion)].recessive=ordinary_definition.value
	else:
		grown.lineage_mix={"Vine":1.0} if ordinary_definition.criterion=="height" else {"Root":1.0}
		grown.genes.size.dominant="Large"
	var daily_rows: Array = state.fair_requests()
	for index in [1,2]:
		var visit: Dictionary = daily_rows[index]
		check(not visit.eligible_ids.is_empty(),"A real grown, bred, grafted and wild collection can satisfy today's rotating request")
		if visit.eligible_ids.is_empty(): continue
		old_coins=state.market_wallet()
		old_resources=state.resources.duplicate(true)
		held=Rules.fingerprint([state.plants,state.plant_order,state.bed,state.display_bed,state.seed_bank,state.fruit_inventory,state.random.state,state.id_counter])
		result=state.fair_claim(str(visit.key),str(visit.eligible_ids[0]))
		check(result.ok and state.market_wallet()==old_coins+int(visit.reward.coins),"Each specific daily request credits its own exact coin gift")
		check(int(state.resources.sunlight)==int(old_resources.sunlight)+int(visit.reward.sunlight) and int(state.resources.grafts)==int(old_resources.grafts)+int(visit.reward.grafts) and int(state.resources.agents)==int(old_resources.agents)+int(visit.reward.agents),"Daily gifts pay every promised light and occasional graft or mutation supply")
		check(Rules.fingerprint([state.plants,state.plant_order,state.bed,state.display_bed,state.seed_bank,state.fruit_inventory,state.random.state,state.id_counter])==held,"Specific daily visits also keep all plants, placement, DNA and future randomness untouched")
	check(state.fair.claims.size()==3,"Today's three distinct daily requests each have exactly one successful ledger record")
	var dna_before: String = DNA.profile(child).code
	var owned_before: Array = state.plant_order.duplicate()
	for milestone: Dictionary in state.fair_ribbons():
		check(milestone.eligible and not milestone.earned,"All seven individually achieved ribbon conditions become claimable")
		old_coins=state.market_wallet()
		old_resources=state.resources.duplicate(true)
		result=state.fair_claim_ribbon(str(milestone.key))
		check(result.ok and state.market_wallet()==old_coins+int(milestone.reward.coins),"Each ribbon pays its exact once-only coin reward")
		check(int(state.resources.sunlight)==int(old_resources.sunlight)+int(milestone.reward.sunlight) and int(state.resources.grafts)==int(old_resources.grafts)+int(milestone.reward.grafts) and int(state.resources.agents)==int(old_resources.agents)+int(milestone.reward.agents),"Each ribbon pays all disclosed light and supply quantities")
		before=snapshot(state)
		check(not state.fair_claim_ribbon(str(milestone.key)).ok and snapshot(state)==before,"An earned ribbon cannot pay twice")
	check(state.plant_order==owned_before and DNA.profile(child).code==dna_before,"Collecting all ribbons keeps every plant and its original inherited DNA")
	state.market_sell("plant",str(child.id))
	check(ribbon(state,"first_cross").earned,"An earned ribbon stays earned after a qualifying plant later leaves the garden")
	state.save_game()
	var restored = State.new(path)
	check(restored.load_game() and Rules.fingerprint(restored.fair)==Rules.fingerprint(state.fair),"Daily claim identities and all permanent ribbons survive save/reload")
	check(restored.wins==17 and restored.battles==31,"Legacy archived counters survive migration without being used for new progression")
	before=snapshot(restored)
	check(not restored.fair_claim(str(requests[0].key),a).ok and not restored.fair_claim_ribbon("first_sprout").ok and snapshot(restored)==before,"Reloading never resets daily gifts or permanent ribbon budgets")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(state._valid_save(payload),"A complete fair save passes validation")
	var malformed: Dictionary = payload.duplicate(true)
	malformed.fair.claims[requests[0].key].rewards.coins=999999
	check(not state._valid_save(malformed),"Forged fair rewards are rejected by schema validation")
	malformed=payload.duplicate(true)
	malformed.fair.claims[requests[0].key].plant_id="missing"
	check(not state._valid_save(malformed),"Claim history cannot refer to a missing archived organism")
	malformed=payload.duplicate(true)
	malformed.fair.ribbons["invented"]={"at":1,"rewards":{"coins":1,"sunlight":1,"grafts":0,"agents":0}}
	check(not state._valid_save(malformed),"Unknown permanent ribbon records are rejected")
	malformed=payload.duplicate(true)
	malformed.fair.claims[requests[0].key].day=INF
	check(not state._valid_save(malformed),"Nonfinite daily identities cannot enter the persisted ledger")
	payload.erase("fair")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	var legacy = State.new(path)
	check(legacy.load_game() and legacy.fair.claims.is_empty() and legacy.fair.ribbons.is_empty(),"An older save gains a fresh fair without resetting its collection, coins or plants")
	check(legacy.market_wallet()==state.market_wallet() and legacy.plant_order==state.plant_order,"Fair migration preserves existing economy and ownership")
	for entry: String in [path,path.get_basename()+".backup.json"]:
		if FileAccess.file_exists(entry): DirAccess.remove_absolute(entry)
	print("GARDEN FAIR TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
