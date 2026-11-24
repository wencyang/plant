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
	expect("2 Twin Wells: prune to split + lures", attempt(1, base, [Vector2(330, 420), Vector2(1270, 420)], [1, 2, 3], [[2.2, Vector2(700, 780), Vector2(900, 780)]]), true)
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
	# crossing guarantees
	var rng := RandomNumberGenerator.new()
	var kids := Genome.cross(with_traits(["thorns"]), Levels.wild("Lanternwort"), rng)
	var k0: Dictionary = kids[0]
	if not (int(k0.thorns) == 1 and int(k0.glow) == 1): failures += 1; print("FAIL first seed carries both gifts")
	print("SOLVE TEST: ", "OK" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures else 0)
