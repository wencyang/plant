extends RefCounted
## One individual plant. Its look and its fighting kit both come from its genes.

const Species := preload("res://scripts/sim/species.gd")
const MAX_ABILITIES := 3

static var _next_uid := 1

var uid: int
var name: String = ""
var lineage: Array = []          # family ids, dominant first (max 3)
var atk: int = 1
var hp: int = 1
var abilities: Dictionary = {}   # ability id -> bonus power
var gen: int = 1
var mutant: bool = false
var token: bool = false
var genes: Dictionary = {}
var parents: Array = []          # head families of the two parents, for the herbarium
var pollen: bool = false         # magic pollen: next cross is a guaranteed mutant
# battle-only
var poison: int = 0
var last_hit_by = null

func _init() -> void:
	uid = _next_uid
	_next_uid += 1

static func create(species: String, rng: RandomNumberGenerator) -> RefCounted:
	var p = load("res://scripts/sim/plant.gd").new()
	var d: Dictionary = Species.DATA[species]
	p.name = d.name
	p.lineage = [species]
	p.atk = int(d.atk)
	p.hp = int(d.hp)
	p.abilities = {d.ability: 0}
	p.genes = random_genes(species, rng)
	return p

static func sproutling(power_value: int, rng: RandomNumberGenerator) -> RefCounted:
	var p = create("leaf", rng)
	p.name = "Sproutling"
	p.atk = power_value
	p.hp = power_value
	p.abilities = {}
	p.token = true
	p.genes.size = 0.62
	return p

static func random_genes(species: String, rng: RandomNumberGenerator) -> Dictionary:
	var d: Dictionary = Species.DATA[species]
	return {
		"leaf_hue": wrapf(float(d.hue) + rng.randf_range(-0.05, 0.05), 0.0, 1.0),
		"flower_hue": wrapf(float(d.flower) + rng.randf_range(-0.07, 0.07), 0.0, 1.0),
		"petals": rng.randi_range(5, 8),
		"leaf_shape": rng.randi_range(0, 2),
		"size": rng.randf_range(0.92, 1.06),
		"eyes": rng.randi_range(0, 2),
		"spots": rng.randf() < 0.3,
	}

func head() -> String:
	return str(lineage[0])

func power(ability: String) -> int:
	var p: int = 1 + int(abilities.get(ability, 0)) + int((gen - 1) / 2)
	if mutant: p += 1
	return p

func clone() -> RefCounted:
	var c = get_script().new()
	c.uid = uid
	c.name = name
	c.lineage = lineage.duplicate()
	c.atk = atk
	c.hp = hp
	c.abilities = abilities.duplicate()
	c.gen = gen
	c.mutant = mutant
	c.token = token
	c.genes = genes.duplicate()
	c.parents = parents.duplicate()
	c.pollen = pollen
	return c

func strength() -> int:
	return atk + hp + abilities.size() * 2 + (gen - 1) * 2

func sell_value() -> int:
	return 1 + int((gen - 1) / 2)
