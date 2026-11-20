extends SceneTree
const State = preload("res://scripts/garden_state.gd")
const Rules = preload("res://scripts/market_rules.gd")
const DNA = preload("res://scripts/plant_dna.gd")
var checks: int = 0
var failures: int = 0

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("MARKET MODEL: "+message)

func total(rows: Array) -> int:
	var value: int = 0
	for row: Dictionary in rows: value+=int(row.amount)
	return value

func contains_label(quote: Dictionary,label: String) -> bool:
	for row: Dictionary in quote.breakdown:
		if row.label==label: return true
	return false

func snapshot(state: RefCounted) -> String:
	return Rules.fingerprint([state.plants,state.plant_order,state.resources,state.seed_bank,state.fruit_inventory,state.fruit_crops,state.pollinations,state.market,state.bed,state.display_bed,state.random.state,state.id_counter,state.reproduction_counter])

func _initialize() -> void:
	var path: String = "/tmp/conservatory_market_%d.json" % Time.get_ticks_usec()
	var state = State.new(path)
	state.new_game()
	check(state.market_wallet()==0 and Rules.valid_market(state.market),"Fresh games have a valid independent empty coin wallet")
	check(state.resources.keys().size()==3 and not state.resources.has("coins"),"Market currency does not alter the existing resource dictionary")
	var a: String = str(state.plant_order[0])
	var b: String = str(state.plant_order[1])
	var p: Dictionary = state.get_plant(a)
	var initial_dna: String = DNA.profile(p).code
	var before: String = snapshot(state)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var quote: Dictionary = state.market_quote("plant",a)
	for kind: String in ["plant","fruit","seed"]:
		var inventory: Array = state.market_inventory(kind)
		for row: Dictionary in inventory:
			check(row.has("reference") and row.has(kind) and row.quote.ok,"Inventory rows expose canonical references, snapshots and quotes")
			check(int(row.quote.price)>0 and total(row.quote.breakdown)==int(row.quote.price),"Every disclosed additive price totals exactly")
			check(state.market_quote(kind,row.reference).quote_id==row.quote.quote_id,"Inventory and direct quotes use identical stable identities")
	for iteration in range(4):
		check(state.market_quote("plant",a)==quote,"Repeated inspection returns the same offer")
		state.market_stock()
		state.market_history()
	check(before==snapshot(state) and FileAccess.get_file_as_bytes(path)==bytes,"All quote, list, wallet, stock and history reads leave saves, inventory, IDs and RNG unchanged")
	var today: Dictionary = state.market_day(20000)
	check(today==state.market_day(20000) and today.label.ends_with("UTC"),"Daily demand is deterministic and explicitly uses UTC")
	check(state.market_day(20001).type!=today.type and state.market_day(20001).pattern!=today.pattern,"Demand rotates between dates without any random draws")
	var plain: Dictionary = p.duplicate(true)
	plain.rarity="Common"
	plain.genes.pattern.dominant="Solid"
	plain.genes.pattern.recessive="Solid"
	plain.genes.glow.dominant="None"
	var valuable: Dictionary = plain.duplicate(true)
	valuable.rarity="Epic"
	valuable.genes.pattern.dominant="Starburst"
	valuable.genes.pattern.recessive="Gradient"
	valuable.genes.glow.dominant="Soft"
	valuable.lineage_mix={"Leaf":0.5,"Bloom":0.5}
	var low: Dictionary = Rules.price("plant",plain,today,0)
	var high: Dictionary = Rules.price("plant",valuable,today,0)
	check(int(high.price)>int(low.price)+30 and contains_label(high,"Rarity") and contains_label(high,"Mixed ancestry") and contains_label(high,"Genetic traits"),"Rarity, visible/carried genetic traits and mixed ancestry have legible positive contributions")
	var demanded: Dictionary = today.duplicate(true)
	demanded.type=plain.type
	demanded.pattern="Solid"
	var no_demand: Dictionary = demanded.duplicate(true)
	no_demand.type="Carnivorous"
	no_demand.pattern="Bicolor Ring"
	check(int(Rules.price("plant",plain,demanded,0).price)==int(Rules.price("plant",plain,no_demand,0).price)+10,"Matching both daily requests adds exactly the disclosed ten coins")
	var tall: Dictionary = plain.duplicate(true)
	tall.measurements.height_variation=1.16
	tall.measurements.weight_variation=1.24
	var short: Dictionary = plain.duplicate(true)
	short.measurements.height_variation=0.86
	short.measurements.weight_variation=0.80
	check(int(Rules.price("plant",tall,today,0).price)>=int(Rules.price("plant",short,today,0).price),"Natural individual height and weight contribute to plant value")
	var cared: Dictionary = plain.duplicate(true)
	cared.care.height_bonus=0.60
	cared.care.weight_bonus=0.80
	check(int(Rules.price("plant",cared,today,0).price)-int(low.price)<=3,"Care-grown size contributes at most three coins and cannot inflate sale value indefinitely")
	var aging: Dictionary = plain.duplicate(true)
	aging.life_age=1210.0
	check(contains_label(Rules.price("plant",aging,today,0),"Aging plant"),"Ordinary aging has its own visible price adjustment")
	aging.life_age=1450.0
	check(contains_label(Rules.price("plant",aging,today,0),"Near the end of its life"),"The final five percent of life has a distinct stronger condition adjustment")
	aging.withered=true
	check(int(Rules.price("plant",aging,today,0).price)<=3,"Withered remains receive only a modest compost offer")
	var saturated: Dictionary = Rules.price("plant",valuable,today,1000)
	check(int(saturated.price)>0 and int(saturated.factors.supply_percent)==60 and total(saturated.breakdown)==int(saturated.price),"Daily category supply reduction stops at a sixty-percent floor and remains additive")
	check(int(Rules.price("plant",valuable,today,1000).price)==int(Rules.price("plant",valuable,today,10).price),"Supply cannot diminish offers beyond ten sales")
	before=snapshot(state)
	check(not state.market_buy("founding_seed").ok and snapshot(state)==before,"Unaffordable seed purchases leave RNG, IDs and every inventory unchanged")
	check(not state.market_buy("missing").ok and snapshot(state)==before,"Unknown stock is rejected transactionally")
	check(not state.market_sell("seed",0).ok and snapshot(state)==before,"Mutable seed indices are never accepted as trade references")
	check(not state.market_sell("plant",a,"expired-review").ok and snapshot(state)==before,"A stale review cannot commit a sale")
	p.favorite=true
	check(not state.market_quote("plant",a).eligible and not state.market_sell("plant",a).ok,"Favorites require an explicit unlock before a sale")
	p.favorite=false
	check(state.pollinate(a,b).ok,"A real hybrid batch can be prepared for market protection checks")
	check(not state.market_quote("plant",a).eligible and not state.market_sell("plant",a).ok,"Developing hybrid embryos block their mother's sale")
	state.pollinations[a].ready_at=0
	check(not state.market_quote("plant",a).eligible,"A ripe hybrid batch still blocks sale until harvested")
	state.fruit_crops[a].natural_ready_at=0
	check(state.harvest_fruit(a).ok and state.fruit_inventory.size()==2,"Hybrid and natural fruit are genuinely harvested before trading")
	var fruit_rows: Array = state.market_inventory("fruit")
	check(fruit_rows.size()==2 and int(fruit_rows[0].quote.price)>0,"Both fruit categories have sale offers based on their actual embryos")
	var fruit_ref: String = str(fruit_rows[0].reference)
	var fruit_quote: Dictionary = fruit_rows[0].quote
	var seeds_before: int = state.seed_bank.size()
	var wallet_before: int = state.market_wallet()
	check(state.market_sell("fruit",fruit_ref,str(fruit_quote.quote_id)).ok,"A reviewed harvested fruit sells successfully")
	check(state.market_wallet()==wallet_before+int(fruit_quote.price) and state.fruit_inventory.size()==1 and state.seed_bank.size()==seeds_before,"Selling fruit credits exact coins and transfers its seeds rather than duplicating them")
	before=snapshot(state)
	check(not state.market_sell("fruit",fruit_ref).ok and not state.extract_seeds(fruit_ref).ok and snapshot(state)==before,"Sold fruit cannot be resold or opened")
	state.extract_all_seeds()
	var seed_rows: Array = state.market_inventory("seed")
	var last: Dictionary = seed_rows.back()
	var target_fingerprint: String = Rules.fingerprint(last.seed)
	var target_ref: Dictionary = last.reference
	var target_quote: Dictionary = last.quote
	state.seed_bank.remove_at(0)
	check(state.market_quote("seed",target_ref).key==target_fingerprint,"A stable seed reference follows its genome when preceding slots move")
	wallet_before=state.market_wallet()
	check(state.market_sell("seed",target_ref,str(target_quote.quote_id)).ok,"A reviewed full-genome seed survives unrelated index shifts")
	check(state.market_wallet()==wallet_before+int(target_quote.price),"A seed sale credits its exact reviewed price")
	var still_present: bool = false
	for seed_data: Dictionary in state.seed_bank:
		if Rules.fingerprint(seed_data)==target_fingerprint: still_present=true
	check(not still_present and not state.market_sell("seed",target_ref).ok,"The chosen genome is removed exactly once instead of a shifted neighbor")
	var duplicate: Dictionary = state.seed_bank[0].duplicate(true)
	state.seed_bank.append(duplicate)
	var duplicate_rows: Array = state.market_inventory("seed")
	var duplicate_ref: Dictionary = duplicate_rows.back().reference
	check(int(duplicate_ref.occurrence)==1 and state.market_quote("seed",duplicate_ref).ok,"Equivalent duplicate seeds receive distinct occurrence references")
	state.fruit_crops[a].natural_ready_at=0
	check(not state.market_quote("plant",a).eligible,"Ripe natural fruit must be harvested before selling its plant")
	state.harvest_fruit(a)
	var offspring: Dictionary = state.crossbreed(a,b).plant
	var child_id: String = str(offspring.id)
	quote=state.market_quote("plant",a)
	check(quote.eligible and quote.notes.has("Unripe natural fruit travels with the sold plant."),"Selling a plant discloses transfer of its developing natural fruit")
	state.advance_lifecycle(0.25)
	check(state.market_quote("plant",a).quote_id==quote.quote_id,"Continuous aging within the same condition band does not invalidate a price review")
	wallet_before=state.market_wallet()
	check(state.market_sell("plant",a,str(quote.quote_id)).ok and state.market_wallet()==wallet_before+int(quote.price),"A reviewed owned plant transfers for exactly its quoted coins")
	check(not state.owns_plant(a) and state.plants.has(a) and state.get_plant(a).sold and state.get_plant(a).retired,"Selling removes ownership but retains the complete archived organism")
	check(not state.plant_order.has(a) and not state.bed.has(a) and not state.display_bed.has(a) and not state.fruit_crops.has(a),"Sold plants leave all active garden slots and fruit production")
	check(state.get_plant(child_id).parents.has(a) and state.lineage(child_id).ancestors.size()>0 and DNA.profile(state.get_plant(a)).code==initial_dna,"A sold ancestor preserves descendants' pedigrees and original DNA")
	before=snapshot(state)
	check(not state.market_sell("plant",a).ok,"Archived sold plants cannot be sold twice")
	check(not state.apply_care(a,"water").ok and not state.care_status(a,"growth").allowed,"Sold plants cannot consume care or free watering")
	check(not state.crossbreed(a,b).ok and not state.pollinate(b,a).ok,"Sold ancestors cannot become new live breeding parents")
	check(not state.graft(a,b).ok and not state.graft(b,a).ok,"Sold plants cannot supply or receive grafts")
	check(not state.mutate(a).ok and not state.mature_plant(a).ok and not state.harvest_fruit(a).ok,"Archived sold plants cannot mutate, regrow or produce new fruit")
	check(not state.place_in_bed(a,0) and not state.place_in_display(a,0),"Sold plants cannot return to active battle or display beds")
	state.rename_plant(a,"Resurrected")
	state.toggle_favorite(a)
	check(snapshot(state)==before,"All rejected sold-plant actions preserve coins, resources, genealogy and RNG")
	var child_quote: Dictionary = state.market_quote("plant",child_id)
	check(state.market_sell("plant",child_id,str(child_quote.quote_id)).ok,"An unpollinated seedling can transfer at its disclosed condition discount")
	var archived_child_found: bool = false
	for descendant: Dictionary in state.lineage(b).descendants:
		if descendant.id==child_id: archived_child_found=true
	check(archived_child_found,"A parent's descendant tree includes offspring that were later sold")
	state.market.coins=1000
	for offer: Dictionary in state.market_stock():
		wallet_before=state.market_wallet()
		var old_light: int = int(state.resources.sunlight)
		var old_kits: int = state.field_kits
		var old_grafts: int = int(state.resources.grafts)
		var old_agents: int = int(state.resources.agents)
		seeds_before=state.seed_bank.size()
		var result: Dictionary = state.market_buy(str(offer.key))
		check(result.ok and state.market_wallet()==wallet_before-int(offer.cost),"Every stock purchase spends exactly its listed coin cost: "+str(offer.key))
		match str(offer.key):
			"sunlight": check(int(state.resources.sunlight)==old_light+30,"Bottled sunlight adds its promised resource")
			"field_kits": check(state.field_kits==old_kits+3,"Field bundle adds three real collection attempts")
			"graft_material": check(int(state.resources.grafts)==old_grafts+1,"Bought material works with the existing graft resource")
			"mutation_agent": check(int(state.resources.agents)==old_agents+1,"Bought agent works with the existing mutation resource")
			"founding_seed":
				check(state.seed_bank.size()==seeds_before+1 and state.seed_bank.back().rarity=="Common","Seed purchases generate one valid founding tendency snapshot")
				check(int(state.market_inventory("seed").back().quote.price)<int(offer.cost),"Buying and immediately reselling a founding seed cannot mint coins")
	check(state.market_history().size()>0 and state.market_history()[0].action=="buy","Transaction history is newest first and includes purchases")
	var detached: Array = state.market_history()
	detached.clear()
	check(not state.market.history.is_empty(),"Returned history snapshots cannot alter the saved ledger")
	state.save_game()
	var restored = State.new(path)
	check(restored.load_game() and Rules.fingerprint(restored.market)==Rules.fingerprint(state.market),"Coins, demand saturation and trading history persist exactly")
	check(not restored.owns_plant(a) and restored.get_plant(a).sold and restored.get_plant(child_id).parents.has(a),"Sold ownership and preserved pedigree remain correct after reload")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(state._valid_save(payload),"The complete market save is valid")
	for bad: Variant in [-1,1.5,"coins",INF]:
		var malformed: Dictionary = payload.duplicate(true)
		malformed.market.coins=bad
		check(not state._valid_save(malformed),"Malformed market wallets are rejected safely")
	var malformed: Dictionary = payload.duplicate(true)
	malformed.market.sold_by_day[str(today.day)]={"plant":-1}
	check(not state._valid_save(malformed),"Negative demand counts cannot enter a loaded save")
	malformed=payload.duplicate(true)
	malformed.plant_order.append(a)
	check(not state._valid_save(malformed),"A sold archive cannot be reintroduced into the owned order through a save")
	malformed=payload.duplicate(true)
	malformed.plants[b]=3
	check(not state._valid_save(malformed),"Invalid owned plant records fail validation without a type error")
	payload.erase("market")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	var legacy = State.new(path)
	check(legacy.load_game() and legacy.market_wallet()==0 and legacy.market.history.is_empty(),"Older saves without market data migrate to a fresh valid ledger")
	# A large existing archive should not scan and hash the entire seed bank for
	# every row. This fixture includes full genomes, not tiny mock seed records.
	state.seed_bank.clear()
	for index in range(332):
		var full: Dictionary = state._genome_seed(offspring,"hybrid",["Stillwater","Emberglass"])
		full.id="benchmark_"+str(index)
		state.seed_bank.append(full)
	var started: int = Time.get_ticks_usec()
	var bulk: Array = state.market_inventory("seed")
	var elapsed: float = float(Time.get_ticks_usec()-started)/1000.0
	check(bulk.size()==332 and elapsed<1500.0,"332 full-genome seed offers are generated in linear time (%.1f ms)" % elapsed)
	print("MARKET INVENTORY BENCHMARK: 332 seeds in %.1f ms" % elapsed)
	for entry: String in [path,path.get_basename()+".backup.json"]:
		if FileAccess.file_exists(entry): DirAccess.remove_absolute(entry)
	print("MARKET MODEL TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
