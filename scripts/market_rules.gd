extends RefCounted
class_name MarketRules

# Offline buyers use transparent, additive prices. Quotes never consume RNG.
const Care = preload("res://scripts/plant_care.gd")
const TYPES := ["Leaf","Bloom","Vine","Root","Spore","Toxin","Parasite","Carnivorous"]
const PATTERNS := ["Solid","Striped","Spotted","Gradient","Starburst","Bicolor Ring"]
const RARITY_VALUE := {"Common":0,"Uncommon":4,"Rare":12,"Epic":28,"Legendary":60}

static func default_market() -> Dictionary:
	return {"coins":0,"sold_by_day":{},"history":[],"sequence":0}

static func stock() -> Array:
	return [
		{"key":"sunlight","name":"Bottled sunlight","description":"Adds 30 gathered light for planting and care.","cost":12,"amount":30},
		{"key":"field_kits","name":"Field kit bundle","description":"Adds 3 field kits for collecting wild plants.","cost":18,"amount":3},
		{"key":"founding_seed","name":"Founder's seed","description":"A common founding seed from one of seven wild species. Its tendencies are revealed after purchase.","cost":80,"amount":1},
		{"key":"graft_material","name":"Grafting material","description":"Adds 1 material for joining two plants.","cost":30,"amount":1},
		{"key":"mutation_agent","name":"Mutation agent","description":"Adds 1 agent for exploring new genetic traits.","cost":35,"amount":1}
	]

static func day(day_override: int = -1) -> Dictionary:
	var ordinal: int = day_override if day_override>=0 else floori(Time.get_unix_time_from_system()/86400.0)
	var date: String = Time.get_datetime_string_from_unix_time(ordinal*86400).left(10)
	return {"day":ordinal,"key":str(ordinal),"label":date+" UTC","type":TYPES[posmod(ordinal*3+1,TYPES.size())],"pattern":PATTERNS[posmod(ordinal*5+2,PATTERNS.size())],"type_bonus":6,"pattern_bonus":4,"supply_step_percent":4,"supply_floor_percent":60}

static func fingerprint(value: Variant) -> String:
	return _canonical(value).sha256_text()

static func _canonical(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(a: Variant,b: Variant) -> bool: return str(a)<str(b))
		var parts: PackedStringArray = []
		for key: Variant in keys: parts.append(JSON.stringify(str(key))+":"+_canonical(value[key]))
		return "{"+",".join(parts)+"}"
	if value is Array:
		var parts: PackedStringArray = []
		for entry: Variant in value: parts.append(_canonical(entry))
		return "["+",".join(parts)+"]"
	if value is int or value is float: return "#"+str(float(value))
	return JSON.stringify(value)

static func _allele(p: Dictionary,key: String,side: String = "dominant",fallback: Variant = "") -> Variant:
	return p.get("genes",{}).get(key,{}).get(side,fallback)

static func _quality(p: Dictionary) -> Dictionary:
	var pattern: String = str(_allele(p,"pattern","dominant",p.get("pattern","Solid")))
	var hidden: String = str(_allele(p,"pattern","recessive",pattern))
	var pattern_values: Dictionary = {"Solid":0,"Striped":2,"Spotted":2,"Gradient":4,"Starburst":8,"Bicolor Ring":8}
	var features: int = int(pattern_values.get(pattern,0))
	if hidden!=pattern and int(pattern_values.get(hidden,0))>=4: features+=2
	if str(_allele(p,"glow","dominant","None"))!="None": features+=6
	if str(_allele(p,"texture"))=="Translucent": features+=3
	if str(_allele(p,"texture"))=="Wet": features+=2
	if str(_allele(p,"size"))=="Large": features+=3
	if str(_allele(p,"size"))=="Giant": features+=6
	var varied: int = 0
	for pair: Variant in p.get("genes",{}).values():
		if pair is Dictionary and pair.get("dominant")==pair.get("recessive"): continue
		varied+=1
	features+=mini(3,varied/3)
	var composition: Dictionary = p.get("lineage_mix",{})
	var ancestries: int = 0
	for share: Variant in composition.values():
		if float(share)>=0.065: ancestries+=1
	var ancestry: int = mini(16,maxi(0,ancestries-1)*4)
	var vigor: float = 0.0
	for stat: Variant in p.get("stats",{}).values(): vigor+=float(stat)
	var stats_count: int = p.get("stats",{}).size()
	var vigor_bonus: int = clampi(floori(vigor/maxi(1,stats_count)/10.0)-3,0,8) if stats_count>0 else 0
	var details: Array[String] = ["Pattern: %s." % pattern]
	if hidden!=pattern: details.append("Hidden pattern: %s." % hidden)
	if not p.get("genes",{}).is_empty(): details.append("Surface: %s. Glow: %s. Size: %s." % [str(_allele(p,"texture","dominant","Matte")),str(_allele(p,"glow","dominant","None")),str(_allele(p,"size","dominant","Standard"))])
	return {"rarity":int(RARITY_VALUE.get(str(p.get("rarity","Common")),0)),"features":features,"ancestry":ancestry,"vigor":vigor_bonus,"generation":clampi(int(p.get("generation",1))-1,0,3),"type":str(p.get("type","Leaf")),"pattern":pattern,"lineage_mix":composition,"details":details}

static func _seed_quality(seed_data: Dictionary) -> Dictionary:
	var p: Dictionary = seed_data.get("genome",seed_data)
	return _quality(p)

static func _add(rows: Array,label: String,amount: int) -> void:
	if amount!=0: rows.append({"label":label,"amount":amount})

static func price(kind: String,item: Dictionary,today: Dictionary,sold_count: int) -> Dictionary:
	var rows: Array = []
	var quality: Dictionary
	var is_withered: bool = false
	var notes: Array = []
	match kind:
		"plant":
			quality=_quality(item)
			_add(rows,"Plant base value",20)
			_add(rows,"Rarity",int(quality.rarity))
			_add(rows,"Genetic traits",int(quality.features))
			_add(rows,"Mixed ancestry",int(quality.ancestry))
			_add(rows,"Vigor",int(quality.vigor))
			_add(rows,"Breeding generation",int(quality.generation))
			var measured: Dictionary = Care.measurements(item)
			_add(rows,"Natural mature height",clampi(floori(float(measured.natural_height_cm)/10.0),0,12))
			_add(rows,"Natural mature weight",clampi(floori(float(measured.natural_weight_g)/100.0),0,10))
			var care_bonus: int = clampi(roundi(float(measured.height_bonus)*2.0+float(measured.weight_bonus)*2.0),0,3)
			_add(rows,"Care-grown size (capped)",care_bonus)
			var limit: float = float(Care.life_limits(item).life_limit)
			is_withered=bool(item.get("withered",false)) or float(item.get("life_age",0.0))>=limit
		"seed":
			quality=_seed_quality(item)
			_add(rows,"Seed base value",4)
			_add(rows,"Rarity",ceili(int(quality.rarity)*0.35))
			_add(rows,"Genetic traits",ceili(int(quality.features)*0.40))
			_add(rows,"Mixed ancestry",ceili(int(quality.ancestry)*0.50))
			_add(rows,"Vigor",ceili(int(quality.vigor)*0.5))
			_add(rows,"Breeding generation",int(quality.generation))
			_add(rows,"Recorded full genome",2 if item.has("genome") else 0)
			if not item.has("genome"): notes.append("This founding seed records tendencies; its full plant genome develops when planted.")
		"fruit":
			var seeds: Array = item.get("seeds",[])
			quality={"rarity":0,"features":0,"ancestry":0,"vigor":0,"generation":0,"type":"Leaf","pattern":"Solid","lineage_mix":item.get("lineage_mix",{})}
			var best: int = -1
			for seed_data: Dictionary in seeds:
				var candidate: Dictionary = _seed_quality(seed_data)
				var score: int = int(candidate.rarity)+int(candidate.features)+int(candidate.ancestry)+int(candidate.vigor)
				if score>best: quality=candidate; best=score
			_add(rows,"Fruit base value",8)
			_add(rows,"Hybrid fruit",4 if item.get("kind","")=="hybrid" else 0)
			_add(rows,"Seeds inside",seeds.size()*2)
			_add(rows,"Embryo rarity",ceili(int(quality.rarity)*0.35))
			_add(rows,"Embryo genetic traits",ceili(int(quality.features)*0.40))
			_add(rows,"Mixed ancestry",ceili(int(quality.ancestry)*0.50))
			_add(rows,"Embryo vigor",ceili(int(quality.vigor)*0.5))
			_add(rows,"Breeding generation",int(quality.generation))
			notes.append("Fruit premiums use the highest-quality seed inside.")
			# A fruit is worth less than the sum of its seeds plus its base value.
			# Opening it retains the same genomes rather than rolling new quality.
		_:
			return {"price":0,"breakdown":[],"factors":{},"notes":[]}
	var subtotal: int = 0
	for row: Dictionary in rows: subtotal+=int(row.amount)
	if kind=="plant":
		if is_withered: _add(rows,"Withered compost value",mini(3,maxi(1,subtotal/12))-subtotal)
		elif not bool(item.get("mature",false)): _add(rows,"Still a seedling",-floori(subtotal*0.30))
		else:
			var limits: Dictionary = Care.life_limits(item)
			var life_fraction: float = float(item.get("life_age",0.0))/float(limits.life_limit)
			if life_fraction>=0.95: _add(rows,"Near the end of its life",-floori(subtotal*0.35))
			elif float(item.get("life_age",0.0))>=float(limits.aging_at): _add(rows,"Aging plant",-floori(subtotal*0.15))
	if not is_withered:
		var matching_type: bool = str(quality.type)==str(today.type) or float(quality.get("lineage_mix",{}).get(today.type,0.0))>=0.25
		_add(rows,"Today's plant type demand",int(today.type_bonus) if matching_type else 0)
		_add(rows,"Today's pattern demand",int(today.pattern_bonus) if str(quality.pattern)==str(today.pattern) else 0)
	var before_supply: int = 0
	for row: Dictionary in rows: before_supply+=int(row.amount)
	var reduction: float = mini(40,maxi(0,sold_count)*4)/100.0
	_add(rows,"Today's supply",-floori(before_supply*reduction))
	var total: int = 0
	for row: Dictionary in rows: total+=int(row.amount)
	if total<1: _add(rows,"Minimum offer",1-total); total=1
	for detail: String in quality.get("details",[]): notes.append(detail)
	return {"price":total,"breakdown":rows,"factors":{"type":quality.type,"pattern":quality.pattern,"sold_today":sold_count,"supply_percent":100-roundi(reduction*100),"compost":is_withered},"notes":notes}

static func valid_market(value: Variant) -> bool:
	if not value is Dictionary: return false
	if not _whole(value.get("coins")) or not _whole(value.get("sequence")): return false
	if not value.get("sold_by_day") is Dictionary or not value.get("history") is Array: return false
	if value.history.size()>60: return false
	for day_key: Variant in value.sold_by_day:
		if not day_key is String or not day_key.is_valid_int() or not value.sold_by_day[day_key] is Dictionary: return false
		for kind: Variant in value.sold_by_day[day_key]:
			if not kind in ["plant","fruit","seed"] or not _whole(value.sold_by_day[day_key][kind]): return false
	for entry: Variant in value.history:
		if not entry is Dictionary: return false
		if not entry.get("action") in ["sell","buy"] or not entry.get("name") is String: return false
		for field: String in ["sequence","at","price","coins"]:
			if not _whole(entry.get(field)): return false
		if not entry.get("kind") is String or not entry.get("key") is String: return false
	return true

static func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=0 and float(value)==floorf(float(value)) and float(value)<=9007199254740991.0
