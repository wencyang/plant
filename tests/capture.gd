extends SceneTree
## Drives the real game and saves screenshots/.
## godot --path . --quit-after 20000 --script res://tests/capture.gd

const Main := preload("res://scripts/main.gd")
const Levels := preload("res://scripts/levels.gd")
var game

func _initialize() -> void:
	call_deferred("run")

func wait(s: float) -> void:
	await create_timer(s).timeout

func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/%s.png" % name)
	print("CAPTURED ", name)

func traits(t: Array) -> Dictionary:
	var g := Levels.starter().duplicate(true)
	for x in t: g[x] = 1
	return g

func run() -> void:
	root.size = Vector2i(1600, 1000)
	var SaveData := load("res://scripts/save_data.gd")
	game = Main.new()
	root.add_child(game)
	game.save.path = "user://capture.json"
	game.save.seeds = [Levels.starter()]
	game.save.completed = {}
	game.sfx.muted = true
	await wait(6.0)
	await snap("01-title")
	game.show_map()
	await wait(1.0)
	await snap("02-map")
	game.show_level_intro(0)
	await wait(1.0)
	await snap("03-seed-choice")
	game._start_level(0, Levels.starter())
	await wait(7.0)
	await snap("04-first-light-growing")
	game.fast = true
	await wait(10.0)
	await snap("05-first-light-bloomed")
	# crystal throat: lure to the Spinebrush -> pollinate -> reveal
	game.fast = true
	game._start_level(2, Levels.starter())
	game._place_lure(Vector2(560, 720))
	await wait(9.0)
	await snap("06-pollinating")
	await wait(4.0)
	await snap("07-cross-reveal")
	game._close_overlay()
	game.paused = false
	# lanternless with a glowing seed
	game._start_level(3, traits(["glow"]))
	await wait(10.0)
	await snap("08-lanternless-glow")
	# glass cliff with tendrils
	game._start_level(4, traits(["tendrils"]))
	await wait(9.0)
	await snap("09-glass-cliff")
	# thirst with roots
	game._start_level(5, traits(["roots"]))
	await wait(9.0)
	await snap("10-thirst-roots")
	# finale
	game._start_level(7, traits(["thorns", "glow", "tendrils"]))
	game._place_lure(Vector2(1290, 570))
	await wait(14.0)
	await snap("11-heart-grove")
	game.save.seeds = [Levels.starter(), traits(["thorns"]), traits(["glow"]), Levels.wild("Hookvine"), Levels.wild("Lanternwort"), traits(["thorns", "glow", "tendrils"])]
	game.show_vault(false)
	await wait(1.0)
	await snap("12-vault")
	quit()
