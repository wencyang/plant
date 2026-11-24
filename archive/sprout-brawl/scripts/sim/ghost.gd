extends RefCounted
## Builds rival gardens by playing the same shop economy the player uses.

const Plant := preload("res://scripts/sim/plant.gd")
const Species := preload("res://scripts/sim/species.gd")
const Breeding := preload("res://scripts/sim/breeding.gd")

const RIVALS := [
	"Mildew Marge", "Sir Thornsby", "The Compost Twins", "Old Man Bramble", "Petunia Pickles",
	"Gnome Commander Gus", "Baroness Von Bloom", "Weedwhacker Wes", "Auntie Fernsworth",
	"Professor Pollen", "Lil' Sapling Sam", "Mossy McGee", "Captain Cabbage", "Dame Dandelion",
]

static func rival_name(round_number: int, run_seed: int) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = run_seed * 31 + round_number * 7919
	return RIVALS[r.randi_range(0, RIVALS.size() - 1)]

## Returns the rival's board, back to front (same layout as the player board).
static func build(round_number: int, run_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed * 977 + round_number * 104729
	var board: Array = []
	for r in range(1, round_number + 1):
		var buys := 2 if r <= 3 else (3 if r % 2 == 0 else 2)
		var pool := Species.pool(r)
		var boost := shop_boost(r)
		for i in buys:
			if board.size() >= 5:
				_cross_weakest(board, rng)
			var species: String = pool[rng.randi_range(0, pool.size() - 1)]
			var p = Plant.create(species, rng)
			p.atk += boost
			p.hp += boost
			board.append(p)
		# Rivals get a little fertilizer later on to keep pressure up.
		if r >= 6 and r % 2 == 0 and not board.is_empty():
			var t = board[rng.randi_range(0, board.size() - 1)]
			t.atk += 1
			t.hp += 1
	board.sort_custom(func(x, y): return x.hp < y.hp)  # tanky plants up front
	return board

static func shop_boost(round_number: int) -> int:
	return int((round_number - 1) / 3)

static func _cross_weakest(board: Array, rng: RandomNumberGenerator) -> void:
	board.sort_custom(func(x, y): return x.strength() < y.strength())
	# Prefer crossing two of the same family to power up abilities.
	var a_index := 0
	var b_index := 1
	var found := false
	for i in board.size():
		if found: break
		for j in range(i + 1, board.size()):
			if board[i].head() == board[j].head():
				a_index = i
				b_index = j
				found = true
				break
	var child = Breeding.cross(board[a_index], board[b_index], rng)
	board.remove_at(b_index)
	board.remove_at(a_index)
	board.append(child)
