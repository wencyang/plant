extends RefCounted
class_name GardenFair
const Care = preload("res://scripts/plant_care.gd")

static func default_fair() -> Dictionary:
	return {"claims":{},"ribbons":{}}

static func day() -> int:
	return floori(Time.get_unix_time_from_system()/86400.0)

static func _reward(coins: int,light: int,grafts: int = 0,agents: int = 0) -> Dictionary:
	return {"coins":coins,"sunlight":light,"grafts":grafts,"agents":agents}

static func requests(day_override: int = -1) -> Array:
	var today: int = day_override if day_override>=0 else day()
	var ordinary: Array = [
		{"slug":"striped","title":"A little stripe story","goal":"Show a plant that shows or carries Striped pattern DNA.","criterion":"pattern","value":"Striped"},
		{"slug":"spotted","title":"Spots for the sketchbook","goal":"Show a plant that shows or carries Spotted pattern DNA.","criterion":"pattern","value":"Spotted"},
		{"slug":"tall","title":"Reach for the bunting","goal":"Show a mature plant at least 60 cm tall. Care-grown height counts.","criterion":"height","value":60.0},
		{"slug":"sturdy","title":"A satisfyingly sturdy plant","goal":"Show a mature plant weighing at least 240 g. Compost-grown weight counts.","criterion":"weight","value":240.0},
		{"slug":"large","title":"Room to unfurl","goal":"Show a plant that shows or carries Large body-size DNA.","criterion":"size","value":"Large"},
		{"slug":"waxy","title":"A leaf with a lovely finish","goal":"Show a plant that shows or carries Waxy surface DNA.","criterion":"texture","value":"Waxy"}
	]
	var journeys: Array = [
		{"slug":"wild","title":"A story from the wild","goal":"Show a plant collected from a wild patch. Find one outdoors and bring it home.","criterion":"wild"},
		{"slug":"two_parent","title":"Meet the next generation","goal":"Show a mature offspring with two recorded parents. Pollinate, harvest, collect the seeds, plant and grow one.","criterion":"two_parent"},
		{"slug":"mixed","title":"Two families, one little plant","goal":"Show a mature plant with at least two types in its inherited ancestry. Cross plants from different families.","criterion":"mixed"},
		{"slug":"seed","title":"From a seed you planted","goal":"Show a plant you planted from seed and grew to maturity.","criterion":"seed"},
		{"slug":"graft","title":"A living collaboration","goal":"Show a mature plant carrying a successful graft. The donor and host both stay in your collection.","criterion":"graft"},
		{"slug":"generation","title":"A family keeps growing","goal":"Show a mature generation-3 or later plant. Grow a child, then use it in the next cross.","criterion":"generation","value":3}
	]
	var welcome: Dictionary = {"slug":"welcome","title":"Bring your favorite grown plant","npc":"Mira, the seed librarian","description":"Mira is setting out tea and would love to meet one of your plants. You keep every plant you show.","goal":"Show any living, mature plant from your garden.","criterion":"any","reward":_reward(8,20)}
	var ordinary_request: Dictionary = ordinary[posmod(today,ordinary.size())].duplicate(true)
	ordinary_request["npc"]="Jun, the botanical illustrator"
	ordinary_request["description"]="Jun is gathering ideas for today's illustrated garden page. Carried DNA counts when the request says so."
	ordinary_request["reward"]=_reward(14,25)
	var journey: Dictionary = journeys[posmod(today*5+1,journeys.size())].duplicate(true)
	journey["npc"]="Pip, the wandering gardener"
	journey["description"]="Pip trades travel stories for growing stories. Bring a plant with a story of its own."
	journey["reward"]=_reward(24,35,1 if posmod(today,2)==0 else 0,1 if posmod(today,2)==1 else 0)
	var result: Array = [welcome,ordinary_request,journey]
	for request: Dictionary in result:
		request["key"]="daily:%d:%s" % [today,request.slug]
		request["day"]=today
		request["day_label"]=Time.get_datetime_string_from_unix_time(today*86400).left(10)+" UTC"
	return result

static func _alleles(p: Dictionary,key: String,value: Variant) -> bool:
	var pair: Dictionary = p.get("genes",{}).get(key,{})
	return pair.get("dominant")==value or pair.get("recessive")==value

static func mixed_ancestry(p: Dictionary) -> bool:
	var count: int = 0
	for share: Variant in p.get("lineage_mix",{}).values():
		if float(share)>=0.065: count+=1
	return count>=2

static func meets(request: Dictionary,p: Dictionary) -> bool:
	match str(request.get("criterion","")):
		"any": return true
		"pattern","size","texture": return _alleles(p,str(request.criterion),request.value)
		"height": return float(Care.measurements(p).height_cm)>=float(request.value)
		"weight": return float(Care.measurements(p).weight_g)>=float(request.value)
		"wild": return p.get("origin",{}).get("kind","")=="wild"
		"seed": return p.get("origin",{}).get("kind","")=="seed"
		"two_parent": return p.get("parents",[]).size()>=2 and int(p.get("generation",1))>=2
		"mixed": return mixed_ancestry(p)
		"generation": return int(p.get("generation",1))>=int(request.get("value",3))
		"graft":
			for record: Variant in p.get("graft_history",[])+p.get("inherited_graft_records",[]):
				if record is Dictionary and bool(record.get("success",true)): return true
			return false
	return false

static func mismatch(request: Dictionary,p: Dictionary) -> String:
	match str(request.get("criterion","")):
		"pattern": return "This plant neither shows nor carries the requested pattern. Check its readable DNA or choose a matching parent."
		"size": return "This plant does not carry Large body-size DNA. Look for a matching wild plant or breed from a Large parent."
		"texture": return "This plant does not carry Waxy surface DNA. Check another plant's visible and carried traits."
		"height": return "This plant is %.1f cm tall; this request needs %.0f cm. Try a taller plant or growth fertilizer." % [float(Care.measurements(p).height_cm),float(request.value)]
		"weight": return "This plant weighs %.1f g; this request needs %.0f g. Try a sturdier plant or rich compost." % [float(Care.measurements(p).weight_g),float(request.value)]
		"wild": return "This plant was not collected in the wild. Go outdoors, collect a wild plant, and bring it home."
		"seed": return "This plant was not grown from a seed you planted. Plant a seed in an empty plot and let it mature."
		"two_parent": return "This plant needs two recorded parents. Pollinate two plants, harvest their fruit, collect a seed, then plant and grow it."
		"mixed": return "This plant has one inherited family. Pollinate parents from different plant types, then plant and grow their offspring."
		"generation": return "This plant is generation %d; this request needs generation %d. Grow an offspring and use it in another cross." % [int(p.get("generation",1)),int(request.get("value",3))]
		"graft": return "This plant has no living graft. Graft a compatible donor onto a mature host, then show the host."
	return "Choose a plant that matches this request."

static func ribbon_definitions() -> Array:
	return [
		{"key":"first_sprout","title":"First sprout ribbon","description":"Raise a plant from a seed you planted.","goal":"Grow one planted seed to maturity.","criterion":"seed","target":1,"reward":_reward(12,25)},
		{"key":"first_cross","title":"Family storyteller ribbon","description":"Complete the full two-parent breeding loop.","goal":"Grow a mature offspring with two recorded parents.","criterion":"two_parent","target":1,"reward":_reward(20,35,1)},
		{"key":"mixed_roots","title":"Mixed roots ribbon","description":"Bring different plant families together through inheritance.","goal":"Grow a mature plant with at least two inherited plant types.","criterion":"mixed","target":1,"reward":_reward(24,40)},
		{"key":"third_generation","title":"A growing family ribbon","description":"Carry a lineage into a second round of breeding.","goal":"Grow a generation-3 or later plant to maturity.","criterion":"generation","value":3,"target":1,"reward":_reward(35,45,0,1)},
		{"key":"wild_friend","title":"Wild welcome ribbon","description":"Give a wild plant a place in your garden.","goal":"Collect one wild plant and keep it in your living collection.","criterion":"wild","target":1,"reward":_reward(18,25,1)},
		{"key":"pattern_collector","title":"Pattern sketchbook ribbon","description":"Discover four different visible patterns across your plants.","goal":"Record 4 different visible patterns in your collection.","criterion":"patterns","target":4,"reward":_reward(30,40,0,1)},
		{"key":"founding_atlas","title":"Seven families ribbon","description":"Discover every founding plant lineage.","goal":"Discover all 7 founding species.","criterion":"species","target":7,"reward":_reward(50,60,1,1)}
	]

static func valid_fair(value: Variant,archive: Dictionary) -> bool:
	if not value is Dictionary or not value.get("claims") is Dictionary or not value.get("ribbons") is Dictionary: return false
	for key: Variant in value.claims:
		var claim: Variant = value.claims[key]
		if not key is String or not claim is Dictionary: return false
		if not _whole(claim.get("day")) or int(claim.day)>3652059 or not _whole(claim.get("at")) or not claim.get("plant_id") is String or not archive.has(claim.plant_id): return false
		var valid_key: bool = false
		for definition: Dictionary in requests(int(claim.day)):
			if key==definition.key and _same_reward(claim.get("rewards"),definition.reward): valid_key=true; break
		if not valid_key: return false
	for key: Variant in value.ribbons:
		var record: Variant = value.ribbons[key]
		if not key is String or not record is Dictionary or not _whole(record.get("at")): return false
		var found: bool = false
		for definition: Dictionary in ribbon_definitions():
			if key==definition.key and _same_reward(record.get("rewards"),definition.reward): found=true; break
		if not found: return false
	return true

static func _same_reward(value: Variant,expected: Dictionary) -> bool:
	if not value is Dictionary or value.size()!=expected.size(): return false
	for key: String in expected:
		if not _whole(value.get(key)) or int(value[key])!=int(expected[key]): return false
	return true

static func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=0 and float(value)==floorf(float(value)) and float(value)<=9007199254740991.0
