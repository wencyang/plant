extends SceneTree
const State = preload("res://scripts/garden_state.gd")
const Guide = preload("res://scripts/genetics_guide.gd")
const DNA = preload("res://scripts/plant_dna.gd")
var checks: int = 0
var failures: int = 0

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("GENETICS GUIDE: "+message)

func find_trait(preview: Dictionary,key: String) -> Dictionary:
	for item: Dictionary in preview.traits:
		if item.key==key: return item
	return {}

func summary(p: Dictionary,key: String) -> Dictionary:
	for item: Dictionary in Guide.trait_summary(p):
		if item.key==key: return item
	return {}

func probability(outcomes: Array,value: Variant) -> float:
	for item: Dictionary in outcomes:
		if DNA.canonical(item.raw)==DNA.canonical(value): return float(item.probability)
	return 0.0

func normalized(outcomes: Array,message: String) -> void:
	var total: float = 0
	for outcome: Dictionary in outcomes:
		total+=float(outcome.probability)
		check(float(outcome.probability)>0 and float(outcome.probability)<=1.000001,message+" valid probability")
	check(is_equal_approx(total,1.0),message+" sums to one")

func set_gene(p: Dictionary,key: String,a: Variant,b: Variant) -> void:
	p.genes[key] = {"dominant":a,"recessive":b}

func _initialize() -> void:
	var model = State.new("/tmp/conservatory_guide_no_save.json")
	var a: Dictionary = model._create_base(0,6031,"guide_a")
	var b: Dictionary = model._create_base(1,6032,"guide_b")
	set_gene(a,"pattern","Solid","Striped")
	set_gene(b,"pattern","Solid","Solid")
	var original: String = DNA.canonical([a,b])
	var random_state: int = model.random.state
	var original_id: int = model.id_counter
	var preview: Dictionary = Guide.cross_preview(a,b)
	var pattern: Dictionary = find_trait(preview,"pattern")
	check(preview.generation==2,"First-generation parents predict the next generation")
	check(is_equal_approx(probability(pattern.parent_a,"Striped"),0.5),"Carrier transmits its stripe allele 50% of the time")
	check(is_equal_approx(probability(pattern.outcomes,"Striped"),0.25),"Carrier crossed with a solid parent shows stripe 25% of the time")
	check(is_equal_approx(probability(pattern.outcomes,"Solid"),0.75),"The other 75% show the solid allele")
	check(is_equal_approx(probability(pattern.hidden_outcomes,"Striped"),0.25),"Visible and hidden offspring outcomes remain distinct from parental transmission")
	check(Guide.hidden_goal(a,"pattern").contains("Striped"),"Breeding advice identifies the actual hidden target")
	set_gene(b,"pattern","Striped","Striped")
	var targeted: Dictionary = find_trait(Guide.cross_preview(a,b),"pattern")
	check(is_equal_approx(probability(targeted.outcomes,"Striped"),0.75),"A mate with two stripe copies improves visible stripe odds to 75% in G2")
	set_gene(a,"pattern","Striped","Striped")
	var fixed: Dictionary = find_trait(Guide.cross_preview(a,b),"pattern")
	check(fixed.parent_a.size()==1 and is_equal_approx(float(fixed.parent_a[0].probability),1.0),"Two equal alleles always transmit that allele")
	check(fixed.outcomes.size()==1 and is_equal_approx(probability(fixed.outcomes,"Striped"),1.0),"Matching fixed parents preserve the pattern without false rare outcomes")
	set_gene(a,"pattern","Solid","Striped")
	set_gene(b,"pattern","Solid","Solid")
	a.generation=2
	var later: Dictionary = find_trait(Guide.cross_preview(a,b),"pattern")
	check(is_equal_approx(probability(later.outcomes,"Solid"),0.73),"G3 combination odds apply only when transmitted alleles differ")
	check(is_equal_approx(probability(later.outcomes,"Striped"),0.23),"G3 stripe expression includes the combination replacement rule")
	check(is_equal_approx(probability(later.outcomes,"Starburst"),0.02) and is_equal_approx(probability(later.outcomes,"Bicolor Ring"),0.02),"G3 carrier pair has 2% of each rare pattern, not an unconditional 4%")
	set_gene(a,"pattern","Striped","Striped")
	set_gene(b,"pattern","Spotted","Spotted")
	var different: Dictionary = find_trait(Guide.cross_preview(a,b),"pattern")
	check(is_equal_approx(probability(different.outcomes,"Striped"),0.46) and is_equal_approx(probability(different.outcomes,"Spotted"),0.46),"Different fixed G3 patterns each express 46%")
	check(is_equal_approx(probability(different.outcomes,"Starburst"),0.04) and is_equal_approx(probability(different.outcomes,"Bicolor Ring"),0.04),"Different fixed G3 patterns each combine to a rare pattern 4%")
	set_gene(a,"color","829d80","829d80")
	set_gene(b,"color","d7a06d","d7a06d")
	var pigment: Dictionary = find_trait(Guide.cross_preview(a,b),"color")
	var blend: String = Color("829d80").lerp(Color("d7a06d"),0.5).to_html(false)
	check(is_equal_approx(probability(pigment.outcomes,"829d80"),0.425) and is_equal_approx(probability(pigment.outcomes,"d7a06d"),0.425),"Pigment inheritance leaves 42.5% of each fixed parent color")
	check(is_equal_approx(probability(pigment.outcomes,blend),0.15),"Blended pigment is predicted at its actual 15% rate")
	for item: Dictionary in pigment.outcomes:
		check(not str(item.value).contains("#") and not str(item.value).is_valid_hex_number(false),"Player-facing pigment has a natural color name")
		check(item.color is Color and str(item.html)==str(item.raw),"Named pigment retains its exact swatch for the interface")
	set_gene(a,"petals",6,6.0)
	set_gene(b,"petals",6.0,6)
	check(find_trait(Guide.cross_preview(a,b),"petals").outcomes.size()==1,"JSON integer and float copies of one petal allele coalesce")
	a.skill_genes={"dominant":"Entangle","recessive":"Entangle"}
	b.skill_genes={"dominant":"Root Network","recessive":"Root Network"}
	var skills: Array = Guide.skill_outcomes(a,b)
	check(is_equal_approx(probability(skills,["Entangle"]),0.35),"A single maternal skill shows with 35% of different fixed skill pairs")
	check(is_equal_approx(probability(skills,["Root Network"]),0.35),"A single paternal skill shows with 35%")
	check(is_equal_approx(probability(skills,["Entangle","Root Network"]),0.30),"Two inherited skills express together at 30%")
	a.graft_history=[{"trait":"skill","value":"Toxin Seep"},{"trait":"skill","value":"Toxin Seep"}]
	var grafted: Array = Guide.skill_outcomes(a,b)
	var graft_presence: float = 0
	for item: Dictionary in grafted:
		if item.raw.has("Toxin Seep"): graft_presence+=float(item.probability)
		check(item.raw.size()<=3,"Grafted skill predictions respect the three-skill limit")
	check(is_equal_approx(graft_presence,0.36),"Two independent records of the same graft skill produce a 36% chance of adding it")
	a.graft_history=[]
	set_gene(a,"pattern","Solid","Striped")
	check(not summary(a,"petals").appearance_applies,"A leaf-only plant explains its dormant flower-petal gene")
	set_gene(a,"pattern","Starburst","Solid")
	check(summary(a,"petals").appearance_applies and summary(a,"petals").visible=="6 starburst rays","A flowerless starburst plant uses the count for actual marking rays")
	set_gene(a,"pattern","Solid","Striped")
	a.lineage_mix={"Leaf":0.5,"Bloom":0.5}
	check(summary(a,"petals").appearance_applies,"Inherited flower organs express the host petal gene")
	a.lineage_mix={"Leaf":1.0}
	a.graft_history=[{"trait":"feature","donor_type":"Bloom","donor_color":"d7a06d","donor_genes":{"petals":{"dominant":8,"recessive":8}},"success":true}]
	check(not summary(a,"petals").appearance_applies,"A grafted flower uses donor petal DNA rather than incorrectly showing the host's stored count")
	a.gene_sources.color={"expressed_origin":"a","allele_a":{"parent_name":"Mother Fern","value":"829d80"},"allele_b":{"parent_name":"Father Bloom","value":"d7a06d"}}
	set_gene(a,"color","829d80","d7a06d")
	var origin: String = Guide.origin_note(a,"color")
	check(origin.contains("Mother Fern") and origin.contains("Father Bloom") and origin.contains("Warm amber"),"Origin notes explain both actual parental sources with a readable hidden color")
	check(not origin.contains("829d80") and not origin.contains("d7a06d"),"Origin notes never expose pigment codes")
	for stat: Dictionary in Guide.cross_preview(a,b).stats:
		var expected: float = (float(a.stats[stat.key])+float(b.stats[stat.key]))*0.5
		check(is_equal_approx(float(stat.expected),expected),"Stat preview uses the real parental average: "+str(stat.key))
		check(int(stat.min)==maxi(1,roundi(expected*0.9)) and int(stat.max)==maxi(1,roundi(expected*1.1)),"Stat preview shows its actual birth range")
	for row: Dictionary in Guide.cross_preview(a,b).traits:
		normalized(row.outcomes,str(row.key)+" visible outcomes")
		normalized(row.hidden_outcomes,str(row.key)+" carried outcomes")
		normalized(row.parent_a,str(row.key)+" maternal transmission")
		normalized(row.parent_b,str(row.key)+" paternal transmission")
	normalized(Guide.skill_outcomes(a,b),"Full skill expression including graft")
	check(Guide.cross_preview({},b).valid==false and Guide.trait_summary({}).is_empty(),"Empty selections do not invent a plant's traits")
	var partial: Dictionary = b.duplicate(true)
	partial.genes.erase("petals")
	check(find_trait(Guide.cross_preview(a,partial),"petals").outcomes.size()==1,"A legacy missing paternal slot follows the model's maternal-slot fallback")
	# Purity is verified on an untouched fixture, including all nested gene data.
	var clean_a: Dictionary = model._create_base(0,8191,"clean_a")
	var clean_b: Dictionary = model._create_base(1,8192,"clean_b")
	var clean_before: String = DNA.canonical([clean_a,clean_b])
	for i in range(10):
		Guide.trait_summary(clean_a)
		Guide.cross_preview(clean_a,clean_b)
	check(DNA.canonical([clean_a,clean_b])==clean_before,"Repeated explanations never change parental genes, stats or ancestry")
	# Compare the analytical advice with actual offspring from the game's birth
	# method. No plants are added, no time is skipped, and no saves are written.
	var sample_a: Dictionary = model._create_base(0,8193,"sample_a")
	var sample_b: Dictionary = model._create_base(1,8194,"sample_b")
	sample_a.generation=2
	set_gene(sample_a,"pattern","Striped","Striped")
	set_gene(sample_b,"pattern","Spotted","Spotted")
	set_gene(sample_a,"color","829d80","829d80")
	set_gene(sample_b,"color","d7a06d","d7a06d")
	sample_a.skill_genes={"dominant":"Entangle","recessive":"Entangle"}
	sample_b.skill_genes={"dominant":"Root Network","recessive":"Root Network"}
	sample_a.graft_history=[{"trait":"skill","value":"Toxin Seep"}]
	var predicted: Dictionary = Guide.cross_preview(sample_a,sample_b)
	var counts: Dictionary = {"pattern":{},"color":{},"skill":{}}
	var stats_in_range: Dictionary = {}
	for row: Dictionary in predicted.stats: stats_in_range[row.key]=true
	const SAMPLES: int = 4000
	for i in range(SAMPLES):
		var born: Dictionary = model._make_offspring(sample_a,sample_b,18401+i*16411,"sample_child_%d" % i)
		for key: String in ["pattern","color"]:
			var identity: String = DNA.canonical(born.genes[key].dominant)
			counts[key][identity]=int(counts[key].get(identity,0))+1
		var ordered_skills: Array = born.skills.duplicate()
		ordered_skills.sort()
		var skill_identity: String = DNA.canonical(ordered_skills)
		counts.skill[skill_identity]=int(counts.skill.get(skill_identity,0))+1
		for row: Dictionary in predicted.stats:
			if int(born.stats[row.key])<int(row.min) or int(born.stats[row.key])>int(row.max): stats_in_range[row.key]=false
	for key: String in ["pattern","color","skill"]:
		var expected_outcomes: Array = predicted.skill_outcomes if key=="skill" else find_trait(predicted,key).outcomes
		var expected_keys: Array[String] = []
		for outcome: Dictionary in expected_outcomes:
			var identity: String = DNA.canonical(outcome.raw)
			expected_keys.append(identity)
			var actual: float = float(counts[key].get(identity,0))/SAMPLES
			check(absf(actual-float(outcome.probability))<0.025,"Actual offspring match the disclosed "+key+" odds for "+str(outcome.value))
		for identity: String in counts[key]: check(expected_keys.has(identity),"Every observed "+key+" outcome is disclosed by the preview")
	for key: String in stats_in_range: check(stats_in_range[key],"Every actual birth stays inside the disclosed "+key+" range")
	check(model.random.state==random_state and model.id_counter==original_id,"Previewing never consumes gameplay randomness or organism IDs")
	check(not original.is_empty(),"Original fixture was captured for independent analytical cases")
	print("GENETICS GUIDE TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
