extends RefCounted
## Deterministic auto-battle. Produces an event list the view plays back.
## Teams are arrays ordered front-first. Side 0 = player, side 1 = enemy.

const Plant := preload("res://scripts/sim/plant.gd")
const MAX_TEAM := 5
const MAX_CLASHES := 60

var teams: Array = [[], []]
var events: Array = []
var rng := RandomNumberGenerator.new()
var winner := -1   # 0 player, 1 enemy, -1 draw

func run(player_front_first: Array, enemy_front_first: Array, seed_value: int) -> int:
	rng.seed = seed_value
	for p in player_front_first: teams[0].append(p.clone())
	for p in enemy_front_first: teams[1].append(p.clone())
	_emit({"t": "begin"})
	_start_of_battle()
	_resolve_deaths()
	var clashes := 0
	while not teams[0].is_empty() and not teams[1].is_empty() and clashes < MAX_CLASHES:
		clashes += 1
		var a = teams[0][0]
		var b = teams[1][0]
		_emit({"t": "clash", "a": a.uid, "b": b.uid})
		var da: int = a.atk
		var db: int = b.atk
		_hit(b, da, a)
		_hit(a, db, b)
		_resolve_deaths()
		var ticked := false
		for side in 2:
			for u in teams[side]:
				if u.poison > 0 and u.hp > 0:
					if not ticked:
						_emit({"t": "poison_tick"})
						ticked = true
					_damage(u, u.poison, null, "poison")
		_resolve_deaths()
	if teams[0].is_empty() and teams[1].is_empty(): winner = -1
	elif teams[1].is_empty(): winner = 0
	elif teams[0].is_empty(): winner = 1
	else: winner = -1
	_emit({"t": "end", "winner": winner})
	for side in 2:
		for u in teams[side]: u.last_hit_by = null
	return winner

func _emit(e: Dictionary) -> void:
	events.append(e)

func _side_of(u) -> int:
	return 0 if teams[0].has(u) else 1

func _start_of_battle() -> void:
	var order: Array = []
	for side in 2:
		for u in teams[side]: order.append(u)
	order.sort_custom(func(x, y): return x.atk > y.atk)
	for u in order:
		if u.hp <= 0: continue
		var side := _side_of(u)
		var foes: Array = teams[1 - side]
		if u.abilities.has("sunburst"):
			var p: int = u.power("sunburst")
			var targets: Array = []
			for ally in teams[side]:
				if ally.hp > 0:
					ally.atk += p
					targets.append(ally.uid)
			_emit({"t": "ability", "ab": "sunburst", "src": u.uid, "targets": targets})
			for ally_uid in targets:
				var ally = _find(ally_uid)
				_emit({"t": "buff", "uid": ally_uid, "datk": p, "dhp": 0, "atk": ally.atk, "hp": ally.hp})
		if u.abilities.has("leech"):
			var target = _first_alive(foes)
			if target != null:
				var steal: int = min(u.power("leech"), target.atk)
				target.atk -= steal
				u.atk += steal
				_emit({"t": "ability", "ab": "leech", "src": u.uid, "targets": [target.uid]})
				_emit({"t": "buff", "uid": target.uid, "datk": -steal, "dhp": 0, "atk": target.atk, "hp": target.hp})
				_emit({"t": "buff", "uid": u.uid, "datk": steal, "dhp": 0, "atk": u.atk, "hp": u.hp})
		if u.abilities.has("lash"):
			var target = _last_alive(foes)
			if target != null:
				_emit({"t": "ability", "ab": "lash", "src": u.uid, "targets": [target.uid]})
				_damage(target, u.power("lash") + 1, u, "lash")

func _first_alive(team: Array):
	for u in team:
		if u.hp > 0: return u
	return null

func _last_alive(team: Array):
	for i in range(team.size() - 1, -1, -1):
		if team[i].hp > 0: return team[i]
	return null

func _find(uid: int):
	for side in 2:
		for u in teams[side]:
			if u.uid == uid: return u
	return null

func _hit(target, amount: int, attacker) -> void:
	if amount <= 0: return
	_damage(target, amount, attacker, "hit")
	if attacker.abilities.has("venom"):
		var p: int = attacker.power("venom")
		target.poison += p
		_emit({"t": "poisoned", "uid": target.uid, "poison": target.poison, "src": attacker.uid})
	if target.abilities.has("thorns"):
		_emit({"t": "ability", "ab": "thorns", "src": target.uid, "targets": [attacker.uid]})
		_damage(attacker, target.power("thorns"), target, "thorns")

func _damage(target, amount: int, source, kind: String) -> void:
	if amount <= 0: return
	target.hp -= amount
	if source != null: target.last_hit_by = source
	_emit({"t": "dmg", "uid": target.uid, "amt": amount, "hp": target.hp, "kind": kind})

func _resolve_deaths() -> void:
	var guard := 0
	while guard < 50:
		guard += 1
		var dead = null
		var dead_side := -1
		for side in 2:
			for u in teams[side]:
				if u.hp <= 0:
					dead = u
					dead_side = side
					break
			if dead != null: break
		if dead == null: return
		var index: int = teams[dead_side].find(dead)
		teams[dead_side].remove_at(index)
		_emit({"t": "faint", "uid": dead.uid, "side": dead_side, "order": _order(dead_side)})
		var killer = dead.last_hit_by
		if killer != null and killer.hp > 0 and killer.abilities.has("devour") and _side_of(killer) != dead_side and teams[_side_of(killer)].has(killer):
			var p: int = killer.power("devour")
			killer.atk += p
			killer.hp += p
			_emit({"t": "ability", "ab": "devour", "src": killer.uid, "targets": [killer.uid]})
			_emit({"t": "buff", "uid": killer.uid, "datk": p, "dhp": p, "atk": killer.atk, "hp": killer.hp})
		if dead.abilities.has("burst"):
			var foes: Array = []
			for f in teams[1 - dead_side]:
				if f.hp > 0: foes.append(f)
			if not foes.is_empty():
				var target = foes[rng.randi_range(0, foes.size() - 1)]
				_emit({"t": "ability", "ab": "burst", "src": dead.uid, "side": dead_side, "targets": [target.uid]})
				_damage(target, dead.power("burst") + 1, dead, "burst")
		if dead.abilities.has("reseed") and teams[dead_side].size() < MAX_TEAM:
			var sprout = Plant.sproutling(dead.power("reseed"), rng)
			sprout.genes.leaf_hue = dead.genes.leaf_hue
			sprout.genes.flower_hue = dead.genes.flower_hue
			teams[dead_side].insert(min(index, teams[dead_side].size()), sprout)
			_emit({"t": "ability", "ab": "reseed", "src": dead.uid, "side": dead_side, "targets": []})
			_emit({"t": "summon", "side": dead_side, "plant": sprout, "order": _order(dead_side)})

func _order(side: int) -> Array:
	var out: Array = []
	for u in teams[side]: out.append(u.uid)
	return out
