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
		push_error("PLANTING MODEL: "+message)

func snapshot(state: RefCounted) -> String:
	return Rules.fingerprint([state.plants,state.plant_order,state.bed,state.seed_bank,state.resources,state.market,state.random.state,state.id_counter,state.reproduction_counter,state.fruit_crops])

func _initialize() -> void:
	var path: String = "/tmp/conservatory_planting_%d.json" % Time.get_ticks_usec()
	var state = State.new(path)
	state.new_game()
	var reference: Dictionary = state.market_ref("seed",0)
	var before: String = snapshot(state)
	var save_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	for cell: int in [-1,9,42]:
		check(not state.plant_seed_at(reference,cell).ok and snapshot(state)==before,"Out-of-range planting rejects before changing inventory, light, IDs or RNG")
	check(not state.plant_seed_at(reference,6).ok and snapshot(state)==before,"An occupied plot cannot displace its plant during sowing")
	check(not state.plant_seed_at(0,0).ok and snapshot(state)==before,"Planting accepts stable owned seed references rather than mutable array slots")
	var missing: Dictionary = {"fingerprint":"missing","occurrence":0}
	check(not state.plant_seed_at(missing,0).ok and snapshot(state)==before,"A removed or unknown seed cannot consume resources")
	check(FileAccess.get_file_as_bytes(path)==save_bytes,"Rejected plot and seed choices never rewrite the save")
	state.resources.sunlight=9
	before=snapshot(state)
	check(not state.plant_seed_at(reference,0).ok and snapshot(state)==before,"Insufficient light rejects atomically before any ID or random draws")
	state.resources.sunlight=180
	var initial_light: int = int(state.resources.sunlight)
	var initial_seeds: int = state.seed_bank.size()
	var result: Dictionary = state.plant_seed_at(reference,4)
	check(result.ok and int(result.bed_index)==4 and str(result.plant_id)==str(result.plant.id),"Success names the exact target plot and new organism ID")
	var id: String = str(result.plant_id)
	check(str(state.bed[4])==id and str(state.bed[0]).is_empty() and state.bed.count(id)==1,"Plot-specific planting never silently uses the first empty plot")
	check(int(state.resources.sunlight)==initial_light-10 and state.seed_bank.size()==initial_seeds-1,"One seed and exactly ten gathered light are spent")
	check(state.owns_plant(id) and not bool(result.plant.mature) and int(result.plant.ready_at)>int(Time.get_unix_time_from_system()),"Sown plants join ownership immediately and begin the normal twelve-second growth stage")
	check(not state.fruit_crops.has(id),"Seedlings do not bear fruit before reaching maturity")
	before=snapshot(state)
	check(not state.plant_seed_at(reference,0).ok and snapshot(state)==before,"A used seed reference cannot plant the next shifted seed by mistake")
	var restored = State.new(path)
	check(restored.load_game() and str(restored.bed[4])==id and restored.owns_plant(id),"The selected plot and seedling survive the single committed save")
	check(restored.get_plant(id).genes==JSON.parse_string(JSON.stringify(result.plant.genes)),"New individual DNA persists while the seedling grows")
	# Use a real fertilized embryo to verify that plot-based planting never
	# regenerates its meaningful DNA, ancestry or carried alleles.
	var a: String = str(state.plant_order[0])
	var b: String = str(state.plant_order[1])
	check(state.pollinate(a,b).ok,"A real hybrid seed fixture can be fertilized")
	state.pollinations[a].ready_at=0
	check(state.harvest_fruit(a).ok and state.extract_all_seeds().ok,"Real hybrid fruit yields full-genome seeds")
	var embryo_index: int = state.seed_bank.size()-1
	var embryo_seed: Dictionary = state.seed_bank[embryo_index].duplicate(true)
	var embryo_ref: Dictionary = state.market_ref("seed",embryo_index)
	var genome: String = DNA.profile(embryo_seed.genome).code
	state.seed_bank.remove_at(0)
	result=state.plant_seed_at(embryo_ref,2)
	check(result.ok and str(state.bed[2])==str(result.plant_id),"The selected hybrid seed reaches its selected plot after earlier bank entries shift")
	check(DNA.profile(result.plant).code==genome and result.plant.parents==embryo_seed.genome.parents,"Full inherited DNA and both parents are preserved without a new inheritance roll")
	check(float(result.plant.care.height_bonus)==0 and float(result.plant.care.weight_bonus)==0 and int(result.plant.care.life_bonus_seconds)==0,"A newly planted individual starts with fresh somatic care and lifespan")
	var growing_id: String = str(result.plant_id)
	state.get_plant(growing_id).ready_at=0
	check(state.tick_growth() and state.get_plant(growing_id).mature and state.fruit_crops.has(growing_id),"Normal growth transitions the planted seedling into a fruit-bearing mature plant")
	state.seed_bank.append({"name":"Incomplete embryo","genome":{"bad":"data"}})
	var broken: Dictionary = state.market_ref("seed",state.seed_bank.size()-1)
	before=snapshot(state)
	check(not state.plant_seed_at(broken,1).ok and snapshot(state)==before,"An incomplete embryo cannot spend light or consume IDs before validation")
	state.seed_bank.pop_back()
	state.seed_bank.append({"species_index":999,"seed":17,"rarity":"Common","pattern":"Solid"})
	broken=state.market_ref("seed",state.seed_bank.size()-1)
	before=snapshot(state)
	check(not state.plant_seed_at(broken,1).ok and snapshot(state)==before,"An invalid founding species snapshot is rejected without an array access or partial sowing")
	state.seed_bank.pop_back()
	# Legacy index callers retain their auto-placement and tray behavior.
	result=state.plant_seed(0)
	check(result.ok and int(result.bed_index)==0 and str(state.bed[0])==str(result.plant_id),"The original planting API still finds the first available plot")
	for cell in range(state.bed.size()):
		if str(state.bed[cell]).is_empty(): state.bed[cell]=a
	var full_bed: Array = state.bed.duplicate()
	var tray_seed: Dictionary = state._make_seed(0,"Common")
	state.seed_bank.append(tray_seed)
	result=state.plant_seed(state.seed_bank.size()-1)
	check(result.ok and int(result.bed_index)==-1 and state.bed==full_bed and state.owns_plant(str(result.plant_id)),"Legacy planting with a full garden keeps the seedling safely in the tray")
	state.seed_bank.append(state._make_seed(0,"Common"))
	before=snapshot(state)
	check(not state.plant_seed_at(state.market_ref("seed",state.seed_bank.size()-1),0).ok and snapshot(state)==before,"Explicit plot planting never falls back to a tray when every plot is occupied")
	for entry: String in [path,path.get_basename()+".backup.json"]:
		if FileAccess.file_exists(entry): DirAccess.remove_absolute(entry)
	print("PLANTING MODEL TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
