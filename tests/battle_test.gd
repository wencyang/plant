extends SceneTree

const Sim = preload("res://scripts/battle_sim.gd")


func _initialize() -> void:
	var players: Array = [_plant("p1", "Leaf"), _plant("p2", "Bloom"), _plant("p3", "Vine")]
	var opponents: Array = [_plant("e1", "Root"), _plant("e2", "Toxin"), _plant("e3", "Spore")]
	var snapshot: Array = players.duplicate(true)
	var fine = Sim.new()
	var coarse = Sim.new()
	fine.start(players, [0, 4, 8], opponents, [2, 4, 6], 345)
	coarse.start(players, [0, 4, 8], opponents, [2, 4, 6], 345)
	for i in range(700):
		fine.update(0.1)
	for i in range(70):
		coarse.update(1.0)
	assert(fine.elapsed == coarse.elapsed, "Playback frame size changed elapsed simulation time")
	for i in range(fine.fighters.size()):
		assert(is_equal_approx(float(fine.fighters[i].hp), float(coarse.fighters[i].hp)), "Playback speed changed combat outcome")
	assert(players == snapshot, "Battle modified a saved garden specimen")
	assert(fine.team_charge == 100.0, "Team burst did not charge")
	assert(fine.team_burst(), "Charged burst could not be triggered")
	assert(not fine.team_burst(), "Team intervention was reusable")
	while not fine.finished:
		fine.update(1.0)
	assert(fine.elapsed <= 150.0)
	assert(not fine.summary().is_empty())
	var root_team: Array = [_plant("r1", "Root"), _plant("r2", "Root"), _plant("r3", "Root")]
	var synergy = Sim.new()
	synergy.start(root_team, [0, 1, 2], opponents, [6, 7, 8])
	assert(int(synergy.get_synergies(0).get("Root", 0)) == 3)
	for i in range(200):
		synergy.update(0.5)
	assert(float(synergy._metrics[0].healing) > 0.0, "Shared root network never restored vitality")
	# Rearrangement changes which organism a root can reach first.
	var reach = Sim.new()
	reach.start([_plant("searcher", "Leaf")], [0], [_plant("far", "Root"), _plant("near", "Root")], [0, 6])
	assert(str(reach._target(reach.fighters[0]).id) == "near")
	var empty = Sim.new()
	empty.start([], [], opponents, [0, 1, 2])
	assert(empty.finished and empty.winner == 1)
	print("Battle tests passed: deterministic playback, preserved specimens, one intervention, positioning, synergy, resolution.")
	quit(0)


func _plant(id: String, type: String) -> Dictionary:
	return {"id": id, "name": id, "type": type, "secondary_type": "", "seed": 1,
		"stats": {"vitality": 100, "growth": 10, "root": 10, "toxin": 10, "bloom": 10, "shade": 5},
		"genes": {}, "skills": []}
