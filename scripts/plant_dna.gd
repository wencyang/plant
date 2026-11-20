extends RefCounted
class_name PlantDNA
## A readable game genome. Every base is a deterministic encoding of a real
## stored allele; the individual marker uses the organism's stable anatomy seed.
const VISUAL_LOCI := ["color","accent","pattern","petals","shape","form","texture","glow","size"]
const LABELS := {"color":"Primary pigment","accent":"Accent pigment","pattern":"Tissue pattern","petals":"Petal count","shape":"Leaf & petal shape","form":"Growth form","texture":"Tissue surface","glow":"Bioluminescence","size":"Body size","skill":"Inherited skill","vitality":"Vitality","growth":"Growth","toxin":"Toxin","root":"Root strength","bloom":"Bloom","shade":"Shade"}
const STAT_LOCI := ["vitality","growth","toxin","root","bloom","shade"]

static func canonical(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var items: Array[String] = []
		for key: Variant in keys: items.append(JSON.stringify(str(key))+":"+canonical(value[key]))
		return "{"+",".join(items)+"}"
	if value is Array:
		var items: Array[String] = []
		for item: Variant in value: items.append(canonical(item))
		return "["+",".join(items)+"]"
	if value is int or value is float:
		var number: float = float(value)
		return str(int(round(number))) if is_equal_approx(number,round(number)) else "%.8f" % number
	return JSON.stringify(value)

static func codons(value: Variant, count: int = 16) -> String:
	var digest: String = canonical(value).sha256_text()
	var letters := "ACGT"
	var result: String = ""
	for index in range(count):
		var nibble: int = digest.substr((index/2)%digest.length(),1).hex_to_int()
		result += letters[(nibble/4 if index%2==0 else nibble%4)%4]
	return result

static func phenotype(key: String,expressed: Variant,p: Dictionary) -> String:
	match key:
		"color": return "Main tissue pigment #%s" % str(expressed)
		"accent": return "Veins, flower centers, and markings #%s" % str(expressed)
		"pattern": return "Visible tissue marking: %s" % str(expressed)
		"petals": return "Flowers express %d petals" % int(expressed)
		"shape": return "Leaf and petal edges: %s" % str(expressed)
		"form": return "Growth silhouette: %s" % str(expressed)
		"texture": return "Tissue sheen and surface: %s" % str(expressed)
		"glow": return "Living glow: %s" % str(expressed)
		"size": return "Visible plant size: %s" % str(expressed)
		"skill": return "Expressed skills: %s" % " / ".join(PackedStringArray(p.get("skills",[])))
		_: return "%s: %d" % [str(LABELS.get(key,key)),int(expressed)]

static func profile(p: Dictionary) -> Dictionary:
	if p.is_empty(): return {"code":"","sequence":"","loci":[]}
	var genes: Dictionary = p.get("genes",{})
	var inherited: Dictionary = p.get("gene_sources",{})
	var loci: Array[Dictionary] = []
	var sequence: String = codons(["individual",int(p.get("seed",1))],24)
	var ancestry: Dictionary = p.get("lineage_mix",{str(p.get("type","Leaf")):1.0})
	var ancestry_names: Array = ancestry.keys()
	ancestry_names.sort()
	var ancestry_parts: Array[String] = []
	for type_name: String in ancestry_names: ancestry_parts.append("%s %d%%" % [type_name,roundi(float(ancestry[type_name])*100)])
	var anatomy_bases: String = codons(["anatomy",p.get("type","Leaf"),ancestry],32)
	loci.append({"key":"lineage","label":"Anatomy & lineage","expressed":str(p.get("type","Leaf")),"carried":"","sequence":anatomy_bases,"phenotype":"Combined anatomy: %s" % " · ".join(ancestry_parts),"origins":{"ancestry":true} if not p.get("parents",[]).is_empty() else {},"diploid":false})
	sequence += anatomy_bases
	for key: String in VISUAL_LOCI:
		var gene: Dictionary = genes.get(key,{"dominant":"?","recessive":"?"})
		var expressed: Variant = gene.get("dominant","?")
		var carried: Variant = gene.get("recessive",expressed)
		var bases: String = codons([key,expressed])+codons([key,carried])
		var origins: Dictionary = inherited.get(key,{"legacy_unrecorded":true} if not p.get("parents",[]).is_empty() else {})
		loci.append({"key":key,"label":LABELS[key],"expressed":canonical(expressed) if expressed is int or expressed is float else str(expressed),"carried":canonical(carried) if carried is int or carried is float else str(carried),"sequence":bases,"phenotype":phenotype(key,expressed,p),"origins":origins,"diploid":true})
		sequence += bases
	var skill: Dictionary = p.get("skill_genes",{})
	var skill_a: String = str(skill.get("dominant",p.get("skills",["?"])[0]))
	var skill_b: String = str(skill.get("recessive",skill_a))
	var skill_bases: String = codons(["skill",skill_a])+codons(["skill",skill_b])
	loci.append({"key":"skill","label":LABELS.skill,"expressed":skill_a,"carried":skill_b,"sequence":skill_bases,"phenotype":phenotype("skill",skill_a,p),"origins":p.get("skill_sources",{}),"diploid":true})
	sequence += skill_bases
	for key: String in STAT_LOCI:
		var value: int = roundi(float(p.get("stats",{}).get(key,0)))
		var bases: String = codons([key,value])
		loci.append({"key":key,"label":LABELS[key],"expressed":str(value),"carried":"","sequence":bases,"phenotype":phenotype(key,value,p),"origins":p.get("stat_sources",{}).get(key,{}),"diploid":false})
		sequence += bases
	var fingerprint: String = canonical([int(p.get("seed",1)),p.get("type","Leaf"),ancestry,genes,p.get("stats",{}),skill]).sha256_text().substr(0,12).to_upper()
	return {"code":fingerprint,"sequence":sequence,"loci":loci,"marker":codons(["individual",int(p.get("seed",1))],24)}

static func origin_text(locus: Dictionary) -> String:
	var origins: Dictionary = locus.get("origins",{})
	if origins.is_empty(): return "Founding DNA · no recorded cross"
	if origins.get("legacy_unrecorded",false): return "Legacy allele origins were not recorded; the genome and pedigree are preserved"
	if origins.get("ancestry",false): return "Anatomy retains the mixed lineages of recorded parents and earlier ancestors"
	if origins.get("allele_a",null) is String:
		return "Maternal skill allele: %s\nPaternal skill allele: %s" % [origins.get("allele_a","?"),origins.get("allele_b","?")]
	if origins.has("value_a"):
		return "Parental values: %s × %s\nParental average with inherited birth variance" % [str(origins.value_a),str(origins.get("value_b","?"))]
	var a: Dictionary = origins.get("allele_a",{})
	var b: Dictionary = origins.get("allele_b",{})
	if a.is_empty() and b.is_empty(): return "Inherited from the parental genome"
	if a.get("allele","")=="founder": return "Founding DNA · no recorded cross"
	if a.get("allele","")=="mutation": return "Mutation created the expressed allele; the previous allele remains recorded"
	var lines: Array[String] = []
	for pair: Array in [["Mother",a],["Father",b]]:
		var allele: Dictionary = pair[1]
		if allele.is_empty(): continue
		lines.append("%s: %s · %s allele · %s" % [pair[0],allele.get("parent_name",allele.get("parent_id","?")),allele.get("allele","?"),str(allele.get("value","?"))])
	var origin: String = str(origins.get("expressed_origin",""))
	if origin=="blend": lines.append("Expression: blended pigment from both parents")
	elif origin=="combination": lines.append("Expression: a new combination of parental patterns")
	elif origin in ["a","b"]: lines.append("Expressed allele from mother" if origin=="a" else "Expressed allele from father")
	elif origin=="mutation": lines.append("Expression changed by mutation; the earlier allele remains recorded")
	return "\n".join(lines)
