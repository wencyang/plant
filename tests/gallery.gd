extends SceneTree
## Plant gallery: founders + wild species + hybrids, with bloom.
## godot --path . --quit-after 600 --script res://tests/gallery.gd

const PlantSim := preload("res://scripts/plant_sim.gd")
const PlantView := preload("res://scripts/view/plant_view.gd")
const Levels := preload("res://scripts/levels.gd")
const Genome := preload("res://scripts/genome.gd")

func _initialize() -> void:
	call_deferred("run")

func grown(g: Dictionary, energy: float, seed_value: int):
	var s = PlantSim.new()
	s.setup(g, null, energy, seed_value, true)
	s.grow_wild(energy, Vector2.ZERO)
	return s

func run() -> void:
	root.size = Vector2i(1600, 1000)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_bloom = 0.08
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	e.set_glow_level(2, 1.0)
	e.set_glow_level(3, 0.8)
	e.set_glow_level(4, 0.6)
	env.environment = e
	root.add_child(env)
	var bg := ColorRect.new()
	bg.size = Vector2(1600, 1000)
	bg.color = Color(0.05, 0.06, 0.1)
	root.add_child(bg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var founders := [Levels.starter(), Levels.wild("Spinebrush"), Levels.wild("Lanternwort"), Levels.wild("Hookvine"), Levels.wild("Deeproot")]
	var row2: Array = []
	row2.append(Genome.cross(founders[0], founders[1], rng)[0])
	row2.append(Genome.cross(founders[0], founders[2], rng)[0])
	row2.append(Genome.cross(founders[0], founders[3], rng)[0])
	var tg: Dictionary = Genome.cross(founders[0], founders[1], rng)[0]
	var tgk: Dictionary = Genome.cross(tg, founders[2], rng)[0]
	row2.append(tgk)
	row2.append(Genome.cross(tgk, founders[3], rng)[0])
	var all: Array = founders + row2
	for i in all.size():
		var v := PlantView.new()
		root.add_child(v)
		v.position = Vector2(160 + (i % 5) * 320, 470 if i < 5 else 960)
		v.setup(grown(all[i], 380.0, 11 + i), true)
		v.preview = true
		var l := Label.new()
		l.text = "%s  G%d  %s" % [all[i].name, all[i].gen, ", ".join(Genome.traits(all[i]))]
		l.position = v.position + Vector2(-140, 6)
		l.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
		root.add_child(l)
	for f in 90: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/gallery.png")
	quit()
