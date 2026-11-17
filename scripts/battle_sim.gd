extends RefCounted
class_name BattleSim
## Deterministic, fixed-step combat. These are temporary copies of garden plants:
## withering never removes a specimen or changes its saved genes.

const STEP: float = 0.25
const TIME_LIMIT: float = 150.0
const SYNERGY_THRESHOLD: int = 3

var fighters: Array = []
var elapsed: float = 0.0
var finished: bool = false
var winner: int = -1
var events: Array = []
var team_charge: float = 0.0
var burst_used: bool = false
var _accumulator: float = 0.0
var _tick_count: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _synergies: Array = [{}, {}]
var _pending_events: Array = []
var _metrics: Array = [{}, {}]


func start(player_plants: Array, positions: Array, opponent_plants: Array,
		opponent_positions: Array, seed_value: int = 42) -> void:
	fighters.clear()
	elapsed = 0.0
	finished = false
	winner = -1
	events.clear()
	_pending_events.clear()
	team_charge = 0.0
	burst_used = false
	_accumulator = 0.0
	_tick_count = 0
	_rng.seed = seed_value
	_metrics = [{"damage": 0.0, "healing": 0.0, "bursts": 0, "devours": 0},
		{"damage": 0.0, "healing": 0.0, "bursts": 0, "devours": 0}]
	_add_side(player_plants, positions, 0)
	_add_side(opponent_plants, opponent_positions, 1)
	_synergies = [_count_synergies(0), _count_synergies(1)]
	_check_end()


func _add_side(plants: Array, positions: Array, side: int) -> void:
	for i in range(mini(plants.size(), 9)):
		var plant: Dictionary = plants[i].duplicate(true)
		var stats: Dictionary = plant.get("stats", {})
		var max_hp: float = maxf(1.0, float(stats.get("vitality", 100.0)))
		var plant_id: String = str(plant.get("id", "%s_%s" % [side, i]))
		for existing in fighters:
			if str(existing.id) == plant_id:
				plant_id = "%s_%s" % [side, plant_id]
				break
		fighters.append({
			"id": plant_id, "plant": plant, "side": side,
			"cell": int(positions[i]) if i < positions.size() else i,
			"hp": max_hp, "max_hp": max_hp, "energy": 0.0,
			"statuses": {}, "alive": true,
			"cooldown": 1.0 + _rng.randf_range(0.0, 1.5),
		})


func update(delta: float) -> void:
	events = _pending_events.duplicate()
	_pending_events.clear()
	if finished:
		return
	_accumulator += maxf(0.0, delta)
	while _accumulator + 0.000001 >= STEP and not finished:
		_accumulator -= STEP
		_step()


func _step() -> void:
	elapsed = minf(TIME_LIMIT, elapsed + STEP)
	_tick_count += 1
	if not burst_used:
		team_charge = minf(100.0, team_charge + STEP * 4.0)
	# Statuses are applied before growth, so roots can wither while entangled.
	for fighter: Dictionary in fighters:
		if not fighter.alive:
			continue
		_tick_statuses(fighter)
	# Alternate iteration direction; a garden never gets a permanent first strike.
	var indices: Array = range(fighters.size())
	if _tick_count % 2 == 0:
		indices.reverse()
	for index: int in indices:
		var fighter: Dictionary = fighters[index]
		if not fighter.alive:
			continue
		var growth_factor: float = 1.0
		var shade: float = _shade_on(fighter)
		if shade > 0.0:
			growth_factor *= 1.0 - shade
			fighter.statuses["shade"] = shade
		else:
			fighter.statuses.erase("shade")
		if fighter.statuses.has("entangle"):
			growth_factor *= 0.48
		var energy_rate: float = (1.3 + _stat(fighter, "bloom") * 0.065) * growth_factor
		if _has_skill(fighter, "Bloom Burst"):
			energy_rate *= 1.12
		if _has_synergy(int(fighter.side), "Bloom"):
			energy_rate *= 1.25
		fighter.energy = minf(100.0, float(fighter.energy) + energy_rate * STEP)
		fighter.cooldown = float(fighter.cooldown) - STEP * growth_factor
		if float(fighter.energy) >= 100.0:
			_bloom(fighter, false)
		if float(fighter.cooldown) <= 0.0:
			_act(fighter)
			var growth: float = _stat(fighter, "growth")
			fighter.cooldown = clampf(6.0 - growth * 0.07, 2.8, 6.0)
			if _has_synergy(int(fighter.side), "Vine"):
				fighter.cooldown *= 0.90
	if _tick_count % 8 == 0:
		_tick_synergies()
	_check_end()


func _tick_statuses(fighter: Dictionary) -> void:
	var statuses: Dictionary = fighter.statuses
	if statuses.has("toxin"):
		var toxin: Dictionary = statuses.toxin
		toxin.duration = float(toxin.duration) - STEP
		var source: Dictionary = _find_fighter(str(toxin.source))
		_damage(source, fighter, float(toxin.power) * STEP, "toxin", false)
		if float(toxin.duration) <= 0.0:
			statuses.erase("toxin")
	if statuses.has("entangle"):
		statuses.entangle = float(statuses.entangle) - STEP
		if float(statuses.entangle) <= 0.0:
			statuses.erase("entangle")


func _act(fighter: Dictionary) -> void:
	var target: Dictionary = _target(fighter)
	if target.is_empty():
		return
	var plant: Dictionary = fighter.plant
	var kind: String = str(plant.get("type", "Leaf"))
	var damage: float = float(fighter.max_hp) * (0.022 + _stat(fighter, "root") * 0.00025)
	if _has_synergy(int(fighter.side), "Leaf"):
		damage *= 1.16
	# Positions matter: a distant root has further to grow before it can drain tissue.
	var distance: float = _distance(fighter, target)
	damage *= clampf(1.12 - distance * 0.055, 0.72, 1.1)
	match kind:
		"Vine":
			target.statuses["entangle"] = 1.8 + _stat(fighter, "root") * 0.07
			_damage(fighter, target, damage * 0.86, "entangle")
		"Spore":
			for nearby: Dictionary in _alive(1 - int(fighter.side)):
				if _same_side_distance(nearby, target) < 1.5:
					_damage(fighter, nearby, damage * 0.65, "spore")
		"Toxin":
			_damage(fighter, target, damage * 0.5, "toxin")
			_apply_toxin(fighter, target, damage * (0.08 + _stat(fighter, "toxin") * 0.003), 7.0)
		"Parasite":
			var drained: float = _damage(fighter, target, damage * 0.85, "parasite")
			_heal(fighter, fighter, drained * 0.60)
		"Root":
			_damage(fighter, target, damage * 0.8, "root")
			var ally: Dictionary = _wounded_ally(fighter)
			_heal(fighter, ally, damage * 0.35)
		"Carnivorous":
			var threshold: float = 0.24 if _has_synergy(int(fighter.side), "Carnivorous") else 0.18
			if float(target.hp) / float(target.max_hp) <= threshold:
				var consumed: float = _damage(fighter, target, float(target.hp), "devour")
				_heal(fighter, fighter, float(fighter.max_hp) * 0.16 + consumed * 0.3)
				fighter.energy = minf(100.0, float(fighter.energy) + 20.0)
				_metrics[int(fighter.side)].devours += 1
			else:
				_damage(fighter, target, damage * 1.05, "root")
		"Bloom":
			_damage(fighter, target, damage * 0.78, "root")
			fighter.energy = minf(100.0, float(fighter.energy) + 4.0)
		_:
			_damage(fighter, target, damage, "root")
			if _stat(fighter, "shade") >= 12.0:
				_event("shade", fighter, target, _shade_on(target))
	# A hybrid expresses a weaker inherited secondary behavior without replacing its form.
	var secondary: String = str(plant.get("secondary_type", ""))
	if secondary == "Toxin" and kind != "Toxin":
		_apply_toxin(fighter, target, damage * 0.08, 4.0)
	elif secondary == "Vine" and kind != "Vine":
		target.statuses["entangle"] = maxf(float(target.statuses.get("entangle", 0.0)), 1.2)
	elif secondary == "Root" and kind != "Root":
		_heal(fighter, _wounded_ally(fighter), damage * 0.15)
	elif secondary == "Parasite" and kind != "Parasite":
		_heal(fighter, fighter, damage * 0.15)
	elif secondary == "Spore" and kind != "Spore":
		for nearby: Dictionary in _alive(1 - int(fighter.side)):
			if nearby.id != target.id and _same_side_distance(nearby, target) < 1.1:
				_damage(fighter, nearby, damage * 0.16, "spore")
				break
	_express_inherited_skills(fighter, target, damage, kind, secondary)
	fighter.energy = minf(100.0, float(fighter.energy) + 2.0)


func _express_inherited_skills(fighter: Dictionary, target: Dictionary, damage: float,
		kind: String, secondary: String) -> void:
	# A grafted/inherited ability is expressed even when neither type advertises it.
	# The organism's native ability is already represented by its main action.
	if _has_skill(fighter, "Entangle") and kind != "Vine" and secondary != "Vine" and target.alive:
		target.statuses["entangle"] = maxf(float(target.statuses.get("entangle", 0.0)), 1.5)
		_event("entangle", fighter, target, 0.0)
	if _has_skill(fighter, "Root Network") and kind != "Root" and secondary != "Root":
		_heal(fighter, _wounded_ally(fighter), damage * 0.22)
	if _has_skill(fighter, "Spore Cloud") and kind != "Spore" and secondary != "Spore":
		for nearby: Dictionary in _alive(1 - int(fighter.side)):
			if nearby.id != target.id and _same_side_distance(nearby, target) < 1.5:
				_damage(fighter, nearby, damage * 0.24, "spore")
	if _has_skill(fighter, "Toxin Seep") and kind != "Toxin" and secondary != "Toxin":
		_apply_toxin(fighter, target, damage * 0.11, 5.0)
	if _has_skill(fighter, "Parasitic Tendril") and kind != "Parasite" and secondary != "Parasite":
		var drained: float = _damage(fighter, target, damage * 0.12, "parasite")
		_heal(fighter, fighter, drained)
	if _has_skill(fighter, "Devour") and kind != "Carnivorous" and target.alive:
		if float(target.hp) / float(target.max_hp) <= 0.1:
			_damage(fighter, target, float(target.hp), "devour")
			_heal(fighter, fighter, float(fighter.max_hp) * 0.1)
			_metrics[int(fighter.side)].devours += 1


func _bloom(fighter: Dictionary, team: bool) -> void:
	if not fighter.alive:
		return
	var power: float = float(fighter.max_hp) * (0.075 + _stat(fighter, "bloom") * 0.0009)
	if team:
		power *= 1.2
	fighter.energy = 0.0
	_metrics[int(fighter.side)].bursts += 1
	var target: Dictionary = _target(fighter)
	if target.is_empty():
		return
	var kind: String = str(fighter.plant.get("type", "Leaf"))
	match kind:
		"Root", "Leaf":
			for ally: Dictionary in _alive(int(fighter.side)):
				if _same_side_distance(fighter, ally) <= 2.1:
					_heal(fighter, ally, power * (0.8 if kind == "Root" else 0.4))
			_damage(fighter, target, power * 0.7, "bloom")
		"Spore", "Toxin":
			for enemy: Dictionary in _alive(1 - int(fighter.side)):
				if _same_side_distance(enemy, target) <= 1.5:
					_damage(fighter, enemy, power * 0.7, "bloom")
					_apply_toxin(fighter, enemy, power * 0.025, 6.0)
		"Vine":
			for enemy: Dictionary in _alive(1 - int(fighter.side)):
				if _same_side_distance(enemy, target) <= 1.5:
					enemy.statuses["entangle"] = 5.0
			_damage(fighter, target, power, "bloom")
		"Parasite":
			var drained: float = _damage(fighter, target, power * 1.1, "bloom")
			_heal(fighter, fighter, drained * 0.8)
		_:
			_damage(fighter, target, power * (1.6 if kind == "Bloom" else 1.15), "bloom")


func team_burst() -> bool:
	if finished or burst_used or team_charge < 100.0:
		return false
	burst_used = true
	team_charge = 0.0
	var previous_count: int = events.size()
	for fighter: Dictionary in _alive(0):
		_bloom(fighter, true)
	# Preserve the intervention's effects until the next frame consumes its events.
	for i in range(previous_count, events.size()):
		_pending_events.append(events[i])
	_check_end()
	return true


func _tick_synergies() -> void:
	for side in range(2):
		var alive_allies: Array = _alive(side)
		if alive_allies.is_empty():
			continue
		var source: Dictionary = alive_allies[0]
		if _has_synergy(side, "Root"):
			for ally: Dictionary in alive_allies:
				_heal(source, ally, float(ally.max_hp) * 0.007)
		if _has_synergy(side, "Toxin"):
			for enemy: Dictionary in _alive(1 - side):
				_apply_toxin(source, enemy, float(enemy.max_hp) * 0.0018, 2.5)
		if _has_synergy(side, "Spore"):
			for enemy: Dictionary in _alive(1 - side):
				_damage(source, enemy, float(enemy.max_hp) * 0.003, "spore")
		if _has_synergy(side, "Parasite"):
			_heal(source, _wounded_ally(source), float(source.max_hp) * 0.012)


func _apply_toxin(source: Dictionary, target: Dictionary, power: float, duration: float) -> void:
	if not target.alive:
		return
	var previous: Dictionary = target.statuses.get("toxin", {})
	target.statuses["toxin"] = {
		"power": maxf(float(previous.get("power", 0.0)), power),
		"duration": maxf(float(previous.get("duration", 0.0)), duration),
		"source": str(source.get("id", "")),
	}


func _damage(source: Dictionary, target: Dictionary, amount: float, kind: String,
		emit: bool = true) -> float:
	if not bool(target.get("alive", false)):
		return 0.0
	var actual: float = minf(float(target.hp), maxf(0.0, amount))
	target.hp = maxf(0.0, float(target.hp) - actual)
	if not source.is_empty():
		_metrics[int(source.side)].damage += actual
	if emit:
		_event(kind, source, target, actual)
	if float(target.hp) <= 0.0:
		target.alive = false
		target.energy = 0.0
		target.statuses.clear()
		_event("wither", source, target, 0.0)
	return actual


func _heal(source: Dictionary, target: Dictionary, amount: float) -> void:
	if target.is_empty() or not bool(target.get("alive", false)):
		return
	var actual: float = minf(float(target.max_hp) - float(target.hp), maxf(0.0, amount))
	if actual <= 0.001:
		return
	target.hp = float(target.hp) + actual
	_metrics[int(source.side)].healing += actual
	_event("root", source, target, -actual)


func _event(kind: String, source: Dictionary, target: Dictionary, amount: float) -> void:
	events.append({"kind": kind, "source": str(source.get("id", "")),
		"target": str(target.get("id", "")), "amount": amount})


func _stat(fighter: Dictionary, name: String) -> float:
	var stats: Dictionary = fighter.plant.get("stats", {})
	return float(stats.get(name, 10.0))


func _has_skill(fighter: Dictionary, skill: String) -> bool:
	var skills: Array = fighter.plant.get("skills", [])
	return skills.has(skill)


func _target(fighter: Dictionary) -> Dictionary:
	var target: Dictionary = {}
	var best: float = INF
	for enemy: Dictionary in _alive(1 - int(fighter.side)):
		var score: float = _distance(fighter, enemy)
		# A searching trap senses nearby weakened tissue; it cannot ignore the bed layout.
		if str(fighter.plant.get("type", "")) == "Carnivorous":
			score += float(enemy.hp) / float(enemy.max_hp) * 0.55
		if score < best:
			best = score
			target = enemy
	return target


func _wounded_ally(fighter: Dictionary) -> Dictionary:
	var ally: Dictionary = fighter
	var lowest: float = float(fighter.hp) / float(fighter.max_hp)
	for candidate: Dictionary in _alive(int(fighter.side)):
		if _same_side_distance(candidate, fighter) <= 1.5:
			var ratio: float = float(candidate.hp) / float(candidate.max_hp)
			if ratio < lowest:
				lowest = ratio
				ally = candidate
	return ally


func _shade_on(fighter: Dictionary) -> float:
	var amount: float = 0.0
	for enemy: Dictionary in _alive(1 - int(fighter.side)):
		if _distance(enemy, fighter) <= 2.5:
			amount += _stat(enemy, "shade") * (0.009 if _has_skill(enemy, "Canopy Shade") else 0.006)
	return minf(0.38, amount)


func _world_cell(fighter: Dictionary) -> Vector2:
	var cell: int = int(fighter.cell)
	var y: float = float(cell / 3)
	if int(fighter.side) == 0:
		y += 3.0
	return Vector2(float(cell % 3), y)


func _distance(a: Dictionary, b: Dictionary) -> float:
	return _world_cell(a).distance_to(_world_cell(b))


func _same_side_distance(a: Dictionary, b: Dictionary) -> float:
	return _world_cell(a).distance_to(_world_cell(b))


func _alive(side: int) -> Array:
	var result: Array = []
	for fighter: Dictionary in fighters:
		if int(fighter.side) == side and bool(fighter.alive):
			result.append(fighter)
	return result


func _find_fighter(fighter_id: String) -> Dictionary:
	for fighter: Dictionary in fighters:
		if str(fighter.id) == fighter_id:
			return fighter
	return {}


func _count_synergies(side: int) -> Dictionary:
	var counts: Dictionary = {}
	for fighter: Dictionary in fighters:
		if int(fighter.side) != side:
			continue
		var kind: String = str(fighter.plant.get("type", "Leaf"))
		counts[kind] = int(counts.get(kind, 0)) + 1
		var secondary: String = str(fighter.plant.get("secondary_type", ""))
		if not secondary.is_empty() and secondary != kind:
			counts[secondary] = int(counts.get(secondary, 0)) + 1
	return counts


func _has_synergy(side: int, kind: String) -> bool:
	return int(_synergies[side].get(kind, 0)) >= SYNERGY_THRESHOLD


func get_synergies(side: int) -> Dictionary:
	return _synergies[clampi(side, 0, 1)].duplicate()


func remaining(side: int) -> float:
	var hp: float = 0.0
	for fighter: Dictionary in _alive(side):
		hp += float(fighter.hp)
	return hp


func _check_end() -> void:
	var left: float = remaining(0)
	var right: float = remaining(1)
	if left <= 0.0 or right <= 0.0 or elapsed >= TIME_LIMIT:
		finished = true
		winner = 0 if left > right else (1 if right > left else -1)


func summary() -> String:
	var side: int = winner if winner >= 0 else 0
	var metrics: Dictionary = _metrics[side]
	var active: Array = []
	for kind: String in _synergies[side]:
		if int(_synergies[side][kind]) >= SYNERGY_THRESHOLD:
			active.append(kind)
	var text: String = "The roots grew quiet after %d seconds. " % int(elapsed)
	if not active.is_empty():
		text += "%s synergy shaped this garden. " % ", ".join(active)
	if int(metrics.devours) > 0:
		text += "%d weakened plants were devoured. " % int(metrics.devours)
	if float(metrics.healing) >= 1.0:
		text += "Connected growth restored %d vitality. " % int(metrics.healing)
	text += "%d bloom events; %d vitality remains." % [int(metrics.bursts), int(remaining(side))]
	return text
