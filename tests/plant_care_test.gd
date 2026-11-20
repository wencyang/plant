extends SceneTree
const State = preload("res://scripts/garden_state.gd")
const Care = preload("res://scripts/plant_care.gd")
const DNA = preload("res://scripts/plant_dna.gd")
var checks: int = 0
var failures: int = 0

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("PLANT CARE: "+message)

func _initialize() -> void:
	var path: String = "/tmp/conservatory_care_%d.json" % Time.get_ticks_usec()
	var state = State.new(path)
	state.new_game()
	state.resources.sunlight=1000
	var id: String = str(state.plant_order[0])
	var other: String = str(state.plant_order[1])
	var p: Dictionary = state.get_plant(id)
	var tool_keys: Dictionary = {}
	for definition: Dictionary in state.care_tools():
		check(not tool_keys.has(definition.key),"Every care tool has one stable action key")
		tool_keys[definition.key]=true
		check(int(definition.cost)>=0 and int(definition.max_uses)>0,"Care tool has a disclosed positive budget and nonnegative price")
	check(tool_keys.size()==6,"Six distinct care tools cover lifespan, size, mass, seedlings and fruit")
	for plant_id: String in state.plant_order:
		check(Care.valid_measurements(state.get_plant(plant_id).measurements),"Each owned plant has persisted individual size variation")
		check(Care.valid_care(state.get_plant(plant_id).care),"Each owned plant starts with valid fresh care state")
	var measures: Dictionary = state.plant_measurements(id)
	check(float(measures.height_cm)>0 and float(measures.weight_g)>0,"Height in centimeters and weight in grams are real positive values")
	check(measures.height_cm==measures.mature_height_cm and measures.weight_g==measures.mature_weight_g,"Mature dimensions match the plant's current measurements")
	check(is_equal_approx(float(measures.height_bonus),0) and is_equal_approx(float(measures.weight_bonus),0),"New plants have no hidden fertilizer bonuses")
	var twin: Dictionary = state._create_base(0,int(p.seed),"twin")
	check(Care.measurements(twin).natural_height_cm==measures.natural_height_cm and Care.measurements(twin).natural_weight_g==measures.natural_weight_g,"Identical anatomy seed and DNA reproduce the same natural measurements")
	var individual: Dictionary = state._create_base(0,int(p.seed)+1,"individual")
	check(individual.measurements!=p.measurements,"Different individuals have their own seeded physical variation")
	var small: Dictionary = p.duplicate(true)
	var large: Dictionary = p.duplicate(true)
	small.genes.size.dominant="Small"
	large.genes.size.dominant="Large"
	check(float(Care.measurements(large).natural_height_cm)>float(Care.measurements(small).natural_height_cm)*1.6,"Inherited body-size DNA affects actual height")
	check(float(Care.measurements(large).natural_weight_g)>float(Care.measurements(small).natural_weight_g)*2.5,"Inherited body-size DNA affects actual biomass")
	var original: String = DNA.canonical([state.plants,state.resources,state.id_counter,state.random.state])
	var saved_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	for i in range(8):
		state.plant_measurements(id)
		state.care_status(id,"growth")
	check(DNA.canonical([state.plants,state.resources,state.id_counter,state.random.state])==original and FileAccess.get_file_as_bytes(path)==saved_bytes,"Inspecting tools and measurements never mutates plants, resources, RNG, IDs or save bytes")
	var original_code: String = DNA.profile(p).code
	var original_genes: String = DNA.canonical([p.genes,p.stats,p.skill_genes,p.parents,p.seed])
	var light: int = int(state.resources.sunlight)
	check(state.apply_care(id,"water").ok and int(state.resources.sunlight)==light,"Watering is free")
	check(int(state.life_profile(id).life_limit)==1560 and int(state.life_profile(id).aging_at)==1260,"Watering extends both maturity and total lifespan by one minute")
	check(not state.care_status(id,"water").allowed and int(state.care_status(id,"water").cooldown_remaining)>0,"The same plant must wait for its watering cooldown")
	check(not state.apply_care(id,"water").ok and int(p.care.uses.water)==1,"Cooldown cannot spend a second care use")
	for i in range(4):
		p.care.cooldowns.water=0
		check(state.apply_care(id,"water").ok,"Later watering is allowed within the per-plant budget")
	p.care.cooldowns.water=0
	check(not state.apply_care(id,"water").ok and int(p.care.uses.water)==5,"Free watering is capped at five uses per plant")
	for i in range(3): check(state.apply_care(id,"longevity").ok,"Longevity tonic extends a living plant")
	check(int(state.life_profile(id).life_limit)==3600 and int(state.life_profile(id).aging_at)==3300,"Water and tonic budgets extend one plant to a one-hour lifespan")
	light=int(state.resources.sunlight)
	check(not state.apply_care(id,"longevity").ok and int(state.resources.sunlight)==light,"A fourth tonic is rejected without charging light")
	var height_before: float = float(state.plant_measurements(id).mature_height_cm)
	var weight_before: float = float(state.plant_measurements(id).mature_weight_g)
	for i in range(4): check(state.apply_care(id,"growth").ok,"Fertilizer adds a visible somatic height increase")
	var tall: Dictionary = state.plant_measurements(id)
	check(is_equal_approx(float(tall.height_bonus),0.60) and absf(float(tall.mature_height_cm)-height_before*1.60)<0.2,"Four fertilizer doses add sixty percent of natural mature height")
	check(float(tall.mature_weight_g)==weight_before,"Height fertilizer does not silently add weight")
	check(not state.apply_care(id,"growth").ok,"Height fertilizer cannot exceed its four-dose budget")
	for i in range(4): check(state.apply_care(id,"compost").ok,"Compost adds a somatic biomass increase")
	var heavy: Dictionary = state.plant_measurements(id)
	check(is_equal_approx(float(heavy.weight_bonus),0.80) and absf(float(heavy.mature_weight_g)-weight_before*1.80)<0.2,"Four compost portions add eighty percent of natural mature weight")
	check(float(heavy.mature_height_cm)==float(tall.mature_height_cm),"Compost does not silently add height")
	check(not state.apply_care(id,"compost").ok,"Compost cannot exceed its four-portion budget")
	check(DNA.profile(p).code==original_code and DNA.canonical([p.genes,p.stats,p.skill_genes,p.parents,p.seed])==original_genes,"Care changes the individual, never its inherited genome, battle stats, pedigree or anatomy seed")
	check(not state.apply_care(id,"sunlamp").ok,"Sun lamp cannot charge an already mature plant")
	var planted: Dictionary = state.plant_seed(0).plant
	var seedling: Dictionary = state.plant_measurements(str(planted.id))
	check(float(seedling.height_cm)<float(seedling.mature_height_cm)*0.4 and float(seedling.weight_g)<float(seedling.mature_weight_g)*0.2,"A new seedling has smaller real height and biomass than its mature potential")
	var halfway: Dictionary = Care.measurements(planted,int(planted.ready_at)-6)
	check(float(halfway.height_cm)>float(seedling.height_cm) and float(halfway.weight_g)>float(seedling.weight_g),"Measurements grow through the seedling stage rather than jumping only at maturity")
	var seedling_code: String = DNA.profile(planted).code
	light=int(state.resources.sunlight)
	check(state.apply_care(str(planted.id),"sunlamp").ok and int(state.resources.sunlight)==light-5,"Sun lamp spends its disclosed price and matures the seedling")
	check(planted.mature and state.fruit_crops.has(str(planted.id)) and DNA.profile(planted).code==seedling_code,"Lamp-grown plants keep their own DNA and begin normal fruit production")
	check(state.pollinate(id,other).ok,"A cared-for plant remains fertile")
	light=int(state.resources.sunlight)
	var ripened: Dictionary = state.apply_care(id,"ripening")
	check(ripened.ok and int(ripened.effects.fruit_ready)==2 and int(state.resources.sunlight)==light-8,"One mist can ripen both pending natural and hybrid fruit at the disclosed cost")
	check(state.fruit_status(id).natural_ready and state.fruit_status(id).cross_ready,"Both fruit types become genuinely harvestable")
	p.care.cooldowns.ripening=0
	check(not state.apply_care(id,"ripening").ok,"Already ripe fruit cannot consume another spray")
	state.harvest_fruit(id)
	var first_seed: int = state.seed_bank.size()
	state.extract_all_seeds()
	var embryo: Dictionary = state.seed_bank[first_seed].genome
	check(float(embryo.care.height_bonus)==0 and float(embryo.care.weight_bonus)==0 and int(embryo.care.life_bonus_seconds)==0,"Fertilized offspring never inherit somatic care bonuses")
	var born: Dictionary = state.plant_seed(first_seed).plant
	check(float(born.care.height_bonus)==0 and float(born.care.weight_bonus)==0 and int(state.life_profile(str(born.id)).life_limit)==1500,"Sowing starts a fresh individual's care and lifespan")
	check(born.measurements!=p.measurements,"Descendants have their own physical variation instead of copying the parent's care-grown body")
	state.save_game()
	var restored = State.new(path)
	check(restored.load_game(),"Cared-for archive reloads")
	check(restored.plant_measurements(id)==state.plant_measurements(id),"Individual height, mass and somatic growth persist exactly")
	check(int(restored.life_profile(id).life_limit)==3600 and int(restored.get_plant(id).care.uses.longevity)==3,"Extended lifetime and use budgets persist")
	check(DNA.profile(restored.get_plant(id)).code==original_code,"Save/reload preserves care-independent DNA identity")
	state.resources.sunlight=0
	light=int(state.resources.sunlight)
	check(not state.apply_care(other,"growth").ok and int(state.resources.sunlight)==light,"Unaffordable care never spends negative light")
	check(not state.apply_care(other,"unknown").ok and not state.apply_care("absent","water").ok,"Unknown tools and missing plants are rejected safely")
	p.life_age=1500.0
	state.advance_lifecycle(1.0)
	check(not p.withered and state.life_profile(id).stage=="mature","An extended lifespan prevents premature withering at the original age limit")
	p.life_age=3599.0
	state.advance_lifecycle(1.0)
	check(p.withered and state.life_profile(id).stage=="withered","Even a fully cared-for plant reaches its final bounded lifespan")
	check(not state.apply_care(id,"water").ok and not state.apply_care(id,"longevity").ok,"Care does not resurrect naturally withered plants")
	check(state.fruit_status(id).natural_ready,"Natural withering still leaves the final seed-bearing fruit")
	state.save_game()
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var malformed: Dictionary = payload.duplicate(true)
	malformed.plants[id].care.height_bonus=999.0
	check(not state._valid_save(malformed),"Malformed care bonuses are rejected by save validation")
	malformed=payload.duplicate(true)
	malformed.plants[id].care.uses.water=6
	check(not state._valid_save(malformed),"Impossible tool use counts are rejected")
	malformed=payload.duplicate(true)
	malformed.plants[id].measurements.height_variation=-1.0
	check(not state._valid_save(malformed),"Malformed physical variation is rejected")
	for plant: Dictionary in payload.plants.values():
		plant.erase("care")
		plant.erase("measurements")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	var legacy = State.new(path)
	check(legacy.load_game(),"Older saves without care fields migrate")
	check(Care.valid_care(legacy.get_plant(id).care) and Care.valid_measurements(legacy.get_plant(id).measurements),"Migration creates usable fresh tool budgets and deterministic measurements")
	check(DNA.profile(legacy.get_plant(id)).code==original_code,"Migration never rewrites the plant's genome")
	for entry in [path,path.get_basename()+".backup.json"]:
		if FileAccess.file_exists(entry): DirAccess.remove_absolute(entry)
	print("PLANT CARE TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
