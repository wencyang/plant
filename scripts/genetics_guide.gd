extends RefCounted
class_name GeneticsGuide
## Read-only explanations and analytical predictions of GardenState's real
## inheritance rules. This guide never rolls gameplay RNG or creates organisms.
const DNA = preload("res://scripts/plant_dna.gd")
const Art = preload("res://scripts/plant_sprite_assets.gd")
const KEYS := ["color","accent","pattern","petals","shape","form","texture","glow","size"]
const LABELS := {"color":"Main color","accent":"Marking color","pattern":"Pattern","petals":"Flower petals","shape":"Leaf and petal shape","form":"Plant shape","texture":"Surface","glow":"Glow","size":"Size","skill":"Battle skill"}
const DEFAULTS := {"color":"829d80","accent":"c4d2a1","pattern":"Solid","petals":5,"shape":"Pointed","form":"Upright","texture":"Matte","glow":"None","size":"Standard"}
const PALETTE := {
	"829d80":"Sage green", "d7a06d":"Warm amber", "9dbcb2":"Silver sage", "aa829b":"Soft mauve",
	"b6c58f":"Lime green", "7fabb0":"Mist blue", "c1a4a0":"Dusty rose", "d2c7a5":"Ivory gold",
	"9c9471":"Olive", "b5beb5":"Pearl gray", "c1b9a0":"Cream", "c4d2a1":"Pale lime",
	"e2c997":"Honey gold", "cfb0b5":"Rose pink", "d5ba8e":"Golden sand", "add7cd":"Sea glass",
	"c275b1":"Orchid pink", "193632":"Deep teal", "e8daca":"Ivory", "6b9368":"Fern green"
}
const SKILL_EFFECTS := {
	"Canopy Shade":"Slows nearby enemy growth with shade.",
	"Bloom Burst":"Gathers flowering energy faster in battle.",
	"Entangle":"Restrains an enemy and slows its next action.",
	"Root Network":"Restores vitality through connected roots.",
	"Spore Cloud":"Spreads damage to a nearby enemy.",
	"Toxin Seep":"Leaves a toxin that damages the enemy over time.",
	"Parasitic Tendril":"Drains an enemy and restores the plant's vitality.",
	"Devour":"Consumes a weakened enemy and restores vitality."
}
const STAT_LABELS := {"vitality":"Vitality","growth":"Growth speed","toxin":"Toxin strength","root":"Root strength","bloom":"Flowering energy","shade":"Shade strength"}
const STAT_EFFECTS := {
	"vitality":"How much damage the plant can survive.",
	"growth":"How quickly the plant acts in battle.",
	"toxin":"Strength of toxin and spore effects.",
	"root":"Strength of entangling, roots, and draining.",
	"bloom":"How quickly flowering energy gathers.",
	"shade":"How strongly the plant suppresses enemy growth."
}

static func color_for(value: Variant) -> Color:
	if value is Color: return value
	return Color.from_string(str(value),Color("829d80"))

static func color_name(value: Variant) -> String:
	var color: Color = color_for(value)
	var code: String = color.to_html(false)
	if PALETTE.has(code): return str(PALETTE[code])
	var nearest: String = "829d80"
	var distance: float = INF
	for candidate: String in PALETTE:
		var swatch := Color(candidate)
		var difference: float = pow(color.r-swatch.r,2)+pow(color.g-swatch.g,2)+pow(color.b-swatch.b,2)
		if difference<distance: distance=difference; nearest=candidate
	return str(PALETTE[nearest])

static func trait_value(key: String,value: Variant) -> String:
	if value==null or str(value) in ["","?"]: return "Unknown"
	if key in ["color","accent"]: return color_name(value)
	if key=="petals": return "%d petals" % int(value)
	if key=="glow" and str(value)=="None": return "No glow"
	if key=="size": return {"Small":"Small plant","Standard":"Medium plant","Large":"Large plant"}.get(str(value),str(value))
	if key=="form": return {"Upright":"Upright","Trailing":"Trailing","Rosette":"Low rosette","Climbing":"Climbing"}.get(str(value),str(value))
	if key=="pattern" and str(value)=="Solid": return "Natural / no extra pattern"
	return str(value)

static func _gene(p: Dictionary,key: String) -> Dictionary:
	if key=="skill":
		var skills: Array = p.get("skills",["Unknown"])
		var first: String = str(skills[0]) if not skills.is_empty() else "Unknown"
		return p.get("skill_genes",{"dominant":first,"recessive":first})
	var fallback: Variant = DEFAULTS.get(key,"Unknown")
	var value: Variant = p.get("genes",{}).get(key,{"dominant":fallback,"recessive":fallback})
	return value if value is Dictionary else {"dominant":value,"recessive":value}

static func _normalized(key: String,value: Variant) -> Variant:
	if key in ["color","accent"]: return color_for(value).to_html(false)
	if key=="petals": return int(value)
	return value

static func _add(distribution: Dictionary,key: String,value: Variant,probability: float) -> void:
	if probability<=0.000000001: return
	var normalized: Variant = _normalized(key,value)
	var identity: String = DNA.canonical(normalized)
	if not distribution.has(identity):
		var entry: Dictionary = {"value":trait_value(key,normalized),"raw":normalized,"probability":0.0}
		if key in ["color","accent"]:
			entry["color"] = color_for(normalized)
			entry["html"] = str(normalized)
		distribution[identity] = entry
	distribution[identity].probability = float(distribution[identity].probability)+probability

static func _sorted(distribution: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Dictionary in distribution.values(): result.append(value)
	result.sort_custom(func(a: Dictionary,b: Dictionary):
		if not is_equal_approx(float(a.probability),float(b.probability)): return float(a.probability)>float(b.probability)
		return str(a.value)+DNA.canonical(a.raw)<str(b.value)+DNA.canonical(b.raw))
	return result

static func transmission(p: Dictionary,key: String) -> Array[Dictionary]:
	var gene: Dictionary = _gene(p,key)
	var outcomes: Dictionary = {}
	_add(outcomes,key,gene.get("dominant",DEFAULTS.get(key,"Unknown")),0.5)
	_add(outcomes,key,gene.get("recessive",gene.get("dominant",DEFAULTS.get(key,"Unknown"))),0.5)
	return _sorted(outcomes)

static func _host_has_flowers(p: Dictionary) -> bool:
	if str(p.get("type","Leaf"))=="Bloom": return true
	for organ: Dictionary in Art.composition_for(p):
		# A grafted flower uses donor petal genes; it does not express the host's
		# otherwise dormant petal-count gene.
		if organ.type=="Bloom" and not bool(organ.get("graft",false)): return true
	return false

static func _explanation(p: Dictionary,key: String,shown: Variant) -> String:
	match key:
		"color":
			if float(p.get("life_age",0))>=1200+float(p.get("care",{}).get("life_bonus_seconds",0)) or bool(p.get("withered",false)): return "Aging can bronze or dry the tissue without changing this inherited color."
			return "Controls the main tissue color. It can blend with the other parent's pigment."
		"accent": return "Colors inherited markings and glowing tissue; easiest to see on patterned or glowing plants."
		"pattern": return "Adds inherited markings on top of the plant's natural leaf and flower detail."
		"petals":
			if _host_has_flowers(p): return "Inherited flowers show %d petals." % int(shown)
			if str(_gene(p,"pattern").get("dominant","Solid"))=="Starburst": return "Makes %d rays in the starburst marking; flowering descendants can use it for their petals." % int(shown)
			return "Stored for flowering descendants. This plant does not currently express its own flower-petal gene."
		"shape": return "Changes the outline and edges of leaves and petals."
		"form": return "Changes whether the plant grows tall, spreads low, or trails."
		"texture": return {"Matte":"A muted surface with little shine.","Waxy":"A waxy sheen catches the light.","Translucent":"Pale, light-filled tissue with softer color.","Fibrous":"Fine fibers make the tissue look rougher.","Wet":"A stronger damp sheen catches the light."}.get(str(shown),"Controls tissue sheen and surface detail.")
		"glow": return "No inherited glow is expressed." if str(shown)=="None" else "Adds faint living light inside the plant's tissue."
		"size": return "Changes how much space the plant occupies in the garden."
		"skill":
			var effects: Array[String] = []
			for skill: String in p.get("skills",[]): effects.append(str(SKILL_EFFECTS.get(skill,"An inherited ability used in battle.")))
			return " ".join(effects)
	return ""

static func hidden_goal(p: Dictionary,key: String = "pattern") -> String:
	if bool(p.get("withered",false)): return "This plant has withered. Its traits can continue through stored seeds."
	var gene: Dictionary = _gene(p,key)
	var shown: Variant = gene.get("dominant",DEFAULTS.get(key,"Unknown"))
	var carried: Variant = gene.get("recessive",shown)
	if _normalized(key,shown)==_normalized(key,carried):
		return "Both copies are %s. This plant always passes that allele; the other parent still affects what the child shows." % trait_value(key,shown)
	return "To bring out %s, choose a mate that also carries or shows %s. A mate with two copies gives the strongest chance." % [trait_value(key,carried),trait_value(key,carried)]

static func _parent_name(p: Dictionary,id: String,fallback: String) -> String:
	for source: Dictionary in p.get("gene_sources",{}).values():
		for role: String in ["allele_a","allele_b"]:
			var allele: Dictionary = source.get(role,{})
			if str(allele.get("parent_id",""))==id and not str(allele.get("parent_name","")).is_empty(): return str(allele.parent_name)
	return str(p.get("pedigree",{}).get(id,{}).get("name",fallback))

static func _hidden_origin(p: Dictionary,key: String,a: Dictionary,b: Dictionary) -> String:
	var hidden: Variant = _gene(p,key).get("recessive","Unknown")
	var from_a: bool = _normalized(key,hidden)==_normalized(key,a.get("value","Unknown"))
	var from_b: bool = _normalized(key,hidden)==_normalized(key,b.get("value","Unknown"))
	if from_a and from_b: return "Both parents passed %s." % trait_value(key,hidden)
	if from_a or from_b: return "The carried %s came from %s." % [trait_value(key,hidden),a.get("parent_name","Mother") if from_a else b.get("parent_name","Father")]
	return ""

static func origin_note(p: Dictionary,key: String) -> String:
	var source: Dictionary = p.get("skill_sources",{}) if key=="skill" else p.get("gene_sources",{}).get(key,{})
	if source.is_empty(): return "The exact parental source was not recorded." if not p.get("parents",[]).is_empty() else "A founding trait, before this lineage was crossed."
	if key=="skill": return "Skill alleles from %s: %s; from %s: %s." % [_parent_name(p,str(source.get("parent_a","")),"Mother"),str(source.get("allele_a","Unknown")),_parent_name(p,str(source.get("parent_b","")),"Father"),str(source.get("allele_b","Unknown"))]
	var origin: String = str(source.get("expressed_origin",""))
	if origin=="founder": return "A founding trait, before this lineage was crossed."
	if origin=="mutation": return "A mutation created the shown trait; the earlier trait remains carried."
	var a: Dictionary = source.get("allele_a",{})
	var b: Dictionary = source.get("allele_b",{})
	var mother: String = str(a.get("parent_name","Mother"))
	var father: String = str(b.get("parent_name","Father"))
	if origin=="blend": return ("The shown color blends pigments passed by %s and %s. " % [mother,father])+_hidden_origin(p,key,a,b)
	if origin=="combination": return ("Patterns passed by %s and %s formed a new combination. " % [mother,father])+_hidden_origin(p,key,a,b)
	if origin in ["a","b"]:
		var gene: Dictionary = _gene(p,key)
		var hidden: Variant = gene.get("recessive",gene.get("dominant","Unknown"))
		return "Shown trait from %s; %s carried from %s." % [mother if origin=="a" else father,trait_value(key,hidden),father if origin=="a" else mother]
	return "Inherited from this plant's recorded parents."

static func trait_summary(p: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if p.is_empty(): return result
	var keys: Array = KEYS.duplicate()
	keys.append("skill")
	for key: String in keys:
		var gene: Dictionary = _gene(p,key)
		var shown: Variant = gene.get("dominant",DEFAULTS.get(key,"Unknown"))
		var hidden: Variant = gene.get("recessive",shown)
		var applies: bool = true
		if key=="petals": applies = _host_has_flowers(p) or str(_gene(p,"pattern").get("dominant","Solid"))=="Starburst"
		if key=="accent": applies = str(_gene(p,"pattern").get("dominant","Solid"))!="Solid" or str(_gene(p,"glow").get("dominant","None"))!="None" or str(_gene(p,"texture").get("dominant","Matte"))=="Translucent"
		var entry: Dictionary = {"key":key,"label":LABELS[key],"visible":trait_value(key,shown),"hidden":trait_value(key,hidden),"explanation":_explanation(p,key,shown),"appearance_applies":applies,"expressed_raw":shown,"carried_raw":hidden,"has_hidden":_normalized(key,shown)!=_normalized(key,hidden),"is_fixed":_normalized(key,shown)==_normalized(key,hidden),"carried_active":key=="skill" and p.get("skills",[]).has(str(hidden)),"transmission":transmission(p,key),"origin":origin_note(p,key),"hint":hidden_goal(p,key)}
		if key in ["color","accent"]: entry["visible_color"]=color_for(shown); entry["hidden_color"]=color_for(hidden)
		if key=="skill": entry.visible = " + ".join(PackedStringArray(p.get("skills",[str(shown)])))
		if key=="petals" and not _host_has_flowers(p) and applies: entry.visible = "%d starburst rays" % int(shown)
		result.append(entry)
	return result

static func _trait_preview(a: Dictionary,b: Dictionary,key: String,generation: int) -> Dictionary:
	var maternal: Array[Dictionary] = transmission(a,key)
	var paternal: Array[Dictionary] = transmission(b,key) if b.get("genes",{}).has(key) else transmission(a,key)
	var shown: Dictionary = {}
	var hidden: Dictionary = {}
	for allele_a: Dictionary in maternal:
		for allele_b: Dictionary in paternal:
			var probability: float = float(allele_a.probability)*float(allele_b.probability)
			_add(hidden,key,allele_a.raw,probability*0.5)
			_add(hidden,key,allele_b.raw,probability*0.5)
			var normal: float = 1.0
			if key in ["color","accent"]:
				normal = 0.85
				var blend: String = color_for(allele_a.raw).lerp(color_for(allele_b.raw),0.5).to_html(false)
				_add(shown,key,blend,probability*0.15)
			elif key=="pattern" and generation>=3 and allele_a.raw!=allele_b.raw:
				normal = 0.92
				_add(shown,key,"Starburst",probability*0.04)
				_add(shown,key,"Bicolor Ring",probability*0.04)
			_add(shown,key,allele_a.raw,probability*normal*0.5)
			_add(shown,key,allele_b.raw,probability*normal*0.5)
	return {"key":key,"label":LABELS[key],"outcomes":_sorted(shown),"hidden_outcomes":_sorted(hidden),"parent_a":maternal,"parent_b":paternal}

static func _add_skill(distribution: Dictionary,skills: Array,probability: float) -> void:
	var ordered: Array = skills.duplicate()
	ordered.sort()
	var identity: String = DNA.canonical(ordered)
	if not distribution.has(identity): distribution[identity] = {"value":" + ".join(PackedStringArray(ordered)),"raw":ordered,"probability":0.0}
	distribution[identity].probability = float(distribution[identity].probability)+probability

static func skill_outcomes(a: Dictionary,b: Dictionary) -> Array[Dictionary]:
	var distribution: Dictionary = {}
	for sa: Dictionary in transmission(a,"skill"):
		for sb: Dictionary in transmission(b,"skill"):
			var probability: float = float(sa.probability)*float(sb.probability)
			if sa.raw==sb.raw: _add_skill(distribution,[sa.raw],probability)
			else:
				_add_skill(distribution,[sa.raw],probability*0.35)
				_add_skill(distribution,[sb.raw],probability*0.35)
				_add_skill(distribution,[sa.raw,sb.raw],probability*0.30)
	# Skill grafts are evaluated after gene expression in the actual model. Each
	# may add one missing skill, but no plant can express more than three.
	for parent: Dictionary in [a,b]:
		var records: Array = parent.get("graft_history",[]).duplicate()
		records.append_array(parent.get("inherited_graft_records",[]))
		for record: Dictionary in records:
			if str(record.get("trait",""))!="skill" or str(record.get("value","")).is_empty(): continue
			var updated: Dictionary = {}
			for outcome: Dictionary in distribution.values():
				var skills: Array = outcome.raw
				if skills.size()>=3 or skills.has(str(record.value)): _add_skill(updated,skills,float(outcome.probability))
				else:
					_add_skill(updated,skills,float(outcome.probability)*0.8)
					var added: Array = skills.duplicate()
					added.append(str(record.value))
					_add_skill(updated,added,float(outcome.probability)*0.2)
			distribution = updated
	return _sorted(distribution)

static func _lineage(p: Dictionary) -> Dictionary:
	var mix: Dictionary = p.get("lineage_mix",{str(p.get("type","Leaf")):1.0})
	if mix.is_empty(): mix={str(p.get("type","Leaf")):1.0}
	var result: Dictionary = {}
	var total: float = 0.0
	for value: Variant in mix.values(): total+=float(value)
	for key: String in mix: result[key]=float(mix[key])/maxf(0.000001,total)
	return result

static func cross_preview(a: Dictionary,b: Dictionary) -> Dictionary:
	if a.is_empty() or b.is_empty(): return {"valid":false,"generation":0,"traits":[],"stats":[],"lineage_mix":{},"skill_outcomes":[],"notes":[]}
	var generation: int = maxi(int(a.get("generation",1)),int(b.get("generation",1)))+1
	var traits: Array[Dictionary] = []
	for key: String in KEYS: traits.append(_trait_preview(a,b,key,generation))
	var stats: Array[Dictionary] = []
	for key: String in ["vitality","growth","toxin","root","bloom","shade"]:
		var average: float = (float(a.get("stats",{}).get(key,0))+float(b.get("stats",{}).get(key,0)))*0.5
		stats.append({"key":key,"label":STAT_LABELS[key],"expected":average,"min":maxi(1,roundi(average*0.9)),"max":maxi(1,roundi(average*1.1)),"explanation":STAT_EFFECTS[key]})
	var mix: Dictionary = {}
	for parent: Dictionary in [a,b]:
		var composition: Dictionary = _lineage(parent)
		for key: String in composition: mix[key]=float(mix.get(key,0))+float(composition[key])*0.5
	var notes: Array[String] = ["These percentages describe what each seed may show. Passing a hidden allele is different from showing it.","Each seed is a separate recombination; two seeds are not guaranteed to cover both outcomes."]
	if generation>=3: notes.append("Different inherited pattern alleles can combine into a rare pattern from the third generation onward.")
	return {"valid":true,"generation":generation,"traits":traits,"stats":stats,"lineage_mix":mix,"skill_outcomes":skill_outcomes(a,b),"notes":notes}
