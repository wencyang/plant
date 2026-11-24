extends RefCounted
## Cross-pollination: two plants become one stronger hybrid that inherits
## abilities, families and looks from both parents.

const Plant := preload("res://scripts/sim/plant.gd")
const Species := preload("res://scripts/sim/species.gd")

static func mutation_chance(a, b) -> float:
	return 0.10 + 0.03 * float(max(a.gen, b.gen) - 1)

static func cross(a, b, rng: RandomNumberGenerator, force_mutant := false):
	var dom = a if rng.randf() < 0.5 else b
	var rec = b if dom == a else a
	var child = Plant.new()
	child.parents = [a.head(), b.head()]
	# Families: dominant parent's line first, then whatever the other adds.
	var lineage: Array = dom.lineage.duplicate()
	for s in rec.lineage:
		if not lineage.has(s): lineage.append(s)
	child.lineage = lineage.slice(0, 3)
	child.name = portmanteau(dom.name, rec.name)
	# Stats: hybrid vigour, the stronger parent plus half the weaker.
	child.atk = max(a.atk, b.atk) + int(ceil(min(a.atk, b.atk) / 2.0))
	child.hp = max(a.hp, b.hp) + int(ceil(min(a.hp, b.hp) / 2.0)) + 1
	child.gen = max(a.gen, b.gen) + 1
	# Abilities: shared abilities get stronger, the rest stack (up to three).
	var merged: Dictionary = {}
	for parent in [a, b]:
		for ab in parent.abilities:
			var bonus: int = int(parent.abilities[ab])
			if merged.has(ab): merged[ab] = max(int(merged[ab]), bonus) + 1
			else: merged[ab] = bonus
	var keys: Array = merged.keys()
	if keys.size() > Plant.MAX_ABILITIES:
		keys.shuffle()
		keys.sort_custom(func(x, y): return int(merged[x]) > int(merged[y]))
		var kept: Dictionary = {}
		for k in keys.slice(0, Plant.MAX_ABILITIES): kept[k] = merged[k]
		merged = kept
	child.abilities = merged
	# Looks: each gene from either parent.
	var genes: Dictionary = {}
	for key in dom.genes:
		genes[key] = dom.genes[key] if rng.randf() < 0.6 else rec.genes.get(key, dom.genes[key])
	genes.size = clampf((float(a.genes.size) + float(b.genes.size)) * 0.5 + 0.06, 0.8, 1.35)
	child.genes = genes
	if force_mutant or a.pollen or b.pollen or rng.randf() < mutation_chance(a, b):
		child.mutant = true
		child.atk += 2
		child.hp += 2
		genes.flower_hue = wrapf(float(genes.flower_hue) + rng.randf_range(0.25, 0.75), 0.0, 1.0)
	return child

static func portmanteau(x: String, y: String) -> String:
	if x == y: return x
	var left := x.substr(0, int(ceil(x.length() / 2.0)))
	var right := y.substr(int(y.length() / 2))
	var word := left + right.to_lower()
	if word.length() > 12: word = word.substr(0, 12)
	return word

static func herbarium_key(child) -> String:
	return Species.pair_key(str(child.parents[0]), str(child.parents[1]))
