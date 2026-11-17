extends RefCounted
class_name GardenState

## All organisms, including retired donors and every ancestor, remain in this archive.
## Visuals are derived from diploid genes and seed; no baked appearance is saved.
const SAVE_PATH := "user://conservatory_v1.json"
const SAVE_VERSION := 1
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

var save_path: String = SAVE_PATH
var plants: Dictionary = {}
var bed: Array = []
var display_bed: Array = []
var resources: Dictionary = {"sunlight": 180, "agents": 3, "grafts": 3}
var seed_bank: Array = []
var wins: int = 0
var battles: int = 0
var discovered: Array = []
var claimed: Array = []
var collection_claimed: Array = []
var collection_seen: Dictionary = {}
var plant_order: Array = []
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
	resources = {"sunlight": 180, "agents": 3, "grafts": 3}
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
	return p

func _add_plant(p: Dictionary) -> void:
	plants[p.id] = p
	plant_order.append(p.id)
	if not discovered.has(p.species):
		discovered.append(p.species)
	_record_collection(p)

func crossbreed(id_a: String, id_b: String) -> Dictionary:
	var a: Dictionary = get_plant(id_a)
	var b: Dictionary = get_plant(id_b)
	if a.is_empty() or b.is_empty():
		return _failure("Choose two mature parents.")
	if id_a == id_b:
		return _failure("Choose two different plants to crossbreed.")
	if not a.mature or not b.mature:
		return _failure("Both parents must finish growing first.")
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
	p["hybrid"] = a.species != b.species
	p["lineage_name"] = "%s × %s" % [a.species, b.species]
	p.name = _offspring_name(rng)
	for slot: String in a.genes:
		var gene_a: Dictionary = a.genes[slot]
		var gene_b: Dictionary = b.genes.get(slot, gene_a)
		var allele_a: Variant = gene_a.dominant if rng.randf() < 0.5 else gene_a.recessive
		var allele_b: Variant = gene_b.dominant if rng.randf() < 0.5 else gene_b.recessive
		var expressed: Variant = allele_a if rng.randf() < 0.5 else allele_b
		var carried: Variant = allele_b if expressed == allele_a else allele_a
		if slot in ["color", "accent"] and rng.randf() < 0.15:
			expressed = Color(str(allele_a)).lerp(Color(str(allele_b)), 0.5).to_html(false)
		if slot == "pattern" and int(p.generation) >= 3 and allele_a != allele_b and rng.randf() < 0.08:
			expressed = "Starburst" if rng.randf() < 0.5 else "Bicolor Ring"
		p.genes[slot] = {"dominant": expressed, "recessive": carried}
	for stat: String in STAT_NAMES:
		var average: float = (float(a.stats[stat]) + float(b.stats[stat])) * 0.5
		p.stats[stat] = maxi(1, int(round(average * rng.randf_range(0.9, 1.1))))
	var a_skills: Dictionary = a.get("skill_genes", {"dominant": a.skills[0], "recessive": a.skills[0]})
	var b_skills: Dictionary = b.get("skill_genes", {"dominant": b.skills[0], "recessive": b.skills[0]})
	var skill_a: String = str(a_skills.dominant if rng.randf() < 0.5 else a_skills.recessive)
	var skill_b: String = str(b_skills.dominant if rng.randf() < 0.5 else b_skills.recessive)
	p.skills = [skill_a if rng.randf() < 0.5 else skill_b]
	p.skill_genes = {"dominant": p.skills[0], "recessive": skill_b if p.skills[0] == skill_a else skill_a}
	if skill_a != skill_b and rng.randf() < 0.3:
		p.skills = [skill_a, skill_b]
	# Graft inheritance is deliberately reduced; inherited joins stay in the pedigree.
	for parent: Dictionary in [a, b]:
		for graft_record: Dictionary in parent.graft_history:
			if rng.randf() < 0.2:
				if graft_record.get("trait", "") == "skill" and p.skills.size() < 3:
					var graft_skill: String = str(graft_record.get("value", ""))
					if not p.skills.has(graft_skill) and not graft_skill.is_empty():
						p.skills.append(graft_skill)
				elif graft_record.get("trait", "") == "feature":
					p["inherited_graft_color"] = graft_record.get("value", "c1a4a0")
	p.rarity = _calculate_rarity(p)
	p.mature = false
	p.ready_at = int(Time.get_unix_time_from_system()) + 12
	return p

func graft(host_id: String, donor_id: String, trait_name: String = "feature") -> Dictionary:
	var host: Dictionary = get_plant(host_id)
	var donor: Dictionary = get_plant(donor_id)
	if host.is_empty() or donor.is_empty() or host_id == donor_id:
		return _failure("Choose a host and a different donor.")
	if not host.mature or not donor.mature:
		return _failure("The host and donor must both be mature.")
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
	var record: Dictionary = {"donor": donor_id, "donor_name": donor.name, "donor_color": donor.genes.color.dominant, "trait": trait_name, "value": value, "generation": host.generation, "success": success, "at": int(Time.get_unix_time_from_system())}
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
	var p: Dictionary = get_plant(id)
	if p.is_empty():
		return _failure("Choose a plant to expose.")
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

func plant_seed(index: int) -> Dictionary:
	if index < 0 or index >= seed_bank.size():
		return _failure("Choose a seed from the bank.")
	if int(resources.sunlight) < 10:
		return _failure("Planting a seed needs 10 gathered light.")
	var snapshot: Dictionary = seed_bank[index]
	var p: Dictionary = _create_base(int(snapshot.get("species_index", 0)), int(snapshot.get("seed", random.randi())))
	p.rarity = str(snapshot.get("rarity", "Common"))
	if snapshot.has("pattern"):
		p.genes.pattern.recessive = snapshot.pattern
		if random.randf() < 0.65:
			p.genes.pattern.dominant = snapshot.pattern
	if snapshot.has("parents"):
		p.parents = snapshot.parents.duplicate()
		var parent_generation: int = 0
		for parent_id: String in p.parents:
			if plants.has(parent_id):
				parent_generation = maxi(parent_generation, int(plants[parent_id].generation))
		p.generation = parent_generation + 1
	p.name = _offspring_name(random)
	p.mature = false
	p.ready_at = int(Time.get_unix_time_from_system()) + 12
	resources.sunlight -= 10
	seed_bank.remove_at(index)
	_add_plant(p)
	for cell in range(bed.size()):
		if str(bed[cell]).is_empty():
			bed[cell] = p.id
			break
	save_game()
	return {"ok": true, "message": "%s has taken root. It will mature in 12 seconds." % p.name, "plant": p}

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
	if plants.has(id) and not new_name.strip_edges().is_empty():
		plants[id].name = new_name.strip_edges().left(28)
		save_game()

func toggle_favorite(id: String) -> void:
	if plants.has(id):
		plants[id].favorite = not plants[id].favorite
		save_game()

func tick_growth() -> bool:
	var now: int = int(Time.get_unix_time_from_system())
	var changed: bool = false
	for id: String in plant_order:
		var p: Dictionary = plants[id]
		if not p.mature and now >= int(p.ready_at):
			p.mature = true
			changed = true
	if changed:
		save_game()
	return changed

func mature_plant(id: String) -> Dictionary:
	var p: Dictionary = get_plant(id)
	if p.is_empty():
		return _failure("Choose a growing plant.")
	if p.mature:
		return _failure("This plant is already mature.")
	if int(resources.sunlight) < 5:
		return _failure("Quick growth needs 5 gathered light, or wait a few seconds.")
	resources.sunlight -= 5
	p.mature = true
	p.ready_at = int(Time.get_unix_time_from_system())
	save_game()
	return {"ok": true, "message": "%s has unfurled." % p.name, "plant": p}

func place_in_bed(id: String, index: int) -> bool:
	if index < 0 or index >= 9 or not plants.has(id):
		return false
	if not bool(plants[id].mature):
		return false
	var old_index: int = bed.find(id)
	var displaced: String = str(bed[index])
	if old_index >= 0:
		bed[old_index] = displaced
	bed[index] = id
	save_game()
	return true

func place_in_display(id: String, index: int) -> bool:
	if index < 0 or index >= 6 or not plants.has(id) or not plants[id].mature:
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
		if plants[id].mature:
			candidates.append(id)
	if candidates.is_empty():
		return _failure("A mature plant is needed to gather a seed.")
	var parent: Dictionary = plants[candidates[random.randi_range(0, candidates.size() - 1)]]
	var snapshot: Dictionary = _make_seed(_species_index(parent.species), parent.rarity)
	snapshot.parents = [parent.id]
	snapshot.pattern = parent.genes.pattern.dominant
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
		for other_id: String in plant_order:
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
		for other_id: String in plant_order:
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

func save_game() -> void:
	var payload: Dictionary = {
		"version": SAVE_VERSION, "plants": plants, "bed": bed,
		"display_bed": display_bed, "resources": resources,
		"seed_bank": seed_bank, "wins": wins, "battles": battles,
		"discovered": discovered, "claimed": claimed, "plant_order": plant_order,
		"collection_claimed": collection_claimed, "collection_seen": collection_seen,
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
	seed_bank = payload.seed_bank
	wins = int(payload.get("wins", 0))
	battles = int(payload.get("battles", 0))
	discovered = payload.get("discovered", [])
	claimed = payload.get("claimed", [])
	collection_claimed = payload.get("collection_claimed", [])
	collection_seen = payload.get("collection_seen", {})
	plant_order = payload.get("plant_order", plants.keys())
	last_daily = int(payload.get("last_daily", 0))
	last_seed_collection = int(payload.get("last_seed_collection", 0))
	id_counter = int(payload.get("id_counter", plants.size()))
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
	for entry: Variant in data.bed + data.display_bed:
		if not entry is String:
			return false
		if not entry.is_empty() and not data.plants.has(entry):
			return false
	return true
