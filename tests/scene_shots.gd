extends SceneTree
## Screens for the refinement pass.
const Main := preload("res://scripts/main.gd")
const Levels := preload("res://scripts/levels.gd")
var game
func _initialize() -> void:
	call_deferred("run")
func traits(t: Array) -> Dictionary:
	var g := Levels.starter().duplicate(true)
	for x in t: g[x] = 1
	return g
func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/%s.png" % name)
	print("CAPTURED ", name)
func shot(idx: int, g: Dictionary, name: String, secs: float, lures := [], hide_wild := true) -> void:
	game._start_level(idx, g)
	if hide_wild:
		for w in game.session.world.wilds: w.pollinated = true
	for l in lures: game._place_lure(l)
	await create_timer(secs).timeout
	await snap(name)
func run() -> void:
	root.size = Vector2i(1600, 1000)
	game = Main.new()
	root.add_child(game)
	game.save.path = "user://scene_shots.json"
	game.save.stars = {}
	game.sfx.muted = true
	await create_timer(0.5).timeout
	await shot(0, Levels.starter(), "21-reach-ring", 3.0)
	await shot(8, Levels.starter(), "22-droop-label", 8.0)
	await shot(14, Levels.starter(), "23-lockstone", 12.0, [Vector2(640, 930)])
	await shot(15, Levels.starter(), "24-false-dawn", 6.0)
	await shot(16, Levels.starter(), "25-updraft", 9.0, [Vector2(1040, 800)])
	await shot(17, Levels.starter(), "26-two-keys", 11.0, [Vector2(520, 838), Vector2(860, 785)])
	await shot(18, traits(["glow"]), "27-sunken-bloom", 10.0, [Vector2(745, 660)])
	await shot(20, traits(["glow", "waxy"]), "28-heartwood", 16.0, [Vector2(515, 820), Vector2(1200, 420)])
	game._start_level(0, Levels.starter())
	for w in game.session.world.wilds: w.pollinated = true
	game.fast = true
	await create_timer(16.0).timeout
	await snap("29-win-stars")
	game.fast = false
	for i in 12: game.save.completed[Levels.all()[i].id] = true
	game.save.stars = {"first_light": [true, true, false], "twin_wells": [true, true, true], "crystal_throat": [true, false, true]}
	game.show_map()
	await create_timer(1.0).timeout
	await snap("30-map-stars")
	quit()
