extends RefCounted
class_name PlantCare
const AGING_SECONDS: int = 1200
const WITHER_SECONDS: int = 1500
const GROW_SECONDS: int = 12
## Somatic care and physical measurements are separate from inherited DNA.
## Individual variation is stable and local: reading measurements never touches
## GardenState's RNG, IDs, resources, or genetic records.
const BASE_HEIGHT := {"Leaf":38.0,"Bloom":52.0,"Vine":92.0,"Root":24.0,"Spore":32.0,"Toxin":45.0,"Parasite":67.0,"Carnivorous":36.0}
const BASE_WEIGHT := {"Leaf":230.0,"Bloom":160.0,"Vine":115.0,"Root":480.0,"Spore":180.0,"Toxin":260.0,"Parasite":95.0,"Carnivorous":250.0}
const TOOLS := [
	{"key":"water","name":"Watering can","description":"Refresh the roots and add 1 minute to this plant's life. Free, with a 60-second cooldown; up to 5 waterings.","cost":0,"icon":"drop","max_uses":5,"cooldown":60,"effect":"Life +1 minute"},
	{"key":"longevity","name":"Longevity tonic","description":"Add 10 minutes to this plant's lifespan. Up to 3 doses; cannot restore a withered plant.","cost":10,"icon":"tonic","max_uses":3,"cooldown":0,"effect":"Life +10 minutes"},
	{"key":"growth","name":"Growth fertilizer","description":"Increase this plant's mature height by 15% of its natural height. Up to 4 doses.","cost":12,"icon":"sprout","max_uses":4,"cooldown":0,"effect":"Height +15%"},
	{"key":"compost","name":"Rich compost","description":"Increase this plant's mature weight by 20% of its natural weight. Up to 4 portions.","cost":12,"icon":"soil","max_uses":4,"cooldown":0,"effect":"Weight +20%"},
	{"key":"sunlamp","name":"Sun lamp","description":"Help one growing seedling reach maturity immediately. Its own DNA and mature measurements stay intact.","cost":5,"icon":"sun","max_uses":1,"cooldown":0,"effect":"Mature a seedling now"},
	{"key":"ripening","name":"Ripening mist","description":"Ripen this plant's developing natural and hybrid fruit. Up to 5 sprays, with a 30-second cooldown.","cost":8,"icon":"fruit","max_uses":5,"cooldown":30,"effect":"Ripen developing fruit"}
]

static func tools() -> Array:
	return TOOLS.duplicate(true)

static func tool(key: String) -> Dictionary:
	for definition: Dictionary in TOOLS:
		if str(definition.key)==key: return definition.duplicate(true)
	return {}

static func default_care() -> Dictionary:
	return {"height_bonus":0.0,"weight_bonus":0.0,"life_bonus_seconds":0,"uses":{},"cooldowns":{}}

static func individual_variation(p: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.get("seed",1)) ^ 0x51A7C3D
	return {"height_variation":rng.randf_range(0.86,1.16),"weight_variation":rng.randf_range(0.80,1.24)}

static func initialize(p: Dictionary) -> void:
	if not p.has("measurements"): p["measurements"] = individual_variation(p)
	if not p.has("care"): p["care"] = default_care()

static func _gene(p: Dictionary,key: String,fallback: Variant) -> Variant:
	var value: Variant = p.get("genes",{}).get(key,fallback)
	return value.get("dominant",fallback) if value is Dictionary else value

static func _natural_base(p: Dictionary,table: Dictionary) -> float:
	var mix: Dictionary = p.get("lineage_mix",{})
	var total: float = 0
	var weighted: float = 0
	for key: Variant in mix:
		if table.has(str(key)) and float(mix[key])>0:
			weighted+=float(table[str(key)])*float(mix[key])
			total+=float(mix[key])
	return weighted/total if total>0 else float(table.get(str(p.get("type","Leaf")),table.Leaf))

static func measurements(p: Dictionary,now: int = -1) -> Dictionary:
	if p.is_empty(): return {"height_cm":0.0,"weight_g":0.0,"mature_height_cm":0.0,"mature_weight_g":0.0,"natural_height_cm":0.0,"natural_weight_g":0.0,"height_bonus":0.0,"weight_bonus":0.0,"growth_progress":0.0,"height_fraction":0.0,"weight_fraction":0.0}
	if now<0: now=int(Time.get_unix_time_from_system())
	var variation: Dictionary = p.get("measurements",{})
	if variation.is_empty(): variation=individual_variation(p)
	var size: String = str(_gene(p,"size","Standard"))
	var height_factor: float = 0.76 if size=="Small" else (1.28 if size=="Large" else 1.0)
	var weight_factor: float = 0.62 if size=="Small" else (1.65 if size=="Large" else 1.0)
	match str(_gene(p,"form","Upright")):
		"Trailing": height_factor*=0.84; weight_factor*=0.96
		"Rosette": height_factor*=0.80; weight_factor*=1.12
		"Climbing": height_factor*=1.18; weight_factor*=0.93
	match str(_gene(p,"texture","Matte")):
		"Waxy": weight_factor*=1.05
		"Wet": weight_factor*=1.10
		"Translucent": weight_factor*=0.90
		"Fibrous": weight_factor*=1.03
	var natural_height: float = _natural_base(p,BASE_HEIGHT)*height_factor*float(variation.get("height_variation",1.0))
	var natural_weight: float = _natural_base(p,BASE_WEIGHT)*weight_factor*float(variation.get("weight_variation",1.0))
	var care: Dictionary = p.get("care",{})
	var height_bonus: float = clampf(float(care.get("height_bonus",0.0)),0.0,0.60)
	var weight_bonus: float = clampf(float(care.get("weight_bonus",0.0)),0.0,0.80)
	var height: float = natural_height*(1.0+height_bonus)
	var weight: float = natural_weight*(1.0+weight_bonus)
	var progress: float = 1.0
	if not bool(p.get("mature",false)):
		var ready: int = int(p.get("ready_at",0))
		progress=clampf(1.0-float(ready-now)/float(GROW_SECONDS),0.0,1.0) if ready>0 else 0.0
	var height_fraction: float = 0.28+0.72*progress
	var weight_fraction: float = 0.12+0.88*pow(progress,1.3)
	return {"height_cm":snappedf(height*height_fraction,0.1),"weight_g":snappedf(weight*weight_fraction,0.1),
		"mature_height_cm":snappedf(height,0.1),"mature_weight_g":snappedf(weight,0.1),
		"natural_height_cm":snappedf(natural_height,0.1),"natural_weight_g":snappedf(natural_weight,0.1),
		"height_bonus":height_bonus,"weight_bonus":weight_bonus,"growth_progress":progress,
		"height_fraction":height_fraction,"weight_fraction":weight_fraction}

static func life_limits(p: Dictionary) -> Dictionary:
	var bonus: float = clampf(float(p.get("care",{}).get("life_bonus_seconds",0)),0.0,2100.0)
	return {"aging_at":float(AGING_SECONDS)+bonus,"life_limit":float(WITHER_SECONDS)+bonus,"bonus_seconds":bonus}

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func valid_measurements(value: Variant) -> bool:
	if not value is Dictionary: return false
	if not _number(value.get("height_variation",null)) or not _number(value.get("weight_variation",null)): return false
	return float(value.height_variation)>=0.859999 and float(value.height_variation)<=1.160001 and float(value.weight_variation)>=0.799999 and float(value.weight_variation)<=1.240001

static func valid_care(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key: String in ["height_bonus","weight_bonus","life_bonus_seconds"]:
		if not _number(value.get(key,null)) or float(value[key])<0: return false
	if float(value.height_bonus)>0.600001 or float(value.weight_bonus)>0.800001 or float(value.life_bonus_seconds)>2100.000001: return false
	if not value.get("uses",null) is Dictionary or not value.get("cooldowns",null) is Dictionary: return false
	for key: Variant in value.uses:
		var definition: Dictionary = tool(str(key))
		var count: Variant = value.uses[key]
		if not key is String or definition.is_empty() or not _number(count) or float(count)!=floorf(float(count)) or float(count)<0 or float(count)>int(definition.max_uses): return false
	for key: Variant in value.cooldowns:
		if not key is String or tool(key).is_empty() or not _number(value.cooldowns[key]) or float(value.cooldowns[key])<0: return false
	return true
