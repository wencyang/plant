extends SceneTree
const State=preload("res://scripts/garden_state.gd")
const DNA=preload("res://scripts/plant_dna.gd")
const PartyUI=preload("res://scripts/field_party_panel.gd")
var checks: int=0
var failures: int=0
var paths: Array[String]=[]

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("TRAVEL PARTY: "+message)

func fresh(label: String) -> RefCounted:
	var path: String="/tmp/conservatory_party_%s_%d.json" % [label,Time.get_ticks_usec()]
	paths.append(path)
	var state=State.new(path)
	state.new_game()
	return state

func ids(state: RefCounted) -> Array:
	var result: Array=[]
	for plant: Dictionary in state.travel_party(): result.append(str(plant.id))
	return result

func inventory(state: RefCounted) -> String:
	return DNA.canonical([state.plants,state.plant_order,state.bed,state.display_bed,state.resources,state.seed_bank,state.fruit_inventory,state.fruit_crops,state.pollinations,state.market,state.fair,state.adventure,state.collection_seen,state.expedition,state.random.state,state.id_counter,state.reproduction_counter])

func payload(state: RefCounted) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(state.save_path))

func run() -> void:
	var state: RefCounted=fresh("main")
	var before: String=inventory(state)
	var disk: String=FileAccess.get_file_as_string(state.save_path)
	check(ids(state)==state.plant_order,"A legacy garden uses its existing living collection in stable order")
	for i in range(5): state.travel_party()
	check(inventory(state)==before and FileAccess.get_file_as_string(state.save_path)==disk,"Reading the default party never changes plants, DNA, RNG, inventory or save bytes")
	check(not payload(state).has("travel_party_ids"),"An unchosen default is an optional legacy field")
	for key: String in ["river_fan","floatcap","gripvine","stone_root"]: state.adventure_collect(key)
	check(ids(state).size()==6,"The default travelling group stops at six actual individuals")
	for plant: Dictionary in state.travel_party():
		check(state.owns_plant(str(plant.id)) and DNA.profile(plant).code==DNA.profile(state.get_plant(str(plant.id))).code,"A party portrait uses the actual owned genome")
	var all: Array=state.plant_order.duplicate()
	for invalid: Array in [all.slice(0,7),[all[0],all[0]],["missing_plant"],[3]]:
		before=inventory(state)
		disk=FileAccess.get_file_as_string(state.save_path)
		check(not state.set_travel_party(invalid).get("ok",false),"Invalid party selection rejects atomically: "+str(invalid))
		check(inventory(state)==before and FileAccess.get_file_as_string(state.save_path)==disk,"Invalid selection leaves inventory and saved party unchanged")
	var selected: Array=[all[4],all[2],all[1],all[0],all[5],all[6]]
	before=inventory(state)
	check(state.set_travel_party(selected).ok and ids(state)==selected,"A chosen group preserves its exact six-member order")
	check(inventory(state)==before,"Choosing companions never benches plants, changes favorites, consumes supplies or alters DNA")
	var loaded=State.new(state.save_path)
	check(loaded.load_game() and ids(loaded)==selected,"The selected six companions survive normal save and reload")
	check(payload(state).travel_party_ids==selected,"Only the companion ID list is persisted for the party")
	before=inventory(state)
	var lead: String=str(selected[3])
	check(state.set_lead_plant(lead).ok and ids(state)[0]==lead,"An existing member can become the visible lead companion")
	check(ids(state).size()==6 and ids(state).slice(1)==[selected[0],selected[1],selected[2],selected[4],selected[5]],"Leading reorders the existing party without duplication")
	check(inventory(state)==before,"Changing the lead preserves every specimen and unrelated game state")
	var outsider: String=str(all[8])
	check(state.set_lead_plant(outsider).ok and ids(state)[0]==outsider and ids(state).size()==6,"A new living lead joins at the front while the sixth member stays safely in the garden")
	check(state.owns_plant(str(selected[5])),"A displaced sixth companion is still owned")
	before=inventory(state)
	disk=FileAccess.get_file_as_string(state.save_path)
	check(not state.set_lead_plant("absent").ok and inventory(state)==before and FileAccess.get_file_as_string(state.save_path)==disk,"An unknown lead cannot mutate or save the party")
	var sown: Dictionary=state.plant_seed(0)
	check(sown.get("ok",false),"A real garden seed can supply a young travelling companion")
	if sown.get("ok",false):
		var young_id: String=str(sown.plant.id)
		check(not state.get_plant(young_id).mature and state.set_lead_plant(young_id).ok and ids(state)[0]==young_id,"Living seedlings can travel without being artificially matured")
	# Life and sale remove a companion from the visible party, but not its archive.
	var aged: String=str(ids(state)[1])
	state.plants[aged].life_age=float(state.life_profile(aged).life_limit)
	before=inventory(state)
	var configured: Array=state.travel_party_ids.duplicate()
	check(not ids(state).has(aged),"A naturally withered companion is omitted from the active party")
	check(inventory(state)==before and state.travel_party_ids==configured,"Filtering a withered companion is a pure read and keeps its family archive")
	check(not state.set_lead_plant(aged).ok,"Withered plants cannot be made to follow")
	var sale_id: String=str(all[1])
	state.set_travel_party([sale_id])
	state.plants[sale_id].favorite=false
	var sale: Dictionary=state.market_sell("plant",sale_id)
	check(sale.get("ok",false),"An ordinary travel companion can be sold through the real market")
	check(ids(state).is_empty() and state.plants.has(sale_id),"A sold companion stops following while its DNA stays archived")
	loaded=State.new(state.save_path)
	check(loaded.load_game() and ids(loaded).is_empty(),"Stale party references after a normal sale cannot invalidate the garden save")
	check(state.set_travel_party([]).ok and ids(state).is_empty(),"The player can explicitly travel without a companion")
	loaded=State.new(state.save_path)
	check(loaded.load_game() and ids(loaded).is_empty(),"An intentionally empty party stays empty after reload")
	var good: Dictionary=payload(state)
	for invalid: Variant in [null,"bad",[all[0],all[0]],["missing_plant"],[0],all.slice(0,7)]:
		var forged: Dictionary=good.duplicate(true)
		forged["travel_party_ids"]=invalid
		check(not state._valid_save(forged),"Optional party data validates known IDs, array shape, uniqueness and capacity")
	good.erase("travel_party_ids")
	check(state._valid_save(good),"Legacy gardens without a party field still validate")
	state.new_game()
	check(ids(state)==state.plant_order and not payload(state).has("travel_party_ids"),"Starting a new garden clears prior companion selection without stale IDs")
	for path: String in paths:
		for suffix: String in [".json",".backup.json"]: DirAccess.remove_absolute(path.get_basename()+suffix)
	print("TRAVEL PARTY TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
