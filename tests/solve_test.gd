extends SceneTree
## Verifies every puzzle: solvable with the intended genes (+ scripted lures),
## and NOT solvable without the gating gift.
## godot --headless --path . --script res://tests/solve_test.gd

const Session := preload("res://scripts/session.gd")
const Levels := preload("res://scripts/levels.gd")
const Genome := preload("res://scripts/genome.gd")

var failures := 0

func with_traits(traits: Array) -> Dictionary:
	var g := Levels.starter().duplicate(true)
	for t in traits: g[t] = 1
	return g

func attempt(index: int, genome: Dictionary, lures: Array, seeds := [1, 2, 3], prunes := []) -> Dictionary:
	var best := {"won": false, "goals": 0, "pollinated": 0}
	for s in seeds:
		var ses = Session.new()
		ses.start(Levels.all()[index], genome, s)
		for l in lures: ses.add_lure(l)
		var t := 0.0
		var pending: Array = prunes.duplicate()
		while t < 90.0 and not ses.won() and not ses.stuck():
			ses.step(1.0 / 30.0)
			t += 1.0 / 30.0
			while not pending.is_empty() and t >= float(pending[0][0]):
				var pr: Array = pending.pop_front()
				ses.prune(pr[1], pr[2])
		var goals := 0
		for g in ses.world.goals:
			if g.reached: goals += 1
		var pol := 0
		for w in ses.world.wilds:
			if w.pollinated: pol += 1
		if ses.won(): return {"won": true, "goals": goals, "pollinated": pol, "time": t, "seed": s}
		if goals >= best.goals: best = {"won": false, "goals": goals, "pollinated": max(pol, best.pollinated), "time": t}
	return best

func expect(name: String, r: Dictionary, should_win: bool) -> void:
	var ok: bool = r.won == should_win
	if not ok: failures += 1
	print("%s %-44s won=%s goals=%d pollinated=%d t=%.1f" % ["ok  " if ok else "FAIL", name, r.won, r.goals, r.pollinated, r.get("time", 0.0)])

func expect_pollinate(name: String, r: Dictionary) -> void:
	var ok: bool = r.pollinated > 0
	if not ok: failures += 1
	print("%s %-44s pollinated=%d" % ["ok  " if ok else "FAIL", name, r.pollinated])

func _initialize() -> void:
	var L := Levels.all()
	var base := Levels.starter()
	expect("1 First Light: starter, no lure", attempt(0, base, []), true)
	expect("2 Twin Wells: starter, no prune fails", attempt(1, base, []), false)
	for tt in [1.4, 2.0, 2.8, 3.6]:
		expect("2 Twin Wells: one prune at %.1fs" % tt, attempt(1, base, [], [1, 2, 3], [[tt, Vector2(720, 770), Vector2(880, 770)]]), true)
	expect("3 Crystal Throat: starter fails", attempt(2, base, []), false)
	expect_pollinate("3 Crystal Throat: lure reaches Spinebrush", attempt(2, base, [Vector2(330, 520)]))
	expect("3 Crystal Throat: thorns", attempt(2, with_traits(["thorns"]), []), true)
	expect("4 Lanternless: starter fails", attempt(3, base, []), false)
	expect_pollinate("4 Lanternless: lure reaches Lanternwort", attempt(3, base, [Vector2(740, 420)]))
	expect("4 Lanternless: best lure without glow fails", attempt(3, base, [Vector2(770, 400)]), false)
	expect("4 Lanternless: glow", attempt(3, with_traits(["glow"]), []), true)
	expect("5 Glass Cliff: starter fails", attempt(4, base, []), false)
	expect_pollinate("5 Glass Cliff: lure reaches Hookvine", attempt(4, base, [Vector2(540, 500)]))
	expect("5 Glass Cliff: tendrils", attempt(4, with_traits(["tendrils"]), []), true)
	expect("6 Thirst: starter fails", attempt(5, base, []), false)
	expect_pollinate("6 Thirst: lure reaches Deeproot", attempt(5, base, [Vector2(560, 720)]))
	expect("6 Thirst: roots", attempt(5, with_traits(["roots"]), []), true)
	expect("7 Spire: thorns only fails", attempt(6, with_traits(["thorns"]), []), false)
	expect("7 Spire: glow only fails", attempt(6, with_traits(["glow"]), []), false)
	expect_pollinate("7 Spire: lure reaches Lanternwort", attempt(6, with_traits(["thorns"]), [Vector2(620, 700)]))
	expect("7 Spire: thorns+glow", attempt(6, with_traits(["thorns", "glow"]), []), true)
	expect("8 Heart: thorns+glow fails", attempt(7, with_traits(["thorns", "glow"]), [Vector2(1290, 570)]), false)
	expect_pollinate("8 Heart: lure reaches Hookvine", attempt(7, with_traits(["thorns", "glow"]), [Vector2(380, 700)]))
	expect("8 Heart: all three", attempt(7, with_traits(["thorns", "glow", "tendrils"]), [Vector2(1290, 570)]), true)
	# ---- new gardens
	expect("9 Drift Chasm: starter fails", attempt(8, base, []), false)
	expect_pollinate("9 Drift Chasm: starter reaches Driftcap", attempt(8, base, []))
	expect("9 Drift Chasm: buoyant", attempt(8, with_traits(["buoyant"]), []), true)
	expect("10 Ember Vents: starter fails", attempt(9, base, []), false)
	expect_pollinate("10 Ember Vents: starter reaches Emberwax", attempt(9, base, []))
	expect("10 Ember Vents: waxy", attempt(9, with_traits(["waxy"]), []), true)
	expect("11 Moon Garden: roots only fails", attempt(10, with_traits(["roots"]), []), false)
	expect("11 Moon Garden: glow only fails", attempt(10, with_traits(["glow"]), []), false)
	expect_pollinate("11 Moon Garden: starter reaches Moonpetal", attempt(10, base, []))
	expect("11 Moon Garden: glow+roots", attempt(10, with_traits(["glow", "roots"]), []), true)
	expect("12 Briar Gate: thorns only fails", attempt(11, with_traits(["thorns"]), []), false)
	expect("12 Briar Gate: tendrils only fails", attempt(11, with_traits(["tendrils"]), []), false)
	expect_pollinate("12 Briar Gate: lure reaches Briarbell", attempt(11, base, [Vector2(880, 690)]))
	expect("12 Briar Gate: thorns+tendrils", attempt(11, with_traits(["thorns", "tendrils"]), []), true)
	expect("13 Coral Steps: no prune fails", attempt(12, base, []), false)
	expect("13 Coral Steps: one prune after first well", attempt(12, base, [], [1, 2, 3], [[5.0, Vector2(720, 800), Vector2(880, 800)]]), true)
	expect("14 Long Bloom: glow+buoyant fails", attempt(13, with_traits(["glow", "buoyant"]), []), false)
	expect("14 Long Bloom: waxy+buoyant fails", attempt(13, with_traits(["waxy", "buoyant"]), []), false)
	expect_pollinate("14 Long Bloom: glow seed reaches Driftcap", attempt(13, with_traits(["glow"]), []))
	expect_pollinate("14 Long Bloom: lure reaches Emberwax", attempt(13, with_traits(["glow"]), [Vector2(340, 700)]))
	expect("14 Long Bloom: all three + lure", attempt(13, with_traits(["glow", "buoyant", "waxy"]), [Vector2(1180, 760)]), true)
	expect("14 Long Bloom: glow+buoyant + lure fails", attempt(13, with_traits(["glow", "buoyant"]), [Vector2(1180, 760)]), false)
	# ---- trick gardens
	expect("15 Lockstone: no lure fails", attempt(14, base, []), false)
	expect("15 Lockstone: lure in pit", attempt(14, base, [Vector2(640, 930)]), true)
	expect("16 False Dawn: no lure fails", attempt(15, base, []), false)
	expect("16 False Dawn: lure", attempt(15, base, [Vector2(1000, 560)]), true)
	expect("17 Updraft Spires: no lure fails", attempt(16, base, []), false)
	expect("17 Updraft Spires: lure into updraft", attempt(16, base, [Vector2(1040, 800)]), true)
	expect("18 Two Keys: no lures fails", attempt(17, base, []), false)
	expect("18 Two Keys: one lure fails", attempt(17, base, [Vector2(520, 838)]), false)
	expect("18 Two Keys: two lures as waypoints", attempt(17, base, [Vector2(520, 838), Vector2(860, 785)]), true)
	expect("19 Sunken Bloom: starter + lure fails", attempt(18, base, [Vector2(745, 660)]), false)
	expect_pollinate("19 Sunken Bloom: reaches Lanternwort", attempt(18, base, [Vector2(200, 400)]))
	expect("19 Sunken Bloom: glow + lure", attempt(18, with_traits(["glow"]), [Vector2(745, 660)]), true)
	expect("20 Mirror Wells: no prune fails", attempt(19, base, []), false)
	expect("20 Mirror Wells: prunes", attempt(19, base, [], [1, 2, 3], [[4.0, Vector2(720, 800), Vector2(880, 800)], [8.0, Vector2(720, 760), Vector2(880, 760)]]), true)
	expect("21 Heartwood: glow only fails", attempt(20, with_traits(["glow"]), [Vector2(515, 820), Vector2(1200, 420)]), false)
	expect("21 Heartwood: glow+waxy, no updraft lure fails", attempt(20, with_traits(["glow", "waxy"]), [Vector2(1200, 420)]), false)
	expect("21 Heartwood: glow+waxy", attempt(20, with_traits(["glow", "waxy"]), [Vector2(515, 820), Vector2(1200, 420)]), true)
	# crossing guarantees
	var rng := RandomNumberGenerator.new()
	var kids := Genome.cross(with_traits(["thorns"]), Levels.wild("Lanternwort"), rng)
	var k0: Dictionary = kids[0]
	if not (int(k0.thorns) == 1 and int(k0.glow) == 1): failures += 1; print("FAIL first seed carries both gifts")
	# every dew must sit in open air, inside the garden
	var WorldSim := load("res://scripts/world_sim.gd")
	for LV in Levels.all():
		var w = WorldSim.new()
		w.load_level(LV)
		for d in w.dews:
			var inside := false
			for r in w.rocks:
				if Geometry2D.is_point_in_polygon(d.pos, r.poly): inside = true
			if inside or not Rect2(10, 10, 1580, 980).has_point(d.pos):
				failures += 1
				print("FAIL dew inside rock/out of bounds in ", LV.id, " at ", d.pos)
	print("SOLVE TEST: ", "OK" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures else 0)
