extends RefCounted
## Botanical abilities come from expressed DNA and inherited ancestry. These
## rules work for every specimen, including ordinary crosses made elsewhere.
const VERSION: int = 1
const PARENTS := [
	{"key":"river_fan","name":"River Fan","species_index":0,"seed":913701,"role":"broad_leaf","description":"Broad, waxy leaves spread over the riverbank like little umbrellas.","tip":"Cross its round, waxy leaves with Floatcap's buoyant spore ancestry to grow a living raft.","genes":{"shape":"Round","texture":"Waxy","size":"Large","form":"Rosette","glow":"None"}},
	{"key":"floatcap","name":"Floatcap","species_index":4,"seed":913702,"role":"buoyant","description":"Airy mushroom caps bob on the stream. Their stems spring back after every ripple.","tip":"Its spore ancestry can support a floating leaf when crossed with River Fan.","genes":{"shape":"Round","texture":"Waxy","size":"Large","form":"Rosette","glow":"None"}},
	{"key":"gripvine","name":"Gripvine","species_index":2,"seed":913703,"role":"climber","description":"Long, fibrous tendrils hook themselves around the old stonework.","tip":"Cross its climbing, fibrous growth with Stone Root's strong root ancestry to grow a vine bridge.","genes":{"shape":"Pointed","texture":"Fibrous","size":"Large","form":"Climbing","glow":"None"}},
	{"key":"stone_root","name":"Stone Root","species_index":3,"seed":913704,"role":"anchor","description":"A sturdy root crown grips the bank while young stems reach toward the opposite shore.","tip":"Its root ancestry can anchor Gripvine's climbing stems across the stream.","genes":{"shape":"Pointed","texture":"Fibrous","size":"Large","form":"Climbing","glow":"None"}},
	{"key":"moonbell","name":"Moonbell","species_index":1,"seed":913705,"role":"glow","description":"A pale flower waits beyond the stream. Both of its glow copies carry Soft Glow.","tip":"Cross Moonbell with a generation-2 plant. Soft Glow can appear in the next generation; an unlit child can still carry it.","genes":{"shape":"Frilled","texture":"Translucent","size":"Standard","form":"Upright","glow":"Soft Glow"}}
]

static func default_adventure() -> Dictionary:
	return {"version":VERSION,"cuttings":{},"route":"","route_plant_id":"","route_record":{},"moonbell_id":"","lantern_id":"","lantern_record":{},"last_cross":{},"siblings":[]}

static func definition(key: String) -> Dictionary:
	for row: Dictionary in PARENTS:
		if str(row.key)==key: return row.duplicate(true)
	return {}

static func gene(p: Dictionary,key: String,fallback: Variant = "") -> Variant:
	var pair: Variant=p.get("genes",{}).get(key,{})
	return pair.get("dominant",fallback) if pair is Dictionary else fallback

static func _share(p: Dictionary,family: String) -> float:
	var mix: Dictionary=p.get("lineage_mix",{})
	return float(mix.get(family,0)) if not mix.is_empty() else (1.0 if str(p.get("type",""))==family else 0.0)

static func capabilities(p: Dictionary) -> Dictionary:
	var broad: bool=str(gene(p,"shape")) in ["Round","Split"]
	var waxy: bool=str(gene(p,"texture"))=="Waxy"
	var climbing: bool=str(gene(p,"form"))=="Climbing"
	var fibrous: bool=str(gene(p,"texture"))=="Fibrous"
	var leafy: bool=_share(p,"Leaf")>=0.199999
	var spores: bool=_share(p,"Spore")>=0.199999
	var vines: bool=_share(p,"Vine")>=0.199999
	var roots: bool=_share(p,"Root")>=0.199999
	var glow: bool=str(gene(p,"glow"))=="Soft Glow"
	var raft: bool=leafy and spores and broad and waxy
	var vine: bool=vines and roots and climbing and fibrous
	var lantern: bool=glow and int(p.get("generation",1))>=3
	var labels: Array[String]=[]
	var routes: Array[String]=[]
	if raft: labels.append("Living raft"); routes.append("raft")
	if vine: labels.append("Vine bridge"); routes.append("vine")
	if lantern: labels.append("Lantern bloom")
	return {"raft":raft,"vine":vine,"lantern":lantern,"glow":glow,"routes":routes,"labels":labels,
		"requirements":[
			{"key":"raft","name":"Living raft","ready":raft,"description":"Leaf and Spore ancestry, round or split leaves, and a waxy surface.","traits":[{"label":"Leaf ancestry · at least 20%","met":leafy},{"label":"Spore ancestry · at least 20%","met":spores},{"label":"Round or Split leaves","met":broad},{"label":"Waxy surface","met":waxy}]},
			{"key":"vine","name":"Vine bridge","ready":vine,"description":"Vine and Root ancestry, climbing growth, and fibrous tissue.","traits":[{"label":"Vine ancestry · at least 20%","met":vines},{"label":"Root ancestry · at least 20%","met":roots},{"label":"Climbing growth","met":climbing},{"label":"Fibrous tissue","met":fibrous}]},
			{"key":"lantern","name":"Lantern bloom","ready":lantern,"description":"A generation-3 or later plant that shows Soft Glow.","traits":[{"label":"Generation 3 or later","met":int(p.get("generation",1))>=3},{"label":"Shows Soft Glow","met":glow}]}]}

static func evidence(p: Dictionary) -> Dictionary:
	return {"id":str(p.id),"seed":int(p.seed),"generation":int(p.generation),"parents":p.parents.duplicate(),"type":str(p.type),"lineage_mix":p.get("lineage_mix",{}).duplicate(true),"genes":p.genes.duplicate(true)}

static func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=0 and float(value)==floorf(float(value))

static func _record(value: Variant,archive: Dictionary,kind: String) -> bool:
	if not value is Dictionary or not value.get("plant_id") is String or not _whole(value.get("at")): return false
	var id: String=str(value.plant_id)
	if not archive.get(id) is Dictionary or not value.get("evidence") is Dictionary: return false
	var proof: Dictionary=value.evidence
	var original: Dictionary=archive[id]
	if str(proof.get("id",""))!=id or not _whole(proof.get("seed")) or int(proof.seed)!=int(original.get("seed",-1)): return false
	if not _whole(proof.get("generation")) or int(proof.generation)!=int(original.get("generation",0)): return false
	if not proof.get("parents") is Array or proof.parents.size()<2 or proof.parents!=original.get("parents",[]): return false
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
	var abilities: Dictionary=capabilities(proof)
	return bool(abilities.get(kind,false))

static func valid_adventure(value: Variant,archive: Dictionary) -> bool:
	if not value is Dictionary or not _whole(value.get("version")) or int(value.version)!=VERSION: return false
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
		if not value.route_plant_id.is_empty() or not value.route_record.is_empty() or not value.moonbell_id.is_empty() or not value.lantern_id.is_empty() or not value.lantern_record.is_empty() or value.cuttings.has("moonbell"): return false
	else:
		if not _record(value.route_record,archive,str(value.route)) or value.route_record.plant_id!=value.route_plant_id: return false
	if not value.moonbell_id.is_empty():
		if not archive.get(value.moonbell_id) is Dictionary or not archive[value.moonbell_id].get("origin",{}) is Dictionary: return false
		if archive[value.moonbell_id].origin.get("adventure_key","")!="moonbell" or value.cuttings.get("moonbell","")!=value.moonbell_id: return false
	elif value.cuttings.has("moonbell"): return false
	if value.lantern_id.is_empty():
		if not value.lantern_record.is_empty(): return false
	else:
		if value.moonbell_id.is_empty() or not _record(value.lantern_record,archive,"lantern") or value.lantern_record.plant_id!=value.lantern_id: return false
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
	return true
