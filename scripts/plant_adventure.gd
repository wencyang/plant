extends RefCounted
## Reusable botanical behavior comes from expressed DNA, in every family and generation.
## Permanent field records preserve the phenotype used, without changing the living plant.
const VERSION: int = 1
const PARENTS := [
	{"key":"river_fan","name":"River Fan","species_index":0,"seed":913701,"role":"broad_leaf","description":"Broad, waxy leaves spread over the riverbank like little umbrellas.","tip":"Its broad, waxy leaves shed rain, catch seeds, and float on still water.","genes":{"shape":"Round","texture":"Waxy","size":"Large","form":"Rosette","glow":"None"}},
	{"key":"floatcap","name":"Floatcap","species_index":4,"seed":913702,"role":"buoyant","description":"Airy mushroom caps bob on the stream. Their stems spring back after every ripple.","tip":"Its round, waxy caps can shelter seedlings or catch drifting seeds.","genes":{"shape":"Round","texture":"Waxy","size":"Large","form":"Rosette","glow":"None"}},
	{"key":"gripvine","name":"Gripvine","species_index":2,"seed":913703,"role":"climber","description":"Long, fibrous tendrils hook themselves around the old stonework.","tip":"Its climbing, fibrous growth grips supports and weaves living nets.","genes":{"shape":"Pointed","texture":"Fibrous","size":"Large","form":"Climbing","glow":"None"}},
	{"key":"stone_root","name":"Stone Root","species_index":3,"seed":913704,"role":"anchor","description":"A sturdy root crown grips the bank while young stems reach toward the opposite shore.","tip":"Its climbing, fibrous tissue anchors a trellis and draws water along its roots.","genes":{"shape":"Pointed","texture":"Fibrous","size":"Large","form":"Climbing","glow":"None"}},
	{"key":"moonbell","name":"Moonbell","species_index":1,"seed":913705,"role":"glow","description":"Round, translucent flowers climb the old orchard branches. Both glow copies carry Soft Glow.","tip":"Its Soft Glow attracts moths. Cross it with a sheltering or coiling plant to discover new combinations.","genes":{"shape":"Round","texture":"Translucent","size":"Standard","form":"Climbing","glow":"Soft Glow"}}
]

const SITES := [
	{"id":"rain_nursery","name":"Rain nursery","question":"How could these seedlings stay dry?","description":"Rain splashes through a broken roof onto tiny seedlings.","clue":"Broad waxy leaves shed water. Soft light can attract moths carrying dry nesting moss.","approaches":[
		{"key":"canopy","label":"Shelter with leaves","effect":"A living canopy shelters the seedlings. Rain slides into the soil around them.","tradeoff":"The sheltered seedlings stay dry, but their flowers remain in shade."},
		{"key":"glow","label":"Invite moss-carrying moths","effect":"Moths gather around the soft light and tuck dry moss over the seedlings.","tradeoff":"The nursery stays open to sunlight; moths need the light to find it."}],"combo":"canopy_glow","combo_effect":"A glowing canopy shelters the seedlings while lantern moths settle beneath it.","reward_name":"Rainlight","reward_species":1,"reward_seed":927101,"reward_genes":{"shape":"Frilled","texture":"Translucent","glow":"Soft Glow","pattern":"Bicolor Ring"}},
	{"id":"seed_catch","name":"Drifting seed bend","question":"Where could the drifting seeds settle?","description":"Winged seeds drift past the bare bank without finding a place to land.","clue":"Wide waxy leaves can cup the seeds. Fibrous climbing growth can weave a net.","approaches":[
		{"key":"canopy","label":"Cup the falling seeds","effect":"Broad leaves cradle the drifting seeds above the damp soil.","tradeoff":"The leaf cups catch seeds close to the ground."},
		{"key":"coil","label":"Weave a seed net","effect":"Coiling tendrils stretch into a living net and catch seeds on the breeze.","tradeoff":"The net reaches higher, while its small leaves leave the bank exposed."}],"combo":"coil_glow","combo_effect":"The glowing tendril net catches seeds carried by the evening moths.","reward_name":"Sailleaf","reward_species":0,"reward_seed":927102,"reward_genes":{"shape":"Split","texture":"Waxy","form":"Trailing","size":"Large","pattern":"Striped"}},
	{"id":"cistern","name":"Forgotten cistern","question":"Could the empty basin hold water again?","description":"The old stone basin is dry. Water trickles just beyond its cracked wall.","clue":"Waxy leaves can funnel rain into the basin. Fibrous climbing roots can draw water through the wall.","approaches":[
		{"key":"canopy","label":"Funnel the rain","effect":"Overlapping leaves guide the rain into the cistern, filling a shallow pool.","tradeoff":"The pool fills from rain collected above it."},
		{"key":"coil","label":"Grow a root wick","effect":"Fibrous roots slip through the cracked wall and draw a ribbon of water into the basin.","tradeoff":"The narrow root channels keep the water moving."}],"combo":"coil_glow","combo_effect":"Soft light traces the root channels as water ripples through the restored cistern.","reward_name":"Wickroot","reward_species":3,"reward_seed":927103,"reward_genes":{"shape":"Pointed","texture":"Fibrous","form":"Climbing","pattern":"Spotted"}},
	{"id":"moth_garden","name":"Moth garden","question":"What would bring the moths back?","description":"Closed flowers wait in a quiet hollow beneath the old trees.","clue":"A plant that shows Soft Glow can guide moths to the waiting flowers.","approaches":[
		{"key":"glow","label":"Light a moth roost","effect":"Moths follow the soft light. As they settle, the sleeping flowers open.","tradeoff":"The light draws visitors; a canopy would also shelter their roost."}],"combo":"canopy_glow","combo_effect":"Moths nest beneath the glowing leaves and a sheltered flower trail blooms around them.","reward_name":"Moonveil","reward_species":4,"reward_seed":927104,"reward_genes":{"shape":"Split","texture":"Matte","form":"Rosette","glow":"Soft Glow","pattern":"Starburst"}},
	{"id":"wind_terrace","name":"Wind terrace","question":"How could a garden take root in this wind?","description":"Gusts sweep the terrace, bending every young stem toward the ground.","clue":"Fibrous climbing stems can anchor a trellis. Broad waxy leaves can turn the gusts aside.","approaches":[
		{"key":"coil","label":"Anchor a living trellis","effect":"Climbing stems grip the old posts. Young shoots wind safely through the anchored trellis.","tradeoff":"The trellis supports tall shoots and lets the breeze pass through."},
		{"key":"canopy","label":"Grow a leafy windbreak","effect":"Broad leaves turn the gusts aside, making a calm pocket for new growth.","tradeoff":"The windbreak shelters low plants while casting a wide shadow."}],"combo":"coil_glow","combo_effect":"The anchored trellis glows softly, becoming a luminous arch over the new growth.","reward_name":"Ribbonvine","reward_species":2,"reward_seed":927105,"reward_genes":{"shape":"Split","texture":"Fibrous","form":"Climbing","size":"Large","pattern":"Gradient"}}
]
const OBSERVATIONS := {
	"river_fan":[{"key":"rain","label":"Drip water on a leaf","result":"Water beads on the waxy surface, then slides from the broad leaf into the soil."},{"key":"shade","label":"Look beneath its leaves","result":"Small seedlings shelter in the dry shade beneath the spreading leaves."}],
	"floatcap":[{"key":"float","label":"Watch a fallen cap","result":"The waxy cap floats at the water's edge and cradles a drifting seed."}],
	"gripvine":[{"key":"twig","label":"Offer a fallen twig","result":"Fibrous tendrils curl around the twig and hold it above the ground."}],
	"stone_root":[{"key":"water","label":"Follow the roots","result":"Water glistens along the fibrous roots where they grip a crack in the stone."}],
	"moonbell":[{"key":"shade","label":"Shade its flower","result":"Soft light shines through the flower. A moth follows the glow and settles beside it."}]
}

static func default_adventure() -> Dictionary:
	return {"version":VERSION,"cuttings":{},"route":"","route_plant_id":"","route_record":{},"moonbell_id":"","lantern_id":"","lantern_record":{},"last_cross":{},"siblings":[],"placements":{},"rewarded_sites":[],"enhanced_sites":[],"enhancement_records":{},"observations":{},"experiments":[]}

static func normalise(value: Dictionary) -> Dictionary:
	var result: Dictionary=value.duplicate(true)
	var defaults: Dictionary=default_adventure()
	for key: String in defaults:
		if not result.has(key): result[key]=defaults[key].duplicate(true) if defaults[key] is Array or defaults[key] is Dictionary else defaults[key]
	return result

static func site(id: String) -> Dictionary:
	for row: Dictionary in SITES:
		if str(row.id)==id: return row.duplicate(true)
	return {}

static func observation_choices(key: String) -> Array:
	return OBSERVATIONS.get(key,[]).duplicate(true)

static func definition(key: String) -> Dictionary:
	for row: Dictionary in PARENTS:
		if str(row.key)==key: return row.duplicate(true)
	return {}

static func gene(p: Dictionary,key: String,fallback: Variant = "") -> Variant:
	var pair: Variant=p.get("genes",{}).get(key,{})
	return pair.get("dominant",fallback) if pair is Dictionary else fallback

static func capabilities(p: Dictionary) -> Dictionary:
	var broad: bool=str(gene(p,"shape")) in ["Round","Split"]
	var waxy: bool=str(gene(p,"texture"))=="Waxy"
	var climbing: bool=str(gene(p,"form"))=="Climbing"
	var fibrous: bool=str(gene(p,"texture"))=="Fibrous"
	var glow: bool=str(gene(p,"glow"))=="Soft Glow"
	var canopy: bool=broad and waxy
	var coil: bool=climbing and fibrous
	var scale: float=0.75 if str(gene(p,"size"))=="Small" else (1.3 if str(gene(p,"size"))=="Large" else 1.0)
	var labels: Array[String]=[]
	var routes: Array[String]=[]
	if canopy: labels.append("Sheltering canopy"); routes.append("raft")
	if coil: labels.append("Coiling growth"); routes.append("vine")
	if glow: labels.append("Soft Glow")
	return {"canopy":canopy,"coil":coil,"glow":glow,"raft":canopy,"vine":coil,"lantern":glow,"routes":routes,"labels":labels,
		"strengths":{"canopy":scale if canopy else 0.0,"coil":scale if coil else 0.0,"glow":scale if glow else 0.0},
		"behaviors":[
			{"key":"canopy","name":"Sheltering canopy","ready":canopy,"strength":scale if canopy else 0.0,"description":"Broad waxy leaves shed rain, cup seeds, and float on still water.","tradeoff":"Broad leaves cast shade. A waxy surface cannot also express fibrous tissue."},
			{"key":"coil","name":"Coiling growth","ready":coil,"strength":scale if coil else 0.0,"description":"Fibrous climbing stems grip supports, catch seeds, and carry water along roots.","tradeoff":"A fibrous climbing plant cannot also express a waxy surface."},
			{"key":"glow","name":"Soft Glow","ready":glow,"strength":scale if glow else 0.0,"description":"Soft light attracts moths and reveals a plant's outline in the shade.","tradeoff":"Light attracts visitors. Shelter or a gripping stem must come from other expressed traits."}],
		"requirements":[
			{"key":"raft","name":"Sheltering canopy","ready":canopy,"description":"Round or Split leaves and a Waxy surface, in any plant family.","traits":[{"label":"Round or Split leaves","met":broad},{"label":"Waxy surface","met":waxy}]},
			{"key":"vine","name":"Coiling growth","ready":coil,"description":"Climbing growth and Fibrous tissue, in any plant family.","traits":[{"label":"Climbing growth","met":climbing},{"label":"Fibrous tissue","met":fibrous}]},
			{"key":"lantern","name":"Soft Glow","ready":glow,"description":"A plant that shows Soft Glow, in any generation.","traits":[{"label":"Shows Soft Glow","met":glow}]}]}

static func site_outcome(site_id: String,p: Dictionary,approach: String="") -> Dictionary:
	var row: Dictionary=site(site_id)
	var abilities: Dictionary=capabilities(p)
	var approaches: Array[String]=[]
	for option: Dictionary in row.get("approaches",[]):
		if bool(abilities.get(str(option.key),false)): approaches.append(str(option.key))
	var chosen: String=approach if not approach.is_empty() else (approaches[0] if not approaches.is_empty() else "")
	var result: Dictionary={"approaches":approaches,"approach":chosen,"effect":"","tradeoff":"","strength":float(abilities.strengths.get(chosen,0)),"combined":false,"combo":"","combined_effect":""}
	for option: Dictionary in row.get("approaches",[]):
		if str(option.key)==chosen: result.effect=str(option.effect); result.tradeoff=str(option.tradeoff)
	var combo: String=str(row.get("combo",""))
	var combined: bool=bool(abilities.glow) and (bool(abilities.canopy) if combo=="canopy_glow" else bool(abilities.coil))
	if combined and approaches.has(chosen):
		result.combined=true; result.combo=combo; result.combined_effect=str(row.get("combo_effect",""))
	return result

static func evidence(p: Dictionary) -> Dictionary:
	return {"id":str(p.id),"seed":int(p.seed),"generation":int(p.generation),"parents":p.parents.duplicate(),"type":str(p.type),"lineage_mix":p.get("lineage_mix",{}).duplicate(true),"genes":p.genes.duplicate(true)}

static func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=0 and float(value)==floorf(float(value))

static func _proof(value: Variant,archive: Dictionary) -> bool:
	if not value is Dictionary or not value.get("plant_id") is String or not _whole(value.get("at")): return false
	var id: String=str(value.plant_id)
	if not archive.get(id) is Dictionary or not value.get("evidence") is Dictionary: return false
	var proof: Dictionary=value.evidence
	var original: Dictionary=archive[id]
	if str(proof.get("id",""))!=id or not _whole(proof.get("seed")) or int(proof.seed)!=int(original.get("seed",-1)): return false
	if not _whole(proof.get("generation")) or int(proof.generation)!=int(original.get("generation",0)): return false
	if not proof.get("parents") is Array or proof.parents!=original.get("parents",[]): return false
	if not proof.get("genes") is Dictionary or not proof.get("lineage_mix") is Dictionary: return false
	var total: float=0
	for family: Variant in proof.lineage_mix:
		if not family is String or not family in ["Leaf","Bloom","Vine","Root","Spore","Toxin","Parasite","Carnivorous"]: return false
		var weight: Variant=proof.lineage_mix[family]
		if not (weight is int or weight is float) or not is_finite(float(weight)) or float(weight)<=0 or float(weight)>1: return false
		total+=float(weight)
	if absf(total-1.0)>0.0001: return false
	for key: String in ["shape","form","texture","glow"]:
		if not proof.genes.get(key) is Dictionary or not proof.genes[key].has("dominant") or not proof.genes[key].has("recessive"): return false
	return true

static func _record(value: Variant,archive: Dictionary,kind: String) -> bool:
	return _proof(value,archive) and bool(capabilities(value.evidence).get(kind,false))

static func valid_adventure(value: Variant,archive: Dictionary) -> bool:
	if not value is Dictionary or not _whole(value.get("version")) or int(value.version)!=VERSION: return false
	if value.has("position"):
		if not value.position is Array or value.position.size()!=2: return false
		for axis in range(2):
			var coordinate: Variant=value.position[axis]
			if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or float(coordinate)<0 or float(coordinate)>(1920 if axis==0 else 1280): return false
	for key: String in ["cuttings","route_record","lantern_record","last_cross"]:
		if not value.get(key) is Dictionary: return false
	for key: String in ["route","route_plant_id","moonbell_id","lantern_id"]:
		if not value.get(key) is String: return false
	if not value.get("siblings") is Array or not value.siblings.size() in [0,2]: return false
	for key: Variant in value.cuttings:
		if not key is String or definition(key).is_empty() or not value.cuttings[key] is String or not archive.get(value.cuttings[key]) is Dictionary: return false
		var p: Dictionary=archive[value.cuttings[key]]
		if not p.get("origin",{}) is Dictionary: return false
		if p.get("origin",{}).get("adventure_key","")!=key: return false
	if not value.route in ["","raft","vine"]: return false
	if value.route.is_empty():
		if not value.route_plant_id.is_empty() or not value.route_record.is_empty(): return false
	else:
		if not _record(value.route_record,archive,str(value.route)) or value.route_record.plant_id!=value.route_plant_id: return false
	if not value.moonbell_id.is_empty():
		if not archive.get(value.moonbell_id) is Dictionary or not archive[value.moonbell_id].get("origin",{}) is Dictionary: return false
		if archive[value.moonbell_id].origin.get("adventure_key","")!="moonbell" or value.cuttings.get("moonbell","")!=value.moonbell_id: return false
	elif value.cuttings.has("moonbell"): return false
	if value.lantern_id.is_empty():
		if not value.lantern_record.is_empty(): return false
	else:
		if not _record(value.lantern_record,archive,"lantern") or value.lantern_record.plant_id!=value.lantern_id: return false
	if not value.last_cross.is_empty():
		for key: String in ["mother_id","father_id","fruit_id"]:
			if not value.last_cross.get(key) is String: return false
		if value.last_cross.mother_id==value.last_cross.father_id or not archive.get(value.last_cross.mother_id) is Dictionary or not archive.get(value.last_cross.father_id) is Dictionary: return false
		var fruit_id: String=str(value.last_cross.fruit_id)
		if not fruit_id.begins_with("fruit_") or not fruit_id.trim_prefix("fruit_").is_valid_int() or int(fruit_id.trim_prefix("fruit_"))<=0: return false
	for id: Variant in value.siblings:
		if not id is String or not archive.get(id) is Dictionary or value.last_cross.is_empty(): return false
		if archive[id].get("parents",[])!=[value.last_cross.mother_id,value.last_cross.father_id]: return false
	if value.siblings.size()==2 and value.siblings[0]==value.siblings[1]: return false
	var placements: Variant=value.get("placements",{})
	var rewarded: Variant=value.get("rewarded_sites",[])
	if not placements is Dictionary or not rewarded is Array: return false
	var reward_seen: Dictionary={}
	for id: Variant in rewarded:
		if not id is String or site(id).is_empty() or reward_seen.has(id) or not placements.has(id): return false
		reward_seen[id]=true
	for id: Variant in placements:
		if not id is String or site(id).is_empty() or not _placement(placements[id],archive,id) or not reward_seen.has(id): return false
	var enhanced: Variant=value.get("enhanced_sites",[])
	var enhancement_records: Variant=value.get("enhancement_records",{})
	if not enhanced is Array or not enhancement_records is Dictionary or enhanced.size()!=enhancement_records.size(): return false
	var enhanced_seen: Dictionary={}
	for id: Variant in enhanced:
		if not id is String or site(id).is_empty() or enhanced_seen.has(id) or not reward_seen.has(id): return false
		var record: Variant=enhancement_records.get(id)
		if not _placement(record,archive,id) or not bool(record.get("combined",false)): return false
		enhanced_seen[id]=true
	var observations: Variant=value.get("observations",{})
	if not observations is Dictionary: return false
	for id: Variant in observations:
		if not id is String or (definition(id).is_empty() and site(id).is_empty()): return false
		var record: Variant=observations[id]
		if not record is Dictionary or not _whole(record.get("at")) or not record.get("choices") is Array or record.choices.is_empty(): return false
		var choices_seen: Dictionary={}
		for choice: Variant in record.choices:
			if not choice is String or choices_seen.has(choice): return false
			var valid: bool=choice=="watch"
			for option: Dictionary in observation_choices(id):
				if str(option.key)==choice: valid=true
			if not valid: return false
			choices_seen[choice]=true
	var experiments: Variant=value.get("experiments",[])
	if not experiments is Array or experiments.size()>24: return false
	for record: Variant in experiments:
		if not record is Dictionary or not record.get("site_id") is String or site(record.site_id).is_empty() or not record.get("success") is bool: return false
		if bool(record.success):
			if not _placement(record,archive,record.site_id): return false
		else:
			if not _proof(record,archive) or not record.get("approach") is String or not record.get("reason") is String: return false
	return true

static func _placement(value: Variant,archive: Dictionary,site_id: String) -> bool:
	if not value is Dictionary or not value.get("approach") is String: return false
	var allowed: Array[String]=[]
	for option: Dictionary in site(site_id).get("approaches",[]): allowed.append(str(option.key))
	if not allowed.has(str(value.approach)) or not _record(value,archive,str(value.approach)): return false
	var outcome: Dictionary=site_outcome(site_id,value.evidence,str(value.approach))
	if value.has("combined") and (not value.combined is bool or value.combined!=outcome.combined): return false
	if value.has("combo") and value.combo!=outcome.combo: return false
	return true
