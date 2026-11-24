extends RefCounted
## One run: hearts, trophies, sun, the 5-plot garden and the seed shop.

const Plant := preload("res://scripts/sim/plant.gd")
const Species := preload("res://scripts/sim/species.gd")
const Breeding := preload("res://scripts/sim/breeding.gd")
const Ghost := preload("res://scripts/sim/ghost.gd")
const Battle := preload("res://scripts/sim/battle.gd")

const SLOTS := 5
const START_HEARTS := 5
const TROPHIES_TO_WIN := 10
const SUN_PER_ROUND := 10
const SEED_COST := 3
const REROLL_COST := 1

const ITEMS := {
	"fertilizer": {"name": "Fertilizer", "cost": 3, "desc": "Give a plant +1/+1."},
	"water": {"name": "Big Watering Can", "cost": 3, "desc": "Give a plant +0/+3."},
	"pollen": {"name": "Magic Pollen", "cost": 4, "desc": "Its next cross is a guaranteed glowing mutant!"},
}

var rng := RandomNumberGenerator.new()
var run_seed := 0
var round_number := 1
var hearts := START_HEARTS
var trophies := 0
var sun := SUN_PER_ROUND
var board: Array = []    # SLOTS entries, null or plant; index 4 is the front
var shop: Array = []     # entries: {kind:"seed", plant} or {kind:"item", item}
var last_result := -2
var history: Array = []  # results per round

func _init(seed_value: int = 0) -> void:
	run_seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system()) ^ randi()
	rng.seed = run_seed
	board.resize(SLOTS)
	roll_shop()

func shop_size() -> int:
	if round_number >= 5: return 5
	if round_number >= 3: return 4
	return 3

func roll_shop() -> void:
	shop.clear()
	var pool := Species.pool(round_number)
	var boost := Ghost.shop_boost(round_number)
	for i in shop_size():
		var p = Plant.create(pool[rng.randi_range(0, pool.size() - 1)], rng)
		p.atk += boost
		p.hp += boost
		shop.append({"kind": "seed", "plant": p, "cost": SEED_COST})
	if round_number >= 2:
		var keys := ["fertilizer", "fertilizer", "water", "pollen"] if round_number >= 3 else ["fertilizer", "water"]
		var item: String = keys[rng.randi_range(0, keys.size() - 1)]
		shop.append({"kind": "item", "item": item, "cost": int(ITEMS[item].cost)})

func reroll() -> bool:
	if sun < REROLL_COST: return false
	sun -= REROLL_COST
	roll_shop()
	return true

func first_empty() -> int:
	# Fill from the front so new plants are ready to fight.
	for i in range(SLOTS - 1, -1, -1):
		if board[i] == null: return i
	return -1

func plant_count() -> int:
	var n := 0
	for p in board:
		if p != null: n += 1
	return n

func can_afford(index: int) -> bool:
	return index >= 0 and index < shop.size() and sun >= int(shop[index].cost)

## Buy a seed packet into a slot. Returns the plant or null.
func buy_seed(index: int, slot: int):
	if not can_afford(index) or shop[index].kind != "seed": return null
	if slot < 0 or slot >= SLOTS or board[slot] != null: return null
	var entry: Dictionary = shop[index]
	sun -= int(entry.cost)
	shop.remove_at(index)
	board[slot] = entry.plant
	return entry.plant

func use_item(index: int, slot: int) -> bool:
	if not can_afford(index) or shop[index].kind != "item": return false
	if slot < 0 or slot >= SLOTS or board[slot] == null: return false
	var item: String = shop[index].item
	var p = board[slot]
	match item:
		"fertilizer":
			p.atk += 1
			p.hp += 1
		"water":
			p.hp += 3
		"pollen":
			if p.pollen: return false
			p.pollen = true
	sun -= int(shop[index].cost)
	shop.remove_at(index)
	return true

func sell(slot: int) -> int:
	var p = board[slot]
	if p == null: return 0
	var value: int = p.sell_value()
	sun += value
	board[slot] = null
	return value

func move(from_slot: int, to_slot: int) -> void:
	var tmp = board[to_slot]
	board[to_slot] = board[from_slot]
	board[from_slot] = tmp

## Cross the plant in `from_slot` onto `to_slot`. The child takes `to_slot`.
func cross(from_slot: int, to_slot: int):
	var a = board[from_slot]
	var b = board[to_slot]
	if a == null or b == null or from_slot == to_slot: return null
	var child = Breeding.cross(b, a, rng)
	board[from_slot] = null
	board[to_slot] = child
	return child

func front_first() -> Array:
	var out: Array = []
	for i in range(SLOTS - 1, -1, -1):
		if board[i] != null: out.append(board[i])
	return out

func rival_name() -> String:
	return Ghost.rival_name(round_number, run_seed)

func rival_board() -> Array:
	return Ghost.build(round_number, run_seed)

## Simulates this round's fight and applies the outcome. Returns the battle.
func fight():
	var enemy := rival_board()
	var enemy_front: Array = []
	for i in range(enemy.size() - 1, -1, -1): enemy_front.append(enemy[i])
	var battle = Battle.new()
	battle.run(front_first(), enemy_front, run_seed + round_number * 13)
	last_result = battle.winner
	history.append(battle.winner)
	if battle.winner == 0: trophies += 1
	elif battle.winner == 1: hearts -= 1
	return battle

func is_over() -> bool:
	return hearts <= 0 or trophies >= TROPHIES_TO_WIN

func won() -> bool:
	return trophies >= TROPHIES_TO_WIN

func next_round() -> void:
	round_number += 1
	sun = SUN_PER_ROUND
	for p in board:
		if p != null: p.poison = 0
	roll_shop()
