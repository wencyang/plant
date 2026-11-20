extends RefCounted
class_name GardenState
const Care = preload("res://scripts/plant_care.gd")
const Market = preload("res://scripts/market_rules.gd")

## All organisms, including retired donors and every ancestor, remain in this archive.
## Visuals are derived from diploid genes and seed; no baked appearance is saved.
const SAVE_PATH := "user://conservatory_v1.json"
const SAVE_VERSION := 1
const POLLINATION_COST: int = 10
const FRUIT_GROW_SECONDS: int = 18
const NATURAL_FRUIT_SECONDS: int = 45
const GROW_SECONDS: int = Care.GROW_SECONDS
const AGING_SECONDS: int = Care.AGING_SECONDS
const WITHER_SECONDS: int = Care.WITHER_SECONDS
const TYPES := ["Leaf", "Bloom", "Vine", "Root", "Spore", "Toxin", "Parasite", "Carnivorous"]
const RARITIES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const PATTERNS := ["Solid", "Striped", "Spotted", "Gradient", "Starburst", "Bicolor Ring"]
const SHAPES := ["Round", "Pointed", "Frilled", "Split"]
const FORMS := ["Upright", "Trailing", "Rosette", "Climbing"]
const TEXTURES := ["Matte", "Waxy", "Translucent", "Fibrous", "Wet"]
const COLORS := ["829d80", "d7a06d", "9dbcb2", "aa829b", "b6c58f", "7fabb0", "c1a4a0", "d2c7a5"]
const SPECIES := [
	{"name": "Veilfern", "type": "Leaf", "description": "Translucent fronds gather the pale light that settles beneath the canopy.", "skill": "Canopy Shade", "color": "829d80", "accent": "c4d2a1"},
	{"name": "Lantern Bloom", "type": "Bloom", "description": "A waxy calyx stores light in its warm, breathing heart.", "skill": "Bloom Burst", "color": "d7a06d", "accent": "e2c997"},
	{"name": "Threadvine", "type": "Vine", "description": "Searching filaments read the soil before committing their roots.", "skill": "Entangle", "color": "9dbcb2", "accent": "cfb0b5"},
	{"name": "Anchoroot", "type": "Root", "description": "Water and vitality move through the knots of its underground crown.", "skill": "Root Network", "color": "9c9471", "accent": "d5ba8e"},
	{"name": "Ghostcap", "type": "Spore", "description": "Papery sacs release a patient cloud of pearl-white spores.", "skill": "Spore Cloud", "color": "b5beb5", "accent": "add7cd"},
	{"name": "Gall Orchid", "type": "Toxin", "description": "Bruised petals advertise a bitter seep beneath the damp soil.", "skill": "Toxin Seep", "color": "aa829b", "accent": "b6c58f"},
	{"name": "Pale Strangler", "type": "Parasite", "description": "Ivory tendrils borrow their host's pigment along with its vitality.", "skill": "Parasitic Tendril", "color": "c1b9a0", "accent": "b6c58f"}
]
const STAT_NAMES := ["vitality", "growth", "toxin", "root", "bloom", "shade"]
const DISPLAY_THRESHOLDS := [100, 180, 260, 340, 420, 500]
const WORLD_WIDTH: int = 160
const WORLD_HEIGHT: int = 128
const WILD_BIOMES := {
	"Mosswood": [0, 1, 2], "Sporefen": [3, 4, 6],
	"Amber Hollow": [1, 5, 3], "Sunken Glade": [6, 2, 4],
	"Glassfall Coast": [2, 3, 0, 1], "Moonfen": [4, 6, 5],
	"Ember Ridge": [5, 1, 3], "Ancient Grove": [3, 2, 6, 4]
}
const WILD_CATCH_CHANCES := {"Common": 0.90, "Uncommon": 0.80, "Rare": 0.70, "Epic": 0.65, "Legendary": 0.65}

var save_path: String = SAVE_PATH
var plants: Dictionary = {}
var bed: Array = []
var display_bed: Array = []
var resources: Dictionary = {"sunlight": 180, "agents": 3, "grafts": 3}
var market: Dictionary = Market.default_market()
var seed_bank: Array = []
var fruit_inventory: Array = []
var fruit_crops: Dictionary = {}
var pollinations: Dictionary = {}
var reproduction_counter: int = 0
var _ready_reproduction: Dictionary = {}
var wins: int = 0
var battles: int = 0
var discovered: Array = []
var claimed: Array = []
var collection_claimed: Array = []
var collection_seen: Dictionary = {}
var plant_order: Array = []
var field_kits: int = 12
var expedition: Dictionary = {}
var last_daily: int = 0
var last_seed_collection: int = 0
var id_counter: int = 0
var random: RandomNumberGenerator = RandomNumberGenerator.new()

func _init(storage_path: String = SAVE_PATH) -> void:
	save_path = storage_path
	random.randomize()

func new_game() -> void:
	plants.clear()
	plant_order.clear()
	discovered.clear()
	claimed.clear()
	collection_claimed.clear()
	collection_seen.clear()
	seed_bank.clear()
	fruit_inventory.clear()
	fruit_crops.clear()
	pollinations.clear()
	_ready_reproduction.clear()
	reproduction_counter = 0
	resources = {"sunlight": 180, "agents": 3, "grafts": 3}
	market = Market.default_market()
	field_kits = 12
	expedition = _default_expedition()
	bed = ["", "", "", "", "", "", "", "", ""]
	display_bed = ["", "", "", "", "", ""]
	wins = 0
	battles = 0
	id_counter = 0
	last_daily = 0
	last_seed_collection = int(Time.get_unix_time_from_system())
	var names: Array = ["Stillwater", "Emberglass", "Silver Thread", "Moss Cathedral", "Honey Veil"]
	for i in range(5):
		var p: Dictionary = _create_base(i % 3, 71351 + i * 10427)
		p["name"] = names[i]
		if i == 3:
			p.genes.pattern.dominant = "Spotted"
		if i == 4:
			p.genes.pattern.dominant = "Striped"
		_add_plant(p)
		if i < 3:
			bed[6 + i] = p.id
		if i < 4:
			display_bed[i] = p.id
	for species_index in [3, 4, 5]:
		seed_bank.append(_make_seed(species_index, "Common"))
	save_game()

func get_plant(id: String) -> Dictionary:
	return plants.get(id, {})

func owns_plant(id: String) -> bool:
	return plants.has(id) and plant_order.has(id) and not bool(plants[id].get("sold",false))

func market_wallet() -> int:
	return int(market.coins)

func market_day(day_override: int = -1) -> Dictionary:
	return Market.day(day_override)

func market_stock() -> Array:
	return Market.stock()

func market_history() -> Array:
	return market.history.duplicate(true)

func market_ref(kind: String,index_or_id: Variant) -> Variant:
	if kind in ["plant","fruit"]: return str(index_or_id)
	if kind!="seed" or not (index_or_id is int or index_or_id is float): return {}
	var index: int = int(index_or_id)
	if index<0 or index>=seed_bank.size(): return {}
	var fingerprint: String = Market.fingerprint(seed_bank[index])
	var occurrence: int = 0
	for earlier in range(index):
		if Market.fingerprint(seed_bank[earlier])==fingerprint: occurrence+=1
	return {"fingerprint":fingerprint,"occurrence":occurrence}

func _market_resolve(kind: String,reference: Variant) -> Dictionary:
	if kind=="plant" and reference is String and owns_plant(reference): return {"item":plants[reference],"index":plant_order.find(reference)}
	if kind=="fruit" and reference is String:
		for index in range(fruit_inventory.size()):
			if str(fruit_inventory[index].id)==reference: return {"item":fruit_inventory[index],"index":index}
	if kind=="seed" and reference is Dictionary and reference.get("fingerprint") is String and Market._whole(reference.get("occurrence")):
		var occurrence: int = 0
		for index in range(seed_bank.size()):
			if Market.fingerprint(seed_bank[index])!=reference.fingerprint: continue
			if occurrence==int(reference.occurrence): return {"item":seed_bank[index],"index":index}
			occurrence+=1
	return {}

func market_inventory(kind: String) -> Array:
	var rows: Array = []
	var occurrences: Dictionary = {}
	var items: Array = []
	if kind=="plant":
		for id: String in plant_order:
			if owns_plant(id): items.append(plants[id])
	elif kind=="fruit": items=fruit_inventory
	elif kind=="seed": items=seed_bank
	for index in range(items.size()):
		var item: Dictionary = items[index]
		var reference: Variant = str(item.get("id",""))
		if kind=="seed":
			var fingerprint: String = Market.fingerprint(item)
			reference={"fingerprint":fingerprint,"occurrence":int(occurrences.get(fingerprint,0))}
			occurrences[fingerprint]=int(reference.occurrence)+1
		var quote: Dictionary = _market_quote_resolved(kind,reference,item)
		var row: Dictionary = {"reference":reference,"name":quote.name,"quote":quote}
		row[kind]=item.duplicate(true)
		rows.append(row)
	return rows

func market_quote(kind: String,reference: Variant) -> Dictionary:
	var resolved: Dictionary = _market_resolve(kind,reference)
	if resolved.is_empty():
		return {"ok":false,"eligible":false,"key":"","name":"Unavailable item","price":0,"breakdown":[],"reason":"This item is no longer in your inventory. Choose it again.","quote_id":"","factors":{},"notes":[]}
	return _market_quote_resolved(kind,reference,resolved.item)

func _market_quote_resolved(kind: String,reference: Variant,item: Dictionary) -> Dictionary:
	var today: Dictionary = market_day()
	var count: int = int(market.sold_by_day.get(today.key,{}).get(kind,0))
	var quote: Dictionary = Market.price(kind,item,today,count)
	quote["ok"]=true
	quote["eligible"]=true
	quote["name"]=str(item.get("name","Hybrid fruit" if item.get("kind","")=="hybrid" else "Natural fruit"))
	quote["key"]=str(item.get("id","")) if kind!="seed" else str(reference.fingerprint)
	quote["reason"]="Ready to sell."
	if kind=="plant":
		if bool(item.get("favorite",false)): quote.eligible=false; quote.reason="Favorites are protected. Unlock this plant before selling it."
		elif pollinations.has(item.id): quote.eligible=false; quote.reason="Harvest this plant's hybrid fruit before selling it."
		elif bool(fruit_status(str(item.id)).natural_ready): quote.eligible=false; quote.reason="Harvest this plant's ripe natural fruit before selling it."
		elif fruit_crops.has(item.id): quote.notes.append("Unripe natural fruit travels with the sold plant.")
		quote.notes.append("The plant leaves your garden. Its DNA and family tree remain in the archive.")
	elif kind=="fruit": quote.notes.append("Selling this fruit also sells every seed inside it.")
	# Only price-relevant condition changes invalidate a review. Active lifetime
	# ticks do not invalidate it every frame while the player reads the offer.
	var identity: Variant = item if kind=="fruit" else reference
	if kind=="plant":
		identity={"id":item.id,"name":item.name,"genes":item.genes,"stats":item.stats,"rarity":item.rarity,"care":item.get("care",{}).duplicate(true),"mature":item.mature,"lineage_mix":item.get("lineage_mix",{})}
		identity.care.erase("cooldowns")
		identity.care.erase("last_cared_at")
	quote["quote_id"]=Market.fingerprint({"kind":kind,"identity":identity,"reference":reference,"day":today.day,"sold":count,"price":quote.price,"breakdown":quote.breakdown,"eligible":quote.eligible,"reason":quote.reason,"notes":quote.notes})
	return quote

func _market_record(action: String,kind: String,key: String,item_name: String,price: int) -> void:
	market.sequence=int(market.sequence)+1
	market.history.push_front({"sequence":int(market.sequence),"at":int(Time.get_unix_time_from_system()),"action":action,"kind":kind,"key":key,"name":item_name,"price":price,"coins":int(market.coins)})
	if market.history.size()>60: market.history.resize(60)
	var oldest: int = int(market_day().day)-14
	for day_key: Variant in market.sold_by_day.keys():
		if int(day_key)<oldest: market.sold_by_day.erase(day_key)

func market_sell(kind: String,reference: Variant,expected_quote_id: String = "") -> Dictionary:
	var resolved: Dictionary = _market_resolve(kind,reference)
	if resolved.is_empty(): return _failure("This item is no longer in your inventory. Choose it again.")
	var quote: Dictionary = _market_quote_resolved(kind,reference,resolved.item)
	if not bool(quote.eligible): return _failure(str(quote.reason))
	if not expected_quote_id.is_empty() and expected_quote_id!=str(quote.quote_id): return _failure("The offer changed. Review the updated price before selling.")
	if kind=="plant":
		var id: String = str(reference)
		plants[id]["sold"]=true
		plants[id]["retired"]=true
		plants[id]["sold_at"]=int(Time.get_unix_time_from_system())
		plant_order.erase(id)
		for index in range(bed.size()):
			if str(bed[index])==id: bed[index]=""
		for index in range(display_bed.size()):
			if str(display_bed[index])==id: display_bed[index]=""
		fruit_crops.erase(id)
	elif kind=="fruit": fruit_inventory.remove_at(int(resolved.index))
	elif kind=="seed": seed_bank.remove_at(int(resolved.index))
	var day_key: String = str(market_day().key)
	if not market.sold_by_day.has(day_key): market.sold_by_day[day_key]={}
	market.sold_by_day[day_key][kind]=int(market.sold_by_day[day_key].get(kind,0))+1
	market.coins=int(market.coins)+int(quote.price)
	_market_record("sell",kind,str(quote.key),str(quote.name),int(quote.price))
	save_game()
	return {"ok":true,"message":"Sold %s for %d coins." % [quote.name,int(quote.price)],"price":int(quote.price),"coins":int(market.coins),"quote":quote}

func market_buy(stock_key: String) -> Dictionary:
	var offer: Dictionary = {}
	for row: Dictionary in market_stock():
		if str(row.key)==stock_key: offer=row; break
	if offer.is_empty(): return _failure("Choose an item from the market shop.")
	var cost: int = int(offer.cost)
	if int(market.coins)<cost: return _failure("You need %d coins for this purchase." % cost)
	# Affordability is checked before all RNG, ID and inventory changes.
	var purchased: Dictionary = {}
	match stock_key:
		"sunlight": resources.sunlight+=int(offer.amount)
		"field_kits": field_kits+=int(offer.amount)
		"graft_material": resources.grafts+=int(offer.amount)
		"mutation_agent": resources.agents+=int(offer.amount)
		"founding_seed":
			purchased=_make_seed(random.randi_range(0,SPECIES.size()-1),"Common")
			seed_bank.append(purchased)
	market.coins=int(market.coins)-cost
	_market_record("buy","stock",stock_key,str(offer.name),cost)
	save_game()
	return {"ok":true,"message":"Bought %s for %d coins." % [offer.name,cost],"cost":cost,"coins":int(market.coins),"seed":purchased}

func care_tools() -> Array:
	return Care.tools()

func plant_measurements(id: String) -> Dictionary:
	return Care.measurements(get_plant(id))

func care_status(id: String,tool_key: String) -> Dictionary:
	var definition: Dictionary = Care.tool(tool_key)
	var result: Dictionary = {"allowed":false,"reason":"Choose a care tool.","cost":int(definition.get("cost",0)),"effect":str(definition.get("effect","")),"cooldown_remaining":0,"uses":0,"max_uses":int(definition.get("max_uses",0)),"remaining_uses":0,"key":tool_key}
	if definition.is_empty(): return result
	var plant: Dictionary = get_plant(id)
	if plant.is_empty(): result.reason="Choose a plant to care for."; return result
	if not owns_plant(id): result.reason="This plant has been sold. Its family record remains in the archive."; return result
	var care: Dictionary = plant.get("care",Care.default_care())
	var count: int = int(care.get("uses",{}).get(tool_key,0))
	var now: int = int(Time.get_unix_time_from_system())
	result.uses=count
	result.remaining_uses=maxi(0,int(definition.max_uses)-count)
	result.cooldown_remaining=maxi(0,ceili(float(care.get("cooldowns",{}).get(tool_key,0))-now))
	if bool(life_profile(id).withered): result.reason="Withered plants cannot receive care. Grow their seeds to continue the lineage."; return result
	if count>=int(definition.max_uses): result.reason="This plant has received the maximum number of uses for this tool."; return result
	if int(result.cooldown_remaining)>0: result.reason="This tool will be ready for this plant in %d seconds." % int(result.cooldown_remaining); return result
	if tool_key=="sunlamp" and (bool(plant.get("mature",false)) or int(plant.get("ready_at",0))<=now): result.reason="The sun lamp is for a seedling that is still growing."; return result
	if tool_key=="ripening":
		var natural_growing: bool = fruit_crops.has(id) and int(fruit_crops[id].natural_ready_at)>now
		var cross_growing: bool = pollinations.has(id) and int(pollinations[id].ready_at)>now
		if not natural_growing and not cross_growing: result.reason="There is no developing fruit to ripen on this plant."; return result
	if int(resources.sunlight)<int(definition.cost): result.reason="This tool needs %d gathered light." % int(definition.cost); return result
	result.allowed=true
	result.reason="Ready to use."
	return result

func apply_care(id: String,tool_key: String) -> Dictionary:
	var status: Dictionary = care_status(id,tool_key)
	if not bool(status.allowed): return {"ok":false,"message":status.reason,"key":tool_key,"status":status}
	var plant: Dictionary = get_plant(id)
	Care.initialize(plant)
	var care: Dictionary = plant.care
	var definition: Dictionary = Care.tool(tool_key)
	var before: Dictionary = plant_measurements(id)
	var before_life: Dictionary = life_profile(id)
	var before_fruit: int = int(fruit_status(id).ready_count)
	var now: int = int(Time.get_unix_time_from_system())
	resources.sunlight-=int(definition.cost)
	care.uses[tool_key]=int(care.uses.get(tool_key,0))+1
	if int(definition.cooldown)>0: care.cooldowns[tool_key]=now+int(definition.cooldown)
	care["last_tool"]=tool_key
	care["last_cared_at"]=now
	var message: String = ""
	match tool_key:
		"water":
			care.life_bonus_seconds=int(care.life_bonus_seconds)+60
			message="%s looks refreshed. Its lifespan grew by 1 minute." % plant.name
		"longevity":
			care.life_bonus_seconds=int(care.life_bonus_seconds)+600
			message="%s can keep growing for 10 more minutes." % plant.name
		"growth": care.height_bonus=minf(0.60,float(care.height_bonus)+0.15)
		"compost": care.weight_bonus=minf(0.80,float(care.weight_bonus)+0.20)
		"sunlamp":
			plant.mature=true
			plant.ready_at=now
			_ensure_natural_crop(id,now)
			message="%s unfurled under the lamp and is ready to breed." % plant.name
		"ripening":
			if fruit_crops.has(id) and int(fruit_crops[id].natural_ready_at)>now: fruit_crops[id].natural_ready_at=now
			if pollinations.has(id) and int(pollinations[id].ready_at)>now: pollinations[id].ready_at=now
	var after: Dictionary = plant_measurements(id)
	var after_life: Dictionary = life_profile(id)
	var newly_ripe: int = maxi(0,int(fruit_status(id).ready_count)-before_fruit)
	if tool_key=="growth": message="%s stands taller: %.1f → %.1f cm at maturity." % [plant.name,before.mature_height_cm,after.mature_height_cm]
	elif tool_key=="compost": message="%s grew sturdier: %.1f → %.1f g at maturity." % [plant.name,before.mature_weight_g,after.mature_weight_g]
	elif tool_key=="ripening": message="%s has %d newly ripened fruit." % [plant.name,newly_ripe]
	save_game()
	return {"ok":true,"message":message,"key":tool_key,"plant":plant,"measurements":after,"life":after_life,
		"effects":{"life_added_seconds":int(after_life.life_limit)-int(before_life.life_limit),"height_added_cm":float(after.mature_height_cm)-float(before.mature_height_cm),"weight_added_g":float(after.mature_weight_g)-float(before.mature_weight_g),"fruit_ready":newly_ripe,"matured":tool_key=="sunlamp"}}

func _new_id() -> String:
	id_counter += 1
	return "p%06d" % id_counter

func _create_base(species_index: int, gene_seed: int = 0, organism_id: String = "") -> Dictionary:
	var organism_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	organism_rng.seed = gene_seed if gene_seed != 0 else random.randi()
	var s: Dictionary = SPECIES[clampi(species_index, 0, SPECIES.size() - 1)]
	var patterns: Array = ["Solid", "Striped", "Spotted", "Gradient"]
	var visual: Dictionary = {
		"color": s.color, "accent": s.accent,
		"pattern": patterns[organism_rng.randi_range(0, patterns.size() - 1)],
		"petals": organism_rng.randi_range(4, 8),
		"shape": SHAPES[organism_rng.randi_range(0, SHAPES.size() - 1)],
		"form": "Trailing" if s.type == "Vine" else ("Rosette" if s.type == "Root" else "Upright"),
		"texture": TEXTURES[organism_rng.randi_range(0, TEXTURES.size() - 1)],
		"glow": "None", "size": "Standard"
	}
	var genes: Dictionary = {}
	for slot: String in visual:
		genes[slot] = {"dominant": visual[slot], "recessive": visual[slot]}
	genes.pattern.recessive = PATTERNS[organism_rng.randi_range(0, PATTERNS.size() - 1)]
	var stats: Dictionary = {
		"vitality": organism_rng.randi_range(110, 145),
		"growth": organism_rng.randi_range(14, 21),
		"toxin": organism_rng.randi_range(9, 16),
		"root": organism_rng.randi_range(14, 22),
		"bloom": organism_rng.randi_range(12, 20),
		"shade": organism_rng.randi_range(9, 17)
	}
	match s.type:
		"Leaf": stats.shade += 8
		"Bloom": stats.bloom += 11
		"Vine": stats.root += 9
		"Root": stats.vitality += 45; stats.root += 12
		"Spore": stats.toxin += 11
		"Toxin": stats.toxin += 17
		"Parasite": stats.root += 12
	var now: int = int(Time.get_unix_time_from_system())
	var p: Dictionary = {
		"id": _new_id() if organism_id.is_empty() else organism_id, "name": s.name, "species": s.name,
		"type": s.type, "secondary_type": "", "generation": 1,
		"parents": [], "seed": int(organism_rng.seed), "rarity": "Common",
		"genes": genes, "stats": stats, "skills": [s.skill],
		"skill_genes": {"dominant": s.skill, "recessive": s.skill},
		"graft_history": [], "mutation_history": [], "favorite": false,
		"mature": true, "ready_at": now, "born_at": now,
		"donor_ready_at": 0, "deformed": false, "retired": false
	}
	p["life_age"] = 0.0
	p["withered"] = false
	Care.initialize(p)
	p["gene_sources"] = {}
	for slot: String in genes:
		p.gene_sources[slot] = {"allele_a":{"parent_id":"","parent_name":s.name,"allele":"founder","value":genes[slot].dominant},
			"allele_b":{"parent_id":"","parent_name":s.name,"allele":"founder","value":genes[slot].recessive},
			"expressed_origin":"founder","expressed":genes[slot].dominant,"carried":genes[slot].recessive}
	return p

func _add_plant(p: Dictionary) -> void:
	Care.initialize(p)
	p["lineage_mix"] = lineage_composition(p)
	p["hybrid"] = p.lineage_mix.size() > 1
	plants[p.id] = p
	plant_order.append(p.id)
	if not discovered.has(p.species):
		discovered.append(p.species)
	_record_collection(p)
	_ensure_natural_crop(str(p.id))

func lineage_composition(p: Dictionary) -> Dictionary:
	return _lineage_composition(p,{}, {})

func _lineage_composition(p: Dictionary, memo: Dictionary, visiting: Dictionary) -> Dictionary:
	if p.is_empty(): return {}
	var id: String = str(p.get("id",""))
	if memo.has(id) and not id.is_empty(): return memo[id].duplicate()
	var result: Dictionary = {}
	var stored: Variant = p.get("lineage_mix",{})
	if stored is Dictionary:
		for key: Variant in stored:
			if key is String and key in TYPES and (stored[key] is int or stored[key] is float) and is_finite(float(stored[key])) and float(stored[key]) > 0:
				result[key] = float(stored[key])
	if result.is_empty() and not visiting.has(id):
		visiting[id] = true
		var parent_mixes: Array = []
		for parent_id: Variant in p.get("parents",[]):
			if parent_id is String and plants.has(parent_id) and not visiting.has(parent_id):
				parent_mixes.append(_lineage_composition(plants[parent_id],memo,visiting))
		for composition: Dictionary in parent_mixes:
			for key: String in composition:
				result[key] = float(result.get(key,0.0))+float(composition[key])/maxi(1,parent_mixes.size())
		visiting.erase(id)
	if result.is_empty(): result[str(p.get("type","Leaf"))] = 1.0
	var total: float = 0.0
	for value: float in result.values(): total += value
	for key: String in result: result[key] = float(result[key])/maxf(0.000001,total)
	if not id.is_empty(): memo[id] = result.duplicate()
	return result

func _combined_lineage(a: Dictionary,b: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for parent: Dictionary in [a,b]:
		var composition: Dictionary = lineage_composition(parent)
		for key: String in composition: result[key] = float(result.get(key,0.0))+float(composition[key])*0.5
	return result

func crossbreed(id_a: String, id_b: String) -> Dictionary:
	if not owns_plant(id_a) or not owns_plant(id_b): return _failure("Choose two plants that belong to your garden.")
	var a: Dictionary = get_plant(id_a)
	var b: Dictionary = get_plant(id_b)
	if a.is_empty() or b.is_empty():
		return _failure("Choose two mature parents.")
	if id_a == id_b:
		return _failure("Choose two different plants to crossbreed.")
	if not a.mature or not b.mature:
		return _failure("Both parents must finish growing first.")
	if bool(a.get("withered",false)) or bool(b.get("withered",false)): return _failure("Withered plants remain in the lineage archive. Grow their seeds to continue breeding.")
	if int(resources.sunlight) < 30:
		return _failure("Crossbreeding needs 30 gathered light. Battles and display rewards replenish it.")
	var p: Dictionary = _make_offspring(a, b, random.randi())
	resources.sunlight -= 30
	_add_plant(p)
	save_game()
	return {"ok": true, "message": "%s is growing. Each gene came from one of its parents; carried recessives can reappear." % p.name, "plant": p}

func _make_offspring(a: Dictionary, b: Dictionary, child_seed: int, child_id: String = "") -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = child_seed
	var dominant: Dictionary = a if rng.randf() < 0.5 else b
	var p: Dictionary = _create_base(_species_index(dominant.species), child_seed, child_id)
	p.species = dominant.species
	p.type = dominant.type
	p.secondary_type = ""
	if a.type != b.type and rng.randf() < 0.45:
		p.secondary_type = b.type if p.type == a.type else a.type
	p.generation = maxi(int(a.generation), int(b.generation)) + 1
	p.parents = [a.id, b.id]
	p["lineage_mix"] = _combined_lineage(a,b)
	p["hybrid"] = p.lineage_mix.size() > 1
	p["lineage_name"] = " × ".join(p.lineage_mix.keys())
	p.name = _offspring_name(rng)
	for slot: String in a.genes:
		var gene_a: Dictionary = a.genes[slot]
		var gene_b: Dictionary = b.genes.get(slot, gene_a)
		var a_key: String = "dominant" if rng.randf()<0.5 else "recessive"
		var b_key: String = "dominant" if rng.randf()<0.5 else "recessive"
		var allele_a: Variant = gene_a[a_key]
		var allele_b: Variant = gene_b[b_key]
		var expresses_a: bool = rng.randf()<0.5
		var expressed: Variant = allele_a if expresses_a else allele_b
		var carried: Variant = allele_b if expresses_a else allele_a
		var expressed_origin: String = "a" if expresses_a else "b"
		if slot in ["color", "accent"] and rng.randf() < 0.15:
			expressed = Color(str(allele_a)).lerp(Color(str(allele_b)), 0.5).to_html(false)
			expressed_origin = "blend"
		if slot == "pattern" and int(p.generation) >= 3 and allele_a != allele_b and rng.randf() < 0.08:
			expressed = "Starburst" if rng.randf() < 0.5 else "Bicolor Ring"
			expressed_origin = "combination"
		p.genes[slot] = {"dominant": expressed, "recessive": carried}
		p.gene_sources[slot] = {"allele_a":{"parent_id":a.id,"parent_name":a.name,"allele":a_key,"value":allele_a},
			"allele_b":{"parent_id":b.id,"parent_name":b.name,"allele":b_key,"value":allele_b},
			"expressed_origin":expressed_origin,"expressed":expressed,"carried":carried}
	p["stat_sources"] = {}
	for stat: String in STAT_NAMES:
		var average: float = (float(a.stats[stat]) + float(b.stats[stat])) * 0.5
		p.stats[stat] = maxi(1, int(round(average * rng.randf_range(0.9, 1.1))))
		p.stat_sources[stat] = {"parent_a":a.id,"parent_b":b.id,"value_a":a.stats[stat],"value_b":b.stats[stat],"average":average,"value":p.stats[stat]}
	var a_skills: Dictionary = a.get("skill_genes", {"dominant": a.skills[0], "recessive": a.skills[0]})
	var b_skills: Dictionary = b.get("skill_genes", {"dominant": b.skills[0], "recessive": b.skills[0]})
	var skill_a: String = str(a_skills.dominant if rng.randf() < 0.5 else a_skills.recessive)
	var skill_b: String = str(b_skills.dominant if rng.randf() < 0.5 else b_skills.recessive)
	p.skills = [skill_a if rng.randf() < 0.5 else skill_b]
	p.skill_genes = {"dominant": p.skills[0], "recessive": skill_b if p.skills[0] == skill_a else skill_a}
	if skill_a != skill_b and rng.randf() < 0.3:
		p.skills = [skill_a, skill_b]
	p["skill_sources"] = {"parent_a":a.id,"parent_b":b.id,"allele_a":skill_a,"allele_b":skill_b,"expressed":p.skills.duplicate()}
	# Graft inheritance is deliberately reduced; inherited joins stay in the pedigree.
	p["inherited_graft_records"] = []
	for parent: Dictionary in [a, b]:
		var graft_records: Array = parent.get("graft_history",[]).duplicate(true)
		graft_records.append_array(parent.get("inherited_graft_records",[]))
		for graft_record: Dictionary in graft_records:
			if rng.randf() < 0.2:
				if p.inherited_graft_records.size() < 2:
					var inherited: Dictionary = graft_record.duplicate(true)
					inherited["inherited_from"] = parent.id
					p.inherited_graft_records.append(inherited)
				if graft_record.get("trait", "") == "skill" and p.skills.size() < 3:
					var graft_skill: String = str(graft_record.get("value", ""))
					if not p.skills.has(graft_skill) and not graft_skill.is_empty():
						p.skills.append(graft_skill)
				elif graft_record.get("trait", "") == "feature":
					p["inherited_graft_color"] = graft_record.get("value", "c1a4a0")
	p.rarity = _calculate_rarity(p)
	p.mature = false
	p.ready_at = int(Time.get_unix_time_from_system()) + GROW_SECONDS
	return p

func _ensure_natural_crop(id: String, now: int = -1) -> bool:
	if not owns_plant(id) or not bool(plants[id].get("mature",false)) or bool(plants[id].get("withered",false)) or fruit_crops.has(id): return false
	if now < 0: now = int(Time.get_unix_time_from_system())
	fruit_crops[id] = {"natural_ready_at":now+NATURAL_FRUIT_SECONDS}
	return true

func life_profile(id: String) -> Dictionary:
	var plant: Dictionary = get_plant(id)
	var age: float = maxf(0.0,float(plant.get("life_age",0.0)))
	var limits: Dictionary = Care.life_limits(plant)
	var withered: bool = bool(plant.get("withered",false)) or age>=float(limits.life_limit)
	var stage: String = "withered" if withered else ("seedling" if not bool(plant.get("mature",false)) else ("aging" if age>=float(limits.aging_at) else "mature"))
	return {"stage":stage,"age":age,"remaining":maxi(0,ceili(float(limits.life_limit)-age)),"progress":clampf(age/float(limits.life_limit),0.0,1.0),"withered":withered,"aging_at":float(limits.aging_at),"life_limit":float(limits.life_limit),"life_bonus_seconds":float(limits.bonus_seconds)}

func advance_lifecycle(delta: float) -> bool:
	if not is_finite(delta) or delta<=0: return false
	var changed: bool = false
	var now: int = int(Time.get_unix_time_from_system())
	for id: String in plant_order:
		var plant: Dictionary = plants[id]
		if not bool(plant.get("mature",false)) or bool(plant.get("withered",false)): continue
		var previous_stage: String = str(life_profile(id).stage)
		var limit: float = float(Care.life_limits(plant).life_limit)
		plant["life_age"] = minf(limit,maxf(0,float(plant.get("life_age",0.0)))+delta)
		if float(plant.life_age)>=limit:
			plant["withered"] = true
			plant["retired"] = true
			for index in range(bed.size()):
				if str(bed[index])==id: bed[index] = ""
			for index in range(display_bed.size()):
				if str(display_bed[index])==id: display_bed[index] = ""
			# A final seed-bearing fruit is retained even when a plant reaches the
			# end of its life. Existing pollinated embryos remain untouched too.
			if not fruit_crops.has(id): fruit_crops[id] = {"natural_ready_at":now,"final":true}
			else:
				fruit_crops[id].natural_ready_at = mini(now,int(fruit_crops[id].natural_ready_at))
				fruit_crops[id]["final"] = true
		if previous_stage!=str(life_profile(id).stage): changed = true
	return changed

func tick_reproduction() -> bool:
	var now: int = int(Time.get_unix_time_from_system())
	var initialized: bool = false
	var ready: Dictionary = {}
	for id: String in plant_order:
		initialized = _ensure_natural_crop(id,now) or initialized
		if fruit_crops.has(id) and now >= int(fruit_crops[id].natural_ready_at):
			ready[id+"/natural/"+str(fruit_crops[id].natural_ready_at)] = true
		if pollinations.has(id) and now >= int(pollinations[id].ready_at): ready[str(pollinations[id].id)] = true
	var changed: bool = initialized or ready != _ready_reproduction
	_ready_reproduction = ready
	if initialized: save_game()
	return changed

func fruit_status(plant_id: String) -> Dictionary:
	var plant: Dictionary = get_plant(plant_id)
	var crop: Dictionary = fruit_crops.get(plant_id,{})
	var batch: Dictionary = pollinations.get(plant_id,{})
	var now: int = int(Time.get_unix_time_from_system())
	var natural_at: int = int(crop.get("natural_ready_at",0))
	var natural_ready: bool = not crop.is_empty() and now >= natural_at
	var cross_ready: bool = not batch.is_empty() and now >= int(batch.get("ready_at",0))
	return {"natural_ready":natural_ready,"natural_ready_at":natural_at,"pollination":batch.duplicate(true),
		"cross_ready":cross_ready,"ready_count":int(natural_ready)+int(cross_ready),"mature":bool(plant.get("mature",false))}

func fruit_overview() -> Dictionary:
	var result := {"ready":0,"growing":0,"fruits":fruit_inventory.size(),"seeds":seed_bank.size(),"next_ready_at":0}
	var now: int = int(Time.get_unix_time_from_system())
	for id: String in plant_order:
		var status: Dictionary = fruit_status(id)
		result.ready += int(status.ready_count)
		var times: Array = []
		if fruit_crops.has(id): times.append(int(status.natural_ready_at))
		if not status.pollination.is_empty(): times.append(int(status.pollination.ready_at))
		for at: int in times:
			if at > now:
				result.growing += 1
				if result.next_ready_at == 0 or at < int(result.next_ready_at): result.next_ready_at = at
	return result

func _next_fruit_id() -> String:
	reproduction_counter += 1
	return "fruit_%08d" % reproduction_counter

func _genome_seed(embryo: Dictionary,kind: String,parent_names: Array) -> Dictionary:
	var genome: Dictionary = embryo.duplicate(true)
	# The canonical archive already retains every ancestor. Nested pedigrees would
	# make a seed grow exponentially with each later-generation cross.
	genome.erase("pedigree")
	genome["mature"] = false
	genome["ready_at"] = 0
	var snapshot: Dictionary = {"id":str(genome.id),"kind":kind,"genome":genome,"species":genome.species,"type":genome.type,
		"name":genome.name+" seed","seed":genome.seed,"rarity":genome.rarity,
		"pattern":genome.genes.pattern.dominant,"parents":genome.parents.duplicate(),
		"parent_names":parent_names.duplicate(),"generation":genome.generation,
		"lineage_mix":genome.lineage_mix.duplicate(),"lineage_name":genome.get("lineage_name",genome.species)}
	# JSON is the persisted genome representation. Canonicalize at fertilization,
	# so numeric allele types do not change when a fruit/seed is later reloaded.
	return JSON.parse_string(JSON.stringify(snapshot))

func pollinate(id_a: String,id_b: String) -> Dictionary:
	if not owns_plant(id_a) or not owns_plant(id_b): return _failure("Choose two plants that belong to your garden.")
	var a: Dictionary = get_plant(id_a)
	var b: Dictionary = get_plant(id_b)
	if a.is_empty() or b.is_empty(): return _failure("Choose two mature parents.")
	if id_a == id_b: return _failure("Choose two different plants to crossbreed.")
	if not bool(a.mature) or not bool(b.mature): return _failure("Both parents must finish growing first.")
	if bool(a.get("withered",false)) or bool(b.get("withered",false)): return _failure("Withered plants remain in the lineage archive. Grow their seeds to continue breeding.")
	if pollinations.has(id_a):
		return _failure("Harvest this mother's hybrid fruit before starting another cross." if int(pollinations[id_a].ready_at) <= int(Time.get_unix_time_from_system()) else "This mother is already growing a hybrid fruit. Choose another mother or wait for harvest.")
	if int(resources.sunlight) < POLLINATION_COST: return _failure("Pollination needs 10 gathered light. Harvesting fruit replenishes it.")
	var id: String = _next_fruit_id()
	var embryos: Array = []
	for index in range(2):
		var embryo: Dictionary = _make_offspring(a,b,maxi(1,random.randi()),"%s_seed_%d" % [id,index+1])
		embryos.append(_genome_seed(embryo,"hybrid",[a.name,b.name]))
	var now: int = int(Time.get_unix_time_from_system())
	var batch: Dictionary = {"id":id,"kind":"hybrid","mother_id":id_a,"father_id":id_b,
		"parent_names":[a.name,b.name],"seeds":embryos,"started_at":now,"ready_at":now+FRUIT_GROW_SECONDS,
		"generation":maxi(int(a.generation),int(b.generation))+1,"lineage_mix":_combined_lineage(a,b)}
	batch = JSON.parse_string(JSON.stringify(batch))
	pollinations[id_a] = batch
	resources.sunlight -= POLLINATION_COST
	save_game()
	return {"ok":true,"fruit_id":id,"batch":batch.duplicate(true),"ready_at":batch.ready_at,
		"message":"Pollination recorded. A hybrid fruit will ripen in 18 seconds, holding two seeds. Both parents remain."}

func _harvest_fruit(plant_id: String,save_after: bool) -> Dictionary:
	if not owns_plant(plant_id): return _failure("Choose a plant in your garden to harvest.")
	var parent: Dictionary = plants[plant_id]
	var status: Dictionary = fruit_status(plant_id)
	var harvested: Array = []
	var light: int = 0
	var now: int = int(Time.get_unix_time_from_system())
	if status.cross_ready:
		var fruit: Dictionary = pollinations[plant_id].duplicate(true)
		fruit["harvested_at"] = now
		harvested.append(JSON.parse_string(JSON.stringify(fruit)))
		pollinations.erase(plant_id)
		light += 30
	if status.natural_ready:
		var id: String = _next_fruit_id()
		var embryo: Dictionary = _make_offspring(parent,parent,maxi(1,random.randi()),id+"_seed_1")
		embryo.parents = [parent.id]
		var seed_data: Dictionary = _genome_seed(embryo,"lineage",[parent.name])
		var fruit: Dictionary = {"id":id,"kind":"natural","mother_id":plant_id,"father_id":"","parent_names":[parent.name],
			"seeds":[seed_data],"harvested_at":now,"generation":embryo.generation,"lineage_mix":embryo.lineage_mix.duplicate()}
		harvested.append(JSON.parse_string(JSON.stringify(fruit)))
		if bool(parent.get("withered",false)): fruit_crops.erase(plant_id)
		else: fruit_crops[plant_id].natural_ready_at = now+NATURAL_FRUIT_SECONDS
		light += 10
	if harvested.is_empty(): return _failure("Fruit is still growing. Harvest it when it is ripe.")
	fruit_inventory.append_array(harvested)
	resources.sunlight += light
	if save_after: save_game()
	return {"ok":true,"fruits":harvested.duplicate(true),"sunlight":light,
		"message":"Harvested %d fruit. Open the fruit to collect its seeds. +%d gathered light." % [harvested.size(),light]}

func harvest_fruit(plant_id: String) -> Dictionary:
	return _harvest_fruit(plant_id,true)

func harvest_all_fruit() -> Dictionary:
	var harvested: Array = []
	var light: int = 0
	for id: String in plant_order:
		if int(fruit_status(id).ready_count) == 0: continue
		var result: Dictionary = _harvest_fruit(id,false)
		if result.ok:
			harvested.append_array(result.fruits)
			light += int(result.sunlight)
	if harvested.is_empty(): return _failure("Fruit is still growing. Harvest it when it is ripe.")
	save_game()
	return {"ok":true,"fruits":harvested,"sunlight":light,
		"message":"Harvested %d fruit. Open the fruit to collect its seeds. +%d gathered light." % [harvested.size(),light]}

func _extract_seeds(fruit_id: String,save_after: bool) -> Dictionary:
	for index in range(fruit_inventory.size()):
		var fruit: Dictionary = fruit_inventory[index]
		if str(fruit.id) != fruit_id: continue
		var seeds: Array = fruit.seeds.duplicate(true)
		seed_bank.append_array(seeds)
		fruit_inventory.remove_at(index)
		last_seed_collection = int(Time.get_unix_time_from_system())
		if save_after: save_game()
		return {"ok":true,"seeds":seeds,"message":"Collected %d seeds. Their full genomes and parentage are preserved for planting." % seeds.size()}
	return _failure("This fruit has already been opened or is no longer in storage.")

func extract_seeds(fruit_id: String) -> Dictionary:
	return _extract_seeds(fruit_id,true)

func extract_all_seeds() -> Dictionary:
	if fruit_inventory.is_empty(): return _failure("Harvest a ripe fruit before collecting its seeds.")
	var seeds: Array = []
	var ids: Array[String] = []
	for fruit: Dictionary in fruit_inventory: ids.append(str(fruit.id))
	for id: String in ids:
		var result: Dictionary = _extract_seeds(id,false)
		if result.ok: seeds.append_array(result.seeds)
	save_game()
	return {"ok":true,"seeds":seeds,"message":"Collected %d seeds. Their full genomes and parentage are preserved for planting." % seeds.size()}

func graft(host_id: String, donor_id: String, trait_name: String = "feature") -> Dictionary:
	if not owns_plant(host_id) or not owns_plant(donor_id): return _failure("Choose a host and donor that belong to your garden.")
	var host: Dictionary = get_plant(host_id)
	var donor: Dictionary = get_plant(donor_id)
	if host.is_empty() or donor.is_empty() or host_id == donor_id:
		return _failure("Choose a host and a different donor.")
	if not host.mature or not donor.mature:
		return _failure("The host and donor must both be mature.")
	if bool(host.get("withered",false)) or bool(donor.get("withered",false)): return _failure("Withered plants cannot supply or receive a graft. Their stored seeds can continue the lineage.")
	if host.graft_history.size() >= 2:
		return _failure("This host already carries its two possible grafts.")
	if donor.favorite:
		return _failure("The donor is locked as a favorite. Unlock it before taking material.")
	if int(donor.get("donor_ready_at", 0)) > int(Time.get_unix_time_from_system()):
		return _failure("The donor is recovering. Its tissue can be collected again in a few minutes.")
	if int(resources.grafts) <= 0:
		return _failure("Grafting requires one grafting material.")
	var same_type: bool = host.type == donor.type or host.type == donor.secondary_type or host.secondary_type == donor.type
	var chance: float = (0.9 if same_type else 0.65) - float(host.graft_history.size()) * 0.05
	resources.grafts -= 1
	donor.donor_ready_at = int(Time.get_unix_time_from_system()) + 180
	var success: bool = random.randf() < chance
	var value: Variant = donor.genes.color.dominant
	if trait_name == "skill":
		value = donor.skills[0]
	elif trait_name in ["stat", "stat bias"]:
		trait_name = "stat"
		value = _strongest_stat(donor.stats)
	var record: Dictionary = {"donor": donor_id, "donor_name": donor.name, "donor_color": donor.genes.color.dominant,
		"donor_type": donor.type, "donor_species": donor.species, "donor_genes": donor.genes.duplicate(true),
		"donor_seed": donor.seed, "donor_lineage_mix": lineage_composition(donor),
		"trait": trait_name, "value": value, "generation": host.generation, "success": success, "at": int(Time.get_unix_time_from_system())}
	if success:
		host.graft_history.append(record)
		if trait_name == "skill":
			if not host.skills.has(value):
				if host.skills.size() >= 3:
					host.skills[2] = value
				else:
					host.skills.append(value)
		elif trait_name == "stat":
			host.stats[value] = int(round(float(host.stats[value]) * 1.15))
		else:
			host["graft_color"] = value
			host["graft_shape"] = donor.genes.shape.dominant
	else:
		if not host.has("graft_attempts"):
			host["graft_attempts"] = []
		host.graft_attempts.append(record)
	save_game()
	return {"ok": true, "success": success, "message": ("The graft took. %s now carries a living piece of %s." % [host.name, donor.name]) if success else "The graft was rejected. The host is unharmed; donor material was spent.", "plant": host, "chance": chance}

func graft_odds(host_id: String, donor_id: String) -> float:
	var a: Dictionary = get_plant(host_id)
	var b: Dictionary = get_plant(donor_id)
	if a.is_empty() or b.is_empty():
		return 0.65
	return (0.9 if (a.type == b.type or a.type == b.secondary_type or a.secondary_type == b.type) else 0.65) - float(a.graft_history.size()) * 0.05

func mutate(id: String, agent: String = "radiation", slot: String = "pattern") -> Dictionary:
	if not owns_plant(id): return _failure("This plant no longer belongs to your garden.")
	var p: Dictionary = get_plant(id)
	if p.is_empty():
		return _failure("Choose a plant to expose.")
	if bool(p.get("withered",false)): return _failure("A withered plant cannot be mutated. Plant its seeds to continue the lineage.")
	if int(resources.agents) <= 0:
		return _failure("Mutation needs one agent. Display milestones and battles can award more.")
	_record_collection(p)
	resources.agents -= 1
	var roll: float = random.randf()
	var outcome: String = "No change"
	var message: String = "The tissue remains unchanged. The agent was consumed."
	var old_value: Variant = ""
	var new_value: Variant = ""
	var actual_slot: String = slot
	var previous_genes: Dictionary = p.genes.duplicate(true)
	if roll < 0.7:
		outcome = "New trait"
		if agent.to_lower() == "radiation" and random.randf() < 0.08:
			actual_slot = "lineage"
			old_value = p.type
			p.secondary_type = p.type if p.type != "Carnivorous" else p.secondary_type
			p.type = "Carnivorous"
			p.species = "Hollow Pitcher"
			p.genes.form.dominant = "Upright"
			p.genes.shape.dominant = "Split"
			p.genes.glow.dominant = "Pulsing core"
			if not p.skills.has("Devour"):
				p.skills.insert(0, "Devour")
				if p.skills.size() > 3:
					p.skills.resize(3)
			new_value = "Carnivorous"
			message = "Reversion. A patient trap unfolds where a bloom once grew. Carnivorous lineage discovered."
			if not discovered.has(p.species):
				discovered.append(p.species)
		else:
			var mutation_slots: Array = ["pattern", "color", "accent", "shape", "form", "glow", "petals", "texture", "size"]
			if agent.to_lower() == "radiation" or not p.genes.has(actual_slot):
				actual_slot = mutation_slots[random.randi_range(0, mutation_slots.size() - 1)]
			old_value = p.genes[actual_slot].dominant
			new_value = _new_trait_value(actual_slot, old_value)
			p.genes[actual_slot].recessive = old_value
			p.genes[actual_slot].dominant = new_value
			message = "%s changed from %s to %s. The old trait remains as a carried recessive." % [actual_slot.capitalize(), str(old_value), str(new_value)]
	elif roll >= 0.9:
		outcome = "Deformity"
		actual_slot = STAT_NAMES[random.randi_range(0, STAT_NAMES.size() - 1)]
		old_value = p.stats[actual_slot]
		p.stats[actual_slot] = maxi(1, int(round(float(old_value) * 0.8)))
		new_value = p.stats[actual_slot]
		p.deformed = true
		message = "Asymmetric growth. %s fell by 20%%; its unusual genes still have breeding value." % actual_slot
	if outcome=="New trait":
		if not p.has("gene_sources"): p["gene_sources"] = {}
		for changed_slot: String in p.genes:
			if p.genes[changed_slot] == previous_genes.get(changed_slot,{}): continue
			p.gene_sources[changed_slot] = {"allele_a":{"parent_id":"","parent_name":"","organism_id":p.id,"allele":"mutation","value":p.genes[changed_slot].dominant},
				"allele_b":{"parent_id":"","parent_name":"","organism_id":p.id,"allele":"prior","value":p.genes[changed_slot].recessive},
				"expressed_origin":"mutation","expressed":p.genes[changed_slot].dominant,"carried":p.genes[changed_slot].recessive,
				"mutation_index":p.mutation_history.size(),"before":previous_genes.get(changed_slot,{}).duplicate(true)}
	p.seed = int(p.seed) # Stored anatomy seed is stable: a new allele changes only its own visual.
	p.mutation_history.append({"agent": agent, "outcome": outcome, "slot": actual_slot, "before": old_value, "after": new_value, "generation": p.generation, "at": int(Time.get_unix_time_from_system())})
	p.rarity = _calculate_rarity(p)
	_record_collection(p)
	save_game()
	return {"ok": true, "message": message, "plant": p, "outcome": outcome}

func _new_trait_value(slot: String, previous: Variant) -> Variant:
	var pool: Array = []
	match slot:
		"pattern": pool = PATTERNS.duplicate()
		"color", "accent": pool = COLORS.duplicate()
		"shape": pool = SHAPES.duplicate()
		"form": pool = FORMS.duplicate()
		"texture": pool = TEXTURES.duplicate()
		"glow": pool = ["Veins", "Spore dust", "Pulsing core"]
		"size": pool = ["Small", "Standard", "Large"]
		"petals": pool = [3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
		_: pool = PATTERNS.duplicate()
	pool.erase(previous)
	return pool[random.randi_range(0, pool.size() - 1)]

func plant_seed_at(reference: Variant,cell: int) -> Dictionary:
	if cell<0 or cell>=bed.size(): return _failure("Choose an empty garden plot to plant this seed.")
	if not str(bed[cell]).is_empty(): return _failure("This plot is occupied. Choose an empty garden plot.")
	var resolved: Dictionary = _market_resolve("seed",reference)
	if resolved.is_empty(): return _failure("This seed is no longer in your seed bank. Choose another seed.")
	return plant_seed(int(resolved.index),cell)

func _valid_planting_seed(snapshot: Dictionary) -> bool:
	if snapshot.has("genome"): return _valid_genome(snapshot.genome,plants)
	if snapshot.has("species_index") and (not Market._whole(snapshot.species_index) or int(snapshot.species_index)>=SPECIES.size()): return false
	if snapshot.has("seed") and not Market._whole(snapshot.seed): return false
	if snapshot.has("rarity") and not snapshot.rarity in RARITIES: return false
	if snapshot.has("pattern") and not snapshot.pattern in PATTERNS: return false
	if snapshot.has("parents"):
		if not snapshot.parents is Array: return false
		for parent_id: Variant in snapshot.parents:
			if not parent_id is String or not plants.has(parent_id): return false
	return true

func plant_seed(index: int,target_cell: int = -1) -> Dictionary:
	if index < 0 or index >= seed_bank.size():
		return _failure("Choose a seed from the bank.")
	if target_cell < -1 or target_cell>=bed.size(): return _failure("Choose an empty garden plot to plant this seed.")
	if target_cell>=0 and not str(bed[target_cell]).is_empty(): return _failure("This plot is occupied. Choose an empty garden plot.")
	if int(resources.sunlight) < 10:
		return _failure("Planting a seed needs 10 gathered light.")
	var snapshot: Dictionary = seed_bank[index]
	if not _valid_planting_seed(snapshot): return _failure("This seed's genome is incomplete. Its parentage has been kept in the archive.")
	var p: Dictionary
	if snapshot.has("genome"):
		p = snapshot.genome.duplicate(true)
		p.id = _new_id()
		p["life_age"] = 0.0
		p["withered"] = false
		p["retired"] = false
		p.erase("sold")
		p.erase("sold_at")
		p["origin"] = {"kind":"seed","seed_id":snapshot.get("id",""),"fruit_kind":snapshot.get("kind","lineage")}
	else:
		# Earlier archives and external rewards carry tendencies rather than a
		# fertilized embryo. They remain plantable alongside full hybrid genomes.
		var archived_parents: Array = []
		for parent_id: Variant in snapshot.get("parents",[]):
			if parent_id is String and plants.has(parent_id): archived_parents.append(plants[parent_id])
		var anatomy_seed: int = int(snapshot.get("seed",random.randi()))
		if archived_parents.is_empty():
			p = _create_base(int(snapshot.get("species_index",0)),anatomy_seed)
		else:
			p = _make_offspring(archived_parents[0],archived_parents[1] if archived_parents.size()>1 else archived_parents[0],anatomy_seed)
		p.rarity = str(snapshot.get("rarity", "Common"))
		if snapshot.has("pattern"):
			p.genes.pattern.recessive = snapshot.pattern
			if random.randf() < 0.65: p.genes.pattern.dominant = snapshot.pattern
		if snapshot.has("parents"):
			p.parents = snapshot.parents.duplicate()
			var parent_generation: int = 0
			for parent_id: String in p.parents:
				if plants.has(parent_id): parent_generation = maxi(parent_generation, int(plants[parent_id].generation))
			p.generation = parent_generation+1
		p.name = _offspring_name(random)
	p.mature = false
	p["care"] = Care.default_care()
	Care.initialize(p)
	p.ready_at = int(Time.get_unix_time_from_system())+GROW_SECONDS
	p.born_at = int(Time.get_unix_time_from_system())
	resources.sunlight -= 10
	seed_bank.remove_at(index)
	_add_plant(p)
	var planted_cell: int = target_cell
	if planted_cell<0:
		for cell in range(bed.size()):
			if str(bed[cell]).is_empty(): planted_cell=cell; break
	if planted_cell>=0: bed[planted_cell]=p.id
	save_game()
	return {"ok": true, "message": "%s has taken root. It will mature in 12 seconds." % p.name, "plant": p,"plant_id":str(p.id),"bed_index":planted_cell}

func display_score() -> Dictionary:
	var types_seen: Dictionary = {}
	var species_seen: Dictionary = {}
	var patterns_seen: Dictionary = {}
	var colors_seen: Dictionary = {}
	var total_rarity: float = 0.0
	var entries: Array = []
	for id: String in display_bed:
		var p: Dictionary = get_plant(id)
		if p.is_empty() or not p.mature:
			continue
		entries.append(p)
		types_seen[p.type] = true
		if not str(p.secondary_type).is_empty():
			types_seen[p.secondary_type] = true
		species_seen[p.species] = true
		patterns_seen[p.genes.pattern.dominant] = true
		colors_seen[p.genes.color.dominant] = true
		var rarity_index: int = maxi(0, RARITIES.find(p.rarity))
		total_rarity += 5.0 + float(rarity_index) * 10.0 + minf(float(p.generation - 1) * 3.0, 18.0)
		if p.genes.pattern.dominant in ["Starburst", "Bicolor Ring"]:
			total_rarity += 9.0
		if p.type == "Carnivorous":
			total_rarity += 15.0
	var diversity: int = types_seen.size() * 13 + species_seen.size() * 8 + patterns_seen.size() * 7 + colors_seen.size() * 4
	var harmony: float = float(entries.size()) * 5.0
	for i in range(entries.size()):
		for j in range(i + 1, entries.size()):
			var a: Dictionary = entries[i]
			var b: Dictionary = entries[j]
			var color_a: Color = Color(str(a.genes.color.dominant))
			var color_b: Color = Color(str(b.genes.color.dominant))
			# Humid, muted tissue colors harmonize; repeated pigments and motifs score extra.
			var difference: float = absf(color_a.r - color_b.r) + absf(color_a.g - color_b.g) + absf(color_a.b - color_b.b)
			harmony += maxf(0.0, 7.0 - difference * 6.0)
			if a.genes.pattern.dominant == b.genes.pattern.dominant:
				harmony += 3.0
			if a.genes.color.dominant == b.genes.color.dominant:
				harmony += 2.0
	var rarity: int = int(round(total_rarity))
	return {"diversity": diversity, "harmony": int(round(harmony)), "rarity": rarity, "total": diversity + int(round(harmony)) + rarity, "count": entries.size()}

func claim_display() -> Dictionary:
	var score: int = int(display_score().total)
	var rewards: int = 0
	for threshold: int in DISPLAY_THRESHOLDS:
		if score >= threshold and not claimed.has(threshold):
			claimed.append(threshold)
			resources.sunlight += 30
			resources.agents += 1
			resources.grafts += 1
			var species_index: int = mini(6, 3 + claimed.size() - 1)
			seed_bank.append(_make_seed(species_index, "Uncommon" if threshold < 340 else "Rare"))
			rewards += 1
	if rewards == 0:
		var next_threshold: int = 0
		for threshold: int in DISPLAY_THRESHOLDS:
			if not claimed.has(threshold):
				next_threshold = threshold
				break
		return _failure("Next display reward at %d beauty. Swap plants to balance diversity, harmony, and rarity." % next_threshold if next_threshold > 0 else "All display milestones collected. Your living collection continues to grow.")
	save_game()
	return {"ok": true, "message": "%d display milestone%s collected: +%d light, +%d agents, +%d grafting materials, +%d seeds." % [rewards, "s" if rewards != 1 else "", rewards * 30, rewards, rewards, rewards]}

func next_display_threshold() -> int:
	for threshold: int in DISPLAY_THRESHOLDS:
		if not claimed.has(threshold):
			return threshold
	return 0


func _record_collection(p: Dictionary) -> void:
	var species_name: String = str(p.get("species", ""))
	if species_name.is_empty() or not p.get("genes", {}).has("pattern"):
		return
	if not collection_seen.has(species_name):
		collection_seen[species_name] = []
	var pattern: String = str(p.genes.pattern.dominant)
	if PATTERNS.has(pattern) and not collection_seen[species_name].has(pattern):
		collection_seen[species_name].append(pattern)
	# Legacy saves can reconstruct earlier pattern discoveries from permanent history.
	for record: Dictionary in p.get("mutation_history", []):
		if str(record.get("slot", "")) != "pattern":
			continue
		for value: Variant in [record.get("before", ""), record.get("after", "")]:
			if PATTERNS.has(value) and not collection_seen[species_name].has(value):
				collection_seen[species_name].append(value)

func collection_progress() -> Dictionary:
	# Discovery remains permanent even after its tissue changes through mutation.
	for id: String in plant_order:
		if plants.has(id):
			_record_collection(plants[id])
	var pages: Array = []
	var earned: Array = []
	var all_patterns: Dictionary = {}
	for species_name: String in collection_seen:
		for pattern: String in collection_seen[species_name]:
			all_patterns[pattern] = true
	var base_count: int = 0
	for s: Dictionary in SPECIES:
		var pattern_count: int = collection_seen.get(s.name, []).size()
		var key: String = "species:" + str(s.name)
		var page: Dictionary = {"id": key, "name": s.name, "patterns": pattern_count, "total": 3, "complete": pattern_count >= 3, "claimed": collection_claimed.has(key)}
		pages.append(page)
		if discovered.has(s.name):
			base_count += 1
		if page.complete:
			earned.append({"id": key, "name": "%s pattern page" % s.name, "claimed": page.claimed, "reward": "1 lineage seed + 1 agent"})
	var pattern_complete: bool = all_patterns.size() >= PATTERNS.size()
	var atlas_complete: bool = base_count >= SPECIES.size()
	if pattern_complete:
		earned.append({"id": "patterns", "name": "Complete pattern family", "claimed": collection_claimed.has("patterns"), "reward": "1 rare seed + 2 agents"})
	if atlas_complete:
		earned.append({"id": "atlas", "name": "Seven founding lineages", "claimed": collection_claimed.has("atlas"), "reward": "1 rare seed + 2 agents"})
	var unclaimed: int = 0
	for entry: Dictionary in earned:
		if not entry.claimed:
			unclaimed += 1
	return {"species_pages": pages, "pattern_count": all_patterns.size(), "pattern_total": PATTERNS.size(), "species_count": base_count, "species_total": SPECIES.size(), "earned": earned, "unclaimed": unclaimed, "pattern_complete": pattern_complete, "atlas_complete": atlas_complete, "pattern_claimed": collection_claimed.has("patterns"), "atlas_claimed": collection_claimed.has("atlas")}

func claim_collection() -> Dictionary:
	var progress: Dictionary = collection_progress()
	if progress.unclaimed == 0:
		return _failure("Record 3 patterns within a species page, all 6 patterns, or all 7 founding lineages to earn collection rewards.")
	var seed_count: int = 0
	var agent_count: int = 0
	var names: Array = []
	for entry: Dictionary in progress.earned:
		if entry.claimed:
			continue
		var key: String = str(entry.id)
		if key.begins_with("species:"):
			seed_bank.append(_make_seed(_species_index(key.trim_prefix("species:")), "Uncommon"))
			agent_count += 1
		else:
			seed_bank.append(_make_seed(random.randi_range(0, SPECIES.size() - 1), "Rare"))
			agent_count += 2
		seed_count += 1
		collection_claimed.append(key)
		names.append(str(entry.name))
	resources.agents += agent_count
	save_game()
	return {"ok": true, "message": "Collection milestones: %s. +%d seeds and +%d mutation agents." % [", ".join(names), seed_count, agent_count], "seeds": seed_count, "agents": agent_count, "earned": names}

func battle_reward(won: bool) -> Dictionary:
	battles += 1
	var light: int = 55 if won else 25
	resources.sunlight += light
	if won:
		wins += 1
	var species_index: int = (battles + 2) % SPECIES.size()
	var seed_rarity: String = "Rare" if won and wins % 3 == 0 else ("Uncommon" if won else "Common")
	seed_bank.append(_make_seed(species_index, seed_rarity))
	resources.grafts += 1
	if won and wins % 2 == 0:
		resources.agents += 1
	save_game()
	return {"ok": true, "message": "+%d gathered light · +1 %s seed · +1 grafting material%s" % [light, SPECIES[species_index].name, " · +1 agent" if won and wins % 2 == 0 else ""], "sunlight": light, "seed": seed_bank[-1]}


func generate_opponent(team_size: int = 3) -> Array:
	# This pure snapshot uses the player's breeding rules, never artificial level scaling.
	# Every ID is external to the owned archive; scouting has no persistent side effects.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 93017 + battles * 8191 + wins * 3571
	var result: Array = []
	var themed: bool = battles >= 2 and battles % 3 == 2
	var theme_index: int = [3, 5, 2, 4][rng.randi_range(0, 3)]
	var max_species: int = mini(6, 2 + battles)
	var target_generation: int = mini(4, 1 + int(battles / 3))
	for i in range(clampi(team_size, 1, 9)):
		var species_index: int = i % 3 if battles == 0 else (theme_index if themed else rng.randi_range(0, max_species))
		var prefix: String = "enemy_%d_%d_%d" % [battles, wins, i]
		var p: Dictionary = _create_base(species_index, maxi(1, rng.randi()), prefix + "_g1")
		var pedigree: Dictionary = {}
		p.name = _offspring_name(rng)
		p.born_at = 0
		p.ready_at = 0
		for generation in range(2, target_generation + 1):
			var donor_index: int = species_index if themed else rng.randi_range(0, max_species)
			var donor: Dictionary = _create_base(donor_index, maxi(1, rng.randi()), prefix + "_donor%d" % generation)
			donor.name = _offspring_name(rng)
			donor.born_at = 0
			donor.ready_at = 0
			pedigree[p.id] = p
			pedigree[donor.id] = donor
			p = _make_offspring(p, donor, maxi(1, rng.randi()), prefix + "_g%d" % generation)
			p.mature = true
			p.born_at = 0
			p.ready_at = 0
		p["pedigree"] = pedigree
		result.append(p)
	return result

func _make_seed(species_index: int, rarity: String) -> Dictionary:
	var s: Dictionary = SPECIES[species_index]
	return {"species_index": species_index, "species": s.name, "type": s.type, "rarity": rarity, "pattern": PATTERNS[random.randi_range(0, PATTERNS.size() - 1)], "seed": random.randi(), "name": "%s seed" % s.name}

func rename_plant(id: String, new_name: String) -> void:
	if owns_plant(id) and not new_name.strip_edges().is_empty():
		plants[id].name = new_name.strip_edges().left(28)
		save_game()

func toggle_favorite(id: String) -> void:
	if owns_plant(id):
		plants[id].favorite = not plants[id].favorite
		save_game()

func tick_growth() -> bool:
	var now: int = int(Time.get_unix_time_from_system())
	var changed: bool = false
	for id: String in plant_order:
		var p: Dictionary = plants[id]
		if not p.mature and now >= int(p.ready_at):
			p.mature = true
			_ensure_natural_crop(id,now)
			changed = true
	if changed:
		save_game()
	return changed

func mature_plant(id: String) -> Dictionary:
	if not owns_plant(id): return _failure("This plant no longer belongs to your garden.")
	var p: Dictionary = get_plant(id)
	if p.is_empty():
		return _failure("Choose a growing plant.")
	if bool(p.get("withered",false)): return _failure("A withered plant cannot be restored by quick growth. Plant its seeds instead.")
	if p.mature:
		return _failure("This plant is already mature.")
	if int(resources.sunlight) < 5:
		return _failure("Quick growth needs 5 gathered light, or wait a few seconds.")
	resources.sunlight -= 5
	p.mature = true
	p.ready_at = int(Time.get_unix_time_from_system())
	_ensure_natural_crop(id,int(p.ready_at))
	save_game()
	return {"ok": true, "message": "%s has unfurled." % p.name, "plant": p}

func place_in_bed(id: String, index: int) -> bool:
	if index < 0 or index >= 9 or not owns_plant(id):
		return false
	if not bool(plants[id].mature) or bool(plants[id].get("withered",false)):
		return false
	var old_index: int = bed.find(id)
	var displaced: String = str(bed[index])
	if old_index >= 0:
		bed[old_index] = displaced
	bed[index] = id
	save_game()
	return true

func place_in_display(id: String, index: int) -> bool:
	if index < 0 or index >= 6 or not owns_plant(id) or not plants[id].mature or bool(plants[id].get("withered",false)):
		return false
	var old_index: int = display_bed.find(id)
	var displaced: String = str(display_bed[index])
	if old_index >= 0:
		display_bed[old_index] = displaced
	display_bed[index] = id
	save_game()
	return true

func bench(id: String) -> void:
	var index: int = bed.find(id)
	if index >= 0:
		bed[index] = ""
		save_game()

func remove_from_display(id: String) -> void:
	var index: int = display_bed.find(id)
	if index >= 0:
		display_bed[index] = ""
		save_game()

func collect_daily() -> Dictionary:
	var now: int = int(Time.get_unix_time_from_system())
	if now - last_daily < 86400:
		return _failure("The leaves are gathering light. Return tomorrow for another harvest.")
	last_daily = now
	resources.sunlight += 60
	var seed_species: int = random.randi_range(0, 2)
	seed_bank.append(_make_seed(seed_species, "Common"))
	save_game()
	return {"ok": true, "message": "Daily gathering: +60 light and one seed. The garden remembers your return."}

func collect_mature_seeds() -> Dictionary:
	var now: int = int(Time.get_unix_time_from_system())
	if now - last_seed_collection < 180:
		return _failure("Seed husks are still forming. Mature plants yield a seed every 3 minutes.")
	var candidates: Array = []
	for id: String in plant_order:
		if plants[id].mature and not bool(plants[id].get("withered",false)):
			candidates.append(id)
	if candidates.is_empty():
		return _failure("A mature plant is needed to gather a seed.")
	var parent: Dictionary = plants[candidates[random.randi_range(0, candidates.size() - 1)]]
	# Compatibility API for old integrations. New gameplay harvests real fruits;
	# this older timed collection must also preserve a hybrid's entire genome.
	var embryo: Dictionary = _make_offspring(parent,parent,maxi(1,random.randi()),_next_fruit_id()+"_seed_1")
	embryo.parents = [parent.id]
	var snapshot: Dictionary = _genome_seed(embryo,"lineage",[parent.name])
	seed_bank.append(snapshot)
	last_seed_collection = now
	save_game()
	return {"ok": true, "message": "%s released a seed, carrying a tendency toward its pattern and lineage." % parent.name}

func lineage(id: String, depth: int = 3) -> Dictionary:
	var p: Dictionary = get_plant(id)
	if p.is_empty():
		return {}
	var ancestors: Array = []
	var descendants: Array = []
	if depth > 0:
		for parent_id: String in p.parents:
			if plants.has(parent_id):
				ancestors.append(_ancestor_branch(parent_id, depth - 1))
		for other_id: String in plants:
			if plants[other_id].parents.has(id):
				descendants.append(_descendant_branch(other_id, depth - 1))
	return {"plant": p, "ancestors": ancestors, "descendants": descendants}

func _ancestor_branch(id: String, remaining: int) -> Dictionary:
	var p: Dictionary = plants[id]
	var children: Array = []
	if remaining > 0:
		for parent_id: String in p.parents:
			if plants.has(parent_id):
				children.append(_ancestor_branch(parent_id, remaining - 1))
	return {"id": id, "name": p.name, "generation": p.generation, "parents": children}

func _descendant_branch(id: String, remaining: int) -> Dictionary:
	var p: Dictionary = plants[id]
	var children: Array = []
	if remaining > 0:
		for other_id: String in plants:
			if plants[other_id].parents.has(id):
				children.append(_descendant_branch(other_id, remaining - 1))
	return {"id": id, "name": p.name, "generation": p.generation, "children": children}

func _species_index(species_name: String) -> int:
	for i in range(SPECIES.size()):
		if SPECIES[i].name == species_name:
			return i
	return 1

func _strongest_stat(stats: Dictionary) -> String:
	var strongest: String = "growth"
	var highest: float = -1.0
	for key: String in ["growth", "toxin", "root", "bloom", "shade"]:
		if float(stats[key]) > highest:
			strongest = key
			highest = float(stats[key])
	return strongest

func _calculate_rarity(p: Dictionary) -> String:
	var rank: int = 0
	if p.genes.pattern.dominant in ["Starburst", "Bicolor Ring"]:
		rank += 1
	if p.genes.glow.dominant != "None":
		rank += 1
	if not str(p.secondary_type).is_empty():
		rank += 1
	if p.type == "Carnivorous":
		rank += 2
	return RARITIES[clampi(rank, 0, 4)]

func _offspring_name(rng: RandomNumberGenerator) -> String:
	var first: Array = ["Pearl", "Dusk", "Quiet", "Amber", "Hollow", "Glass", "Rain", "Velvet", "Pale", "Silt", "Silver", "Woven"]
	var last: Array = ["Veil", "Crown", "Whisper", "Lantern", "Thread", "Lumen", "Frond", "Vessel", "Bloom", "Husk", "Chalice", "Spiral"]
	return "%s %s" % [first[rng.randi_range(0, first.size() - 1)], last[rng.randi_range(0, last.size() - 1)]]

func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}

func _default_expedition() -> Dictionary:
	return {"map_seed": 813931, "position": [15, 18], "steps": 0,
		"encounters": 0, "captures": 0, "discovered_biomes": ["Mosswood"],
		"collected_sites": [], "active_encounter": {}, "site_records": {}, "visited_landmarks": [],
		"respawn_day": int(Time.get_unix_time_from_system()) / 86400}

func _normalise_expedition(value: Variant) -> Dictionary:
	var result: Dictionary = _default_expedition()
	if value is Dictionary:
		for key: String in result:
			if value.has(key): result[key] = value[key]
	result.position = [clampi(int(result.position[0]), 0, WORLD_WIDTH-1), clampi(int(result.position[1]), 0, WORLD_HEIGHT-1)]
	return result

func _valid_expedition(value: Variant) -> bool:
	if not value is Dictionary: return false
	var data: Dictionary = value
	if data.has("position"):
		if not data.position is Array or data.position.size() != 2: return false
		for coordinate: Variant in data.position:
			if not (coordinate is float or coordinate is int): return false
	for key: String in ["steps", "encounters", "captures", "map_seed", "respawn_day"]:
		if data.has(key) and not (data[key] is float or data[key] is int): return false
	for key: String in ["discovered_biomes", "collected_sites", "visited_landmarks"]:
		if data.has(key) and not data[key] is Array: return false
	for key: String in ["active_encounter", "site_records"]:
		if data.has(key) and not data[key] is Dictionary: return false
	if data.has("site_records"):
		for site: Variant in data.site_records:
			if not site is String or not data.site_records[site] is Dictionary: return false
	if data.has("active_encounter") and not data.active_encounter.is_empty():
		var encounter: Dictionary = data.active_encounter
		for key: String in ["plant", "site_id", "biome", "encounter_id", "capture_chance", "attempts", "observed"]:
			if not encounter.has(key): return false
		if not encounter.plant is Dictionary: return false
		for key: String in ["id", "seed", "name", "species", "type", "genes", "stats", "parents", "skills"]:
			if not encounter.plant.has(key): return false
		if not encounter.site_id is String or not encounter.encounter_id is String or not encounter.biome is String: return false
		if not encounter.observed is bool: return false
		if not (encounter.attempts is int or encounter.attempts is float): return false
		if not (encounter.capture_chance is int or encounter.capture_chance is float): return false
	return true

func begin_expedition() -> Dictionary:
	if expedition.is_empty(): expedition = _default_expedition()
	var day: int = int(Time.get_unix_time_from_system()) / 86400
	if int(expedition.respawn_day) != day:
		expedition.respawn_day = day
		expedition.collected_sites.clear()
		expedition.site_records.clear()
		expedition.active_encounter.clear()
	save_game()
	return expedition

func move_explorer(x: int, y: int) -> void:
	if expedition.is_empty(): expedition = _default_expedition()
	if not expedition.active_encounter.is_empty(): return
	var next: Array = [clampi(x, 0, WORLD_WIDTH-1), clampi(y, 0, WORLD_HEIGHT-1)]
	if next == expedition.position: return
	# Navigation owns collision and paths; the model counts tiles actually traversed.
	expedition.steps += absi(int(next[0]) - int(expedition.position[0])) + absi(int(next[1]) - int(expedition.position[1]))
	expedition.position = next
	save_game()

func register_biome(biome: String) -> void:
	if not WILD_BIOMES.has(biome): return
	if expedition.is_empty(): expedition = _default_expedition()
	if not expedition.discovered_biomes.has(biome):
		expedition.discovered_biomes.append(biome)
		save_game()

func visit_landmark(id: String, biome: String = "Mosswood") -> void:
	if id.is_empty(): return
	if expedition.is_empty(): expedition = _default_expedition()
	if not expedition.has("visited_landmarks"): expedition.visited_landmarks = []
	var changed: bool = false
	if not expedition.visited_landmarks.has(id):
		expedition.visited_landmarks.append(id)
		changed = true
	if WILD_BIOMES.has(biome) and not expedition.discovered_biomes.has(biome):
		expedition.discovered_biomes.append(biome)
		changed = true
	if changed: save_game()

func preview_wild_plant(biome: String = "Mosswood", site_id: String = "") -> Dictionary:
	# Rendering can inspect an organism without opening an encounter, saving,
	# consuming a persistent ID, or advancing any gameplay random generator.
	if not WILD_BIOMES.has(biome): return {}
	var preview_expedition: Dictionary = expedition if not expedition.is_empty() else _default_expedition()
	if site_id.is_empty(): site_id = "%s_%d_%d" % [biome, preview_expedition.position[0], preview_expedition.position[1]]
	var active: Dictionary = preview_expedition.get("active_encounter",{})
	if not active.is_empty() and str(active.get("site_id","")) == site_id:
		return active.plant.duplicate(true)
	var organism_seed: int = maxi(1, absi(("%d/%s/%d" % [preview_expedition.map_seed, site_id, preview_expedition.respawn_day]).hash()))
	var rng := RandomNumberGenerator.new()
	rng.seed = organism_seed
	var pool: Array = WILD_BIOMES[biome]
	var species_index: int = int(pool[rng.randi_range(0, pool.size() - 1)])
	# The first reachable patch is a readable, familiar organism; later biomes expand the atlas.
	if site_id == "moss_01": species_index = 0
	var p: Dictionary = _create_base(species_index, organism_seed, "wild_%d" % organism_seed)
	p.name = _offspring_name(rng)
	var rare_roll: float = rng.randf()
	if site_id != "moss_01":
		if rare_roll < 0.10:
			p.genes.pattern.dominant = "Starburst" if rng.randf() < 0.5 else "Bicolor Ring"
			p.genes.glow.dominant = "Veins" if rng.randf() < 0.5 else "Spore dust"
		elif rare_roll < 0.30:
			p.genes.pattern.dominant = "Starburst" if rng.randf() < 0.5 else "Bicolor Ring"
		if rng.randf() < 0.20: p.genes.color.dominant = COLORS[rng.randi_range(0, COLORS.size() - 1)]
		# Deep-field traps remain rare: 4% after ten successful collections.
		if biome in ["Sunken Glade","Ancient Grove","Moonfen"] and int(preview_expedition.captures) >= 10 and rng.randf() < 0.04:
			p.type = "Carnivorous"
			p.species = "Hollow Pitcher"
			p.secondary_type = "Parasite"
			p.skills = ["Devour"]
			p.skill_genes = {"dominant": "Devour", "recessive": "Parasitic Tendril"}
			p.genes.shape.dominant = "Split"
			p.genes.form.dominant = "Upright"
			p.genes.glow.dominant = "Pulsing core"
	p.rarity = _calculate_rarity(p)
	p["origin"] = {"kind": "wild", "biome": biome, "site": site_id, "found_at": int(Time.get_unix_time_from_system())}
	return p

func wild_encounter(biome: String = "Mosswood", site_id: String = "") -> Dictionary:
	begin_expedition()
	if not WILD_BIOMES.has(biome): return _failure("This habitat has not been mapped.")
	if site_id.is_empty(): site_id = "%s_%d_%d" % [biome, expedition.position[0], expedition.position[1]]
	if not expedition.active_encounter.is_empty():
		if str(expedition.active_encounter.site_id) != site_id:
			return _failure("Finish observing this organism before moving to another patch.")
		return _encounter_result("The same wild specimen is still here.")
	if expedition.collected_sites.has(site_id): return _failure("This patch is resting. New wild growth returns next field day.")
	var record: Dictionary = expedition.site_records.get(site_id, {"attempts": 0, "observed": false, "fled": false})
	if bool(record.get("fled", false)): return _failure("The plant withdrew into its roots. This patch will regrow next field day.")
	var p: Dictionary = preview_wild_plant(biome,site_id)
	var organism_seed: int = int(p.seed)
	var observed: bool = bool(record.get("observed", false))
	var chance: float = minf(0.98, float(WILD_CATCH_CHANCES.get(p.rarity, 0.90)) + (0.15 if observed else 0.0))
	expedition.active_encounter = {"plant": p, "biome": biome, "site_id": site_id,
		"encounter_id": "encounter_%d" % organism_seed, "capture_chance": chance,
		"observed": observed, "attempts": int(record.get("attempts", 0)), "base_chance": WILD_CATCH_CHANCES.get(p.rarity, 0.90)}
	expedition.site_records[site_id] = record
	expedition.encounters += 1
	if not expedition.discovered_biomes.has(biome): expedition.discovered_biomes.append(biome)
	save_game()
	return _encounter_result("A wild %s is growing here. Observe its rhythms before taking a cutting." % p.species)

func _encounter_result(message: String) -> Dictionary:
	var active: Dictionary = expedition.active_encounter
	return {"ok": true, "message": message, "plant": active.plant,
		"encounter_id": active.encounter_id, "capture_chance": capture_odds(),
		"chance": capture_odds(), "observed": active.observed,
		"rare": RARITIES.find(active.plant.rarity) >= 2}

func capture_odds(method: String = "gather") -> float:
	if expedition.is_empty() or expedition.active_encounter.is_empty(): return 0.0
	var chance: float = float(expedition.active_encounter.capture_chance)
	if method == "entangle" and _has_mature_vine(): chance += 0.10
	return clampf(chance, 0.0, 0.98)

func _has_mature_vine() -> bool:
	for id: String in plant_order:
		var p: Dictionary = plants[id]
		if bool(p.mature) and not bool(p.get("withered",false)) and (p.type == "Vine" or p.secondary_type == "Vine"): return true
	return false

func resolve_wild_capture(method: String = "gather") -> Dictionary:
	if expedition.is_empty() or expedition.active_encounter.is_empty(): return _failure("Find a wild plant in the field first.")
	var active: Dictionary = expedition.active_encounter
	var site: String = str(active.site_id)
	var record: Dictionary = expedition.site_records.get(site, {"attempts": 0, "observed": false, "fled": false})
	if method == "observe":
		if bool(active.observed): return _failure("You have already studied this specimen. Its collection odds are shown below.")
		active.observed = true
		active.capture_chance = minf(0.98, float(active.capture_chance) + 0.15)
		record.observed = true
		expedition.site_records[site] = record
		save_game()
		return {"ok": true, "caught": false, "fled": false, "observed": true, "plant": active.plant,
			"chance": capture_odds(), "capture_chance": capture_odds(),
			"message": "You learned its rhythm. Collection odds rose by 15 points, up to 98%. No kit was used."}
	if method not in ["gather", "entangle"]: return _failure("Choose Observe, Gather, or a supporting vine.")
	if field_kits <= 0: return _failure("No field kits remain. Refill five kits for 20 gathered light, or return home.")
	if method == "entangle":
		if not _has_mature_vine(): return _failure("A mature Vine specimen is needed to steady these roots.")
		if int(resources.sunlight) < 5: return _failure("A supporting vine needs 5 gathered light.")
	var chance: float = capture_odds(method)
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(1, int(active.plant.seed) + int(active.attempts) * 104729 + 26771)
	var caught: bool = rng.randf() < chance
	field_kits -= 1
	if method == "entangle": resources.sunlight -= 5
	active.attempts = int(active.attempts) + 1
	record.attempts = active.attempts
	if caught:
		var p: Dictionary = active.plant.duplicate(true)
		p.id = _new_id()
		p.mature = true
		p.ready_at = int(Time.get_unix_time_from_system())
		p.origin["collected_at"] = int(Time.get_unix_time_from_system())
		_add_plant(p)
		expedition.captures += 1
		expedition.collected_sites.append(site)
		expedition.site_records[site] = record
		expedition.active_encounter = {}
		save_game()
		return {"ok": true, "caught": true, "fled": false, "plant": p, "chance": chance,
			"message": "%s joined your living collection. Its wild genes are ready to battle, display, and breed." % p.name}
	var fled: bool = rng.randf() < 0.25
	record.fled = fled
	expedition.site_records[site] = record
	var p: Dictionary = active.plant
	if fled: expedition.active_encounter = {}
	save_game()
	return {"ok": true, "caught": false, "fled": fled, "plant": p, "chance": chance,
		"message": "The plant withdrew below the soil. This patch will regrow next field day." if fled else "The cutting did not take. The wild plant remains; you may try another field kit."}

func leave_wild_encounter() -> void:
	if expedition.is_empty(): return
	expedition.active_encounter = {}
	save_game()

func restock_field_kits() -> Dictionary:
	if int(resources.sunlight) < 20: return _failure("Five field kits need 20 gathered light. Garden rewards replenish it.")
	resources.sunlight -= 20
	field_kits += 5
	save_game()
	return {"ok": true, "message": "Field satchel refilled: +5 kits for 20 gathered light.", "kits": field_kits}

func field_status() -> Dictionary:
	if expedition.is_empty(): expedition = _default_expedition()
	return {"kits": field_kits, "field_kits": field_kits, "steps": expedition.steps,
		"encounters": expedition.encounters, "captures": expedition.captures,
		"discovered_biomes": expedition.discovered_biomes.duplicate(),
		"visited_landmarks": expedition.get("visited_landmarks",[]).duplicate(),
		"active_encounter": expedition.active_encounter, "chance": capture_odds(),
		"can_entangle": _has_mature_vine()}

func save_game() -> void:
	var payload: Dictionary = {
		"version": SAVE_VERSION, "plants": plants, "bed": bed,
		"display_bed": display_bed, "resources": resources, "market":market,
		"seed_bank": seed_bank, "wins": wins, "battles": battles,
		"fruit_inventory":fruit_inventory,"fruit_crops":fruit_crops,"pollinations":pollinations,"reproduction_counter":reproduction_counter,
		"discovered": discovered, "claimed": claimed, "plant_order": plant_order,
		"collection_claimed": collection_claimed, "collection_seen": collection_seen,
		"field_kits": field_kits, "expedition": expedition,
		"last_daily": last_daily, "last_seed_collection": last_seed_collection,
		"id_counter": id_counter
	}
	# Write a temporary file, then replace the save, so an interrupted write is recoverable.
	var file: FileAccess = FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		push_warning("Could not save the conservatory: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(payload))
	file.close()
	var absolute_path: String = ProjectSettings.globalize_path(save_path)
	var backup_path: String = absolute_path.get_basename() + ".backup.json"
	if FileAccess.file_exists(absolute_path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		DirAccess.rename_absolute(absolute_path, backup_path)
	DirAccess.rename_absolute(absolute_path + ".tmp", absolute_path)

func load_game() -> bool:
	var payload: Variant = _read_save(save_path)
	if not _valid_save(payload):
		payload = _read_save(save_path.get_basename() + ".backup.json")
	if not _valid_save(payload):
		return false
	plants = payload.plants
	bed = payload.bed
	display_bed = payload.display_bed
	resources = payload.resources
	market = payload.get("market",Market.default_market())
	seed_bank = payload.seed_bank
	wins = int(payload.get("wins", 0))
	battles = int(payload.get("battles", 0))
	discovered = payload.get("discovered", [])
	claimed = payload.get("claimed", [])
	collection_claimed = payload.get("collection_claimed", [])
	collection_seen = payload.get("collection_seen", {})
	field_kits = maxi(0, int(payload.get("field_kits", 12)))
	expedition = _normalise_expedition(payload.get("expedition", {}))
	plant_order = payload.get("plant_order", plants.keys())
	last_daily = int(payload.get("last_daily", 0))
	last_seed_collection = int(payload.get("last_seed_collection", 0))
	id_counter = int(payload.get("id_counter", plants.size()))
	fruit_inventory = payload.get("fruit_inventory",[])
	fruit_crops = payload.get("fruit_crops",{})
	pollinations = payload.get("pollinations",{})
	reproduction_counter = maxi(0,int(payload.get("reproduction_counter",0)))
	for fruit: Dictionary in fruit_inventory: _recover_fruit_counter(str(fruit.id))
	for batch: Dictionary in pollinations.values(): _recover_fruit_counter(str(batch.id))
	for seed_data: Dictionary in seed_bank: _recover_fruit_counter(str(seed_data.get("id","")))
	_ready_reproduction.clear()
	# Optional fields migrate the original V1 archive in place. Reconstruct old
	# mixed ancestry from actual parents instead of guessing from dominant type.
	var memo: Dictionary = {}
	for id: String in plant_order:
		Care.initialize(plants[id])
		plants[id]["life_age"] = maxf(0.0,float(plants[id].get("life_age",0.0)))
		plants[id]["withered"] = bool(plants[id].get("withered",false))
		var composition: Dictionary = _lineage_composition(plants[id],memo,{})
		plants[id]["lineage_mix"] = composition
		plants[id]["hybrid"] = composition.size()>1
		if not plants[id].has("lineage_name"): plants[id]["lineage_name"] = " × ".join(composition.keys())
		_ensure_natural_crop(id)
	collection_progress()
	tick_growth()
	return true

func _read_save(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return parser.data

func _valid_save(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	if int(data.get("version", 0)) != SAVE_VERSION:
		return false
	if not data.get("plants", null) is Dictionary or not data.get("resources", null) is Dictionary:
		return false
	if data.has("market") and not Market.valid_market(data.market): return false
	if not data.get("bed", null) is Array or data.bed.size() != 9:
		return false
	if not data.get("display_bed", null) is Array or data.display_bed.size() != 6:
		return false
	if not data.get("seed_bank", null) is Array or data.plants.is_empty():
		return false
	if not data.get("plant_order", null) is Array:
		return false
	for entry: Variant in data.plant_order:
		if not entry is String or not data.plants.has(entry):
			return false
		if not data.plants[entry] is Dictionary: return false
		if bool(data.plants[entry].get("sold",false)): return false
	if data.has("field_kits") and not (data.field_kits is float or data.field_kits is int):
		return false
	if data.has("expedition") and not _valid_expedition(data.expedition):
		return false
	if data.has("collection_claimed") and not data.collection_claimed is Array:
		return false
	if data.has("collection_seen"):
		if not data.collection_seen is Dictionary:
			return false
		for page_name: String in data.collection_seen:
			if not data.collection_seen[page_name] is Array:
				return false
	for key: String in ["sunlight", "agents", "grafts"]:
		if not data.resources.has(key) or not (data.resources[key] is float or data.resources[key] is int):
			return false
	for id: String in data.plants:
		var p: Variant = data.plants[id]
		if not p is Dictionary:
			return false
		for key: String in ["id", "name", "species", "type", "generation", "parents", "seed", "rarity", "genes", "stats", "skills", "mature", "ready_at", "graft_history", "mutation_history", "favorite"]:
			if not p.has(key):
				return false
		if not p.genes is Dictionary or not p.stats is Dictionary or not p.skills is Array or p.skills.is_empty():
			return false
		if not p.parents is Array or not p.graft_history is Array or not p.mutation_history is Array:
			return false
		if not p.mature is bool or not p.favorite is bool:
			return false
		if not (p.ready_at is float or p.ready_at is int):
			return false
		for parent_id: Variant in p.parents:
			if not parent_id is String or not data.plants.has(parent_id):
				return false
		for slot: String in ["color", "accent", "pattern", "petals", "shape", "form", "texture", "glow", "size"]:
			if not p.genes.has(slot) or not p.genes[slot] is Dictionary or not p.genes[slot].has("dominant") or not p.genes[slot].has("recessive"):
				return false
		for stat: String in STAT_NAMES:
			if not p.stats.has(stat) or not (p.stats[stat] is int or p.stats[stat] is float):
				return false
		if p.has("lineage_mix") and not _valid_lineage_mix(p.lineage_mix): return false
		if p.has("inherited_graft_records") and (not p.inherited_graft_records is Array or p.inherited_graft_records.size()>2): return false
		if p.has("life_age") and (not _number(p.life_age) or float(p.life_age)<0): return false
		if p.has("withered") and not p.withered is bool: return false
		if p.has("sold") and not p.sold is bool: return false
		if p.has("sold_at") and not Market._whole(p.sold_at): return false
		if bool(p.get("sold",false)) and not bool(p.get("retired",false)): return false
		if p.has("measurements") and not Care.valid_measurements(p.measurements): return false
		if p.has("care") and not Care.valid_care(p.care): return false
		if p.has("gene_sources") and not _valid_gene_sources(p.gene_sources): return false
	for seed_data: Variant in data.seed_bank:
		if not seed_data is Dictionary: return false
		if seed_data.has("genome") and not _valid_genome(seed_data.genome,data.plants): return false
	if data.has("reproduction_counter") and (not _number(data.reproduction_counter) or float(data.reproduction_counter)<0): return false
	if data.has("fruit_crops"):
		if not data.fruit_crops is Dictionary: return false
		for id: Variant in data.fruit_crops:
			var crop: Variant = data.fruit_crops[id]
			if not id is String or not data.plants.has(id) or not crop is Dictionary or not _number(crop.get("natural_ready_at",null)): return false
			if bool(data.plants[id].get("sold",false)): return false
	var fruit_ids: Dictionary = {}
	if data.has("pollinations"):
		if not data.pollinations is Dictionary: return false
		for id: Variant in data.pollinations:
			var batch: Variant = data.pollinations[id]
			if not id is String or not data.plants.has(id) or not _valid_fruit(batch,data.plants): return false
			if bool(data.plants[id].get("sold",false)): return false
			if str(batch.mother_id)!=id or batch.kind!="hybrid" or not _number(batch.get("ready_at",null)): return false
			if fruit_ids.has(batch.id): return false
			fruit_ids[batch.id] = true
	if data.has("fruit_inventory"):
		if not data.fruit_inventory is Array: return false
		for fruit: Variant in data.fruit_inventory:
			if not _valid_fruit(fruit,data.plants) or not _number(fruit.get("harvested_at",null)): return false
			if fruit_ids.has(fruit.id): return false
			fruit_ids[fruit.id] = true
	for entry: Variant in data.bed + data.display_bed:
		if not entry is String:
			return false
		if not entry.is_empty() and not data.plants.has(entry):
			return false
		if not entry.is_empty() and bool(data.plants[entry].get("sold",false)): return false
	return true

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _recover_fruit_counter(id: String) -> void:
	if not id.begins_with("fruit_"): return
	var digits: String = id.trim_prefix("fruit_").get_slice("_",0)
	if digits.is_valid_int(): reproduction_counter = maxi(reproduction_counter,int(digits))

func _valid_lineage_mix(value: Variant) -> bool:
	if not value is Dictionary or value.is_empty(): return false
	var total: float = 0.0
	for key: Variant in value:
		if not key is String or key not in TYPES or not _number(value[key]) or float(value[key])<=0: return false
		total += float(value[key])
	return total>0.0 and is_finite(total)

func _valid_genome(value: Variant,archive: Dictionary) -> bool:
	if not value is Dictionary: return false
	for key: String in ["id","name","species","type","rarity"]:
		if not value.get(key,null) is String or str(value[key]).is_empty(): return false
	if str(value.type) not in TYPES or not _number(value.get("seed",null)) or not _number(value.get("generation",null)) or int(value.generation)<1: return false
	if not value.get("parents",null) is Array or not value.get("genes",null) is Dictionary or not value.get("stats",null) is Dictionary: return false
	for parent: Variant in value.parents:
		if not parent is String or not archive.has(parent): return false
	for slot: String in ["color","accent","pattern","petals","shape","form","texture","glow","size"]:
		var gene: Variant = value.genes.get(slot,null)
		if not gene is Dictionary or not gene.has("dominant") or not gene.has("recessive"): return false
	for stat: String in STAT_NAMES:
		if not _number(value.stats.get(stat,null)) or float(value.stats[stat])<1: return false
	if not value.get("skills",null) is Array or value.skills.is_empty(): return false
	for skill: Variant in value.skills:
		if not skill is String: return false
	if not value.get("skill_genes",null) is Dictionary or not value.skill_genes.get("dominant",null) is String or not value.skill_genes.get("recessive",null) is String: return false
	for array_key: String in ["graft_history","mutation_history"]:
		if not value.get(array_key,null) is Array: return false
	if not value.get("mature",null) is bool or not value.get("favorite",null) is bool or not _number(value.get("ready_at",null)): return false
	if not _valid_lineage_mix(value.get("lineage_mix",null)): return false
	if value.has("inherited_graft_records") and (not value.inherited_graft_records is Array or value.inherited_graft_records.size()>2): return false
	if value.has("life_age") and (not _number(value.life_age) or float(value.life_age)<0): return false
	if value.has("withered") and not value.withered is bool: return false
	if value.has("measurements") and not Care.valid_measurements(value.measurements): return false
	if value.has("care") and not Care.valid_care(value.care): return false
	if value.has("gene_sources") and not _valid_gene_sources(value.gene_sources): return false
	return true

func _valid_gene_sources(value: Variant) -> bool:
	if not value is Dictionary: return false
	for slot: Variant in value:
		var source: Variant = value[slot]
		if not slot is String or not source is Dictionary: return false
		if not source.get("expressed_origin",null) is String or not source.has("expressed") or not source.has("carried"): return false
		for key: String in ["allele_a","allele_b"]:
			var allele: Variant = source.get(key,null)
			if not allele is Dictionary or not allele.has("value"): return false
			for field: String in ["parent_id","parent_name","allele"]:
				if not allele.get(field,null) is String: return false
	return true

func _valid_fruit(value: Variant,archive: Dictionary) -> bool:
	if not value is Dictionary or not value.get("id",null) is String or str(value.id).is_empty(): return false
	if str(value.get("kind","")) not in ["natural","hybrid"]: return false
	if not value.get("mother_id",null) is String or not archive.has(value.mother_id): return false
	if not value.get("father_id",null) is String or (not str(value.father_id).is_empty() and not archive.has(value.father_id)): return false
	if value.kind=="hybrid" and str(value.father_id).is_empty(): return false
	if not value.get("parent_names",null) is Array or not _number(value.get("generation",null)): return false
	if not _valid_lineage_mix(value.get("lineage_mix",null)): return false
	if not value.get("seeds",null) is Array or value.seeds.size()!=(2 if value.kind=="hybrid" else 1): return false
	for seed_data: Variant in value.seeds:
		if not seed_data is Dictionary or not _valid_genome(seed_data.get("genome",null),archive): return false
	return true
