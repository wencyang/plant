extends SceneTree
const State = preload("res://scripts/garden_state.gd")
const DNA = preload("res://scripts/plant_dna.gd")
var checks: int = 0
var failures: int = 0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("DNA: "+message)
func _initialize() -> void:
	var path: String = "/tmp/conservatory_dna_%d.json" % Time.get_ticks_usec()
	var state = State.new(path)
	state.new_game()
	var codes: Dictionary = {}
	var alphabet := RegEx.new()
	alphabet.compile("^[ACGT]+$")
	for id: String in state.plant_order:
		var genome: Dictionary = DNA.profile(state.get_plant(id))
		check(not codes.has(genome.code),"Every founding individual has its own stable DNA identity")
		codes[genome.code] = true
		check(genome.loci.size()==17,"Genome exposes anatomy, nine visual loci, skill, and six inherited stats")
		check(alphabet.search(genome.sequence)!=null and str(genome.sequence).length()>400,"Encoded sequence contains the actual game's gene bases")
	var mother: String = str(state.plant_order[0])
	var father: String = str(state.plant_order[1])
	var child: Dictionary = state.crossbreed(mother,father).plant
	var profile: Dictionary = DNA.profile(child)
	var legacy: Dictionary = child.duplicate(true)
	legacy.erase("gene_sources")
	var old_profile: Dictionary = DNA.profile(legacy)
	check(DNA.origin_text(old_profile.loci[1]).begins_with("Legacy allele origins"),"Older hybrids report unknown allele provenance without inventing a parent source")
	check(profile.code!=DNA.profile(state.get_plant(mother)).code and profile.code!=DNA.profile(state.get_plant(father)).code,"Recombined offspring has its own DNA")
	for locus: Dictionary in profile.loci:
		check(not str(locus.phenotype).is_empty(),"Every critical locus explains its actual visible or behavioral expression")
		if locus.key in State.PATTERNS: continue
		if child.genes.has(locus.key):
			check(locus.sequence==DNA.codons([locus.key,child.genes[locus.key].dominant])+DNA.codons([locus.key,child.genes[locus.key].recessive]),"Locus bases encode its actual expressed and carried alleles: "+str(locus.key))
	var changed: Dictionary = child.duplicate(true)
	changed.genes.color.recessive = "c275b1"
	check(DNA.profile(changed).code!=profile.code,"A changed hidden allele changes DNA even when appearance is unchanged")
	check(DNA.profile(changed).sequence!=profile.sequence,"Hidden allele changes the encoded DNA sequence")
	var ordered: Dictionary = child.duplicate(true)
	ordered.genes = {}
	var keys: Array = child.genes.keys()
	keys.reverse()
	for key: String in keys: ordered.genes[key] = child.genes[key].duplicate(true)
	check(DNA.profile(ordered).code==profile.code,"DNA identity does not depend on dictionary insertion order")
	state.rename_plant(str(child.id),"A new name")
	child.ready_at=0
	state.tick_growth()
	state.advance_lifecycle(1200.0)
	check(DNA.profile(child).code==profile.code,"Name, maturity and natural aging do not rewrite DNA")
	state.save_game()
	var restored = State.new(path)
	check(restored.load_game(),"DNA-bearing archive reloads")
	check(DNA.profile(restored.get_plant(str(child.id))).code==profile.code,"JSON numeric normalization preserves DNA identity")
	check(DNA.profile(restored.get_plant(str(child.id))).sequence==profile.sequence,"Complete encoded genome survives reload")
	check(state.pollinate(str(child.id),father).ok,"An aging living hybrid remains a valid parent")
	state.pollinations[child.id].ready_at=0
	state.harvest_fruit(str(child.id))
	var cross_fruit: Dictionary = {}
	for fruit: Dictionary in state.fruit_inventory:
		if fruit.kind=="hybrid": cross_fruit=fruit
	state.extract_seeds(str(cross_fruit.id))
	var seed: Dictionary = state.seed_bank.back()
	var encoded_seed: Dictionary = DNA.profile(seed.genome)
	var successor: Dictionary = state.plant_seed(state.seed_bank.size()-1).plant
	check(DNA.profile(successor).code==encoded_seed.code and DNA.profile(successor).sequence==encoded_seed.sequence,"Fruit→seed→sowing preserves the complete predetermined genome")
	state.get_plant(str(child.id)).life_age=1499.0
	state.advance_lifecycle(1.0)
	check(DNA.profile(child).code==profile.code,"Natural withering preserves DNA for the permanent pedigree")
	for entry in [path,path.get_basename()+".backup.json"]:
		if FileAccess.file_exists(entry): DirAccess.remove_absolute(entry)
	print("DNA TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
