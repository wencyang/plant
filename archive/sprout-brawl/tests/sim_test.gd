extends SceneTree
## Headless rules test + balance report.
## godot --headless --path . --script res://tests/sim_test.gd

const Plant := preload("res://scripts/sim/plant.gd")
const Breeding := preload("res://scripts/sim/breeding.gd")
const Battle := preload("res://scripts/sim/battle.gd")
const RunState := preload("res://scripts/sim/run_state.gd")
const Species := preload("res://scripts/sim/species.gd")

var failures := 0

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		push_error("FAIL: " + msg)
		print("FAIL: ", msg)

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# Crossing
	var a = Plant.create("snap", rng)
	var b = Plant.create("root", rng)
	var c = Breeding.cross(a, b, rng)
	check(c.gen == 2, "gen increments")
	check(c.abilities.has("devour") and c.abilities.has("thorns"), "abilities inherited")
	check(c.atk >= 3 and c.hp >= 5, "hybrid vigour")
	check(c.lineage.size() == 2, "lineage merged")
	var d = Breeding.cross(Plant.create("bloom", rng), Plant.create("bloom", rng), rng)
	check(int(d.abilities.sunburst) == 1, "same ability merges stronger")
	var pol = Plant.create("leaf", rng)
	pol.pollen = true
	check(Breeding.cross(pol, Plant.create("leaf", rng), rng).mutant, "pollen forces mutant")
	check(Species.herbarium_keys().size() == 36, "36 herbarium entries")
	# Battle basics
	var bt = Battle.new()
	var w: int = bt.run([Plant.create("snap", rng)], [Plant.create("spore", rng)], 1)
	check(w != -2 and bt.events.back().t == "end", "battle ends")
	var bt2 = Battle.new()
	var lone = Plant.create("leaf", rng)
	check(bt2.run([lone], [], 1) == 0, "empty enemy loses")
	var reseed_seen := false
	var bt3 = Battle.new()
	bt3.run([Plant.create("leaf", rng)], [Plant.create("snap", rng)], 3)
	for e in bt3.events:
		if e.t == "summon": reseed_seen = true
	check(reseed_seen, "reseed summons")
	# Run economy
	var run = RunState.new(7)
	check(run.shop.size() == 3, "round 1 shop has 3 seeds")
	var p = run.buy_seed(0, run.first_empty())
	check(p != null and run.sun == 7, "buy costs 3")
	balance()
	print("SIM TEST: ", "OK" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)

## A reasonable greedy bot plays many runs to check the difficulty curve.
func bot_turn(run, smart: bool) -> void:
	var guard := 0
	while guard < 30:
		guard += 1
		# use items on the strongest plant
		var bought := false
		for i in run.shop.size():
			var e: Dictionary = run.shop[i]
			if e.kind == "item" and run.can_afford(i) and run.plant_count() > 0:
				var best := -1
				for s in run.SLOTS:
					if run.board[s] != null and (best < 0 or run.board[s].strength() > run.board[best].strength()): best = s
				if run.use_item(i, best):
					bought = true
					break
		if bought: continue
		var seed_index := -1
		var best_strength := -1
		for i in run.shop.size():
			if run.shop[i].kind == "seed" and run.can_afford(i) and run.shop[i].plant.strength() > best_strength:
				best_strength = run.shop[i].plant.strength()
				seed_index = i
		if seed_index < 0:
			if smart and run.sun >= 1 and run.sun < 3: break
			if run.sun >= 4 and run.reroll(): continue
			break
		if run.first_empty() < 0:
			if not smart: break
			# cross the two weakest, prefer same family
			var slots: Array = []
			for s in run.SLOTS:
				if run.board[s] != null: slots.append(s)
			slots.sort_custom(func(x, y): return run.board[x].strength() < run.board[y].strength())
			var pair := [slots[0], slots[1]]
			for i in slots.size():
				for j in range(i + 1, slots.size()):
					if run.board[slots[i]].head() == run.board[slots[j]].head():
						pair = [slots[i], slots[j]]
			run.cross(pair[0], pair[1])
		run.buy_seed(seed_index, run.first_empty())
	# tanky in front
	var plants: Array = run.front_first()
	plants.sort_custom(func(x, y): return x.hp > y.hp)
	for s in run.SLOTS: run.board[s] = null
	for i in plants.size(): run.board[run.SLOTS - 1 - i] = plants[i]

func balance() -> void:
	for smart in [false, true]:
		var wins := 0
		var runs := 200
		var round_wins: Dictionary = {}
		var round_total: Dictionary = {}
		var total_rounds := 0
		for r in runs:
			var run = RunState.new(1000 + r)
			while not run.is_over() and run.round_number < 30:
				bot_turn(run, smart)
				var battle = run.fight()
				round_total[run.round_number] = int(round_total.get(run.round_number, 0)) + 1
				if battle.winner == 0: round_wins[run.round_number] = int(round_wins.get(run.round_number, 0)) + 1
				if run.is_over(): break
				run.next_round()
			total_rounds += run.round_number
			if run.won(): wins += 1
		var line := ""
		for k in range(1, 16):
			if round_total.has(k): line += "r%d:%d%% " % [k, int(100.0 * int(round_wins.get(k, 0)) / int(round_total[k]))]
		print("BALANCE %s bot: run win %d%%, avg rounds %.1f | %s" % ["crossing" if smart else "no-cross", int(100.0 * wins / runs), float(total_rounds) / runs, line])
