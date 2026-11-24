extends SceneTree
## Draws simulated attempts (geometry + grown plant) into screenshots/debug.png
## godot --path . --quit-after 2000 --script res://tests/debug_draw.gd -- 0:none 2:thorns ...

const Session := preload("res://scripts/session.gd")
const Levels := preload("res://scripts/levels.gd")

class Drawer extends Node2D:
	var sessions: Array = []
	var labels: Array = []
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		for i in sessions.size():
			var s = sessions[i]
			var ox := (i % 4) * 400.0
			var oy := int(i / 4) * 260.0
			draw_set_transform(Vector2(ox, oy), 0, Vector2(0.25, 0.25))
			draw_rect(Rect2(0, 0, 1600, 1000), Color(0.08, 0.1, 0.14))
			for d in s.world.darks: draw_circle(d.pos, d.r, Color(0, 0, 0, 0.8))
			for w in s.world.waters: draw_rect(w, Color(0.2, 0.4, 0.9))
			for r in s.world.rocks: draw_colored_polygon(r.poly, Color(0.6, 0.75, 0.9) if r.slick else (Color(0.35, 0.27, 0.2) if r.soil else Color(0.45, 0.45, 0.5)))
			for c in s.world.crystals:
				if c.alive: draw_colored_polygon(c.poly, Color(0.5, 0.9, 1.0))
			for g in s.world.goals: draw_circle(g.pos, g.r, Color(1, 0.9, 0.3) if not g.reached else Color(1, 0.4, 0.8))
			for l in s.world.lures: draw_circle(l, 20, Color(0.3, 1, 1))
			for w in s.world.wilds:
				for p in w.nodes: draw_circle(p, 6, Color(1, 0.5, 0.2) if not w.pollinated else Color(1, 1, 1))
			var pl = s.plant
			for n in range(1, pl.pos.size()):
				if pl.alive[n] == 1 and pl.parent[n] >= 0:
					draw_line(pl.pos[pl.parent[n]], pl.pos[n], Color(0.4, 1, 0.4) if pl.kind[n] == 0 else Color(0.9, 0.8, 0.6), 6)
			for t in pl.tips:
				var col := Color.WHITE
				match t.state:
					"stopped": col = Color.RED
					"stalled": col = Color.BLUE
				draw_circle(pl.pos[t.node], 10, col)
			draw_set_transform(Vector2(ox, oy), 0, Vector2.ONE)
			draw_string(font, Vector2(6, 16), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1600, 520)
	var d := Drawer.new()
	root.add_child(d)
	var args := OS.get_cmdline_user_args()
	for a in args:
		var parts: PackedStringArray = a.split(":")
		var idx := int(parts[0])
		var g := Levels.starter().duplicate(true)
		var lures: Array = []
		for t in parts[1].split(","):
			if t in ["thorns", "glow", "tendrils", "roots"]: g[t] = 1
		if parts.size() > 2 and parts[2] != "":
			for l in parts[2].split(";"):
				var xy := l.split(",")
				lures.append(Vector2(float(xy[0]), float(xy[1])))
		var prune: Array = []
		if parts.size() > 3:
			var v := parts[3].split(",")
			prune = [float(v[0]), Vector2(float(v[1]), float(v[2])), Vector2(float(v[3]), float(v[4]))]
		var s = Session.new()
		s.start(Levels.all()[idx], g, 1)
		for l in lures: s.add_lure(l)
		var t := 0.0
		while t < 90.0 and not s.won() and not s.stuck():
			s.step(1.0 / 30.0)
			t += 1.0 / 30.0
			if not prune.is_empty() and t >= prune[0]:
				s.prune(prune[1], prune[2])
				prune = []
		d.sessions.append(s)
		d.labels.append("%s won=%s e=%d" % [a, s.won(), int(s.plant.energy)])
	d.queue_redraw()
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/debug.png")
	quit()
